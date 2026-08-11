import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/utils/week_off_utils.dart';
import '../models/user_model.dart';
import 'app_switch.dart';

/// Urgent / مستعجل switch for lead create/edit with soft on-shift warning.
class LeadUrgentSwitch extends StatelessWidget {
  const LeadUrgentSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.candidateUsers,
    required this.companyTimeZone,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final List<UserModel> candidateUsers;
  final String companyTimeZone;

  bool get _someoneOnShift {
    final tz = companyTimeZone.trim().isEmpty ? 'UTC' : companyTimeZone;
    return candidateUsers.any(
      (u) => isUserOnShiftForUrgent(
        weeklyDayOff: u.weeklyDayOff,
        workStartTime: u.workStartTime,
        workEndTime: u.workEndTime,
        companyTimeZone: tz,
        isActive: u.isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showHint = value && !_someoneOnShift;
    final label = localizations?.translate('urgent') ?? 'Urgent';
    final help = localizations?.translate('urgentHelp') ??
        'When on, this lead is auto-assigned to someone currently within working hours.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + switch stay adjacent; help sits under like a field hint.
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                AppSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          help,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        if (showHint) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              localizations?.translate('urgentNoOneOnShift') ??
                  'No employee is currently within working hours. Assignment will fall back to normal rules.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact urgent chip for list/detail.
class LeadUrgentBadge extends StatelessWidget {
  const LeadUrgentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
      ),
      child: Text(
        localizations?.translate('urgent') ?? 'Urgent',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
        ),
      ),
    );
  }
}
