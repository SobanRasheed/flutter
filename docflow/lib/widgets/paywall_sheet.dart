import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/quota.dart';

/// Shown when the backend answers `402 Payment Required`.
///
/// This is the only thing that gates a conversion, and it is driven entirely by
/// the server's answer — never by a local count. A client-side check would be
/// both bypassable and wrong after the month rolls over.
///
/// Returns true when the user asked to upgrade, so the caller can push the
/// purchase flow once billing exists.
Future<bool> showPaywall(
  BuildContext context, {
  required Quota quota,
  String? message,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaywallSheet(quota: quota, message: message),
  );
  return result ?? false;
}

class _PaywallSheet extends StatelessWidget {
  const _PaywallSheet({required this.quota, this.message});

  final Quota quota;
  final String? message;

  static const _benefits = [
    (LucideIcons.infinity, 'Unlimited conversions', 'No monthly cap, ever'),
    (LucideIcons.zap, 'Priority processing', 'Your files go to the front'),
    (LucideIcons.fileStack, 'Larger files', 'Convert documents up to 200 MB'),
    (LucideIcons.shieldCheck, 'No ads', 'A clean, uninterrupted app'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = quota.limit ?? 100;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.crown,
                      size: 34, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  'You have used all\n$limit free conversions',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  message ??
                      'Upgrade to Pro for unlimited conversions, or wait for '
                          'your allowance to reset next month.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                // The bar reads full — that is the point of this sheet.
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1,
                    minHeight: 8,
                    backgroundColor: AppColors.primaryTint,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${quota.conversionsUsed} of $limit used this month',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                for (final (icon, title, subtitle) in _benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius:
                                BorderRadius.circular(AppRadius.field),
                          ),
                          child: Icon(icon,
                              size: 19, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: theme.textTheme.titleSmall),
                              Text(subtitle,
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Upgrade to Pro'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Maybe later'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
