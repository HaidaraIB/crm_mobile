import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_mobile/core/api/api_exceptions.dart';
import 'package:crm_mobile/core/localization/app_localizations.dart';
import 'package:crm_mobile/core/utils/form_api_errors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en'), Locale('ar')],
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );
  }

  testWidgets('maps duplicate_lead_phone code to phone field', (tester) async {
    await tester.pumpWidget(wrap(Builder(
      builder: (context) {
        final errors = mapLeadApiErrorToFieldErrors(
          context,
          ApiFieldException(
            'Validation failed.',
            code: 'duplicate_lead_phone',
            fields: {
              'phone_number':
                  'A lead with this phone number already exists in your company.',
            },
          ),
        );
        expect(errors['phone'], isNotNull);
        expect(errors['phone'], isNot(contains('Validation failed')));
        expect(errors.containsKey('general'), isFalse);
        return const SizedBox.shrink();
      },
    )));
  });

  testWidgets('maps phone_number detail without code', (tester) async {
    await tester.pumpWidget(wrap(Builder(
      builder: (context) {
        final errors = mapLeadApiErrorToFieldErrors(
          context,
          ApiFieldException(
            'Validation failed.',
            code: 'bad_request',
            fields: {
              'phone_number':
                  'A lead with this phone number already exists in your company.',
            },
          ),
        );
        expect(errors['phone'], isNotNull);
        expect(errors['phone']!.toLowerCase(), contains('phone'));
        return const SizedBox.shrink();
      },
    )));
  });

  testWidgets('generic validation without fields uses fallback', (tester) async {
    await tester.pumpWidget(wrap(Builder(
      builder: (context) {
        final errors = mapLeadApiErrorToFieldErrors(
          context,
          ApiFieldException('Validation failed.', code: 'bad_request'),
          fallbackGeneralKey: 'failedToUpdateLead',
        );
        expect(errors['general'], isNotNull);
        expect(errors['general'], isNot(equals('Validation failed.')));
        return const SizedBox.shrink();
      },
    )));
  });

  test('isGenericValidationMessage detects API message', () {
    expect(isGenericValidationMessage('Validation failed.'), isTrue);
    expect(isGenericValidationMessage('Something else'), isFalse);
  });
}
