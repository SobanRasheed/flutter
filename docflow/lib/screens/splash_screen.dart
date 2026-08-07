import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../widgets/docflow_logo.dart';
import 'onboarding_screen.dart';

/// Splash. ProScan's launch screen: white ground, centred mark over the
/// wordmark, three-dot loader at the foot. The fade + scale entrance and the
/// FadeThroughTransition out are unchanged from before; the splash now hands
/// off to the onboarding carousel rather than straight to sign-in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Navigate to onboarding after splash
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) {
              return FadeThroughTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                child: const OnboardingScreen(),
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const DocFlowLogo(size: 96),
                    const SizedBox(height: 28),
                    Text(
                      'DocFlow',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 36,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Convert, manage and scan documents',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const _DotLoader(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots pulsing in sequence — the loader at the bottom of ProScan's
/// splash.
class _DotLoader extends StatefulWidget {
  const _DotLoader();

  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              _dot(i),
              if (i < 2) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    // Each dot leads the next by a third of the cycle.
    final phase = (_controller.value - index / 3) % 1.0;
    final t = (1 - (phase * 2 - 1).abs()).clamp(0.0, 1.0);

    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(AppColors.divider, AppColors.primary, t),
      ),
    );
  }
}
