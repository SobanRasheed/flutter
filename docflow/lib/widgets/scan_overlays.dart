import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Rounded corner brackets around the code-scanning window, with a sweep line
/// crossing the frame. The region above the line reads as already-scanned, so
/// it carries a light wash.
class FinderOverlay extends StatelessWidget {
  const FinderOverlay({super.key, required this.sweep});

  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sweep,
      builder: (context, _) => CustomPaint(
        painter: _FinderPainter(sweep.value),
        size: Size.infinite,
      ),
    );
  }
}

class _FinderPainter extends CustomPainter {
  const _FinderPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 46.0;
    const radius = 26.0;
    final stroke = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Four L brackets, each turning the corner on a quarter-circle.
    void bracket(Offset corner, double sx, double sy) {
      final path = Path()
        ..moveTo(corner.dx + sx * arm, corner.dy)
        ..lineTo(corner.dx + sx * radius, corner.dy)
        ..quadraticBezierTo(
          corner.dx,
          corner.dy,
          corner.dx,
          corner.dy + sy * radius,
        )
        ..lineTo(corner.dx, corner.dy + sy * arm);
      canvas.drawPath(path, stroke);
    }

    bracket(Offset.zero, 1, 1);
    bracket(Offset(size.width, 0), -1, 1);
    bracket(Offset(0, size.height), 1, -1);
    bracket(Offset(size.width, size.height), -1, -1);

    // Sweep line plus the wash above it.
    final y = size.height * t;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, y),
      Paint()..color = AppColors.primary.withValues(alpha: 0.22),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(_FinderPainter oldDelegate) => oldDelegate.t != t;
}

/// Dashed centre line for book mode, with the page numbers either side.
class SplitOverlay extends StatelessWidget {
  const SplitOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _SplitPainter())),
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final n in ['1', '2'])
                Text(
                  n,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplitPainter extends CustomPainter {
  const _SplitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    const dash = 26.0;
    const gap = 20.0;
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + dash).clamp(0, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SplitPainter oldDelegate) => false;
}

/// The draggable crop frame: a hairline rectangle with round grab handles at
/// the corners and stubby bars at the edge midpoints.
class CropHandlesOverlay extends StatelessWidget {
  const CropHandlesOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _CropPainter(), size: Size.infinite);
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    // Edge grips: short bars centred on each side, long axis along the edge.
    final grip = Paint()..color = AppColors.primary;
    void bar(Offset centre, double w, double h) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: centre, width: w, height: h),
          const Radius.circular(3),
        ),
        grip,
      );
    }

    bar(Offset(rect.center.dx, rect.top), 46, 14);
    bar(Offset(rect.center.dx, rect.bottom), 46, 14);
    bar(Offset(rect.left, rect.center.dy), 14, 46);
    bar(Offset(rect.right, rect.center.dy), 14, 46);

    // Corner handles: white disc ringed in primary.
    final fill = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 13, fill);
      canvas.drawCircle(corner, 13, ring);
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) => false;
}
