import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_locales.dart';
import '../core/utils/week_off_utils.dart';
import '../models/user_model.dart';
import '../services/work_session_service.dart';
import 'work_hours_chip.dart';

/// Where the employee stands in their own working day.
enum _ShiftState { onShift, offShift, dayOff, onLeave, unavailable, noSchedule }

/// "Working hours today" dashboard card: the employee's shift for today (from
/// their schedule, evaluated in the company's timezone) plus the time actually
/// tracked so far when the company measures CRM usage.
///
/// Deliberately self-hiding: companies that set neither shifts nor tracking see
/// nothing rather than an empty "no working hours" placeholder on every dashboard.
class WorkingHoursTodayCard extends StatefulWidget {
  const WorkingHoursTodayCard({
    super.key,
    required this.user,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final UserModel? user;

  /// Owned by the card rather than a wrapping Padding so a hidden card leaves no
  /// dead space behind it.
  final EdgeInsetsGeometry margin;

  @override
  State<WorkingHoursTodayCard> createState() => _WorkingHoursTodayCardState();
}

class _WorkingHoursTodayCardState extends State<WorkingHoursTodayCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // On/off shift flips on the clock, not on a rebuild — re-evaluate each minute.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _timeZone {
    final tz = widget.user?.company?.timezone?.trim();
    return (tz == null || tz.isEmpty) ? 'UTC' : tz;
  }

  bool get _hasShift =>
      parseTimeToMinutes(widget.user?.workStartTime) != null &&
      parseTimeToMinutes(widget.user?.workEndTime) != null;

  _ShiftState get _state {
    final user = widget.user;
    if (user == null) return _ShiftState.noSchedule;

    switch (user.availabilityReason) {
      case 'time_off':
        return _ShiftState.onLeave;
      case 'unavailable':
        return _ShiftState.unavailable;
      case 'weekly_day_off':
        return _ShiftState.dayOff;
    }
    // Payloads without the server-computed reason (or a day that rolled over since
    // the last fetch) still get the weekly day off right from the raw field.
    if (isUserOnWeeklyDayOff(user.weeklyDayOff, _timeZone)) {
      return _ShiftState.dayOff;
    }
    if (!_hasShift) return _ShiftState.noSchedule;
    return isUserWithinWorkingHours(
      workStartTime: user.workStartTime,
      workEndTime: user.workEndTime,
      companyTimeZone: _timeZone,
    )
        ? _ShiftState.onShift
        : _ShiftState.offShift;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ValueListenableBuilder<WorkSessionSnapshot>(
      valueListenable: WorkSessionService.instance.snapshot,
      builder: (context, snapshot, _) {
        final tracking = snapshot.state != WorkSessionState.off;
        final state = _state;
        // Nothing scheduled and nothing measured: no card at all.
        if (state == _ShiftState.noSchedule && !tracking) {
          return const SizedBox.shrink();
        }
        final until = _untilText(state, loc);

        // Explicit surface + border rather than the ambient Card colour: this sits on
        // the drawer, whose background is nearly the same navy as the default card,
        // and the two blended into one flat block.
        return Card(
          elevation: 0,
          margin: widget.margin,
          color: _cardColor(theme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _borderColor(theme)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc?.translate('workingHoursTodayTitle') ??
                            'Working hours today',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildStateBadge(state, loc, theme),
                  ],
                ),
                const SizedBox(height: 10),
                _buildShiftRow(loc, theme),
                if (until != null) ...[
                  const SizedBox(height: 4),
                  Text(until, style: theme.textTheme.bodySmall?.copyWith(
                    color: _labelColor(theme),
                  )),
                ],
                if (tracking) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  _buildTrackedRow(snapshot, loc, theme),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isDark(ThemeData theme) => theme.brightness == Brightness.dark;

  /// One step away from the surface behind it, in both themes.
  Color _cardColor(ThemeData theme) => _isDark(theme)
      ? Color.alphaBlend(Colors.white.withValues(alpha: 0.06), theme.cardColor)
      : theme.cardColor;

  Color _borderColor(ThemeData theme) => _isDark(theme)
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.black.withValues(alpha: 0.10);

  /// Row labels: readable, still clearly secondary to the values next to them.
  /// The old white70-at-75%-alpha was the low-contrast culprit.
  Color _labelColor(ThemeData theme) {
    final base = theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    return base.withValues(alpha: _isDark(theme) ? 0.82 : 0.70);
  }

  /// Values, and the shift window when one is set: full-strength foreground.
  Color _valueColor(ThemeData theme) =>
      theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;

  Widget _buildShiftRow(AppLocalizations? loc, ThemeData theme) {
    final window = _shiftWindowText(loc);
    return Row(
      children: [
        Expanded(
          child: Text(
            loc?.translate('shiftLabel') ?? 'Shift',
            style: theme.textTheme.bodyMedium?.copyWith(color: _labelColor(theme)),
          ),
        ),
        Text(
          window,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: _hasShift ? FontWeight.w700 : FontWeight.w500,
            color: _hasShift ? _valueColor(theme) : _labelColor(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackedRow(
    WorkSessionSnapshot snapshot,
    AppLocalizations? loc,
    ThemeData theme,
  ) {
    final isPaused = snapshot.state == WorkSessionState.paused;
    return Row(
      children: [
        Expanded(
          child: Text(
            loc?.translate('workTrackedTodayLabel') ?? 'Tracked today',
            style: theme.textTheme.bodyMedium?.copyWith(color: _labelColor(theme)),
          ),
        ),
        if (isPaused) ...[
          Icon(Icons.pause_circle_outline, size: 14, color: _pausedColor(theme)),
          const SizedBox(width: 4),
          Text(
            loc?.translate('workTrackingPausedShort') ?? 'Paused',
            style: theme.textTheme.bodySmall?.copyWith(color: _pausedColor(theme)),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          WorkHoursChip.formatDuration(snapshot.todaySeconds, loc),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: _valueColor(theme),
          ),
        ),
      ],
    );
  }

  /// Amber that stays legible on both a light card and a navy one.
  Color _pausedColor(ThemeData theme) =>
      _isDark(theme) ? Colors.amber.shade300 : Colors.amber.shade800;

  Widget _buildStateBadge(
    _ShiftState state,
    AppLocalizations? loc,
    ThemeData theme,
  ) {
    final isDark = _isDark(theme);
    // Shade per theme instead of a single mid-tone: shade300 reads on navy,
    // shade700/800 reads on white. The neutral states use blue-grey rather than
    // the body text colour, which washed out to nothing at badge opacity.
    final neutral = isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700;
    late final String label;
    late final Color color;
    switch (state) {
      case _ShiftState.onShift:
        label = loc?.translate('statusOnShift') ?? 'On shift';
        color = isDark ? Colors.greenAccent.shade100 : Colors.green.shade800;
        break;
      case _ShiftState.offShift:
        label = loc?.translate('statusOffShift') ?? 'Off shift';
        color = neutral;
        break;
      case _ShiftState.dayOff:
        label = loc?.translate('statusDayOffToday') ?? 'Day off today';
        color = isDark ? Colors.lightBlue.shade200 : Colors.blue.shade800;
        break;
      case _ShiftState.onLeave:
        label = loc?.translate('statusOnLeave') ?? 'On leave';
        color = isDark ? Colors.orange.shade200 : Colors.orange.shade900;
        break;
      case _ShiftState.unavailable:
        label = loc?.translate('statusUnavailable') ?? 'Unavailable';
        color = isDark ? Colors.orange.shade200 : Colors.orange.shade900;
        break;
      case _ShiftState.noSchedule:
        label = loc?.translate('statusNoShiftSet') ?? 'No shift set';
        color = neutral;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // Tinted fill plus a matching hairline: the old 15% fill alone left the
        // pill floating with no edge on a dark surface.
        color: color.withValues(alpha: isDark ? 0.20 : 0.14),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.55 : 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  /// "9:00 AM – 5:00 PM" in the company's own clock — the schedule is stored as a
  /// local wall-clock window, so it is shown as written, never converted.
  String _shiftWindowText(AppLocalizations? loc) {
    final start = _formatClock(widget.user?.workStartTime);
    final end = _formatClock(widget.user?.workEndTime);
    if (start == null || end == null) {
      return loc?.translate('noWorkingHoursSet') ?? 'No working hours set';
    }
    return '$start – $end';
  }

  String? _formatClock(String? value) {
    final minutes = parseTimeToMinutes(value);
    if (minutes == null) return null;
    final locale = AppLocalizations.of(context)?.locale ?? AppLocales.english;
    return DateFormat(
      'h:mm a',
      AppLocales.intlDateFormat(locale),
    ).format(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));
  }

  /// "Until 3 Sep 2026" for planned leave, "Until 3 Sep 2026, 4:30 PM" for the
  /// ad-hoc away toggle. Null for every other state.
  String? _untilText(_ShiftState state, AppLocalizations? loc) {
    if (state != _ShiftState.onLeave && state != _ShiftState.unavailable) {
      return null;
    }
    final raw = widget.user?.availabilityUntil;
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    final locale = AppLocalizations.of(context)?.locale ?? AppLocales.english;
    final tag = AppLocales.intlDateFormat(locale);
    // A bare YYYY-MM-DD is a company-local date; only timestamps get converted.
    final formatted = raw.trim().length <= 10
        ? DateFormat.yMMMd(tag).format(parsed)
        : DateFormat.yMMMd(tag).add_jm().format(parsed.toLocal());
    final template = loc?.translate('untilLabel') ?? 'Until {value}';
    return template.replaceAll('{value}', formatted);
  }
}
