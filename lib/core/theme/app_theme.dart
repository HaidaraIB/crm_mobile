import 'package:flutter/material.dart';

class AppTheme {
  // Primary Purple Color
  static const Color primaryColor = Color(0xFF4215AA);

  /// Lighter primary for icons/checks on dark surfaces (keeps contrast).
  static const Color primaryAccentDark = Color(0xFFB794F6);

  /// Primary accent that stays visible on the current surface brightness.
  static Color primaryAccent(Brightness brightness) =>
      brightness == Brightness.dark ? primaryAccentDark : primaryColor;

  /// High-contrast switch colors for light/dark surfaces.
  static SwitchThemeData switchThemeFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isDark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB);
        }
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return isDark ? const Color(0xFFE5E7EB) : const Color(0xFFF9FAFB);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isDark
              ? const Color(0xFF374151).withValues(alpha: 0.6)
              : const Color(0xFFE5E7EB);
        }
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        // Off track must stay clearly lighter than dark card surfaces.
        return isDark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected) ||
            states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        return const Color(0xFF9CA3AF);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.hovered)) {
          return primaryColor.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }),
    );
  }

  /// Blue color for SMS button (matches web app)
  static const Color smsButtonColor = Color(0xFF2563EB);

  /// Thmanyah typeface (matches CRM-project / admin):
  /// Sans = UI (including headings).
  static const String fontFamilySans = 'ThmanyahSans';

  static TextStyle? _withFont(TextStyle? style, String family) =>
      style?.copyWith(fontFamily: family);

  static TextTheme _textTheme(TextTheme base, Color color) {
    TextStyle? applyColor(TextStyle? s) =>
        _withFont(s?.copyWith(color: color), fontFamilySans);
    TextStyle? applyColorSecondary(TextStyle? s) =>
        _withFont(s?.copyWith(color: color.withValues(alpha: 0.87)), fontFamilySans);

    return TextTheme(
      displayLarge: applyColor(base.displayLarge),
      displayMedium: applyColor(base.displayMedium),
      displaySmall: applyColor(base.displaySmall),
      headlineLarge: applyColor(base.headlineLarge),
      headlineMedium: applyColor(base.headlineMedium),
      headlineSmall: applyColor(base.headlineSmall),
      titleLarge: applyColor(base.titleLarge),
      titleMedium: applyColor(base.titleMedium),
      titleSmall: applyColor(base.titleSmall),
      bodyLarge: applyColor(base.bodyLarge),
      bodyMedium: applyColor(base.bodyMedium),
      bodySmall: applyColorSecondary(base.bodySmall),
      labelLarge: applyColor(base.labelLarge),
      labelMedium: applyColor(base.labelMedium),
      labelSmall: applyColorSecondary(base.labelSmall),
    );
  }

  static ThemeData lightThemeFor(Locale locale) {
    final base = ThemeData.light().textTheme;
    final textTheme = _textTheme(base, Colors.black);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      fontFamily: fontFamilySans,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF9FAFB), // gray-50
      cardColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.black),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: fontFamilySans,
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamilySans,
          color: Color(0xFF111827),
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: switchThemeFor(Brightness.light),
    );
  }

  static ThemeData darkThemeFor(Locale locale) {
    final base = ThemeData.dark().textTheme;
    final textThemeBase = _textTheme(base, Colors.white);
    final textTheme = textThemeBase.copyWith(
      bodySmall: textThemeBase.bodySmall?.copyWith(color: Colors.white70),
      labelSmall: textThemeBase.labelSmall?.copyWith(color: Colors.white70),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      fontFamily: fontFamilySans,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF1F2937), // gray-800
        onSurface: const Color(0xFFD1D5DB), // gray-300
        onSurfaceVariant: const Color(0xFF9CA3AF), // gray-400
        outline: const Color(0xFF374151), // gray-700
        outlineVariant: const Color(0xFF4B5563), // gray-600
      ),
      scaffoldBackgroundColor: const Color(0xFF111827), // gray-900
      cardColor: const Color(0xFF1F2937), // gray-800
      dividerColor: Colors.white.withValues(alpha: 0.1),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: fontFamilySans,
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFD1D5DB), // gray-300
      ),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F2937), // gray-800
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamilySans,
          color: Color(0xFF9CA3AF), // gray-400
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1F2937), // gray-800
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1F2937), // gray-800
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1F2937), // gray-800
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF1F2937), // gray-800
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFFD1D5DB), // gray-300
        iconColor: Color(0xFFD1D5DB),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamilySans,
          color: Color(0xFFE5E7EB),
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: switchThemeFor(Brightness.dark),
    );
  }

  /// للتوافق مع الشيفرة التي تستخدم theme بدون locale (يُستخدم الانجليزي)
  static ThemeData get lightTheme => lightThemeFor(const Locale('en'));
  static ThemeData get darkTheme => darkThemeFor(const Locale('en'));
}
