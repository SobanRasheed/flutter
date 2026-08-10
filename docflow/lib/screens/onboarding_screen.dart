import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'welcome_screen.dart';

/// ProScan's three-page onboarding carousel: scan docs quickly, edit results,
/// organize files. Each screen shows an illustration, heading, body, page
/// indicators, and Skip/Next pill buttons. After screen 3 → WelcomeScreen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToWelcome();
    }
  }

  void _goToWelcome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: const WelcomeScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _OnboardingPage(
                    art: 'assets/onboarding/ob_art_1.png',
                    title: 'Convert any document\nquickly and easily',
                    body:
                        'PDF to Word, Excel to PDF and more — pick a tool, '
                        'drop in a file, done in seconds.',
                  ),
                  _OnboardingPage(
                    art: 'assets/onboarding/ob_art_2.png',
                    title: 'You can also scan and\ncustomize results',
                    body:
                        'Capture a page with the camera, crop it and save it '
                        'straight into your library as a PDF.',
                  ),
                  _OnboardingPage(
                    art: 'assets/onboarding/ob_art_3.png',
                    title: 'Organize your documents\nwith DocFlow now!',
                    body:
                        'Converted files are saved to your phone and stay '
                        'there. We never store them on our servers.',
                  ),
                ],
              ),
            ),
            _Dots(page: _page),
            const SizedBox(height: 32),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: _SkipButton(onPressed: _goToWelcome),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _next,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One carousel page: illustration on top, heading and body beneath.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.art,
    required this.title,
    required this.body,
  });

  final String art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // The art band runs edge to edge and takes the upper half of the page.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Image.asset(art, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(height: 1.32),
              ),
              const SizedBox(height: 20),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Three indicators; the active one stretches into a 32pt bar.
class _Dots extends StatelessWidget {
  const _Dots({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: i == page ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == page ? AppColors.primary : const Color(0xFFE2E2E1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          if (i < 2) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// Skip is a tinted pill — same height as the primary CTA, primary label on
/// primaryTint rather than an outline.
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEDF0FF),
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      child: const Text('Skip'),
    );
  }
}
