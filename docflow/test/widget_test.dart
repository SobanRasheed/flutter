import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docflow/main.dart';

/// Boots the app at the design's 430x932 frame and pumps through the splash.
/// The default 800x600 test surface is too short for the pinned CTAs, so every
/// test runs at the real phone size.
Future<void> _bootPastSplash(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const DocFlowApp());

  // The splash holds for 3s, then fades through to onboarding. Pump past both
  // rather than settling — the dot loader repeats forever.
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 800));
}

/// Splash -> onboarding -> welcome -> sign in.
Future<void> _bootToSignIn(WidgetTester tester) async {
  await _bootPastSplash(tester);
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign in with password'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boots to the splash, then hands off to onboarding',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DocFlowApp());

    expect(find.text('DocFlow'), findsOneWidget);
    expect(find.text('Convert, manage and scan documents'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text('Convert any document\nquickly and easily'),
      findsOneWidget,
    );
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Skip jumps the carousel straight to the welcome screen',
      (WidgetTester tester) async {
    await _bootPastSplash(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text("Let's you in"), findsOneWidget);
    expect(find.text('Sign in with password'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('Next advances through all three onboarding pages',
      (WidgetTester tester) async {
    await _bootPastSplash(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('You can also scan and\ncustomize results'),
      findsOneWidget,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('Organize your documents\nwith DocFlow now!'),
      findsOneWidget,
    );

    // The third Next leaves the carousel for the welcome screen.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text("Let's you in"), findsOneWidget);
  });

  testWidgets('welcome hands off to sign in', (WidgetTester tester) async {
    await _bootToSignIn(tester);

    expect(find.text('Hello there 👋'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Forgot Password'), findsOneWidget);
  });

  testWidgets('reset flow runs email -> OTP -> new password -> success',
      (WidgetTester tester) async {
    await _bootToSignIn(tester);

    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password 🔑'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("You've got mail 📩"), findsOneWidget);

    // Confirm stays disabled until all four digits land.
    final confirm = find.widgetWithText(ElevatedButton, 'Confirm');
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '4679');
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Create new password 🔒'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password\nSuccessful!'), findsOneWidget);

    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Convert'), findsWidgets);
  });

  testWidgets('mismatched confirm password blocks the reset',
      (WidgetTester tester) async {
    await _bootToSignIn(tester);

    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '4679');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pumpAndSettle();

    // Second field is Confirm Password; break the match.
    await tester.enterText(find.byType(TextField).at(1), 'different');
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    final cta = find.widgetWithText(ElevatedButton, 'Continue');
    expect(tester.widget<ElevatedButton>(cta).onPressed, isNull);
  });
}
