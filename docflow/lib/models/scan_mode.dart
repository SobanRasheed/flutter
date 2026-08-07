import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// What the camera is pointed at. The kit ships a mode per subject; the overlay
/// and the framing guide change with the choice.
enum ScanMode {
  qrCode('QR Code', _Overlay.finder),
  barcode('Barcode', _Overlay.finder),
  book('Book', _Overlay.split),
  idCard('ID Card', _Overlay.crop),
  document('Document', _Overlay.crop),
  businessCard('Business Card', _Overlay.crop),
  whiteboard('Whiteboard', _Overlay.crop);

  const ScanMode(this.label, this.overlay);

  final String label;
  final _Overlay overlay;

  /// Codes get their own stripped-back chrome: a title and instruction in place
  /// of the edit icons, and no captured-page thumbnail.
  bool get isCode => this == ScanMode.qrCode || this == ScanMode.barcode;

  /// Books are shot two pages at a time, so the guide splits down the middle.
  bool get isSplit => overlay == _Overlay.split;

  bool get hasFinder => overlay == _Overlay.finder;
  bool get hasCropHandles => overlay == _Overlay.crop;

  /// Caption floated over the frame while composing the shot.
  String? get hint => switch (this) {
        ScanMode.qrCode => 'Please point the camera at the QR Code',
        ScanMode.barcode => 'Please point the camera at the Barcode',
        ScanMode.idCard => 'ID Card Front Page',
        _ => null,
      };

  /// The frame the subject is expected to fill.
  double get aspectRatio => switch (this) {
        ScanMode.idCard || ScanMode.businessCard => 1.6,
        ScanMode.qrCode || ScanMode.barcode => 1.1,
        ScanMode.whiteboard => 1.4,
        _ => 0.72,
      };

  IconData get icon => switch (this) {
        ScanMode.qrCode => LucideIcons.qrCode,
        ScanMode.barcode => LucideIcons.scanLine,
        ScanMode.book => LucideIcons.bookOpen,
        ScanMode.idCard => LucideIcons.creditCard,
        ScanMode.document => LucideIcons.fileText,
        ScanMode.businessCard => LucideIcons.contact,
        ScanMode.whiteboard => LucideIcons.presentation,
      };
}

enum _Overlay { finder, split, crop }

/// One retouch action on the post-capture edit strip.
enum ScanTool {
  auto('Auto', LucideIcons.scanLine),
  retake('Retake', LucideIcons.refreshCw),
  crop('Crop', LucideIcons.crop),
  rotate('Rotate', LucideIcons.rotateCw),
  filter('Filter', LucideIcons.sparkles),
  resize('Resize', LucideIcons.maximize2),
  delete('Delete', LucideIcons.trash2);

  const ScanTool(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Paper sizes offered by the resize sheet.
enum PaperSize {
  autoFit('Auto', 'Fit', null),
  a4('A4', 'Portrait', 210 / 297),
  a3('A3', 'Portrait', 297 / 420),
  a5('A5', 'Portrait', 148 / 210),
  usLetter('US Letter', 'Portrait', 8.5 / 11),
  usLegal('US Legal', 'Portrait', 8.5 / 14);

  const PaperSize(this.label, this.orientation, this.aspectRatio);

  final String label;
  final String orientation;

  /// Null for Auto Fit, which keeps whatever the capture produced.
  final double? aspectRatio;
}
