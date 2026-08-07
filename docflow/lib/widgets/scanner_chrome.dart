import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Pieces shared by the capture screen and the post-capture editor: both sit on
/// the same dark ground with the same header and footer metrics.
///
/// Header is 56pt of chrome over #181A20; the footer bar is #1F222A.

/// Circular ghost button used for the gallery/import actions beside the shutter.
class ScannerCircleButton extends StatelessWidget {
  const ScannerCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkElevated,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }
}

/// The shutter: a 90pt ring that fills while a capture runs, hollow at rest.
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    super.key,
    required this.progress,
    required this.capturing,
    required this.onPressed,
  });

  final Animation<double> progress;
  final bool capturing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  // Resting state shows the ring three-quarters drawn, as in
                  // the kit; a capture sweeps it to full.
                  value: capturing ? progress.value : 0.78,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.darkElevated,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.darkSurface,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnail of the most recent capture, sitting opposite the ghost buttons.
class CaptureThumbnail extends StatelessWidget {
  const CaptureThumbnail({super.key, required this.onPressed, this.pages = 1});

  final VoidCallback onPressed;
  final int pages;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 78,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.all(4),
        child: pages > 1
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$pages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// A page rendered on white, sized to the paper it is bound for. Used by the
/// editor, the resize sheet and the viewer.
class PagePreview extends StatelessWidget {
  const PagePreview({super.key, required this.asset, this.aspectRatio});

  final String asset;

  /// Null keeps the render's own proportions (Auto Fit).
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final page = ColoredBox(
      color: Colors.white,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        errorBuilder: (context, _, __) => const SizedBox.shrink(),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: aspectRatio == null
          ? page
          : AspectRatio(aspectRatio: aspectRatio!, child: page),
    );
  }
}

/// Rounded dark pill used for the mode hint and the "Page 1 of 1" counter.
class DarkPill extends StatelessWidget {
  const DarkPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
