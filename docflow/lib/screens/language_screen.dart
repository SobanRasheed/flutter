import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../widgets/settings_row.dart';

/// Interface language. Suggested sits above the full list; the active choice
/// carries a primary check and is returned to the caller.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, required this.selected});

  final String selected;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selected = widget.selected;

  static const _suggested = ['English (US)', 'English (UK)'];
  static const _languages = [
    'Mandarin',
    'Spanish',
    'French',
    'Arabic',
    'Bengali',
    'Russian',
    'Japanese',
    'Korean',
    'Indonesia',
    'Portuguese',
    'German',
    'Urdu',
  ];

  void _choose(String language) {
    setState(() => _selected = language);
    Navigator.of(context).pop(language);
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
        title: Text('Language', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            Text('Suggested', style: theme.textTheme.titleMedium),
            for (final language in _suggested)
              _LanguageRow(
                label: language,
                selected: language == _selected,
                onTap: () => _choose(language),
              ),
            const SettingsDivider(),
            Text('Language', style: theme.textTheme.titleMedium),
            for (final language in _languages)
              _LanguageRow(
                label: language,
                selected: language == _selected,
                onTap: () => _choose(language),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      label: label,
      showChevron: false,
      onTap: onTap,
      trailing: selected
          ? const Icon(LucideIcons.check, size: 24, color: AppColors.primary)
          : null,
    );
  }
}
