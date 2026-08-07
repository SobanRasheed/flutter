import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/conversion_tool.dart';
import 'conversion_flow.dart';

/// The Convert tab: every DocFlow tool in one list, grouped the way the
/// marketing site groups them. Styled as ProScan's "Export to..." screen —
/// sectioned rows over a pinned pill CTA.
class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key, this.initialTool});

  /// When launched from the home grid, that tool starts selected.
  final ConversionTool? initialTool;

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  late ConversionTool? _selected = widget.initialTool;

  static const _groups = <String, List<String>>{
    'Convert': ['pdf-to-word', 'word-to-pdf', 'pdf-to-excel', 'excel-to-pdf'],
    'Organise': ['merge-pdf', 'split-pdf'],
    'Optimise': ['compress-pdf', 'image-pdf'],
  };

  void _start() {
    final tool = _selected;
    if (tool == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConversionFlow(tool: tool)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.arrowLeft),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Convert to...', style: theme.textTheme.displayLarge),
                  const SizedBox(height: 10),
                  Text(
                    'Pick a tool. Everything runs on your device — '
                    'your files are never uploaded.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  for (final entry in _groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                        entry.key,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    for (final id in entry.value)
                      _ToolRow(
                        tool: ConversionTool.byId(id),
                        selected: _selected?.id == id,
                        onTap: () => setState(
                          () => _selected = ConversionTool.byId(id),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            _CtaBar(
              enabled: _selected != null,
              label: _selected == null
                  ? 'Select a tool'
                  : 'Continue with ${_selected!.title}',
              onPressed: _start,
            ),
          ],
        ),
      ),
    );
  }
}

/// One tool row: name and format pair, with a check when selected — the
/// interaction ProScan used for export targets.
class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final ConversionTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: tool.tint, shape: BoxShape.circle),
              child: Icon(tool.icon, size: 20, color: tool.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(tool.description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (selected)
              const Icon(LucideIcons.check, color: AppColors.primary, size: 22)
            else
              _FormatPair(tool: tool),
          ],
        ),
      ),
    );
  }
}

class _FormatPair extends StatelessWidget {
  const _FormatPair({required this.tool});

  final ConversionTool tool;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip(label: tool.from),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            tool.twoWay ? LucideIcons.arrowLeftRight : LucideIcons.arrowRight,
            size: 12,
            color: AppColors.textSecondary,
          ),
        ),
        _Chip(label: tool.to),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Pinned pill CTA with the hairline above it, as on every ProScan screen.
class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
