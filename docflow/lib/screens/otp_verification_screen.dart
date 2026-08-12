import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../services/auth_service.dart';

/// "Check your inbox 📩" — shown after Firebase sends the password-reset email.
///
/// Firebase delivers a secure reset link (not a numeric OTP). This screen
/// confirms the send, lets the user resend after a countdown, and guides them
/// to open their email app.
class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  static const _resendSeconds = 60;

  final _auth = AuthService();
  Timer? _timer;
  int _remaining = _resendSeconds;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remaining = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await _auth.sendPasswordResetEmail(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset link resent to ${widget.email}')),
      );
      _startCountdown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not resend. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text("Check your inbox 📩", style: theme.textTheme.displayMedium),
              const SizedBox(height: 12),
              Text(
                'We sent a password reset link to:',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Open the email and tap the reset link to choose a new password.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 48),

              // ── Envelope illustration ────────────────────────────────────
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.mail,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // ── Resend ───────────────────────────────────────────────────
              Center(
                child: Text(
                  "Didn't receive the email?",
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: _resending
                    ? const CircularProgressIndicator()
                    : _remaining > 0
                        ? Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.textPrimary),
                              children: [
                                const TextSpan(text: 'Resend in '),
                                TextSpan(
                                  text: '$_remaining',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: ' s'),
                              ],
                            ),
                          )
                        : TextButton(
                            onPressed: _resend,
                            child: const Text('Resend reset link'),
                          ),
              ),
              const SizedBox(height: 32),

              // ── Check spam hint ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.info,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'If you don\'t see it, check your Spam or Junk folder.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
