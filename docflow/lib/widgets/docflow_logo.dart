import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// The DocFlow mark: ProScan's aperture logo geometry — a ring of six angled
/// blades — recoloured to the brand blue.
class DocFlowLogo extends StatelessWidget {
  const DocFlowLogo({super.key, this.size = 32, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _AperturePainter(color ?? AppColors.primary),
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  const _AperturePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    // Six blades, each a wedge inset from the centre so the gaps read as the
    // aperture's spiral.
    const bladeCount = 6;
    const sweep = 6.283185307179586 / bladeCount;
    const gap = 0.10;

    for (var i = 0; i < bladeCount; i++) {
      final start = sweep * i + gap;
      final paint = Paint()
        // Alternating opacity gives the two-tone look of the original mark.
        ..color = i.isEven ? color : color.withValues(alpha: 0.72)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep - gap * 2,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }

  }

  @override
  bool shouldRepaint(_AperturePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Logo + wordmark, as it appears in the ProScan home/files/account headers.
class DocFlowWordmark extends StatelessWidget {
  const DocFlowWordmark({super.key, this.logoSize = 32, this.onDark = false});

  final double logoSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DocFlowLogo(size: logoSize),
        const SizedBox(width: 12),
        Text(
          'DocFlow',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: onDark ? Colors.white : AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}
