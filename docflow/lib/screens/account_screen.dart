import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import 'login_screen.dart';

/// Account tab, following ProScan's settings layout: profile card, storage
/// meter, then grouped rows. ProScan's premium upsell is replaced with a
/// privacy card — DocFlow is free and processes files on device.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _darkMode = false;

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Row(
            children: [
              Text('Account', style: theme.textTheme.displayMedium),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.moreHorizontal,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _ProfileCard(),
          const SizedBox(height: 16),
          const _PrivacyCard(),
          const SizedBox(height: 24),
          _Row(
            icon: LucideIcons.user,
            label: 'Personal Info',
            onTap: () {},
          ),
          _Row(
            icon: LucideIcons.settings,
            label: 'Preferences',
            onTap: () {},
          ),
          _Row(
            icon: LucideIcons.shield,
            label: 'Security',
            onTap: () {},
          ),
          _Row(
            icon: LucideIcons.globe,
            label: 'Language',
            trailing: Text('English (US)', style: theme.textTheme.bodyMedium),
            onTap: () {},
          ),
          _Row(
            icon: LucideIcons.eye,
            label: 'Dark Mode',
            trailing: Switch(
              value: _darkMode,
              onChanged: (v) {
                setState(() => _darkMode = v);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dark theme coming soon')),
                );
              },
            ),
            showChevron: false,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _Row(
            icon: LucideIcons.helpCircle,
            label: 'Help Center',
            onTap: () {},
          ),
          _Row(
            icon: LucideIcons.info,
            label: 'About DocFlow',
            onTap: () {},
          ),
          _Row(
            icon: LucideIcons.logOut,
            label: 'Logout',
            danger: true,
            showChevron: false,
            onTap: _logout,
          ),
        ],
      ),
    );
  }
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
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user,
                size: 28, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Andrew Ainsley',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: const Text(
                        'Free',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${used.toInt()} MB / ${total.toInt()} MB',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: used / total,
                    minHeight: 6,
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.shieldCheck,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Private',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Files never leave your device. Nothing is uploaded.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.coral : AppColors.textPrimary;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 22, color: color),
      title: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailing,
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}
