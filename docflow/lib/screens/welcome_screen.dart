import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// ProScan's "Let's you in" screen — the last stop before sign-in. Three
/// outlined social buttons, an "or" rule, then the primary password CTA.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: AppColors.background,
            child: const LoginScreen(),
          );
        },
      ),
    );
  }

  void _openSignup(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: AppColors.background,
            child: const SignupScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Image.asset(
                        'assets/onboarding/welcome_art.png',
                        height: 228,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 46),
                      Text(
                        "Let's you in",
                        style: theme.textTheme.displayLarge,
                      ),
                      const SizedBox(height: 36),
                      _SocialButton(
                        asset: 'assets/onboarding/social_google.png',
                        onPressed: () => _openLogin(context),
                      ),
                      const SizedBox(height: 20),
                      _SocialButton(
                        asset: 'assets/onboarding/social_facebook.png',
                        onPressed: () => _openLogin(context),
                      ),
                      const SizedBox(height: 20),
                      _SocialButton(
                        asset: 'assets/onboarding/social_apple.png',
                        onPressed: () => _openLogin(context),
                      ),
                      const SizedBox(height: 28),
                      const _OrRule(),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: () => _openLogin(context),
                        child: const Text('Sign in with password'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              "Don't have an account?",
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _openSignup(context),
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4)),
                            child: const Text('Sign up'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// An outlined pill holding the exported brand lockup (mark + label), which
/// ships as one image because the Google mark is multicolour.
class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.asset, required this.onPressed});

  final String asset;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(62),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Image.asset(asset, height: 24, fit: BoxFit.contain),
    );
  }
}

/// A centred "or" with a hairline running out to each gutter.
class _OrRule extends StatelessWidget {
  const _OrRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textPrimary),
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }
}
