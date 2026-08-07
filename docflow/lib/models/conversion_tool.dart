import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import 'document.dart';

/// The eight conversion tools DocFlow ships, taken verbatim from the DocFlow
/// marketing site (docflowmarketing.vercel.app) — same titles, descriptions and
/// from/to formats. They occupy the tool grid that ProScan used for its PDF
/// utilities.
class ConversionTool {
  const ConversionTool({
    required this.id,
    required this.title,
    required this.description,
    required this.from,
    required this.to,
    required this.icon,
    required this.color,
    required this.tint,
    this.twoWay = false,
  });

  final String id;
  final String title;
  final String description;
  final String from;
  final String to;
  final IconData icon;
  final Color color;
  final Color tint;

  /// Image ↔ PDF converts in both directions.
  final bool twoWay;

  static const List<ConversionTool> all = [
    ConversionTool(
      id: 'pdf-to-word',
      title: 'PDF to Word',
      description: 'Convert PDF documents to editable .docx files',
      from: 'PDF',
      to: 'DOCX',
      icon: LucideIcons.fileText,
      color: AppColors.amber,
      tint: AppColors.amberTint,
    ),
    ConversionTool(
      id: 'word-to-pdf',
      title: 'Word to PDF',
      description: 'Turn your Word documents into universal PDFs',
      from: 'DOCX',
      to: 'PDF',
      icon: LucideIcons.fileType,
      color: AppColors.violet,
      tint: AppColors.violetTint,
    ),
    ConversionTool(
      id: 'pdf-to-excel',
      title: 'PDF to Excel',
      description: 'Extract tables and data into .xlsx spreadsheets',
      from: 'PDF',
      to: 'XLSX',
      icon: LucideIcons.table2,
      color: AppColors.green,
      tint: AppColors.greenTint,
    ),
    ConversionTool(
      id: 'excel-to-pdf',
      title: 'Excel to PDF',
      description: 'Convert spreadsheets to shareable PDF format',
      from: 'XLSX',
      to: 'PDF',
      icon: LucideIcons.fileSpreadsheet,
      color: AppColors.green,
      tint: AppColors.greenTint,
    ),
    ConversionTool(
      id: 'merge-pdf',
      title: 'Merge PDF',
      description: 'Combine multiple PDFs into a single document',
      from: 'PDF+PDF',
      to: 'PDF',
      icon: LucideIcons.combine,
      color: AppColors.coral,
      tint: AppColors.coralTint,
    ),
    ConversionTool(
      id: 'split-pdf',
      title: 'Split PDF',
      description: 'Extract specific pages from any PDF file',
      from: 'PDF',
      to: 'Pages',
      icon: LucideIcons.scissors,
      color: AppColors.violet,
      tint: AppColors.violetTint,
    ),
    ConversionTool(
      id: 'compress-pdf',
      title: 'Compress PDF',
      description: 'Reduce file size without losing quality',
      from: 'PDF',
      to: 'Smaller PDF',
      icon: LucideIcons.minimize2,
      color: AppColors.amber,
      tint: AppColors.amberTint,
    ),
    ConversionTool(
      id: 'image-pdf',
      title: 'Image ↔ PDF',
      description: 'Convert images to PDF or extract pages as images',
      from: 'JPG/PNG',
      to: 'PDF',
      icon: LucideIcons.image,
      color: AppColors.brown,
      tint: AppColors.brownTint,
      twoWay: true,
    ),
  ];

  static ConversionTool byId(String id) =>
      all.firstWhere((tool) => tool.id == id);

  /// Whether this tool can read [format] as its input.
  bool accepts(DocFormat format) => switch (from) {
        'PDF' || 'PDF+PDF' => format == DocFormat.pdf,
        'DOCX' => format == DocFormat.docx,
        'XLSX' => format == DocFormat.xlsx,
        'JPG/PNG' => format == DocFormat.jpg || format == DocFormat.png,
        _ => false,
      };
}
