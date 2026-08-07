import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/scan_mode.dart';
import '../widgets/scan_overlays.dart';
import '../widgets/scanner_chrome.dart';
import 'scan_edit_screen.dart';

/// Capture. Dark chrome, a full-bleed camera feed, the framing guide for the
/// chosen subject, and a mode strip above the shutter.
///
/// In DocFlow this is a secondary entry point — reached from the camera button
/// on the shell, not from a tab — and a capture lands in the library as a PDF.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.initialMode = ScanMode.document});

  final ScanMode initialMode;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  late ScanMode _mode = widget.initialMode;
  bool _flashOn = false;
  bool _capturing = false;

  // The finder line sweeps down and back; the ring fills once per capture.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _shutter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void dispose() {
    _sweep.dispose();
    _shutter.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    await _shutter.forward(from: 0);
    if (!mounted) return;
    setState(() => _capturing = false);

    // Codes resolve in place; page scans continue to the editor.
    if (_mode.isCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_mode.label} detected')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScanEditScreen(mode: _mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _mode.isCode
                ? _CodeHeader(
                    mode: _mode,
                    onBack: () => Navigator.of(context).pop(),
                  )
                : _CaptureHeader(
                    flashOn: _flashOn,
                    onBack: () => Navigator.of(context).pop(),
                    onToggleFlash: () =>
                        setState(() => _flashOn = !_flashOn),
                  ),
          ),
          Expanded(child: _Viewfinder(mode: _mode, sweep: _sweep)),
          _ModeStrip(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          SafeArea(
            top: false,
            child: _ControlBar(
              mode: _mode,
              progress: _shutter,
              capturing: _capturing,
              onCapture: _capture,
            ),
          ),
        ],
      ),
    );
  }
}

/// Header for page scans: back, then auto-detect, enhance, flash and more.
class _CaptureHeader extends StatelessWidget {
  const _CaptureHeader({
    required this.flashOn,
    required this.onBack,
    required this.onToggleFlash,
  });

  final bool flashOn;
  final VoidCallback onBack;
  final VoidCallback onToggleFlash;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: onBack,
            icon: const Icon(LucideIcons.arrowLeft,
                color: Colors.white, size: 26),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            tooltip: 'Auto detect edges',
            icon: const Icon(LucideIcons.scanLine,
                color: Colors.white, size: 24),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Enhance',
            icon: const Icon(LucideIcons.wand2, color: Colors.white, size: 24),
          ),
          IconButton(
            onPressed: onToggleFlash,
            tooltip: flashOn ? 'Flash on' : 'Flash off',
            icon: Icon(
              flashOn ? LucideIcons.zap : LucideIcons.zapOff,
              color: flashOn ? AppColors.amber : Colors.white,
              size: 24,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.moreHorizontal,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Header for code scans: back arrow over a centred title and instruction.
class _CodeHeader extends StatelessWidget {
  const _CodeHeader({required this.mode, required this.onBack});

  final ScanMode mode;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 76,
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                onPressed: onBack,
                icon: const Icon(LucideIcons.arrowLeft,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Scan ${mode.label}',
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontSize: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            mode.hint ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// The camera area. A real preview would sit where the placeholder is; the
/// framing guide for the active mode is painted over it.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.mode, required this.sweep});

  final ScanMode mode;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.darkSurface),
          Center(
            child: Icon(mode.icon, size: 64, color: AppColors.darkDivider),
          ),
          // Book mode guides the whole frame; the rest frame a subject.
          if (mode.isSplit)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SplitOverlay(),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: AspectRatio(
                  aspectRatio: mode.aspectRatio,
                  child: mode.hasFinder
                      ? FinderOverlay(sweep: sweep)
                      : const CropHandlesOverlay(),
                ),
              ),
            ),
          if (mode == ScanMode.idCard)
            Align(
              alignment: const Alignment(0, -0.55),
              child: DarkPill(label: mode.hint!),
            ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling subject modes. The active one is primary with a bar
/// above it; the strip keeps the selection centred.
class _ModeStrip extends StatefulWidget {
  const _ModeStrip({required this.mode, required this.onChanged});

  final ScanMode mode;
  final ValueChanged<ScanMode> onChanged;

  @override
  State<_ModeStrip> createState() => _ModeStripState();
}

class _ModeStripState extends State<_ModeStrip> {
  final _controller = ScrollController();
  final _keys = {for (final m in ScanMode.values) m: GlobalKey()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centre());
  }

  @override
  void didUpdateWidget(_ModeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _centre();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _centre() {
    final context = _keys[widget.mode]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      color: AppColors.darkBackground,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            for (final mode in ScanMode.values)
              _ModeTab(
                key: _keys[mode],
                mode: mode,
                selected: mode == widget.mode,
                onTap: () => widget.onChanged(mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    super.key,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ScanMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 5,
              width: selected ? 72 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              mode.label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Import buttons, the shutter, and the last capture. Code modes have nothing
/// to review, so the thumbnail slot stays empty to keep the shutter centred.
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.mode,
    required this.progress,
    required this.capturing,
    required this.onCapture,
  });

  final ScanMode mode;
  final Animation<double> progress;
  final bool capturing;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkBackground,
      padding: const EdgeInsets.fromLTRB(38, 18, 38, 22),
      child: Row(
        children: [
          ScannerCircleButton(icon: LucideIcons.folder, onPressed: () {}),
          const SizedBox(width: 12),
          ScannerCircleButton(icon: LucideIcons.image, onPressed: () {}),
          Expanded(
            child: Center(
              child: ShutterButton(
                progress: progress,
                capturing: capturing,
                onPressed: onCapture,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: mode.isCode
                ? null
                : CaptureThumbnail(onPressed: () {}),
          ),
        ],
      ),
    );
  }
}
