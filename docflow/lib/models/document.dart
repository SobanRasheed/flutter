import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';

/// File formats DocFlow can read or write.
enum DocFormat {
  pdf('PDF', 'pdf', LucideIcons.fileText, AppColors.coral, AppColors.coralTint),
  docx('Word', 'docx', LucideIcons.fileType, AppColors.primary,
      AppColors.primaryTint),
  xlsx('Excel', 'xlsx', LucideIcons.fileSpreadsheet, AppColors.green,
      AppColors.greenTint),
  pptx('PowerPoint', 'pptx', LucideIcons.presentation, AppColors.amber,
      AppColors.amberTint),
  jpg('JPEG', 'jpg', LucideIcons.image, AppColors.violet, AppColors.violetTint),
  png('PNG', 'png', LucideIcons.image, AppColors.brown, AppColors.brownTint);

  const DocFormat(this.label, this.extension, this.icon, this.color, this.tint);

  final String label;
  final String extension;
  final IconData icon;
  final Color color;
  final Color tint;
}

/// A document in the user's library.
class DocumentFile {
  const DocumentFile({
    required this.name,
    required this.format,
    required this.sizeLabel,
    required this.date,
    required this.time,
    this.pages = 1,
    this.starred = false,
    this.thumbnail,
  });

  final String name;
  final DocFormat format;
  final String sizeLabel;
  final String date;
  final String time;
  final int pages;
  final bool starred;

  /// Page render exported from the kit. Null falls back to the drawn sheet.
  final String? thumbnail;

  String get fullName => '$name.${format.extension}';
}

/// A user-created folder, rendered with ProScan's blue folder tile.
class DocFolder {
  const DocFolder({
    required this.name,
    required this.fileCount,
    required this.date,
    required this.time,
  });

  final String name;
  final int fileCount;
  final String date;
  final String time;
}
