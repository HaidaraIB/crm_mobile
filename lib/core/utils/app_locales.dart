import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart';

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

/// Arabic month names stay; every formatter emits 0–9.
/// Call once from `main` before `runApp`.
Future<void> installLatinDigits() async {
  await initializeDateFormatting();
  for (final locale in DateFormat.allLocalesWithSymbols()) {
    DateFormat.useNativeDigitsByDefaultFor(locale, false);
  }
  // intl ignores `u-nu-latn` unless this flag is set for that exact tag.
  DateFormat.useNativeDigitsByDefaultFor('ar_EG_u_nu_latn', false);

  for (final entry in numberFormatSymbols.entries.toList()) {
    final s = entry.value;
    if (s.ZERO_DIGIT == '0') continue;
    numberFormatSymbols[entry.key] = NumberSymbols(
      NAME: s.NAME,
      DECIMAL_SEP: s.DECIMAL_SEP,
      GROUP_SEP: s.GROUP_SEP,
      PERCENT: s.PERCENT,
      ZERO_DIGIT: '0',
      PLUS_SIGN: s.PLUS_SIGN,
      MINUS_SIGN: s.MINUS_SIGN,
      EXP_SYMBOL: s.EXP_SYMBOL,
      PERMILL: s.PERMILL,
      INFINITY: s.INFINITY,
      NAN: s.NAN,
      DECIMAL_PATTERN: s.DECIMAL_PATTERN,
      SCIENTIFIC_PATTERN: s.SCIENTIFIC_PATTERN,
      PERCENT_PATTERN: s.PERCENT_PATTERN,
      CURRENCY_PATTERN: s.CURRENCY_PATTERN,
      DEF_CURRENCY_CODE: s.DEF_CURRENCY_CODE,
    );
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
