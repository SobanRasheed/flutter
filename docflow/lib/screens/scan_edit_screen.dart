import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/scan_mode.dart';
import '../widgets/scanner_chrome.dart';
import 'document_viewer_screen.dart';

/// Review and retouch a capture before it is saved. Dark ground, the page
/// centred, a scrolling tool strip, then Scan More / Save PDF.
class ScanEditScreen extends StatefulWidget {
  const ScanEditScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  State<ScanEditScreen> createState() => _ScanEditScreenState();
}

class _ScanEditScreenState extends State<ScanEditScreen> {
  /// Untouched captures are titled by timestamp until the user renames them.
  String _name = 'Scan - 12/30/2023 - 09:41';
  bool _renamed = false;
  ScanTool _tool = ScanTool.auto;
  PaperSize _paper = PaperSize.autoFit;

  Future<void> _rename() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ScanRenameScreen(name: _name)),
    );
    if (name == null || !mounted) return;
    setState(() {
      _name = name;
      _renamed = true;
    });
  }

  Future<void> _resize() async {
    final paper = await Navigator.of(context).push<PaperSize>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ResizeScreen(selected: _paper),
      ),
    );
    if (paper == null || !mounted) return;
    setState(() => _paper = paper);
  }

  Future<void> _onTool(ScanTool tool) async {
    setState(() => _tool = tool);
    switch (tool) {
      case ScanTool.resize:
        await _resize();
      case ScanTool.retake:
        if (mounted) Navigator.of(context).pop();
      case ScanTool.delete:
        if (mounted) Navigator.of(context).pop();
      default:
        break;
    }
  }

  void _save() {
    // The scan lands in the library; the viewer is where it opens next.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          title: _renamed ? _name : 'Job Application Letter',
          thumbnail: 'assets/thumbnails/doc_01.png',
        ),
      ),
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
            child: _EditHeader(title: _name, onRename: _rename),
          ),
          Expanded(
            child: Container(
              color: AppColors.darkSurface,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: PagePreview(
                          asset: 'assets/thumbnails/doc_01.png',
                          aspectRatio: _paper.aspectRatio,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: DarkPill(label: 'Page 1 of 1'),
                  ),
                ],
              ),
            ),
          ),
          _ToolStrip(selected: _tool, onSelected: _onTool),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _DarkButton(
                      label: 'Scan More',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

DOCFLOW_EDIT_PART_2
