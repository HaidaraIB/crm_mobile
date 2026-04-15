import 'package:flutter/material.dart';
import '../models/settings_model.dart';

/// Compact pill for lead status — replaces the large bordered block for clearer hierarchy.
class LeadStatusBadge extends StatelessWidget {
  const LeadStatusBadge({
    super.key,
    required this.accentColor,
    required this.label,
    required this.parseColor,
    this.statuses,
    this.selected,
    this.onStatusSelected,
    this.isLoading = false,
  });

  final Color accentColor;
  final String label;
  final Color Function(String hexColor) parseColor;

  /// When null, shows read-only pill (no chevron / menu).
  final List<StatusModel>? statuses;
  final StatusModel? selected;
  final ValueChanged<StatusModel>? onStatusSelected;
  final bool isLoading;

  bool get _interactive =>
      statuses != null &&
      statuses!.isNotEmpty &&
      onStatusSelected != null &&
      selected != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surface = theme.cardColor;
    final fill = Color.alphaBlend(
      accentColor.withValues(alpha: isDark ? 0.14 : 0.10),
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
            color: accentColor.withValues(alpha: isDark ? 0.42 : 0.38),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : _interactive
                ? _buildDropdown(context, theme)
                : _buildReadOnly(context, theme),
      ),
    );
  }

  Widget _buildReadOnly(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusDot(accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, ThemeData theme) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<StatusModel>(
        value: selected,
        isExpanded: true,
        isDense: true,
        borderRadius: BorderRadius.circular(16),
        dropdownColor: theme.cardColor,
        icon: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.expand_more_rounded,
            color: accentColor.withValues(alpha: 0.95),
            size: 22,
          ),
        ),
        padding: EdgeInsets.zero,
        items: statuses!.map((status) {
          final itemColor = parseColor(status.color);
          return DropdownMenuItem<StatusModel>(
            value: status,
            child: Row(
              children: [
                _statusDot(itemColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (StatusModel? newStatus) {
          if (newStatus != null) {
            onStatusSelected!(newStatus);
          }
        },
        selectedItemBuilder: (context) {
          return statuses!.map((status) {
            final itemColor = parseColor(status.color);
            return Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  _statusDot(itemColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }

  static Widget _statusDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
