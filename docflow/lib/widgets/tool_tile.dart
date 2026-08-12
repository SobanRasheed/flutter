import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../models/conversion_tool.dart';

/// A single cell of the home tool grid: a 60pt pastel circle holding the tool
/// glyph, with the label beneath — ProScan's tool-grid treatment.
class ToolTile extends StatelessWidget {
  const ToolTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
    this.onTap,
  });

  /// Cell for one of DocFlow's conversion tools.
  ToolTile.tool({Key? key, required ConversionTool tool, VoidCallback? onTap})
      : this(
          key: key,
          icon: tool.icon,
          label: tool.title,
          color: tool.color,
          tint: tool.tint,
          onTap: onTap,
        );

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 12),
          // Flexible so a taller fallback font drops the label to one line
          // instead of overflowing the fixed grid cell.
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLabel,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 4-across grid on Home: seven conversion tools, then an All Tools cell
/// that opens the full list — the eighth slot in the kit's layout.
class ToolGrid extends StatelessWidget {
  const ToolGrid({super.key, required this.onToolTap, required this.onAllTools});

  final ValueChanged<ConversionTool> onToolTap;
  final VoidCallback onAllTools;

  @override
  Widget build(BuildContext context) {
    final featured = ConversionTool.all.take(7);

    return GridView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        childAspectRatio: 0.86,
      ),
      children: [
        for (final tool in featured)
          ToolTile.tool(tool: tool, onTap: () => onToolTap(tool)),
        ToolTile(
          icon: LucideIcons.layoutGrid,
          label: 'All Tools',
          color: AppColors.primary,
          tint: AppColors.violetTint,
          onTap: onAllTools,
        ),
      ],
    );
  }
}
