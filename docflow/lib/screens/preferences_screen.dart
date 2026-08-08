import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../widgets/settings_row.dart';

/// App defaults, grouped. The kit's groups are Scan / File Naming / Files &
/// Storage / Payments & Subscriptions / Cloud & Sync. DocFlow is free and works
/// on device, so the payments group becomes Conversion — the app's main job —
/// and Cloud & Sync becomes Notifications.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _keepOriginal = true;
  bool _highQuality = true;
  bool _autoCrop = true;
  bool _saveToGallery = true;
  bool _notifyOnComplete = true;
  bool _weeklySummary = false;

  String _outputFormat = 'PDF';
  String _enhanceMode = 'Auto';
  String _namePattern = 'Scan - date - time';

  Future<void> _pick(
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onPicked,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child:
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
              const Divider(height: 1),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SettingsRow(
                    label: option,
                    showChevron: false,
                    trailing: option == current
                        ? const Icon(LucideIcons.check,
                            size: 22, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onPicked(picked);
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
        title: Text('Preferences', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            const SettingsSectionHeader('Conversion'),
            SettingsRow(
              label: 'Default Output Format',
              value: _outputFormat,
              onTap: () => _pick(
                'Default Output Format',
                const ['PDF', 'DOCX', 'XLSX', 'JPG', 'PNG'],
                _outputFormat,
                (v) => setState(() => _outputFormat = v),
              ),
            ),
            _Toggle(
              label: 'Keep Original After Converting',
              value: _keepOriginal,
              onChanged: (v) => setState(() => _keepOriginal = v),
            ),
            const SettingsDivider(),
            const SettingsSectionHeader('Scan'),
            _Toggle(
              label: 'High Quality Scan',
              value: _highQuality,
              onChanged: (v) => setState(() => _highQuality = v),
            ),
            _Toggle(
              label: 'Auto Crop Image',
              value: _autoCrop,
              onChanged: (v) => setState(() => _autoCrop = v),
            ),
            SettingsRow(
              label: 'Enhance Mode',
              value: _enhanceMode,
              onTap: () => _pick(
                'Enhance Mode',
                const ['Auto', 'Original', 'Black & White', 'Greyscale'],
                _enhanceMode,
                (v) => setState(() => _enhanceMode = v),
              ),
            ),
            const SettingsDivider(),
            const SettingsSectionHeader('File Naming'),
            SettingsRow(
              label: 'Default File Name',
              onTap: () => _pick(
                'Default File Name',
                const [
                  'Scan - date - time',
                  'Document - number',
                  'Ask every time',
                ],
                _namePattern,
                (v) => setState(() => _namePattern = v),
              ),
            ),
            const SettingsDivider(),
            const SettingsSectionHeader('Files & Storage'),
            _Toggle(
              label: 'Save Original Image to Gallery',
              value: _saveToGallery,
              onChanged: (v) => setState(() => _saveToGallery = v),
            ),
            SettingsRow(
              label: 'Free Up Storage',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('465 MB in use')),
              ),
            ),
            const SettingsDivider(),
            const SettingsSectionHeader('Notifications'),
            _Toggle(
              label: 'Conversion Complete',
              value: _notifyOnComplete,
              onChanged: (v) => setState(() => _notifyOnComplete = v),
            ),
            _Toggle(
              label: 'Weekly Summary',
              value: _weeklySummary,
              onChanged: (v) => setState(() => _weeklySummary = v),
            ),
          ],
        ),
      ),
    );
  }
}

/// A settings row whose control is a switch, so no chevron.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      label: label,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
