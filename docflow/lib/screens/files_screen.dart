import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../data/sample_data.dart';
import '../widgets/file_row.dart';

/// The Files tab — ProScan's file manager: a segmented Files/Folders control
/// over the list, with search and sort in the header.
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Text('My Files', style: theme.textTheme.displayMedium),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.arrowUpDown,
                      size: 20, color: AppColors.textPrimary),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.folderPlus,
                      size: 20, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search files and folders',
                prefixIcon: Icon(LucideIcons.search, size: 20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Segmented(
              index: _segment,
              labels: [
                'Files (${SampleData.recentFiles.length})',
                'Folders (${SampleData.folders.length})',
              ],
              onChanged: (i) => setState(() => _segment = i),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _segment == 0
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                    children: [
                      for (final file in SampleData.recentFiles)
                        FileRow(
                          file: file,
                          onTap: () {},
                          onShare: () {},
                          onMore: () {},
                        ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                    children: [
                      for (final folder in SampleData.folders)
                        FolderRow(
                          folder: folder,
                          onTap: () {},
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

/// Pill segmented control from the ProScan files screen.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: i == index ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
