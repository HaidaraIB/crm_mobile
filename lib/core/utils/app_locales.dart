import 'package:flutter/material.dart';

/// Arabic (Egypt): Gregorian calendar for dates; aligns with CRM web `ar-EG` / `ARABIC_DATE_LOCALE`.
abstract final class AppLocales {
  static const Locale arabic = Locale('ar', 'EG');
  static const Locale english = Locale('en');

  /// ICU locale string for [intl] [DateFormat] (underscore), not Flutter's [Locale] constructor.
  static String intlDateFormat(Locale locale) {
    if (locale.languageCode == 'ar') return 'ar_EG';
    return 'en';
  }

  /// From persisted or API language code (`ar` / `en`).
  static Locale fromLanguageCode(String? code) {
    if (code == 'ar') return arabic;
    return english;
  }
}
