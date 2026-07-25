import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/app_locales.dart';

/// Locale-aware date+time for lead timeline rows (mirrors web formatTimelineDate).
String formatTimelineDate(DateTime? date, Locale locale) {
  final d = date ?? DateTime.now();
  final fmt = DateFormat(
    'MMM d, yyyy h:mm a',
    AppLocales.intlDateFormat(locale),
  );
  return fmt.format(d.toLocal());
}

String formatTimelineDetailDateTime(DateTime? date, Locale locale) {
  if (date == null) return '';
  return formatTimelineDate(date, locale);
}
