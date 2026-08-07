import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../data/sample_data.dart';
import '../widgets/file_row.dart';

/// Recent Files — the kit's full-height list behind Home's "See all". Back
/// arrow, title and search sit in the header; below it every recent document
/// as a card with its page preview.
class RecentFilesScreen extends StatelessWidget {
  const RecentFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(LucideIcons.arrowLeft,
                        size: 24, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recent Files',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.search,
                        size: 24, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  for (final file in SampleData.recentFiles)
                    FileRow(
                      file: file,
                      onTap: () {},
                      onShare: () {},
                      onMore: () {},
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
