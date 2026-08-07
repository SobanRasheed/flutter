import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/conversion_tool.dart';
import 'convert_screen.dart';

/// Scan. ProScan's capture screen, unchanged in layout: dark ground, blue crop
/// handles over the viewport, format tabs above a progress-ring shutter.
///
/// In DocFlow this is a secondary entry point — reached from the Scan button on
/// the shell, not from a tab — and a capture lands in the library as a PDF.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  static const _formats = ['Book', 'ID Card', 'Document', 'Business Card'];

  int _format = 2;
  bool _flashOn = false;
  bool _capturing = false;

  // The scan line sweeps down and back; the ring fills once per capture.
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _shutter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void dispose() {
    _scan.dispose();
    _shutter.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    await _shutter.forward(from: 0);
    if (!mounted) return;
    setState(() => _capturing = false);
    _showResult();
  }

  Future<void> _showResult() async {
    final convert = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(format: _formats[_format]),
    );
    if (!mounted) return;
    if (convert ?? false) {
      // A scan lands as a PDF, so open the converter with a PDF tool ready.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConvertScreen(
            initialTool: ConversionTool.byId('pdf-to-word'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          Positioned.fill(child: _Viewport(scan: _scan, capturing: _capturing)),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  flashOn: _flashOn,
                  onClose: () => Navigator.of(context).pop(),
                  onToggleFlash: () => setState(() => _flashOn = !_flashOn),
                ),
                const Spacer(),
                _FormatTabs(
                  formats: _formats,
                  index: _format,
                  onChanged: (i) => setState(() => _format = i),
                ),
                const SizedBox(height: 20),
                _Controls(
                  progress: _shutter,
                  capturing: _capturing,
                  onCapture: _capture,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera stand-in with the crop frame. A real preview would sit behind the
/// same overlay.
class _Viewport extends StatelessWidget {
  const _Viewport({required this.scan, required this.capturing});

  final Animation<double> scan;
  final bool capturing;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.darkSurface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 96, 28, 220),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.fileText,
                        size: 72, color: AppColors.darkDivider),
                  ),
                ),
                if (!capturing)
                  AnimatedBuilder(
                    animation: scan,
                    builder: (context, _) => CustomPaint(
                      painter: _ScanLinePainter(scan.value),
                    ),
                  ),
                const CustomPaint(painter: _CropHandlesPainter()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The four blue L-brackets marking the detected page edges.
class _CropHandlesPainter extends CustomPainter {
  const _CropHandlesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 30.0;
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void corner(Offset at, double dx, double dy) {
      canvas.drawLine(at, at.translate(arm * dx, 0), paint);
      canvas.drawLine(at, at.translate(0, arm * dy), paint);
    }

    corner(Offset.zero, 1, 1);
    corner(Offset(size.width, 0), -1, 1);
    corner(Offset(0, size.height), 1, -1);
    corner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(_CropHandlesPainter oldDelegate) => false;
}

/// Soft blue sweep line, glow trailing behind it.
class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    canvas.drawRect(
      Rect.fromLTWH(0, y - 26, size.width, 26),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x004B68FF), Color(0x554B68FF)],
        ).createShader(Rect.fromLTWH(0, y - 26, size.width, 26)),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) => oldDelegate.t != t;
}
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flashOn,
    required this.onClose,
    required this.onToggleFlash,
  });

  final bool flashOn;
  final VoidCallback onClose;
  final VoidCallback onToggleFlash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(LucideIcons.x, color: Colors.white),
          ),
          const Spacer(),
          Text(
            'Scan Document',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            onPressed: onToggleFlash,
            icon: Icon(
              flashOn ? LucideIcons.zap : LucideIcons.zapOff,
              color: flashOn ? AppColors.amber : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
/// Horizontally scrolling capture modes; the active one is a filled pill.
class _FormatTabs extends StatelessWidget {
  const _FormatTabs({
    required this.formats,
    required this.index,
    required this.onChanged,
  });

  final List<String> formats;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < formats.length; i++) ...[
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: i == index
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  formats[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: i == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.70),
                  ),
                ),
              ),
            ),
            if (i < formats.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}
/// Gallery, shutter, flip. The shutter's ring fills while a capture runs —
/// the same progress-ring motion ProScan uses.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.progress,
    required this.capturing,
    required this.onCapture,
  });

  final Animation<double> progress;
  final bool capturing;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GhostButton(icon: LucideIcons.image, onPressed: () {}),
          GestureDetector(
            onTap: onCapture,
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) => SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: capturing ? progress.value : 1,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withValues(alpha: 0.20),
                        valueColor: AlwaysStoppedAnimation(
                          capturing ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: capturing ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: capturing
                          ? const Icon(LucideIcons.loader,
                              color: Colors.white, size: 22)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _GhostButton(icon: LucideIcons.refreshCw, onPressed: () {}),
        ],
      ),
    );
  }
}
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// After a capture: the scan is saved as a PDF, and the primary action sends it
/// straight into the conversion tools — scanning feeds the converter.
class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.format});

  final String format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.greenTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check,
                size: 34, color: AppColors.green),
          ),
          const SizedBox(height: 18),
          Text('Scan saved', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '$format scan saved to your library as a PDF.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Convert this file'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep as PDF'),
          ),
        ],
      ),
    );
  }
}
