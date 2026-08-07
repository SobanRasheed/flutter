import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import 'app_shell.dart';
import 'forgot_password_screen.dart';

/// Sign in — ProScan's "Hello there 👋" screen. Fields are underline-only with
/// no prefix icons, Forgot Password sits centred below a rule, and the Sign In
/// pill is pinned above the home indicator. The FadeThrough hand-off to the
/// shell is unchanged.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(
    text: 'andrew.ainsley@yourdomain.com',
  );
  final _passwordController = TextEditingController(text: 'docflow1234');
  bool _obscurePassword = true;
  bool _remember = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: const AppShell(),
          );
        },
      ),
    );
  }

  void _forgotPassword() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: const ForgotPasswordScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text('Hello there 👋',
                        style: theme.textTheme.displayMedium),
                    const SizedBox(height: 12),
                    Text(
                      'Please enter your email & password to sign in.',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    Text('Email', style: theme.textTheme.labelLarge),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 24),
                    Text('Password', style: theme.textTheme.labelLarge),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Checkbox(
                          value: _remember,
                          onChanged: (v) =>
                              setState(() => _remember = v ?? false),
                        ),
                        const SizedBox(width: 8),
                        Text('Remember me', style: theme.textTheme.bodyLarge),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: Text(
                          'Forgot Password',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or continue with',
                              style: theme.textTheme.bodyMedium),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SocialRow(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: ElevatedButton(
                onPressed: _handleLogin,
                child: const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google / Apple / Facebook, drawn from the kit's exported marks so the
/// multicolour G and the Apple glyph render on every platform.
class _SocialRow extends StatelessWidget {
  const _SocialRow();

  static const _marks = [
    'assets/onboarding/mark_google.png',
    'assets/onboarding/mark_apple.png',
    'assets/onboarding/mark_facebook.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, asset) in _marks.indexed) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                ),
              ),
              child: Image.asset(asset, height: 26, fit: BoxFit.contain),
            ),
          ),
          if (index < _marks.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}
