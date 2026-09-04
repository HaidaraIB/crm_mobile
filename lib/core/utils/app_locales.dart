import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Arabic (Egypt): Gregorian calendar for dates; aligns with CRM web `ar-EG` / `ARABIC_DATE_LOCALE`.
abstract final class AppLocales {
  static const Locale arabic = Locale('ar', 'EG');
  static const Locale english = Locale('en');

  /// ICU locale for [intl] [DateFormat] (underscore form). Prefer this over bare `'ar'`.
  /// Still run the result through [withLatinDigits] — Flutter's intl often ignores `u-nu-latn`.
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

/// Force Western digits (0–9). Maps Eastern Arabic-Indic (٠–٩) and Persian/Urdu
/// (۰–۹) so Arabic UI keeps Latin numerals even if a formatter skipped `u-nu-latn`.
String withLatinDigits(String input) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(eastern[i], '$i');
    out = out.replaceAll(persian[i], '$i');
  }
  return out;
}

/// [DateFormat.format] plus [withLatinDigits]. Use for every on-screen date/time.
String formatLatin(DateFormat format, DateTime date) =>
    withLatinDigits(format.format(date));
