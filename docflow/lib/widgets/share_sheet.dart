import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';

/// Export formats offered when sharing a document, with the size each would
/// produce. A link shares in place and has no download weight.
enum _ShareOption {
  link('Share Link', LucideIcons.link, null),
  pdf('Share PDF', LucideIcons.fileText, '1.2 MB'),
  word('Share Word', LucideIcons.file, '456 KB'),
  jpg('Share JPG', LucideIcons.image, '800 KB'),
  png('Share PNG', LucideIcons.image, '568 KB');

  const _ShareOption(this.label, this.icon, this.size);

  final String label;
  final IconData icon;
  final String? size;
}

/// Opens the share sheet for [title]. Resolves once the user picks a format or
/// dismisses the sheet.
Future<void> showShareSheet(BuildContext context, {required String title}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ShareSheet(title: title),
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('Share', style: theme.textTheme.titleLarge),
          ),
          const Divider(height: 1),
          for (final option in _ShareOption.values)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(option.icon,
                  size: 26, color: AppColors.textPrimary),
              title: Row(
                children: [
                  Text(option.label, style: theme.textTheme.bodyLarge),
                  if (option.size case final size?) ...[
                    const SizedBox(width: 8),
                    Text('($size)', style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${option.label}: $title')),
                );
              },
            ),
        ],
      ),
    );
  }
}
