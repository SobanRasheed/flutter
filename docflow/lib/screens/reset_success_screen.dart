import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import 'app_shell.dart';

/// Raises the "Reset Password Successful!" card over whatever screen called it.
/// ProScan shows this as a modal on top of the create-password screen rather
/// than as its own route, so the dimmed form stays visible behind it.
Future<void> showResetSuccessDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.55),
    builder: (_) => const _ResetSuccessDialog(),
  );
}

class _ResetSuccessDialog extends StatelessWidget {
  const _ResetSuccessDialog();

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SuccessBadge(),
            const SizedBox(height: 28),
            Text(
              'Reset Password\nSuccessful!',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium
                  ?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'Your password has been successfully changed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => _goHome(context),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient disc holding a white rounded square with a primary check, ringed by
/// scattered dots. Offsets are fractions of the 150pt box.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  // (dx, dy, diameter, opacity) — dx/dy are fractions of the box.
  static const _dots = [
    (0.10, 0.16, 15.0, 1.0),
    (0.52, 0.06, 5.0, 1.0),
    (0.88, 0.24, 11.0, 1.0),
    (0.05, 0.62, 8.0, 1.0),
    (0.24, 0.44, 4.0, 0.5),
    (0.90, 0.60, 5.0, 0.6),
    (0.38, 0.92, 6.0, 1.0),
    (0.62, 0.86, 4.0, 0.5),
  ];

  @override
  Widget build(BuildContext context) {
    const box = 150.0;

    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        children: [
          for (final (dx, dy, size, opacity) in _dots)
            Positioned(
              left: dx * box,
              top: dy * box,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primarySoft, AppColors.primary],
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  LucideIcons.check,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
