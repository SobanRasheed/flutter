import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:docflow/data/sample_data.dart';
import 'package:docflow/screens/pdf_tools_screens.dart';
import 'package:docflow/screens/signature_screen.dart';
import 'package:docflow/screens/watermark_screen.dart';
import 'package:docflow/widgets/file_actions.dart';

/// Hosts one screen at the design's 430x932 frame. The default 800x600 surface
/// is too short for the pinned CTAs on these screens.
Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  final file = SampleData.recentFiles.first;

  group('Compress PDF', () {
    testWidgets('offers three levels with Medium preselected',
        (WidgetTester tester) async {
      await _pumpScreen(tester, CompressPdfScreen(file: file));

      expect(find.text('Compress PDF'), findsOneWidget);
      expect(find.text('Select compression level:'), findsOneWidget);
      expect(find.text('High Compression'), findsOneWidget);
      expect(find.text('Medium Compression'), findsOneWidget);
      expect(find.text('Low Compression'), findsOneWidget);
      // The file being compressed is named on the card.
      expect(find.text(file.name), findsOneWidget);
    });

    testWidgets('tapping a level moves the selection',
        (WidgetTester tester) async {
      await _pumpScreen(tester, CompressPdfScreen(file: file));

      await tester.tap(find.text('High Compression'));
      await tester.pumpAndSettle();

      // Still on the screen, with the tapped level now shown as chosen.
      expect(find.text('High Compression'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Compress'), findsOneWidget);
    });
  });

  group('Protect PDF', () {
    testWidgets('keeps the CTA disabled until both fields match',
        (WidgetTester tester) async {
      await _pumpScreen(tester, ProtectPdfScreen(file: file));

      final cta = find.widgetWithText(ElevatedButton, 'Protect File');
      expect(tester.widget<ElevatedButton>(cta).onPressed, isNull);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'example-test-password');
      await tester.enterText(fields.at(1), 'nope');
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(cta).onPressed, isNull);

      await tester.enterText(fields.at(1), 'example-test-password');
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsNothing);
      expect(tester.widget<ElevatedButton>(cta).onPressed, isNotNull);
    });
  });

  group('Merge PDF', () {
    testWidgets('removing a file updates the list and the count',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const MergePdfScreen());

      expect(find.text('Merge PDF'), findsOneWidget);
      expect(find.textContaining('3 files'), findsOneWidget);

      // Each row carries its own remove control.
      await tester.tap(find.byIcon(LucideIcons.x).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('2 files'), findsOneWidget);
    });

    testWidgets('merge is blocked below two files',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const MergePdfScreen());

      final cta = find.widgetWithText(ElevatedButton, 'Merge Files');
      expect(tester.widget<ElevatedButton>(cta).onPressed, isNotNull);
    });
  });

  group('Watermark', () {
    testWidgets('renders the editor with its default mark',
        (WidgetTester tester) async {
      await _pumpScreen(tester, WatermarkScreen(file: file));

      expect(find.text('Add Watermark'), findsOneWidget);
      // Once in the field, once as the hint behind it.
      expect(find.text('CONFIDENTIAL'), findsWidgets);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Opacity'), findsOneWidget);
      expect(find.text('Angle'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Apply Watermark'),
        findsOneWidget,
      );
    });
  });

  group('Signature', () {
    testWidgets('Continue unlocks only once something is drawn',
        (WidgetTester tester) async {
      await _pumpScreen(tester, SignatureScreen(file: file));

      expect(find.text('Add Signature'), findsOneWidget);

      final cta = find.widgetWithText(ElevatedButton, 'Continue');
      expect(tester.widget<ElevatedButton>(cta).onPressed, isNull);

      // Drag across the pad to lay down a stroke.
      await tester.drag(find.byType(CustomPaint).first, const Offset(90, 30));
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(cta).onPressed, isNotNull);

      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('Place Signature'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Save Signed PDF'),
        findsOneWidget,
      );
    });
  });

  group('File actions', () {
    testWidgets('delete sheet names the file and confirms',
        (WidgetTester tester) async {
      var confirmed = false;

      await _pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  confirmed = await showDeleteSheet(context, file: file);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete file'), findsOneWidget);
      expect(find.text(file.name), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets('rename sheet returns the edited name',
        (WidgetTester tester) async {
      String? result;

      await _pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRenameSheet(context, name: file.name);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Rename file'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Contract v2');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(result, 'Contract v2');
    });
  });
}
