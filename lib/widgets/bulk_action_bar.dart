import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Compact floating command bar for multi-select. Mirrors web `BulkActionBar`,
/// but uses icon actions so the pill fits a phone width without scrolling.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.selectedLabel,
    required this.clearLabel,
    required this.onClear,
    this.statusActionLabel,
    this.statusActionTitle,
    this.onStatusAction,
    this.badgeLabel,
    this.actions = const [],
  });

  final int selectedCount;
  final String selectedLabel;
  final String clearLabel;
  final VoidCallback onClear;
  final String? statusActionLabel;
  final String? statusActionTitle;
  final VoidCallback? onStatusAction;
  final String? badgeLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (selectedCount <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final countText = '$selectedCount';

    return Semantics(
      container: true,
      label: selectedLabel,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.55 : 0.18,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: selectedLabel,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          countText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    if (badgeLabel != null && badgeLabel!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _BulkBarIconButton(
                        icon: Icons.filter_alt,
                        tooltip: badgeLabel!,
                        background: AppTheme.primaryColor.withValues(
                          alpha: isDark ? 0.22 : 0.10,
                        ),
                        foreground: isDark
                            ? const Color(0xFFE9D5FF)
                            : const Color(0xFF5B21B6),
                      ),
                    ],
                    if (statusActionLabel != null && onStatusAction != null) ...[
                      const SizedBox(width: 8),
                      _BulkBarIconButton(
                        icon: Icons.select_all,
                        tooltip: statusActionTitle ?? statusActionLabel!,
                        onPressed: onStatusAction,
                        background: AppTheme.primaryColor,
                        foreground: Colors.white,
                      ),
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 22,
                        child: VerticalDivider(
                          width: 16,
                          thickness: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ..._withGaps(actions),
                    ],
                    const SizedBox(width: 8),
                    _BulkBarIconButton(
                      icon: Icons.close,
                      tooltip: clearLabel,
                      onPressed: onClear,
                      background: Colors.transparent,
                      foreground: isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _withGaps(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 8));
      out.add(items[i]);
    }
    return out;
  }
}

enum BulkBarActionVariant { secondary, danger }

/// Circular icon action used inside [BulkActionBar] (Assign, Delete).
class BulkBarActionButton extends StatelessWidget {
  const BulkBarActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = BulkBarActionVariant.secondary,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final BulkBarActionVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDanger = variant == BulkBarActionVariant.danger;
    final enabled = onPressed != null && !loading;

    final Color background;
    final Color foreground;
    if (isDanger) {
      background = const Color(0xFFDC2626);
      foreground = Colors.white;
    } else if (isDark) {
      background = Colors.white.withValues(alpha: 0.10);
      foreground = Colors.white;
    } else {
      background = const Color(0xFFF3F4F6);
      foreground = const Color(0xFF111827);
    }

    return _BulkBarIconButton(
      icon: icon,
      tooltip: label,
      onPressed: enabled ? onPressed : null,
      background: background,
      foreground: foreground,
      loading: loading,
    );
  }
}

class _BulkBarIconButton extends StatelessWidget {
  const _BulkBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Icon(icon, size: 18, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
