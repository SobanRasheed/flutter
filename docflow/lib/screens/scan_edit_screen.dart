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

class _EditHeader extends StatelessWidget {
  const _EditHeader({required this.title, required this.onRename});

  final String title;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft,
                color: Colors.white, size: 26),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onRename,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
              ),
            ),
          ),
          IconButton(
            onPressed: onRename,
            icon: const Icon(LucideIcons.moreHorizontal,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// The retouch actions. Scrolls horizontally; the active tool fills primary.
class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.selected, required this.onSelected});

  final ScanTool selected;
  final ValueChanged<ScanTool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkBackground,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (final tool in ScanTool.values)
              _ToolButton(
                tool: tool,
                selected: tool == selected,
                onTap: () => onSelected(tool),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final ScanTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.field),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(tool.icon, color: Colors.white, size: 26),
                const SizedBox(height: 8),
                Text(
                  tool.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral counterpart to the primary pill, for the secondary action.
class _DarkButton extends StatelessWidget {
  const _DarkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkElevated,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }
}

/// Rename a scan. The title becomes an inline field in the header and the page
/// dims behind it while the keyboard is up.
class ScanRenameScreen extends StatefulWidget {
  const ScanRenameScreen({super.key, required this.name});

  final String name;

  @override
  State<ScanRenameScreen> createState() => _ScanRenameScreenState();
}

class _ScanRenameScreenState extends State<ScanRenameScreen> {
  late final _controller = TextEditingController(text: widget.name);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 76,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.arrowLeft,
                        color: Colors.white, size: 26),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      cursorColor: AppColors.primary,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                    ),
                  ),
                  TextButton(
                    onPressed: _save,
                    child: const Text('Save',
                        style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          // The page stays visible but recedes while the title is edited.
          Expanded(
            child: ColoredBox(
              color: AppColors.darkSurface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Opacity(
                    opacity: 0.4,
                    child: PagePreview(
                      asset: 'assets/thumbnails/doc_01.png',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choose the output paper size. The preview reflows to the selection so the
/// change is visible before it is committed.
class ResizeScreen extends StatefulWidget {
  const ResizeScreen({super.key, required this.selected});

  final PaperSize selected;

  @override
  State<ResizeScreen> createState() => _ResizeScreenState();
}

class _ResizeScreenState extends State<ResizeScreen> {
  late PaperSize _paper = widget.selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 76,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(LucideIcons.x, color: Colors.white, size: 26),
                  ),
                  Text(
                    'Resize',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.darkSurface,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
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
          Container(
            color: AppColors.darkBackground,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final paper in PaperSize.values)
                    _PaperButton(
                      paper: paper,
                      selected: paper == _paper,
                      onTap: () => setState(() => _paper = paper),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _DarkButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_paper),
                      child: const Text('OK'),
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

class _PaperButton extends StatelessWidget {
  const _PaperButton({
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final PaperSize paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.field),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(
                  paper == PaperSize.autoFit
                      ? LucideIcons.alignJustify
                      : LucideIcons.fileText,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  paper.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  paper.orientation,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
