import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../data/sample_data.dart';
import '../models/document.dart';
import 'file_row.dart';

/// Bottom-sheet chrome shared by the file actions: a grab handle, then a
/// title row with a dismiss X.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const SizedBox(width: 20),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              icon: const Icon(LucideIcons.x,
                  size: 22, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ],
    );
  }
}

/// Prompts for a new file name and resolves with it.
Future<String?> showRenameSheet(BuildContext context, {required String name}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RenameSheet(name: name),
  );
}

class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.name});

  final String name;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final _controller = TextEditingController(text: widget.name);
  late final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: 'Rename file',
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    Navigator.of(context).pop(_controller.text.trim()),
                decoration: InputDecoration(
                  hintText: 'File name',
                  suffixIcon: IconButton(
                    onPressed: () {
                      _controller.clear();
                      _focus.requestFocus();
                    },
                    icon: const Icon(LucideIcons.x,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_controller.text.trim()),
                  child: const Text('Save'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user pick a destination folder. The current folder is checked; a
/// Move action commits the choice.
class MoveToFolderScreen extends StatefulWidget {
  const MoveToFolderScreen({super.key, required this.file});

  final DocumentFile file;

  @override
  State<MoveToFolderScreen> createState() => _MoveToFolderScreenState();
}

class _MoveToFolderScreenState extends State<MoveToFolderScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folders = SampleData.folders;

    return Scaffold(
      appBar: AppBar(
        title: Text('Move to folder', style: theme.textTheme.titleLarge),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('Move',
                style: TextStyle(color: AppColors.primary, fontSize: 16)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text('Select a folder', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _FolderTile(
              label: 'Recent Files',
              fileCount: '${SampleData.recentFiles.length} files',
              selected: _selected == -1,
              onTap: () => setState(() => _selected = -1),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < folders.length; i++) ...[
              _FolderTile(
                label: folders[i].name,
                fileCount: '${folders[i].fileCount} files',
                selected: _selected == i,
                onTap: () => setState(() => _selected = i),
              ),
              if (i < folders.length - 1) const SizedBox(height: 16),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Move "${widget.file.name}" to:',
              style: theme.textTheme.bodyMedium,
            ),
            if (_selected != null)
              Text(
                _selected == -1
                    ? 'Recent Files'
                    : folders[_selected!].name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.label,
    required this.fileCount,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String fileCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryTint : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(LucideIcons.folder,
                  size: 26, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyLarge),
                    Text(fileCount,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? LucideIcons.circleDot : LucideIcons.circle,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms deletion. Shows the file being deleted, a coral trash button, and
/// resolves true on confirm.
Future<bool> showDeleteSheet(BuildContext context, {required DocumentFile file}) {
  return showModalBottomSheet<bool>(
    context: context,
    builder: (_) => _DeleteSheet(file: file),
  ).then((value) => value ?? false);
}

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({required this.file});

  final DocumentFile file;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(title: 'Delete file'),
            const SizedBox(height: 8),
            FileCard(file: file),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(LucideIcons.trash2, size: 18),
              label: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
