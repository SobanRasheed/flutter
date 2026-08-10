import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';

import '../core/tokens.dart';
import '../models/conversion_tool.dart';
import '../services/conversion_service.dart';
import '../services/file_store.dart';
import '../widgets/paywall_sheet.dart';

/// Pick a file, watch it convert, then act on the result.
///
/// The progress ring is indeterminate on purpose: the work happens on the
/// server and there is no byte-level progress to report, so a fake percentage
/// would be a lie that stalls at 99%.
class ConversionFlow extends StatefulWidget {
  const ConversionFlow({super.key, required this.tool});

  final ConversionTool tool;

  @override
  State<ConversionFlow> createState() => _ConversionFlowState();
}

enum _Stage { pick, working, done, failed }

class _ConversionFlowState extends State<ConversionFlow> {
  final _service = ConversionService();

  _Stage _stage = _Stage.pick;
  List<File> _inputs = const [];
  StoredFile? _output;
  String _error = '';
  bool _canRetry = false;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _pickAndConvert() async {
    final tool = widget.tool;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: tool.isMultiFile,
      type: tool.inputExtensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions:
          tool.inputExtensions.isEmpty ? null : tool.inputExtensions,
      withData: false, // Paths only; the file is streamed, not held in memory.
    );
    if (picked == null || picked.files.isEmpty) return;

    final files = picked.files
        .map((f) => f.path)
        .whereType<String>()
        .map(File.new)
        .toList();
    if (files.isEmpty) return;

    if (tool.isMultiFile && tool.id == 'merge-pdf' && files.length < 2) {
      _fail('Merge needs at least two PDFs', retry: false);
      return;
    }

    setState(() {
      _inputs = files;
      _stage = _Stage.working;
    });
    await _convert();
  }

  Future<void> _convert() async {
    final outcome = await _service.run(
      toolId: widget.tool.backendId(),
      files: _inputs,
    );
    if (!mounted) return;

    switch (outcome) {
      case ConversionSuccess(:final file):
        setState(() {
          _output = file;
          _stage = _Stage.done;
        });

      case ConversionQuotaBlocked(:final quota, :final message):
        // 402 is not an error state — back to the picker, then the paywall.
        setState(() => _stage = _Stage.pick);
        await showPaywall(context, quota: quota, message: message);

      case ConversionFailure(:final message, :final isRetryable):
        _fail(message, retry: isRetryable);
    }
  }

  void _fail(String message, {required bool retry}) {
    setState(() {
      _error = message;
      _canRetry = retry;
      _stage = _Stage.failed;
    });
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
          _Stage.pick => _PickStage(tool: widget.tool, onPick: _pickAndConvert),
          _Stage.working =>
            _WorkingStage(tool: widget.tool, inputs: _inputs),
          _Stage.done => _DoneStage(
              tool: widget.tool,
              file: _output!,
              onDone: () => Navigator.of(context).pop(true),
            ),
          _Stage.failed => _FailedStage(
              message: _error,
              onRetry: _canRetry
                  ? () {
                      setState(() => _stage = _Stage.working);
                      _convert();
                    }
                  : null,
              onBack: () => setState(() => _stage = _Stage.pick),
            ),
        },
      ),
    );
  }
}

class _PickStage extends StatelessWidget {
  const _PickStage({required this.tool, required this.onPick});

  final ConversionTool tool;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(tool.description, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onPick,
          child: Container(
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
                  tool.isMultiFile
                      ? 'Choose ${tool.from} files'
                      : 'Choose a ${tool.from} file',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'From your device or cloud storage',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: onPick,
          icon: const Icon(LucideIcons.filePlus, size: 18),
          label: Text(tool.isMultiFile ? 'Select files' : 'Select file'),
        ),
      ],
    );
  }
}

class _WorkingStage extends StatelessWidget {
  const _WorkingStage({required this.tool, required this.inputs});

  final ConversionTool tool;
  final List<File> inputs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = inputs.length == 1
        ? inputs.first.path.split(RegExp(r'[/\\]')).last
        : '${inputs.length} files';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: CircularProgressIndicator(
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                backgroundColor: tool.tint,
                valueColor: AlwaysStoppedAnimation(tool.color),
              ),
            ),
            const SizedBox(height: 28),
            Text('Converting…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '$label → ${tool.to}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            // The honest claim. Files are uploaded, held in memory for the
            // conversion, and never written to storage on the server — saying
            // "on device" here would be false.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.shieldCheck,
                    size: 14, color: AppColors.green),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Processed in memory, never stored on our servers',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneStage extends StatelessWidget {
  const _DoneStage({
    required this.tool,
    required this.file,
    required this.onDone,
  });

  final ConversionTool tool;
  final StoredFile file;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  file.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text('${file.sizeLabel} • saved to your files',
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
                onPressed: onDone,
                child: const Text('Done'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => OpenFilex.open(file.path),
                icon: const Icon(LucideIcons.externalLink, size: 18),
                label: const Text('Open file'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FailedStage extends StatelessWidget {
  const _FailedStage({
    required this.message,
    required this.onBack,
    this.onRetry,
  });

  final String message;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    color: AppColors.coralTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.alertCircle,
                      size: 44, color: AppColors.coral),
                ),
                const SizedBox(height: 24),
                Text("That didn't work",
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              if (onRetry != null) ...[
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: onBack,
                child: const Text('Choose another file'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
