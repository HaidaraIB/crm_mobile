import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Toast-style snackbars aligned with app surfaces (gray-50 / gray-800 cards),
/// primary purple accents, and semantic colors for success, error, warning, and info.
enum AppSnackBarVariant {
  success,
  error,
  warning,
  info,
}

class _SnackPalette {
  const _SnackPalette({
    required this.surface,
    required this.border,
    required this.iconBg,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });

  final Color surface;
  final Color border;
  final Color iconBg;
  final Color iconColor;
  final Color textColor;
  final IconData icon;
}

class SnackbarHelper {
  static const EdgeInsets _margin = EdgeInsets.fromLTRB(16, 0, 16, 24);
  static const EdgeInsets _innerPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 12);
  static const double _radius = 14;

  static _SnackPalette _palette(Brightness brightness, AppSnackBarVariant variant) {
    final isDark = brightness == Brightness.dark;
    final Color primaryMuted = AppTheme.primaryColor.withValues(alpha: isDark ? 0.35 : 0.12);

    switch (variant) {
      case AppSnackBarVariant.success:
        return _SnackPalette(
          surface: isDark ? const Color(0xFF14532D).withValues(alpha: 0.45) : const Color(0xFFECFDF5),
          border: isDark ? const Color(0xFF22C55E).withValues(alpha: 0.45) : const Color(0xFFA7F3D0),
          iconBg: isDark ? const Color(0xFF166534).withValues(alpha: 0.6) : const Color(0xFFD1FAE5),
          iconColor: isDark ? const Color(0xFF86EFAC) : const Color(0xFF047857),
          textColor: isDark ? const Color(0xFFECFDF5) : const Color(0xFF064E3B),
          icon: Icons.check_circle_rounded,
        );
      case AppSnackBarVariant.error:
        return _SnackPalette(
          surface: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.45) : const Color(0xFFFEF2F2),
          border: isDark ? const Color(0xFFF87171).withValues(alpha: 0.45) : const Color(0xFFFECACA),
          iconBg: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.55) : const Color(0xFFFEE2E2),
          iconColor: isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
          textColor: isDark ? const Color(0xFFFFF1F2) : const Color(0xFF7F1D1D),
          icon: Icons.error_rounded,
        );
      case AppSnackBarVariant.warning:
        return _SnackPalette(
          surface: isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFFFBEB),
          border: isDark ? const Color(0xFFFBBF24).withValues(alpha: 0.45) : const Color(0xFFFDE68A),
          iconBg: isDark ? const Color(0xFF92400E).withValues(alpha: 0.55) : const Color(0xFFFEF3C7),
          iconColor: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
          textColor: isDark ? const Color(0xFFFFFBEB) : const Color(0xFF78350F),
          icon: Icons.warning_amber_rounded,
        );
      case AppSnackBarVariant.info:
        return _SnackPalette(
          surface: isDark ? const Color(0xFF312E81).withValues(alpha: 0.35) : const Color(0xFFF5F3FF),
          border: isDark ? AppTheme.primaryColor.withValues(alpha: 0.55) : const Color(0xFFDDD6FE),
          iconBg: primaryMuted,
          iconColor: isDark ? const Color(0xFFC4B5FD) : AppTheme.primaryColor,
          textColor: isDark ? const Color(0xFFE9E7FF) : const Color(0xFF3730A3),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  static void show(
    BuildContext context,
    String message, {
    required AppSnackBarVariant variant,
    Duration duration = const Duration(seconds: 3),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    _showMessenger(
      messenger,
      message,
      variant: variant,
      brightness: Theme.of(context).brightness,
      textTheme: Theme.of(context).textTheme,
      duration: duration,
      clearSnackBars: clearSnackBars,
      action: action,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    show(context, message, variant: AppSnackBarVariant.success, duration: duration, clearSnackBars: clearSnackBars, action: action);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    show(context, message, variant: AppSnackBarVariant.error, duration: duration, clearSnackBars: clearSnackBars, action: action);
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    show(context, message, variant: AppSnackBarVariant.warning, duration: duration, clearSnackBars: clearSnackBars, action: action);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    show(context, message, variant: AppSnackBarVariant.info, duration: duration, clearSnackBars: clearSnackBars, action: action);
  }

  /// Use when showing a snackbar after [Navigator.pop] (e.g. in dialogs). Pass [brightness]
  /// from [Theme.of] before pop.
  static void showWithMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required AppSnackBarVariant variant,
    required Brightness brightness,
    TextTheme? textTheme,
    Duration duration = const Duration(seconds: 3),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    _showMessenger(
      messenger,
      message,
      variant: variant,
      brightness: brightness,
      textTheme: textTheme,
      duration: duration,
      clearSnackBars: clearSnackBars,
      action: action,
    );
  }

  static void showSuccessWithMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required Brightness brightness,
    TextTheme? textTheme,
    Duration duration = const Duration(seconds: 2),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    showWithMessenger(
      messenger,
      message,
      variant: AppSnackBarVariant.success,
      brightness: brightness,
      textTheme: textTheme,
      duration: duration,
      clearSnackBars: clearSnackBars,
      action: action,
    );
  }

  static void showErrorWithMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required Brightness brightness,
    TextTheme? textTheme,
    Duration duration = const Duration(seconds: 4),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    showWithMessenger(
      messenger,
      message,
      variant: AppSnackBarVariant.error,
      brightness: brightness,
      textTheme: textTheme,
      duration: duration,
      clearSnackBars: clearSnackBars,
      action: action,
    );
  }

  static void showWarningWithMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required Brightness brightness,
    TextTheme? textTheme,
    Duration duration = const Duration(seconds: 3),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    showWithMessenger(
      messenger,
      message,
      variant: AppSnackBarVariant.warning,
      brightness: brightness,
      textTheme: textTheme,
      duration: duration,
      clearSnackBars: clearSnackBars,
      action: action,
    );
  }

  static void showInfoWithMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required Brightness brightness,
    TextTheme? textTheme,
    Duration duration = const Duration(seconds: 3),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    showWithMessenger(
      messenger,
      message,
      variant: AppSnackBarVariant.info,
      brightness: brightness,
      textTheme: textTheme,
      duration: duration,
      clearSnackBars: clearSnackBars,
      action: action,
    );
  }

  static void _showMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required AppSnackBarVariant variant,
    required Brightness brightness,
    TextTheme? textTheme,
    Duration duration = const Duration(seconds: 3),
    bool clearSnackBars = false,
    SnackBarAction? action,
  }) {
    if (clearSnackBars) {
      messenger.clearSnackBars();
    }
    final p = _palette(brightness, variant);
    final bodyStyle = textTheme?.bodyMedium?.copyWith(
          color: p.textColor,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(color: p.textColor, height: 1.35, fontWeight: FontWeight.w500);

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: _margin,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        action: action,
        content: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: p.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.35 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: _innerPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(p.icon, size: 22, color: p.iconColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(message, style: bodyStyle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
