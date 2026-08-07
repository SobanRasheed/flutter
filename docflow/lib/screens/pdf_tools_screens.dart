import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../data/sample_data.dart';
import '../models/conversion_tool.dart';
import '../models/document.dart';

/// The three "Organise / Optimise" tools from the marketing site — Merge,
/// Protect and Compress — each a small workflow of its own on the light ground.
/// They share the tool-header treatment from the converter.

/// Merge PDF: a growing list of files, each removable, with a fixed footer.
class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<DocumentFile> _files = [
    SampleData.recentFiles[0],
    SampleData.recentFiles[2],
    SampleData.recentFiles[4],
  ];

  int get _totalPages =>
      _files.fold(0, (sum, f) => sum + f.pages);

  void _remove(DocumentFile file) {
    setState(() => _files.remove(file));
  }

  void _addMore() {
    final candidates = SampleData.recentFiles
        .where((f) => f.format == DocFormat.pdf && !_files.contains(f))
        .toList();
    if (candidates.isEmpty) return;
    setState(() => _files.add(candidates.first));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text('Merge PDF', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Text(
                    'Combine multiple PDFs into a single document.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  for (final (index, file) in _files.indexed) ...[
                    _MergeRow(
                      file: file,
                      index: index,
                      onRemove: () => _remove(file),
                    ),
                    if (index < _files.length - 1)
                      Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.plus,
                              color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  if (_files.length < 3)
                    OutlinedButton.icon(
                      onPressed: _addMore,
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add more files'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${_files.length} files  •  $_totalPages pages',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _files.length < 2
                        ? null
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Merged ${_files.length} PDFs')),
                            ),
                    child: const Text('Merge Files'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MergeRow extends StatelessWidget {
  const _MergeRow({
    required this.file,
    required this.index,
    required this.onRemove,
  });

  final DocumentFile file;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(LucideIcons.fileText, size: 22, color: AppColors.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    style: theme.textTheme.titleSmall, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${file.sizeLabel} • ${file.pages} pages',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(LucideIcons.x,
                size: 20, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Protect PDF: set a password (twice) before locking the file.
class ProtectPdfScreen extends StatefulWidget {
  const ProtectPdfScreen({super.key});

  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready =>
      _password.text.isNotEmpty && _password.text == _confirm.text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mismatch = _confirm.text.isNotEmpty &&
        _confirm.text != _password.text;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text('Protect PDF', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Text(
                    'Set a password to open this PDF.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('Password', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Enter a password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Confirm Password', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirm,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Repeat the password',
                      errorText: mismatch ? 'Passwords do not match' : null,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: ElevatedButton(
                onPressed: _ready
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PDF is protected')),
                        )
                    : null,
                child: const Text('Protect File'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compress PDF: three quality tiers as radio cards.
class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  /// Medium leads in the kit, so it is the default.
  int _level = 1;

  static const _levels = [
    ('High Compression', 'Smallest size, lower quality'),
    ('Medium Compression', 'Medium size, medium quality'),
    ('Low Compression', 'Largest size, better quality'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                children: [
                  Text('Compress PDF', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 16),
                  Text(
                    'Reduce the size of your PDF file.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  FileCard(file: widget.file),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text('Select compression level:',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 20),
                  for (final (index, (title, subtitle)) in _levels.indexed)
                    _CompressTile(
                      title: title,
                      subtitle: subtitle,
                      selected: index == _level,
                      onTap: () => setState(() => _level = index),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Compressing at ${_levels[_level].$1}'),
                  ),
                ),
                child: const Text('Compress'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One compression level. The kit draws a hollow blue ring, filled with a solid
/// dot when picked — a Radio with the label and hint stacked beside it.
class _CompressTile extends StatelessWidget {
  const _CompressTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
