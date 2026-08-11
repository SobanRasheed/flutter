import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../widgets/docflow_logo.dart';
import '../widgets/settings_row.dart';
import 'about_screen.dart';
import 'help_center_screen.dart';
import 'language_screen.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'personal_info_screen.dart';
import 'preferences_screen.dart';
import 'security_screen.dart';

/// Account tab: wordmark header, profile card with a storage meter, then the
/// settings rows. The kit puts a premium upsell under the profile; that slot
/// carries the privacy card until the Pro subscription flow lands.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _darkMode = false;
  String _language = 'English (US)';

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openLanguage() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => LanguageScreen(selected: _language)),
    );
    if (picked != null) setState(() => _language = picked);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showLogoutSheet(context);
    if (!confirmed || !mounted) return;
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        children: [
          Row(
            children: [
              const DocFlowLogo(size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Account',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.displayMedium,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.moreHorizontal,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _ProfileCard(),
          const SizedBox(height: 20),
          const _PrivacyCard(),
          const SizedBox(height: 20),
          SettingsRow(
            icon: LucideIcons.user,
            label: 'Personal Info',
            onTap: () => _open(const PersonalInfoScreen()),
          ),
          SettingsRow(
            icon: LucideIcons.settings,
            label: 'Preferences',
            onTap: () => _open(const PreferencesScreen()),
          ),
          SettingsRow(
            icon: LucideIcons.shieldCheck,
            label: 'Security',
            onTap: () => _open(const SecurityScreen()),
          ),
          SettingsRow(
            icon: LucideIcons.languages,
            label: 'Language',
            value: _language,
            onTap: _openLanguage,
          ),
          SettingsRow(
            icon: LucideIcons.eye,
            label: 'Dark Mode',
            showChevron: false,
            trailing: Switch(
              value: _darkMode,
              onChanged: (v) {
                setState(() => _darkMode = v);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dark theme coming soon')),
                );
              },
            ),
          ),
          const SettingsDivider(),
          SettingsRow(
            icon: LucideIcons.fileText,
            label: 'Help Center',
            onTap: () => _open(const HelpCenterScreen()),
          ),
          SettingsRow(
            icon: LucideIcons.info,
            label: 'About DocFlow',
            onTap: () => _open(const AboutScreen()),
          ),
          SettingsRow(
            icon: LucideIcons.logOut,
            label: 'Logout',
            danger: true,
            showChevron: false,
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }
}

/// Confirms sign-out. Coral title, then Cancel beside a primary confirm.
Future<bool> showLogoutSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Logout',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppColors.coral, fontSize: 24),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 28),
          Text(
            'Are you sure you want to log out?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryTint,
                        foregroundColor: AppColors.primary,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes, Logout'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ).then((value) => value ?? false);
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const used = 465.0;
    const total = 1024.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user,
                size: 34, color: AppColors.primary),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Andrew Ainsley',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: const Text(
                        'Free',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${used.toInt()} MB  /  ${total.toInt()} MB',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 15, color: AppColors.textMeta),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: used / total,
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.shieldCheck,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private by design',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Files are processed in memory and never stored on our servers.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
