import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/document.dart';

/// A file row from the ProScan recent-files list: page thumbnail on the left,
/// name over timestamp, then share and overflow actions.
class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.file,
    this.onTap,
    this.onShare,
    this.onMore,
  });

  final DocumentFile file;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                _Thumbnail(file: file),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 18,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${file.date}   ${file.time}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMeta),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onShare,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.share2,
                      size: 20, color: AppColors.textPrimary),
                ),
                IconButton(
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.moreVertical,
                      size: 20, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A read-only file summary — thumbnail, name, timestamp — with no actions.
/// Used where a screen needs to confirm *which* file it is acting on: the
/// delete sheet and the single-file PDF tools.
class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.file});

  final DocumentFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          _Thumbnail(file: file),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontSize: 18, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  '${file.date}   ${file.time}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textMeta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The page preview: an 88pt square holding the render exported from the kit,
/// cropped to the top of the page. Files with no render fall back to a drawn
/// sheet with ruled lines and a format badge.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.file});

  final DocumentFile file;

  @override
  Widget build(BuildContext context) {
    final thumbnail = file.thumbnail;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 88,
        height: 88,
        child: thumbnail == null
            ? _DrawnSheet(format: file.format)
            : Image.asset(
                thumbnail,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
      ),
    );
  }
}

class _DrawnSheet extends StatelessWidget {
  const _DrawnSheet({required this.format});

  final DocFormat format;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(format.icon, size: 16, color: format.color),
          const SizedBox(height: 8),
          for (var i = 0; i < 5; i++) ...[
            Container(
              height: 2,
              width: i.isEven ? 58 : 44,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 5),
          ],
          const Spacer(),
          Text(
            format.extension.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: format.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Folder row from the ProScan files screen: rounded blue folder, name, and
/// file count over a timestamp.
class FolderRow extends StatelessWidget {
  const FolderRow({super.key, required this.folder, this.onTap, this.onMore});

  final DocFolder folder;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const _FolderGlyph(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(folder.name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(LucideIcons.fileText,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('${folder.fileCount} files',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${folder.date}   ${folder.time}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.moreVertical,
                      size: 20, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderGlyph extends StatelessWidget {
  const _FolderGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 72,
      child: Stack(
        children: [
          // Offset tab peeking out behind the folder body.
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              width: 44,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: 16,
            child: Container(
              width: 52,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
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
