import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/document.dart';
import '../widgets/file_actions.dart';
import '../widgets/share_sheet.dart';
import 'pdf_tools_screens.dart';
import 'signature_screen.dart';
import 'watermark_screen.dart';

/// The overflow sheet behind the ⋯ on every file row: share and the file
/// operations, then the PDF tools that act on a single document. Routing lives
/// here so the list screens only have to hand over the file.
Future<void> showFileActionMenu(
  BuildContext context, {
  required DocumentFile file,
}) async {
  final action = await showModalBottomSheet<_FileAction>(
    context: context,
    builder: (_) => _ActionSheet(file: file),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _FileAction.share:
      await showShareSheet(context, title: file.name);
    case _FileAction.rename:
      final name = await showRenameSheet(context, name: file.name);
      if (name == null || name.isEmpty || !context.mounted) return;
      _toast(context, 'Renamed to "$name"');
    case _FileAction.move:
      final folder = await Navigator.of(context).push<int>(
        MaterialPageRoute(builder: (_) => MoveToFolderScreen(file: file)),
      );
      if (folder == null || !context.mounted) return;
      _toast(context, 'Moved "${file.name}"');
    case _FileAction.watermark:
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WatermarkScreen(file: file)),
      );
    case _FileAction.sign:
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SignatureScreen(file: file)),
      );
    case _FileAction.protect:
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProtectPdfScreen(file: file)),
      );
    case _FileAction.compress:
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CompressPdfScreen(file: file)),
      );
    case _FileAction.delete:
      final confirmed = await showDeleteSheet(context, file: file);
      if (!confirmed || !context.mounted) return;
      _toast(context, '"${file.name}" deleted');
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

enum _FileAction {
  share,
  rename,
  move,
  watermark,
  sign,
  protect,
  compress,
  delete,
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.file});

  final DocumentFile file;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(title: file.name),
            const SizedBox(height: 4),
            const _Tile(
              icon: LucideIcons.share2,
              label: 'Share',
              action: _FileAction.share,
            ),
            const _Tile(
              icon: LucideIcons.pencil,
              label: 'Rename',
              action: _FileAction.rename,
            ),
            const _Tile(
              icon: LucideIcons.folderInput,
              label: 'Move to folder',
              action: _FileAction.move,
            ),
            const Divider(indent: 20, endIndent: 20),
            const _Tile(
              icon: LucideIcons.droplets,
              label: 'Add watermark',
              action: _FileAction.watermark,
            ),
            const _Tile(
              icon: LucideIcons.penTool,
              label: 'Add signature',
              action: _FileAction.sign,
            ),
            const _Tile(
              icon: LucideIcons.lock,
              label: 'Protect with password',
              action: _FileAction.protect,
            ),
            const _Tile(
              icon: LucideIcons.minimize2,
              label: 'Compress',
              action: _FileAction.compress,
            ),
            const Divider(indent: 20, endIndent: 20),
            const _Tile(
              icon: LucideIcons.trash2,
              label: 'Delete',
              action: _FileAction.delete,
              danger: true,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.action,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final _FileAction action;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.coral : AppColors.textPrimary;

    return ListTile(
      onTap: () => Navigator.of(context).pop(action),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, size: 22, color: color),
      title: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
