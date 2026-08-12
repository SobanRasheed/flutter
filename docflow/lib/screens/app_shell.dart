import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/conversion_tool.dart';
import 'account_screen.dart';
import 'convert_screen.dart';
import 'files_screen.dart';
import 'home_dashboard.dart';
import 'scanner_screen.dart';

/// Bottom-nav shell. ProScan's four tabs were Home / Files / Premium /
/// Account; DocFlow is free with no premium tier, so that slot becomes
/// Convert — the app's primary job.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  static const _tabs = [
    (icon: LucideIcons.home, label: 'Home'),
    (icon: LucideIcons.folder, label: 'Recent Files'),
    (icon: LucideIcons.combine, label: 'Convert'),
    (icon: LucideIcons.user, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeDashboard(onSeeAllFiles: () => setState(() => _index = 1)),
          const FilesScreen(),
          const ConvertScreen(),
          const AccountScreen(),
        ],
      ),
      // Design shows a paired action cluster above the nav bar. Convert leads
      // because that is DocFlow's primary job; the camera is secondary.
      floatingActionButton: _index == 3 ? null : const _ActionCluster(),
      bottomNavigationBar: _BottomNav(
        index: _index,
        tabs: _tabs,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _ActionCluster extends StatelessWidget {
  const _ActionCluster();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleAction(
          icon: LucideIcons.camera,
          tooltip: 'Scan a document',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScannerScreen()),
          ),
        ),
        const SizedBox(width: 10),
        _CircleAction(
          icon: LucideIcons.image,
          tooltip: 'Import from gallery',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ConvertScreen(
                initialTool: ConversionTool.byId('image-pdf'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.tabs,
    required this.onChanged,
  });

  final int index;
  final List<({IconData icon, String label})> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: tabs[i].icon,
                    label: tabs[i].label,
                    selected: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selected tab fills solid in the design; unselected is a line icon.
          AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
