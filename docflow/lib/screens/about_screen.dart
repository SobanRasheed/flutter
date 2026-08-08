import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../widgets/docflow_logo.dart';
import '../widgets/settings_row.dart';

/// About: the mark over a version string, then the company and legal links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = 'v1.0.0';

  static const _rows = [
    'Job Vacancy',
    'Developer',
    'Partner',
    'Accessibility',
    'Privacy Policy',
    'Feedback',
    'Rate us',
    'Visit Our Website',
    'Follow us on Social Media',
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
        title: Text('About DocFlow', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            const Center(child: DocFlowLogo(size: 128)),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'DocFlow $_version',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
              ),
            ),
            const SettingsDivider(),
            for (final row in _rows)
              SettingsRow(
                label: row,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening $row')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
