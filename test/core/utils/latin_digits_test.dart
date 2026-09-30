import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:crm_mobile/core/utils/app_locales.dart';

void main() {
  test('arabic formatters use latin digits', () async {
    await installLatinDigits();
    const eastern = '٠١٢٣٤٥٦٧٨٩';

    final date = DateFormat.yMMMd('ar_EG').format(DateTime(2026, 10, 1));
    final tagged = DateFormat(
      'd MMM y',
      AppLocales.intlDateFormat(AppLocales.arabic),
    ).format(DateTime(2026, 10, 1));
    final number = NumberFormat.decimalPattern('ar').format(1234567);

    for (final sample in [date, tagged, number]) {
      expect(sample.split('').any(eastern.contains), isFalse, reason: sample);
    }
    expect(date, contains('2026'));
    expect(number, contains('1'));
    expect(number, contains('7'));
  });
}
