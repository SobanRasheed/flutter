import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';

/// One settings line: icon, label, optional trailing value, chevron. Rows sit
/// on a 53pt pitch across every settings screen in the kit.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.showChevron = true,
  });

  /// Leading glyph. The nested settings screens drop it and lead with the label.
  final IconData? icon;
  final String label;

  /// Right-aligned value, as on Language's "English (US)".
  final String? value;

  /// Replaces the chevron — a Switch, typically.
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.coral : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 53,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            if (trailing != null)
              trailing!
            else if (showChevron) ...[
              const SizedBox(width: 12),
              const Icon(LucideIcons.chevronRight,
                  size: 22, color: AppColors.textPrimary),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grey group label above a run of rows ("Scan", "File Naming").
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textMeta,
        ),
      ),
    );
  }
}

/// Hairline between groups, with the kit's breathing room either side.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1),
    );
  }
}

/// Underlined two-tab control used by the Help Center. The inactive half keeps
/// a light rule so the bar reads as one track.
class SettingsTabs extends StatelessWidget {
  const SettingsTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, label) in labels.indexed)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: i == index
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          i == index ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Outlined pill filter, filled when active — the FAQ category chips.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.primary,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
