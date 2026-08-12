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
    // The SVG viewBox is 2400x1200 (2:1 ratio), so we render it at size×size
    // but let flutter_svg fit it properly within the bounding box.
    return SvgPicture.asset(
      'assets/logo/logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
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
