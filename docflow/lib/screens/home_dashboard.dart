import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../data/sample_data.dart';
import '../models/conversion_tool.dart';
import '../widgets/docflow_logo.dart';
import '../widgets/file_row.dart';
import '../widgets/tool_tile.dart';
import 'convert_screen.dart';

/// Home. Follows the ProScan home screen structure — wordmark header, search
/// field, hero card, tool grid, recent files — with DocFlow's conversion tools
/// filling the grid.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key, this.onSeeAllFiles});

  final VoidCallback? onSeeAllFiles;

  void _openTool(BuildContext context, ConversionTool tool) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConvertScreen(initialTool: tool)),
    );
  }

  void _openAllTools(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConvertScreen()),
    );
  }

  void _openRecentFiles(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecentFilesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = SampleData.recentFiles.take(3).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
            child: Row(
              children: [
                const DocFlowWordmark(),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.search,
                      color: AppColors.textPrimary, size: 24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 20pt gutter here, not 24 — the grid runs wider than the cards below.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ToolGrid(
              onToolTap: (tool) => _openTool(context, tool),
              onAllTools: () => _openAllTools(context),
            ),
          ),
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(height: 1),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 20, 0),
            child: Row(
              children: [
                Text('Recent Files',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 24)),
                const Spacer(),
                IconButton(
                  onPressed: () => _openRecentFiles(context),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.arrowRight,
                      size: 22, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                for (final file in recent)
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
    );
  }
}

/// The gradient hero card. ProScan advertised its scanner here; DocFlow leads
/// with conversion and keeps scanning as the secondary action.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.zap, size: 12, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Free & unlimited',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Convert any document\nin seconds',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PDF, Word, Excel and images — no sign-up limits, '
            'no watermarks.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConvertScreen()),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text('Start converting'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onAction,
          child: Text(
            actionLabel,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
