import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../data/sample_data.dart';
import '../models/conversion_tool.dart';
import '../widgets/docflow_logo.dart';
import '../widgets/file_row.dart';
import '../widgets/tool_tile.dart';
import 'convert_screen.dart';
import 'recent_files_screen.dart';

/// Home. Follows the ProScan home screen: wordmark header with a search
/// button, a 4x2 tool grid ending in All Tools, then Recent Files. DocFlow's
/// conversion tools fill the grid in place of ProScan's PDF utilities.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

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

