import 'package:flutter/material.dart';

/// Arabic (Egypt): Gregorian calendar for dates; aligns with CRM web `ar-EG` / `ARABIC_DATE_LOCALE`.
abstract final class AppLocales {
  static const Locale arabic = Locale('ar', 'EG');
  static const Locale english = Locale('en');

  /// ICU locale for [intl] [DateFormat] (underscore form). `u-nu-latn` forces Western digits (0–9)
  /// while keeping Arabic month/weekday names for `ar`.
  static String intlDateFormat(Locale locale) {
    if (locale.languageCode == 'ar') return 'ar_EG_u_nu_latn';
    return 'en';
  }

  /// From persisted or API language code (`ar` / `en`).
  static Locale fromLanguageCode(String? code) {
    if (code == 'ar') return arabic;
    return english;
  }
}
