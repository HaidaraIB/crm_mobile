import 'package:flutter/material.dart';
import '../models/settings_model.dart';

Color parseTagHexColor(String hexColor) {
  try {
    return Color(int.parse(hexColor.replaceAll('#', ''), radix: 16) + 0xFF000000);
  } catch (e) {
    return Colors.grey;
  }
}

/// Read-only tag chips for a lead. Uses the same translucent-accent treatment
/// as [LeadStatusBadge] so tags and status read as one system.
class LeadTagChips extends StatelessWidget {
  const LeadTagChips({
    super.key,
    required this.tags,
    this.max,
    this.dense = false,
  });

  final List<TagModel> tags;

  /// Collapse the overflow into a "+N" chip; null renders every tag.
  final int? max;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visible = max != null && tags.length > max! ? tags.take(max!).toList() : tags;
    final hiddenCount = tags.length - visible.length;

    Widget chip({required String label, required Color accent, bool showDot = true}) {
      final fill = Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.16 : 0.12),
        theme.cardColor,
      );
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.42 : 0.38),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: dense ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in visible)
          chip(label: tag.name, accent: parseTagHexColor(tag.color)),
        if (hiddenCount > 0)
          Tooltip(
            message: tags.skip(visible.length).map((t) => t.name).join(', '),
            child: chip(
              label: '+$hiddenCount',
              accent: theme.colorScheme.outline,
              showDot: false,
            ),
          ),
      ],
    );
  }
}
