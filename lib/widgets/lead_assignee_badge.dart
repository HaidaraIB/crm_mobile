import 'package:flutter/material.dart';
import '../core/utils/week_off_utils.dart';
import '../models/user_model.dart';

/// Compact assignee pill — same shell / alignment as [LeadStatusBadge].
class LeadAssigneeBadge extends StatelessWidget {
  const LeadAssigneeBadge({
    super.key,
    required this.accentColor,
    required this.label,
    this.users,
    this.selectedUserId,
    this.onAssigneeSelected,
    this.isLoading = false,
    this.unassignLabel = 'Unassign',
    this.weeklyDayOffLabel = 'Day off',
    this.companyTimeZone = 'UTC',
  });

  static const int unassignedValue = -1;

  final Color accentColor;
  final String label;

  /// When null (or no callback), shows read-only pill (no chevron / menu).
  final List<UserModel>? users;
  final int? selectedUserId;
  final ValueChanged<int?>? onAssigneeSelected;
  final bool isLoading;
  final String unassignLabel;
  final String weeklyDayOffLabel;
  final String companyTimeZone;

  bool get _interactive =>
      users != null && onAssigneeSelected != null;

  bool get _isAssigned =>
      selectedUserId != null && selectedUserId! > 0;

  int get _selectedValue {
    final id = selectedUserId;
    if (id == null || id <= 0) return unassignedValue;
    return id;
  }

  /// Primary purple washes out on dark cards; lift it so border/dot read like status.
  Color _resolvedAccent(bool isDark) {
    if (!isDark) return accentColor;
    return Color.lerp(accentColor, const Color(0xFFB794F6), 0.55)!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _resolvedAccent(isDark);

    final surface = theme.cardColor;
    final fill = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.22 : 0.12),
      surface,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.72 : 0.48),
            width: 1.25,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading
            ? SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ),
              )
            : _interactive
                ? _buildDropdown(context, theme, accent)
                : _buildReadOnly(context, theme, accent),
      ),
    );
  }

  Widget _buildReadOnly(
    BuildContext context,
    ThemeData theme,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _leadingBadge(accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context,
    ThemeData theme,
    Color accent,
  ) {
    final menuUsers = List<UserModel>.from(users ?? const <UserModel>[]);
    final selected = _selectedValue;
    // DropdownButton requires the current value to exist in items.
    if (selected != unassignedValue &&
        !menuUsers.any((u) => u.id == selected)) {
      menuUsers.insert(
        0,
        UserModel(
          id: selected,
          role: 'Employee',
          phone: '',
          name: label,
        ),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: selected,
        isExpanded: true,
        isDense: true,
        borderRadius: BorderRadius.circular(16),
        dropdownColor: theme.cardColor,
        icon: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.expand_more_rounded,
            color: accent,
            size: 22,
          ),
        ),
        padding: EdgeInsets.zero,
        items: [
          DropdownMenuItem<int>(
            value: unassignedValue,
            child: Row(
              children: [
                _menuLeading(
                  accent: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  assigned: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    unassignLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...menuUsers.map((user) {
            final off =
                isUserOnWeeklyDayOff(user.weeklyDayOff, companyTimeZone);
            return DropdownMenuItem<int>(
              value: user.id,
              enabled: !off,
              child: Row(
                children: [
                  _menuLeading(
                    accent: off ? theme.disabledColor : accent,
                    assigned: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      off
                          ? '${user.displayName} ($weeklyDayOffLabel)'
                          : user.displayName,
                      style: TextStyle(
                        color: off
                            ? theme.disabledColor
                            : theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        onChanged: (value) {
          if (value == null) return;
          if (value == unassignedValue) {
            onAssigneeSelected!(null);
          } else {
            onAssigneeSelected!(value);
          }
        },
        selectedItemBuilder: (context) {
          final count = 1 + menuUsers.length;
          return List<Widget>.generate(count, (_) {
            return Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  _leadingBadge(accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  /// Solid accent chip — same visual weight as the status color dot.
  Widget _leadingBadge(Color accent) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.5),
            blurRadius: 5,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        _isAssigned ? Icons.person : Icons.person_outline,
        size: 11,
        color: Colors.white,
      ),
    );
  }

  Widget _menuLeading({required Color accent, required bool assigned}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        assigned ? Icons.person : Icons.person_outline,
        size: 11,
        color: Colors.white,
      ),
    );
  }
}
