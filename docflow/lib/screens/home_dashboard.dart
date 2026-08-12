import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';

import '../core/tokens.dart';
import '../models/conversion_tool.dart';
import '../services/file_store.dart';
import '../widgets/docflow_logo.dart';
import '../widgets/file_row.dart';
import '../widgets/share_sheet.dart';
import '../widgets/tool_tile.dart';
import 'conversion_flow.dart';
import 'convert_screen.dart';
import 'recent_files_screen.dart';

/// Home. Follows the ProScan home screen: wordmark header with a search
/// button, a 4x2 tool grid ending in All Tools, then Recent Files. DocFlow's
/// conversion tools fill the grid in place of ProScan's PDF utilities.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key, this.onSeeAllFiles});

  final VoidCallback? onSeeAllFiles;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _store = FileStore.instance;

  List<StoredFile> _recent = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recent = await _store.recent(limit: 3);
    if (!mounted) return;
    setState(() => _recent = recent);
  }

  Future<void> _openTool(BuildContext context, ConversionTool tool) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConversionFlow(tool: tool)),
    );
    // A conversion may have finished while that route was up.
    await _load();
  }

  Future<void> _openAllTools(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConvertScreen()),
    );
    await _load();
  }

  Future<void> _openRecentFiles(BuildContext context) async {
    if (widget.onSeeAllFiles != null) {
      widget.onSeeAllFiles!();
    }
  }

  Future<void> _open(StoredFile file) async {
    final result = await OpenFilex.open(file.path);
    if (result.type == ResultType.done || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${file.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            child: _recent.isEmpty
                ? const _NoFilesYet()
                : Column(
                    children: [
                      for (final file in _recent)
                        FileRow(
                          file: file.toDocumentFile(),
                          onTap: () => _open(file),
                          onShare: () =>
                              showShareSheet(context, title: file.name),
                          onMore: () => _openRecentFiles(context),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}


/// Placeholder under Recent Files before the user has converted anything.
/// Nothing to migrate here — a fresh install genuinely has no files, and the
/// old sample rows made the app look populated when it was not.
class _NoFilesYet extends StatelessWidget {
  const _NoFilesYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.fileText, size: 30, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('No files yet', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Pick a tool above to convert your first document.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
