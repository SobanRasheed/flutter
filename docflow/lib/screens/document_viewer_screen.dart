import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/document.dart';
import '../widgets/scanner_chrome.dart';
import '../widgets/share_sheet.dart';
import 'file_action_menu.dart';

/// A saved document, full bleed on the dark ground. Rename from the pencil,
/// everything else from the overflow menu.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.title,
    this.thumbnail = '',
    this.pdfPath,
    this.pages = 1,
    this.file,
  });

  /// Convenience for opening straight from a library row. Files with no page
  /// render fall back to a blank sheet.
  DocumentViewerScreen.file({Key? key, required DocumentFile file})
      : this(
          key: key,
          title: file.name,
          thumbnail: file.thumbnail ?? '',
          pages: file.pages,
          file: file,
        );

  final String title;
  final String thumbnail;

  /// When set, the viewer shows the actual saved file bytes instead of a
  /// bundled thumbnail asset. Used after a scan-to-PDF conversion.
  final String? pdfPath;
  final int pages;

  /// The library entry this view came from, when there is one. Fresh scans
  /// have no record yet, so their overflow menu falls back to sharing.
  final DocumentFile? file;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late String _title = widget.title;
  int _page = 1;

  Future<void> _openMenu() {
    final file = widget.file;
    if (file == null) return showShareSheet(context, title: _title);
    return showFileActionMenu(context, file: file);
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _title);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _title = name);
  }

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
                    child: Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                    ),
                  ),
                  IconButton(
                    onPressed: _rename,
                    tooltip: 'Rename',
                    icon: const Icon(LucideIcons.edit2,
                        color: Colors.white, size: 24),
                  ),
                  IconButton(
                    onPressed: _openMenu,
                    icon: const Icon(LucideIcons.moreHorizontal,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 8),
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
                    child: PageView.builder(
                      itemCount: widget.pages,
                      onPageChanged: (i) => setState(() => _page = i + 1),
                      itemBuilder: (context, index) => Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                          child: widget.pdfPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  child: Image.file(
                                    File(widget.pdfPath!),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        LucideIcons.fileText,
                                        color: Colors.white54,
                                        size: 64,
                                      ),
                                    ),
                                  ),
                                )
                              : PagePreview(asset: widget.thumbnail),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child:
                          DarkPill(label: 'Page $_page of ${widget.pages}'),
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
