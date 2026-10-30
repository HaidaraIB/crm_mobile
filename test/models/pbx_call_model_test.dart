import 'package:crm_mobile/core/localization/app_localizations.dart';
import 'package:crm_mobile/models/notification_model.dart';
import 'package:crm_mobile/models/pbx_call_model.dart';
import 'package:crm_mobile/services/pbx_call_launcher.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PbxMe', () {
    test('parses /telephony/me/ with a desk phone', () {
      final me = PbxMe.fromJson({
        'provisioned': true,
        'outbound_suspended': false,
        'extension': {
          'id': 'x',
          'number': '101',
          'device_type': 'desk_phone',
          'registered': true,
        },
        'can_click_to_call': true,
      });
      expect(me.extensionNumber, '101');
      expect(me.deviceType, 'desk_phone');
      expect(PbxCallLauncher.canClickToCall(me), isTrue);
    });

    test('no extension or no click-to-call falls back to the dialer', () {
      final noExt = PbxMe.fromJson({
        'provisioned': true,
        'extension': null,
        'can_click_to_call': false,
      });
      expect(PbxCallLauncher.canClickToCall(noExt), isFalse);
      expect(PbxCallLauncher.canClickToCall(null), isFalse);
    });
  });

  group('PbxCallRecord', () {
    test('parses a missed inbound call', () {
      final c = PbxCallRecord.fromJson({
        'id': 'c1',
        'direction': 'inbound',
        'status': 'no_answer',
        'from_party': '+9647801234567',
        'to_party': '+9647700000001',
        'extension_number': null,
        'answered_by_number': null,
        'crm_contact': 12,
        'crm_contact_name': 'Lead',
        'billsec_s': 0,
        'has_recording': false,
        'started_at': '2026-10-17T09:00:00Z',
      });
      expect(c.isMissed, isTrue);
      expect(c.remoteParty, '+9647801234567');
      expect(c.crmContactId, 12);
      expect(c.startedAt!.toUtc(), DateTime.utc(2026, 10, 17, 9));
    });

    test(
      'an answered or outbound call is not missed; outbound remote is the callee',
      () {
        final out = PbxCallRecord.fromJson({
          'id': 'c2',
          'direction': 'outbound',
          'status': 'no_answer',
          'from_party': '100',
          'to_party': '+9647801234567',
          'has_recording': true,
        });
        expect(out.isMissed, isFalse);
        expect(out.remoteParty, '+9647801234567');
      },
    );

    test('the cursor comes from the next link', () {
      expect(
        PbxCallsPage.cursorFromNextUrl(
          'https://api.x/api/v1/telephony/calls/?cursor=cD0yMDI2&limit=30',
        ),
        'cD0yMDI2',
      );
      expect(PbxCallsPage.cursorFromNextUrl(null), isNull);
    });
  });

  group('click-to-call refusals', () {
    final me = PbxMe.fromJson({
      'provisioned': true,
      'extension': {'number': '100', 'device_type': 'webrtc'},
      'can_click_to_call': true,
    });

    for (final lang in ['en', 'ar']) {
      test('every refusal code has a $lang message', () async {
        final loc = AppLocalizations(Locale(lang));
        String t(String k) => loc.translate(k);
        for (final code in [
          'concurrency_limit',
          'cps_limit',
          'phone_not_registered',
          'outbound_suspended',
          'pbx_unavailable',
          'destination_not_allowed',
          'invalid_destination',
          'no_extension',
          'not_provisioned',
          'monthly_pbx_minutes',
          'something_new',
        ]) {
          final msg = PbxCallLauncher.refusalMessage(code, me, t);
          expect(
            msg.startsWith('pbxCallError_'),
            isFalse,
            reason: '$lang $code',
          );
          expect(msg.contains('{ext}'), isFalse);
        }
        expect(
          PbxCallLauncher.refusalMessage('phone_not_registered', me, t),
          contains('100'),
        );
        expect(PbxCallLauncher.deviceLabel(me, t), t('pbxDevice_webrtc'));
      });
    }
  });

  test('the phone-system push types parse', () {
    expect(
      NotificationPayload.parseNotificationType('pbx_call_missed'),
      NotificationType.pbxCallMissed,
    );
    expect(
      NotificationPayload.parseNotificationType('pbx_trunk_down'),
      NotificationType.pbxTrunkDown,
    );
    expect(
      NotificationPayload.parseNotificationType('pbx_trunk_recovered'),
      NotificationType.pbxTrunkRecovered,
    );
  });
}
