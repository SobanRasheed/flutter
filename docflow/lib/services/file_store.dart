import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/document.dart';

/// One converted file, as recorded in the local database.
///
/// The bytes live on disk in the app documents directory; this row is the index
/// that lets "My Files" list them without walking the filesystem.
class StoredFile {
  const StoredFile({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
    required this.toolId,
    this.sourceName,
  });

  final int id;

  /// File name including extension, as the backend named the output.
  final String name;

  /// Absolute path on this device.
  final String path;
  final int sizeBytes;
  final DateTime createdAt;

  /// Which tool produced it, so the list can show provenance.
  final String toolId;

  /// What the user fed in, when we know it.
  final String? sourceName;

  File get file => File(path);

  /// Whether the bytes are still there. A user can clear app storage, or a
  /// backup can restore the database without the documents directory.
  Future<bool> get exists => file.exists();

  String get extension =>
      p.extension(name).replaceFirst('.', '').toLowerCase();

  /// Maps onto the format enum the existing UI is built around. Anything the
  /// enum has no case for falls back to PDF, the common output.
  DocFormat get format => switch (extension) {
        'pdf' => DocFormat.pdf,
        'docx' || 'doc' || 'odt' || 'rtf' => DocFormat.docx,
        'xlsx' || 'xls' || 'csv' => DocFormat.xlsx,
        'pptx' || 'ppt' => DocFormat.pptx,
        'jpg' || 'jpeg' => DocFormat.jpg,
        'png' || 'webp' || 'zip' => DocFormat.png,
        _ => DocFormat.pdf,
      };

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Adapts a stored row onto the model the ProScan-derived widgets take.
  ///
  /// Those widgets were built against [DocumentFile] and are shared with the
  /// scan flow, so bridging here is cheaper than threading a second type
  /// through every list, sheet and viewer.
  DocumentFile toDocumentFile() => DocumentFile(
        name: p.basenameWithoutExtension(name),
        format: format,
        sizeLabel: sizeLabel,
        date: _dateLabel(createdAt),
        time: _timeLabel(createdAt),
      );

  static String _dateLabel(DateTime at) {
    final now = DateTime.now();
    final justDay = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(justDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${at.day} ${months[at.month - 1]} ${at.year}';
  }

  static String _timeLabel(DateTime at) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
  }

  factory StoredFile.fromRow(Map<String, Object?> row) => StoredFile(
        id: row['id'] as int,
        name: row['name'] as String,
        path: row['path'] as String,
        sizeBytes: row['size_bytes'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        toolId: row['tool_id'] as String,
        sourceName: row['source_name'] as String?,
      );
}

/// The local file library: bytes in the documents directory, index in SQLite.
///
/// Nothing here touches the network. Converted files belong to the user and
/// live on their device — the backend keeps no copy.
class FileStore {
  FileStore._();

  static final FileStore instance = FileStore._();

  static const _dbName = 'docflow.db';
  static const _table = 'files';

  /// Subdirectory of the documents directory. Keeping conversions in their own
  /// folder means we never enumerate or delete anything the platform put there.
  static const _folder = 'DocFlow';

  Database? _db;

  /// Test-only overrides. `path_provider` has no implementation in the test VM,
  /// so tests point both the documents root and the database at a temp dir.
  static Directory? _documentsOverride;
  static String? _databasePathOverride;

  @visibleForTesting
  static void debugOverrideDirectories({
    required Directory documents,
    required String databasePath,
  }) {
    _documentsOverride = documents;
    _databasePathOverride = databasePath;
  }

  /// Closes the handle and clears overrides so the next test starts clean.
  @visibleForTesting
  Future<void> debugReset() async {
    await _db?.close();
    _db = null;
    _documentsOverride = null;
    _databasePathOverride = null;
  }

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = _databasePathOverride ?? await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            name         TEXT    NOT NULL,
            path         TEXT    NOT NULL UNIQUE,
            size_bytes   INTEGER NOT NULL,
            created_at   INTEGER NOT NULL,
            tool_id      TEXT    NOT NULL,
            source_name  TEXT
          )
        ''');
        // The list is always newest-first, so index the sort column.
        await db.execute(
          'CREATE INDEX idx_files_created_at ON $_table (created_at DESC)',
        );
      },
    );
  }

  /// Where converted files are kept. Documents, not cache — iOS purges the
  /// cache directory under storage pressure, which would silently delete the
  /// user's library.
  Future<Directory> _outputDirectory() async {
    final base = _documentsOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes [bytes] to disk under [filename] and records the row.
  Future<StoredFile> save({
    required Uint8List bytes,
    required String filename,
    required String toolId,
    String? sourceName,
  }) async {
    final dir = await _outputDirectory();
    final target = await _uniquePath(dir, filename);

    await File(target).writeAsBytes(bytes, flush: true);

    final db = await _database;
    final createdAt = DateTime.now();
    final id = await db.insert(_table, {
      'name': p.basename(target),
      'path': target,
      'size_bytes': bytes.length,
      'created_at': createdAt.millisecondsSinceEpoch,
      'tool_id': toolId,
      'source_name': sourceName,
    });

    return StoredFile(
      id: id,
      name: p.basename(target),
      path: target,
      sizeBytes: bytes.length,
      createdAt: createdAt,
      toolId: toolId,
      sourceName: sourceName,
    );
  }

  /// Finds a free name, so converting the same document twice keeps both
  /// results instead of overwriting the first.
  Future<String> _uniquePath(Directory dir, String filename) async {
    final safe = _sanitize(filename);
    final stem = p.basenameWithoutExtension(safe);
    final ext = p.extension(safe);

    var candidate = p.join(dir.path, safe);
    var counter = 2;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '$stem ($counter)$ext');
      counter++;
    }
    return candidate;
  }

  /// Strips path separators and characters Windows and iOS reject. The name
  /// arrives in a server response header, so it is not trusted input.
  String _sanitize(String filename) {
    final base = p.basename(filename.replaceAll(RegExp(r'[/\\]'), '_'));
    final cleaned = base.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_').trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'converted.pdf';
    }
    // Keep clear of the 255-byte limit on most filesystems.
    if (cleaned.length <= 120) return cleaned;
    final ext = p.extension(cleaned);
    return cleaned.substring(0, 120 - ext.length) + ext;
  }

  /// Every stored file, newest first.
  Future<List<StoredFile>> all() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'created_at DESC');
    return rows.map(StoredFile.fromRow).toList();
  }

  /// The most recent files, for the home dashboard.
  Future<List<StoredFile>> recent({int limit = 3}) async {
    final db = await _database;
    final rows =
        await db.query(_table, orderBy: 'created_at DESC', limit: limit);
    return rows.map(StoredFile.fromRow).toList();
  }

  Future<int> count() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) AS n FROM $_table');
    return (result.first['n'] as int?) ?? 0;
  }

  /// Total bytes the library occupies, for the account screen.
  Future<int> totalBytes() async {
    final db = await _database;
    final result =
        await db.rawQuery('SELECT SUM(size_bytes) AS total FROM $_table');
    return (result.first['total'] as int?) ?? 0;
  }

  /// Renames both the row and the file on disk, keeping the extension.
  Future<StoredFile?> rename(StoredFile stored, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return null;

    final withExt = p.extension(trimmed).isEmpty
        ? '$trimmed${p.extension(stored.name)}'
        : trimmed;
    final dir = await _outputDirectory();
    final target = await _uniquePath(dir, withExt);

    if (await stored.file.exists()) {
      await stored.file.rename(target);
    }

    final db = await _database;
    await db.update(
      _table,
      {'name': p.basename(target), 'path': target},
      where: 'id = ?',
      whereArgs: [stored.id],
    );

    return StoredFile(
      id: stored.id,
      name: p.basename(target),
      path: target,
      sizeBytes: stored.sizeBytes,
      createdAt: stored.createdAt,
      toolId: stored.toolId,
      sourceName: stored.sourceName,
    );
  }

  /// Removes the row and the bytes. The row goes even when the file is already
  /// missing, so a half-deleted entry can't haunt the list forever.
  Future<void> delete(StoredFile stored) async {
    try {
      if (await stored.file.exists()) await stored.file.delete();
    } on FileSystemException {
      // Locked by a viewer, or already gone. Drop the row regardless.
    }
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [stored.id]);
  }

  /// Drops rows whose file no longer exists. Worth running when the library
  /// screen opens: a restored backup or cleared storage leaves stale rows,
  /// and tapping one would fail with a confusing error.
  Future<int> pruneMissing() async {
    final db = await _database;
    final rows = await db.query(_table);
    var removed = 0;
    for (final row in rows) {
      final path = row['path'] as String;
      if (await File(path).exists()) continue;
      await db.delete(_table, where: 'id = ?', whereArgs: [row['id']]);
      removed++;
    }
    return removed;
  }

  /// Wipes the library — bytes and rows. Used by "Clear all files" in
  /// settings, and after sign-out so one user's documents aren't left visible
  /// to the next person who signs in on the same device.
  Future<void> clear() async {
    final db = await _database;
    final rows = await db.query(_table, columns: ['path']);
    for (final row in rows) {
      try {
        final file = File(row['path'] as String);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Best effort; the row still goes.
      }
    }
    await db.delete(_table);
  }
}
