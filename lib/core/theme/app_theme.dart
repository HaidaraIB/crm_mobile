import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Purple Color
  static const Color primaryColor = Color(0xFF9333EA);

  /// نفس CRM-project: الإنجليزية = Inter (font-sans)، العربية = Tajawal (font-arabic)
  static bool _isArabic(Locale locale) => locale.languageCode == 'ar';

  static TextTheme _textThemeForLocale(TextTheme base, Color color, bool isArabic) {
    final fontTheme = isArabic
        ? GoogleFonts.tajawalTextTheme(base)
        : GoogleFonts.interTextTheme(base);
    TextStyle? applyColor(TextStyle? s) => s?.copyWith(color: color);
    TextStyle? applyColorSecondary(TextStyle? s) =>
        s?.copyWith(color: color.withValues(alpha: 0.87));
    return TextTheme(
      displayLarge: applyColor(fontTheme.displayLarge),
      displayMedium: applyColor(fontTheme.displayMedium),
      displaySmall: applyColor(fontTheme.displaySmall),
      headlineLarge: applyColor(fontTheme.headlineLarge),
      headlineMedium: applyColor(fontTheme.headlineMedium),
      headlineSmall: applyColor(fontTheme.headlineSmall),
      titleLarge: applyColor(fontTheme.titleLarge),
      titleMedium: applyColor(fontTheme.titleMedium),
      titleSmall: applyColor(fontTheme.titleSmall),
      bodyLarge: applyColor(fontTheme.bodyLarge),
      bodyMedium: applyColor(fontTheme.bodyMedium),
      bodySmall: applyColorSecondary(fontTheme.bodySmall),
      labelLarge: applyColor(fontTheme.labelLarge),
      labelMedium: applyColor(fontTheme.labelMedium),
      labelSmall: applyColorSecondary(fontTheme.labelSmall),
    );
  }

  static ThemeData lightThemeFor(Locale locale) {
    final isArabic = _isArabic(locale);
    final fontFamily = isArabic ? GoogleFonts.tajawal().fontFamily : GoogleFonts.inter().fontFamily;
    final base = ThemeData.light().textTheme;
    final textTheme = _textThemeForLocale(base, Colors.black, isArabic);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      fontFamily: fontFamily,
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
      ),
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: (isArabic ? GoogleFonts.tajawalTextTheme(base) : GoogleFonts.interTextTheme(base))
            .bodyLarge
            ?.copyWith(color: Colors.black),
      ),
    );
  }

  static ThemeData darkThemeFor(Locale locale) {
    final isArabic = _isArabic(locale);
    final fontFamily = isArabic ? GoogleFonts.tajawal().fontFamily : GoogleFonts.inter().fontFamily;
    final base = ThemeData.dark().textTheme;
    final textThemeBase = _textThemeForLocale(base, Colors.white, isArabic);
    final textTheme = textThemeBase.copyWith(
      bodySmall: textThemeBase.bodySmall?.copyWith(color: Colors.white70),
      labelSmall: textThemeBase.labelSmall?.copyWith(color: Colors.white70),
    );
    final fontTextTheme = isArabic ? GoogleFonts.tajawalTextTheme(base) : GoogleFonts.interTextTheme(base);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      fontFamily: fontFamily,
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
        iconTheme: IconThemeData(color: Color(0xFFD1D5DB)), // gray-300
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
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: fontTextTheme.bodyLarge?.copyWith(color: Colors.white),
    ),
  );
  }

  /// للتوافق مع الشيفرة التي تستخدم theme بدون locale (يُستخدم الانجليزي)
  static ThemeData get lightTheme => lightThemeFor(const Locale('en'));
  static ThemeData get darkTheme => darkThemeFor(const Locale('en'));
}
