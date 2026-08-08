import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/document.dart';
import '../widgets/scanner_chrome.dart';

/// Stamp a repeating mark across every page. Dark ground like the scan
/// editors, the page centred under a live preview of the tiling, then a
/// controls sheet for the text, its size and its opacity.
class WatermarkScreen extends StatefulWidget {
  const WatermarkScreen({super.key, required this.file});

  final DocumentFile file;

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  final _text = TextEditingController(text: 'CONFIDENTIAL');
  double _size = 22;
  double _opacity = 0.28;
  double _angle = -35;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Watermark applied to ${widget.file.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        title: const Text('Add Watermark',
            style: TextStyle(color: Colors.white, fontSize: 20)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      widget.file.thumbnail == null
                          ? AspectRatio(
                              aspectRatio: 3 / 4,
                              child: ColoredBox(color: Colors.white),
                            )
                          : PagePreview(
                              asset: widget.file.thumbnail!,
                              aspectRatio: 3 / 4,
                            ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _WatermarkPainter(
                              text: _text.text,
                              fontSize: _size,
                              opacity: _opacity,
                              angle: _angle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _Controls(
            controller: _text,
            size: _size,
            opacity: _opacity,
            angle: _angle,
            onSize: (v) => setState(() => _size = v),
            onOpacity: (v) => setState(() => _opacity = v),
            onAngle: (v) => setState(() => _angle = v),
            onApply: _apply,
          ),
        ],
      ),
    );
  }
}

/// Tiles [text] across the page on a rotated grid, the way a stamped PDF reads.
class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({
    required this.text,
    required this.fontSize,
    required this.opacity,
    required this.angle,
  });

  final String text;
  final double fontSize;
  final double opacity;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.trim().isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary.withValues(alpha: opacity),
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final radians = angle * math.pi / 180;
    // Step by the mark's own footprint so the grid stays even at any size.
    final stepX = painter.width + fontSize * 2.2;
    final stepY = painter.height + fontSize * 3.4;
    // Overdraw past the edges so rotation never leaves a bare corner.
    final reach = size.longestSide;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(radians);

    for (var y = -reach; y < reach; y += stepY) {
      for (var x = -reach; x < reach; x += stepX) {
        painter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter old) =>
      old.text != text ||
      old.fontSize != fontSize ||
      old.opacity != opacity ||
      old.angle != angle;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.size,
    required this.opacity,
    required this.angle,
    required this.onSize,
    required this.onOpacity,
    required this.onAngle,
    required this.onApply,
  });

  final TextEditingController controller;
  final double size;
  final double opacity;
  final double angle;
  final ValueChanged<double> onSize;
  final ValueChanged<double> onOpacity;
  final ValueChanged<double> onAngle;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  labelText: 'Watermark text',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  hintText: 'CONFIDENTIAL',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.darkDivider),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _Slider(
                icon: LucideIcons.type,
                label: 'Size',
                value: size,
                min: 12,
                max: 44,
                display: size.round().toString(),
                onChanged: onSize,
              ),
              _Slider(
                icon: LucideIcons.droplet,
                label: 'Opacity',
                value: opacity,
                min: 0.05,
                max: 0.6,
                display: '${(opacity * 100).round()}%',
                onChanged: onOpacity,
              ),
              _Slider(
                icon: LucideIcons.rotateCw,
                label: 'Angle',
                value: angle,
                min: -90,
                max: 90,
                display: '${angle.round()}°',
                onChanged: onAngle,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onApply,
                  child: const Text('Apply Watermark'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.darkDivider,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
