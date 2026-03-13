import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Shared styling for settings list cards (Channels, Stages, Statuses, Call Methods).
class SettingsListCard extends StatelessWidget {
  const SettingsListCard({
    super.key,
    required this.child,
  });

  final Widget child;

  static const double cardRadius = 12;
  static const double listBottomMargin = 12;
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: listBottomMargin),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Consistent "Default" badge for settings entities.
class SettingsDefaultChip extends StatelessWidget {
  const SettingsDefaultChip({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

/// Small chip for priority/category/required badges with custom color.
class SettingsLabelChip extends StatelessWidget {
  const SettingsLabelChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
    );
  }
}
