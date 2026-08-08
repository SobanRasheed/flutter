import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/document.dart';
import '../widgets/scanner_chrome.dart';

/// Sign a document in two beats: draw the signature, then drop it on the page
/// and drag it where it belongs.
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key, required this.file});

  final DocumentFile file;

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  /// Each stroke is a run of points; a new stroke starts on every pen-down so
  /// lifting the finger does not connect back to the last mark.
  final List<List<Offset>> _strokes = [];
  bool _placing = false;

  /// Where the signature sits on the page, as a fraction of its box.
  Offset _position = const Offset(0.55, 0.78);
  double _scale = 1;

  bool get _hasInk => _strokes.any((s) => s.length > 1);

  void _clear() => setState(_strokes.clear);

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _save() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Signed ${widget.file.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        title: Text(
          _placing ? 'Place Signature' : 'Add Signature',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: IconButton(
          onPressed: () => _placing
              ? setState(() => _placing = false)
              : Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        ),
        actions: [
          if (!_placing) ...[
            IconButton(
              onPressed: _hasInk ? _undo : null,
              tooltip: 'Undo stroke',
              icon: const Icon(LucideIcons.undo2, color: Colors.white),
            ),
            IconButton(
              onPressed: _hasInk ? _clear : null,
              tooltip: 'Clear',
              icon: const Icon(LucideIcons.trash2, color: Colors.white),
            ),
          ],
        ],
      ),
      body: _placing ? _buildPlacing() : _buildDrawing(),
    );
  }

  Widget _buildDrawing() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _SignaturePad(
              strokes: _strokes,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              children: [
                const Text(
                  'Draw your signature above',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _hasInk ? () => setState(() => _placing = true) : null,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlacing() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        child: widget.file.thumbnail == null
                            ? const AspectRatio(
                                aspectRatio: 3 / 4,
                                child: ColoredBox(color: Colors.white),
                              )
                            : PagePreview(
                                asset: widget.file.thumbnail!,
                                aspectRatio: 3 / 4,
                              ),
                      ),
                      Positioned(
                        left: _position.dx * constraints.maxWidth - 80 * _scale,
                        top: _position.dy * constraints.maxHeight - 30 * _scale,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _position += Offset(
                                details.delta.dx / constraints.maxWidth,
                                details.delta.dy / constraints.maxHeight,
                              );
                            });
                          },
                          child: Container(
                            width: 160 * _scale,
                            height: 60 * _scale,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: CustomPaint(
                              painter: _InkPainter(
                                strokes: _strokes,
                                color: AppColors.textPrimary,
                                fit: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.move,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    const Text('Size',
                        style: TextStyle(color: AppColors.textSecondary)),
                    Expanded(
                      child: Slider(
                        value: _scale,
                        min: 0.6,
                        max: 1.8,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.darkDivider,
                        onChanged: (v) => setState(() => _scale = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save Signed PDF'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The draw surface: white card, guide rule, ink follows the finger.
class _SignaturePad extends StatelessWidget {
  const _SignaturePad({required this.strokes, required this.onChanged});

  final List<List<Offset>> strokes;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: GestureDetector(
        onPanStart: (details) {
          strokes.add([details.localPosition]);
          onChanged();
        },
        onPanUpdate: (details) {
          if (strokes.isEmpty) return;
          strokes.last.add(details.localPosition);
          onChanged();
        },
        child: CustomPaint(
          painter: _InkPainter(
            strokes: strokes,
            color: AppColors.textPrimary,
            guide: true,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  const _InkPainter({
    required this.strokes,
    required this.color,
    this.guide = false,
    this.fit = false,
  });

  final List<List<Offset>> strokes;
  final Color color;

  /// Draws the dashed baseline shown on the empty pad.
  final bool guide;

  /// Rescales the captured ink to fill this box, for the placement preview.
  final bool fit;

  @override
  void paint(Canvas canvas, Size size) {
    if (guide) {
      final y = size.height * 0.72;
      final dash = Paint()
        ..color = AppColors.divider
        ..strokeWidth = 2;
      for (var x = 24.0; x < size.width - 24; x += 14) {
        canvas.drawLine(Offset(x, y), Offset(x + 7, y), dash);
      }
    }

    if (strokes.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = fit ? 2 : 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // In fit mode the ink was captured in a different box, so map its bounds
    // onto this one before drawing.
    var scale = 1.0;
    var offset = Offset.zero;
    if (fit) {
      var minX = double.infinity, minY = double.infinity;
      var maxX = -double.infinity, maxY = -double.infinity;
      for (final stroke in strokes) {
        for (final p in stroke) {
          minX = p.dx < minX ? p.dx : minX;
          minY = p.dy < minY ? p.dy : minY;
          maxX = p.dx > maxX ? p.dx : maxX;
          maxY = p.dy > maxY ? p.dy : maxY;
        }
      }
      final w = (maxX - minX).abs();
      final h = (maxY - minY).abs();
      if (w == 0 || h == 0) return;
      const pad = 6.0;
      scale = ((size.width - pad * 2) / w).clamp(0.0, (size.height - pad * 2) / h);
      offset = Offset(
        pad - minX * scale + (size.width - pad * 2 - w * scale) / 2,
        pad - minY * scale + (size.height - pad * 2 - h * scale) / 2,
      );
    }

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      final first = stroke.first * scale + offset;
      path.moveTo(first.dx, first.dy);
      for (final point in stroke.skip(1)) {
        final p = point * scale + offset;
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => true;
}
