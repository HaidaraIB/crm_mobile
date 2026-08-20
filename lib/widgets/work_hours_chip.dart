import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../services/work_session_service.dart';

/// The employee's own measured CRM usage for today.
///
/// Reads the tracker's notifier rather than fetching: every ping already refreshes
/// the total there, so this stays current at no extra request cost. Renders nothing
/// when tracking is off for this user or company.
class WorkHoursChip extends StatelessWidget {
  const WorkHoursChip({super.key});

  static String formatDuration(int seconds, AppLocalizations? loc) {
    final totalMinutes = (seconds / 60).round().clamp(0, 1 << 30);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final h = loc?.translate('hoursShort') ?? 'h';
    final m = loc?.translate('minutesShort') ?? 'm';

    if (hours == 0 && minutes == 0) return '0$h';
    if (hours == 0) return '$minutes$m';
    if (minutes == 0) return '$hours$h';
    return '$hours$h $minutes$m';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ValueListenableBuilder<WorkSessionSnapshot>(
      valueListenable: WorkSessionService.instance.snapshot,
      builder: (context, snapshot, _) {
        if (snapshot.state == WorkSessionState.off) {
          return const SizedBox.shrink();
        }
        final isPaused = snapshot.state == WorkSessionState.paused;
        final color = isPaused ? Colors.amber.shade700 : theme.colorScheme.onSurfaceVariant;

        return Tooltip(
          message: loc?.translate('workTrackingTodayLabel') ?? 'Working hours today',
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPaused ? Icons.pause_circle_outline : Icons.schedule,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  formatDuration(snapshot.todaySeconds, loc),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
