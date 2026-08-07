import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../data/sample_data.dart';
import '../models/conversion_tool.dart';
import '../models/document.dart';

/// Pick a file, watch it convert, then act on the result. Three states in one
/// route, using the same progress-ring motion as the ProScan capture screen.
class ConversionFlow extends StatefulWidget {
  const ConversionFlow({super.key, required this.tool});

  final ConversionTool tool;

  @override
  State<ConversionFlow> createState() => _ConversionFlowState();
}

enum _Stage { pick, working, done }

class _ConversionFlowState extends State<ConversionFlow>
    with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.pick;
  DocumentFile? _file;
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _convert(DocumentFile file) async {
    setState(() {
      _file = file;
      _stage = _Stage.working;
    });
    await _progress.forward(from: 0);
    if (mounted) setState(() => _stage = _Stage.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text(widget.tool.title),
      ),
      body: SafeArea(
        top: false,
        child: switch (_stage) {
          _Stage.pick => _PickStage(tool: widget.tool, onPick: _convert),
          _Stage.working => _WorkingStage(
              tool: widget.tool,
              file: _file!,
              progress: _progress,
            ),
          _Stage.done => _DoneStage(tool: widget.tool, file: _file!),
        },
      ),
    );
  }
}
class _PickStage extends StatelessWidget {
  const _PickStage({required this.tool, required this.onPick});

  final ConversionTool tool;
  final ValueChanged<DocumentFile> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only offer files the tool can actually read.
    final eligible = SampleData.recentFiles
        .where((f) => tool.accepts(f.format))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(tool.description, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        _DropTarget(tool: tool),
        const SizedBox(height: 28),
        Text('Or choose from your library',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          eligible.isEmpty
              ? 'No ${tool.from} files in your library yet.'
              : 'Showing ${tool.from} files',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final file in eligible)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => onPick(file),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: file.format.tint,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Icon(file.format.icon, size: 19, color: file.format.color),
            ),
            title: Text(file.fullName, style: theme.textTheme.titleSmall),
            subtitle: Text('${file.sizeLabel} • ${file.pages} pages',
                style: theme.textTheme.bodySmall),
            trailing: const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}
class _DropTarget extends StatelessWidget {
  const _DropTarget({required this.tool});

  final ConversionTool tool;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: tool.tint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.uploadCloud, size: 34, color: tool.color),
          const SizedBox(height: 12),
          Text(
            'Import a ${tool.from} file',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'From your device or cloud storage',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
class _WorkingStage extends StatelessWidget {
  const _WorkingStage({
    required this.tool,
    required this.file,
    required this.progress,
  });

  final ConversionTool tool;
  final DocumentFile file;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: progress,
              builder: (context, _) => SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress.value,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: tool.tint,
                        valueColor: AlwaysStoppedAnimation(tool.color),
                      ),
                    ),
                    Text(
                      '${(progress.value * 100).round()}%',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Converting…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '${file.fullName} → ${tool.to}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.shieldCheck,
                    size: 14, color: AppColors.green),
                const SizedBox(width: 6),
                Text('Processing on device',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class _DoneStage extends StatelessWidget {
  const _DoneStage({required this.tool, required this.file});

  final ConversionTool tool;
  final DocumentFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outName = '${file.name}.${tool.to.toLowerCase()}';

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.greenTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.check,
                      size: 44, color: AppColors.green),
                ),
                const SizedBox(height: 24),
                Text('Conversion complete',
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  outName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text('Saved to your library',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.share2, size: 18),
                label: const Text('Share file'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
