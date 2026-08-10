import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:docflow/models/document.dart';
import 'package:docflow/services/file_store.dart';

/// The store is where a user's only copy of a converted file lives — the
/// backend keeps nothing. These run against a real SQLite database and a real
/// temp directory rather than mocks, because the failures worth catching here
/// (name collisions, orphaned rows, path escapes) are filesystem behaviour.
void main() {
  late Directory sandbox;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('docflow-store-');
    FileStore.debugOverrideDirectories(
      documents: sandbox,
      databasePath: sandbox.path,
    );
  });

  tearDown(() async {
    await FileStore.instance.debugReset();
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  Uint8List bytes(String content) => Uint8List.fromList(content.codeUnits);

  group('save', () {
    test('writes the bytes and records the row', () async {
      final store = FileStore.instance;

      final stored = await store.save(
        bytes: bytes('%PDF-1.7 hello'),
        filename: 'Contract.pdf',
        toolId: 'word-to-pdf',
        sourceName: 'Contract.docx',
      );

      expect(stored.name, 'Contract.pdf');
      expect(stored.sizeBytes, 14);
      expect(stored.toolId, 'word-to-pdf');
      expect(stored.sourceName, 'Contract.docx');
      expect(await File(stored.path).exists(), isTrue);
      expect(await File(stored.path).readAsString(), '%PDF-1.7 hello');

      final all = await store.all();
      expect(all, hasLength(1));
      expect(all.first.id, stored.id);
    });

    test('keeps both results when the same name is saved twice', () async {
      final store = FileStore.instance;

      final first =
          await store.save(bytes: bytes('one'), filename: 'Report.pdf', toolId: 't');
      final second =
          await store.save(bytes: bytes('two'), filename: 'Report.pdf', toolId: 't');

      expect(first.name, 'Report.pdf');
      expect(second.name, 'Report (2).pdf');
      // The first file must survive — overwriting would destroy a conversion
      // the user already paid a quota credit for.
      expect(await File(first.path).readAsString(), 'one');
      expect(await File(second.path).readAsString(), 'two');
      expect(await store.count(), 2);
    });

    test('strips path separators from a server-supplied name', () async {
      final store = FileStore.instance;

      // The filename arrives in a Content-Disposition header, so it is
      // untrusted. Separators are replaced rather than the dots stripped, so
      // ".." can survive as literal text — what matters is that the resolved
      // path cannot escape the DocFlow directory.
      final stored = await store.save(
        bytes: bytes('x'),
        filename: '../../etc/passwd',
        toolId: 't',
      );

      expect(stored.name, isNot(contains('/')));
      expect(stored.name, isNot(contains('\\')));
      expect(p.dirname(stored.path), p.join(sandbox.path, 'DocFlow'));
      // Belt and braces: the canonical path is still inside the sandbox.
      expect(
        p.canonicalize(stored.path),
        startsWith(p.canonicalize(p.join(sandbox.path, 'DocFlow'))),
      );
    });

    test('falls back to a usable name when the header is junk', () async {
      final stored = await FileStore.instance
          .save(bytes: bytes('x'), filename: '..', toolId: 't');

      expect(stored.name, 'converted.pdf');
    });
  });

  group('listing', () {
    test('returns newest first and honours the recent limit', () async {
      final store = FileStore.instance;

      for (final name in ['A.pdf', 'B.pdf', 'C.pdf', 'D.pdf']) {
        await store.save(bytes: bytes(name), filename: name, toolId: 't');
        // created_at has millisecond resolution; without a gap the ordering
        // of same-millisecond rows is not deterministic.
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final all = await store.all();
      expect(all.map((f) => f.name), ['D.pdf', 'C.pdf', 'B.pdf', 'A.pdf']);

      final recent = await store.recent(limit: 2);
      expect(recent.map((f) => f.name), ['D.pdf', 'C.pdf']);
    });

    test('totals the stored bytes', () async {
      final store = FileStore.instance;
      await store.save(bytes: bytes('12345'), filename: 'a.pdf', toolId: 't');
      await store.save(bytes: bytes('123'), filename: 'b.pdf', toolId: 't');

      expect(await store.totalBytes(), 8);
    });
  });

  group('rename', () {
    test('moves the file and keeps the extension', () async {
      final store = FileStore.instance;
      final stored =
          await store.save(bytes: bytes('x'), filename: 'Old.pdf', toolId: 't');

      final renamed = await store.rename(stored, 'Quarterly Report');

      expect(renamed, isNotNull);
      expect(renamed!.name, 'Quarterly Report.pdf');
      expect(await File(renamed.path).exists(), isTrue);
      expect(await File(stored.path).exists(), isFalse);

      final all = await store.all();
      expect(all, hasLength(1));
      expect(all.first.name, 'Quarterly Report.pdf');
    });

    test('refuses an empty name', () async {
      final store = FileStore.instance;
      final stored =
          await store.save(bytes: bytes('x'), filename: 'Keep.pdf', toolId: 't');

      expect(await store.rename(stored, '   '), isNull);
      expect((await store.all()).first.name, 'Keep.pdf');
    });
  });

  group('delete and prune', () {
    test('removes both the row and the bytes', () async {
      final store = FileStore.instance;
      final stored =
          await store.save(bytes: bytes('x'), filename: 'Gone.pdf', toolId: 't');

      await store.delete(stored);

      expect(await File(stored.path).exists(), isFalse);
      expect(await store.count(), 0);
    });

    test('drops the row even when the file already vanished', () async {
      final store = FileStore.instance;
      final stored =
          await store.save(bytes: bytes('x'), filename: 'Ghost.pdf', toolId: 't');
      await File(stored.path).delete();

      await store.delete(stored);

      expect(await store.count(), 0);
    });

    test('pruneMissing clears rows orphaned by cleared storage', () async {
      final store = FileStore.instance;
      final kept =
          await store.save(bytes: bytes('x'), filename: 'Kept.pdf', toolId: 't');
      final lost =
          await store.save(bytes: bytes('y'), filename: 'Lost.pdf', toolId: 't');

      await File(lost.path).delete();
      final removed = await store.pruneMissing();

      expect(removed, 1);
      final all = await store.all();
      expect(all, hasLength(1));
      expect(all.first.id, kept.id);
    });

    test('clear wipes every file and row', () async {
      final store = FileStore.instance;
      final a =
          await store.save(bytes: bytes('a'), filename: 'A.pdf', toolId: 't');
      final b =
          await store.save(bytes: bytes('b'), filename: 'B.pdf', toolId: 't');

      await store.clear();

      expect(await store.count(), 0);
      expect(await File(a.path).exists(), isFalse);
      expect(await File(b.path).exists(), isFalse);
    });
  });

  group('StoredFile', () {
    test('maps extensions onto the UI format enum', () async {
      final store = FileStore.instance;

      Future<DocFormat> formatOf(String filename) async {
        final f =
            await store.save(bytes: bytes('x'), filename: filename, toolId: 't');
        return f.format;
      }

      expect(await formatOf('a.pdf'), DocFormat.pdf);
      expect(await formatOf('b.docx'), DocFormat.docx);
      expect(await formatOf('c.xlsx'), DocFormat.xlsx);
      expect(await formatOf('d.jpg'), DocFormat.jpg);
      // split-pdf and pdf-to-image both return zips.
      expect(await formatOf('e.zip'), DocFormat.png);
    });

    test('formats sizes for the row label', () async {
      final store = FileStore.instance;

      final small = await store.save(
          bytes: Uint8List(512), filename: 'small.pdf', toolId: 't');
      final medium = await store.save(
          bytes: Uint8List(2048), filename: 'medium.pdf', toolId: 't');
      final large = await store.save(
          bytes: Uint8List(3 * 1024 * 1024), filename: 'large.pdf', toolId: 't');

      expect(small.sizeLabel, '512 B');
      expect(medium.sizeLabel, '2 KB');
      expect(large.sizeLabel, '3.0 MB');
    });

    test('adapts onto DocumentFile for the shared ProScan widgets', () async {
      final stored = await FileStore.instance.save(
        bytes: bytes('x'),
        filename: 'Invoice.pdf',
        toolId: 'word-to-pdf',
      );

      final doc = stored.toDocumentFile();
      expect(doc.name, 'Invoice');
      expect(doc.format, DocFormat.pdf);
      expect(doc.date, 'Today');
    });
  });
}
