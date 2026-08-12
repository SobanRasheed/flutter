import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/tokens.dart';

/// DocFlow SVG logo mark.
class DocFlowLogo extends StatelessWidget {
  const DocFlowLogo({super.key, this.size = 32, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // The SVG canvas is 2400×1200 but the logo mark only occupies roughly
    // x:[930,1620] y:[295,895] — a 690×600 region.
    // Strategy: render the SVG at 2× height so 600 SVG units = `size` pixels,
    // then use OverflowBox + ClipRect to pan to that region and clip everything
    // outside it.
    return SizedBox(
      width: size * 1.15, // content aspect ratio: 690/600 ≈ 1.15
      height: size,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          // Shifts the viewport so the logo mark is centred in the box.
          alignment: const Alignment(0.08, -0.01),
          child: SvgPicture.asset(
            'assets/logo/logo.svg',
            height: size * 2, // scale: 600 SVG units → size px
            colorFilter: color != null
                ? ColorFilter.mode(color!, BlendMode.srcIn)
                : null,
          ),
        ),
      ),
    );
  }
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DocFlowLogo(size: logoSize),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: onDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
            children: const [
              TextSpan(text: 'Doc'),
              TextSpan(
                text: 'Flow',
                style: TextStyle(
                  color: Color(0xFF3D53DC),
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
