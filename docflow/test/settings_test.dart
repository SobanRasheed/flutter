import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:docflow/screens/about_screen.dart';
import 'package:docflow/screens/account_screen.dart';
import 'package:docflow/screens/help_center_screen.dart';
import 'package:docflow/screens/language_screen.dart';
import 'package:docflow/screens/personal_info_screen.dart';
import 'package:docflow/screens/preferences_screen.dart';
import 'package:docflow/screens/security_screen.dart';

/// Hosts one screen at the design's 430x932 frame. The default 800x600 surface
/// is too short for these long settings lists.
Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  group('Account', () {
    testWidgets('lists every settings row over the profile card',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const Scaffold(body: AccountScreen()));

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Andrew Ainsley'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('465 MB  /  1024 MB'), findsOneWidget);
      // DocFlow keeps the privacy card where the kit sells premium. The claim
      // must stay accurate: files ARE uploaded, they are just never persisted
      // server-side, so this must not drift back to "never leave your device".
      expect(find.text('Private by design'), findsOneWidget);
      expect(
        find.text(
          'Files are processed in memory and never stored on our servers.',
        ),
        findsOneWidget,
      );

      for (final row in [
        'Personal Info',
        'Preferences',
        'Security',
        'Language',
        'Dark Mode',
        'Help Center',
        'About DocFlow',
        'Logout',
      ]) {
        expect(find.text(row), findsOneWidget, reason: 'missing row: $row');
      }
      expect(find.text('English (US)'), findsOneWidget);
    });

    testWidgets('logout asks before signing out',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const Scaffold(body: AccountScreen()));

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to log out?'), findsOneWidget);

      // Cancelling leaves the user on the Account tab.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to log out?'), findsNothing);
      expect(find.text('Andrew Ainsley'), findsOneWidget);
    });
  });

  group('Personal Info', () {
    testWidgets('fields are read-only until the pencil is tapped',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const PersonalInfoScreen());

      expect(find.text('Personal Info'), findsOneWidget);
      expect(find.text('Andrew Ainsley'), findsOneWidget);
      expect(find.text('andrew.ainsley@yourdomain.com'), findsOneWidget);
      expect(find.text('12/27/1995'), findsOneWidget);

      final name = tester.widget<TextField>(find.byType(TextField).first);
      expect(name.enabled, isFalse);

      await tester.tap(find.byIcon(LucideIcons.edit2));
      await tester.pumpAndSettle();

      final editable = tester.widget<TextField>(find.byType(TextField).first);
      expect(editable.enabled, isTrue);

      // The check replaces the pencil while editing.
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });
  });

  group('Preferences', () {
    testWidgets('groups settings and toggles a switch',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const PreferencesScreen());

      // Conversion leads, since that is DocFlow's main job.
      expect(find.text('Conversion'), findsOneWidget);
      expect(find.text('Default Output Format'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('High Quality Scan'), findsOneWidget);

      // Switch order follows the list: Keep Original, then High Quality Scan.
      expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);

      await tester.tap(find.text('High Quality Scan'));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
    });
  });

  group('Security', () {
    testWidgets('shows the auth toggles and a change-password action',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const SecurityScreen());

      for (final row in [
        'Remember me',
        'Biometric ID',
        'Face ID',
        'SMS Authenticator',
        'Google Authenticator',
        'Device Management',
      ]) {
        expect(find.text(row), findsOneWidget, reason: 'missing row: $row');
      }
      expect(
        find.widgetWithText(FilledButton, 'Change Password'),
        findsOneWidget,
      );
    });
  });

  group('Language', () {
    testWidgets('checks the active language and returns a new pick',
        (WidgetTester tester) async {
      String? picked;

      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const LanguageScreen(selected: 'English (US)'),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Suggested'), findsOneWidget);
      expect(find.text('English (US)'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);

      await tester.tap(find.text('Spanish'));
      await tester.pumpAndSettle();

      expect(picked, 'Spanish');
    });
  });

  group('Help Center', () {
    testWidgets('FAQ expands an answer and the chips filter the list',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const HelpCenterScreen());

      expect(find.text('What is DocFlow?'), findsOneWidget);
      // The first entry starts open, as in the kit.
      expect(find.textContaining('DocFlow converts documents'), findsOneWidget);

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      expect(find.text('What is DocFlow?'), findsNothing);
      expect(find.text('How can I log out from DocFlow?'), findsOneWidget);
    });

    testWidgets('search suggests questions across categories',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const HelpCenterScreen());

      await tester.enterText(find.byType(TextField), 'Why');
      await tester.pumpAndSettle();

      // Matches come from Account and Convert while General is the active chip.
      expect(find.text('Why does the DocFlow app force close?'), findsOneWidget);
      expect(find.text("Why can't I export to PDF?"), findsOneWidget);
    });

    testWidgets('Contact us tab lists the support channels',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const HelpCenterScreen());

      await tester.tap(find.text('Contact us'));
      await tester.pumpAndSettle();

      for (final channel in [
        'WhatsApp',
        'Instagram',
        'Facebook',
        'Twitter',
        'Website',
      ]) {
        expect(find.text(channel), findsOneWidget);
      }
    });
  });

  group('About', () {
    testWidgets('shows the version and the link rows',
        (WidgetTester tester) async {
      await _pumpScreen(tester, const AboutScreen());

      expect(find.text('About DocFlow'), findsOneWidget);
      expect(find.text('DocFlow v1.0.0'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Rate us'), findsOneWidget);
    });
  });
}
