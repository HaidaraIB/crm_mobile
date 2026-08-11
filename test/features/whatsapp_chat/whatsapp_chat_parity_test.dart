import 'package:flutter_test/flutter_test.dart';

import 'package:crm_mobile/features/whatsapp_chat/cubit/whatsapp_chat_thread_cubit.dart';
import 'package:crm_mobile/models/user_model.dart';
import 'package:crm_mobile/models/whatsapp_account_status_model.dart';
import 'package:crm_mobile/utils/whatsapp_access.dart';
import 'package:crm_mobile/utils/whatsapp_meta_error_display.dart';

UserModel _user(
  String role, {
  bool whatsappChatEnabled = true,
  Map<String, bool>? supervisorPermissions,
  bool supervisorIsActive = true,
}) {
  return UserModel(
    id: 1,
    username: 'u',
    email: 'u@test.com',
    firstName: 'U',
    lastName: 'Ser',
    role: role,
    phone: '',
    whatsappChatEnabled: whatsappChatEnabled,
    supervisorPermissions: supervisorPermissions,
    supervisorIsActive: supervisorIsActive,
  );
}

void main() {
  group('canAccessWhatsAppChats', () {
    test('admin and owner always allowed', () {
      expect(canAccessWhatsAppChats(_user('admin')), isTrue);
      expect(canAccessWhatsAppChats(_user('owner')), isTrue);
      // The per-user toggle never overrides an owner.
      expect(
        canAccessWhatsAppChats(_user('admin', whatsappChatEnabled: false)),
        isTrue,
      );
    });

    test('null user denied', () {
      expect(canAccessWhatsAppChats(null), isFalse);
    });

    test('data entry and reception always denied', () {
      expect(canAccessWhatsAppChats(_user('data_entry')), isFalse);
      expect(canAccessWhatsAppChats(_user('reception')), isFalse);
    });

    test('supervisor needs can_manage_whatsapp_chats', () {
      expect(canAccessWhatsAppChats(_user('supervisor')), isFalse);
      expect(
        canAccessWhatsAppChats(
          _user(
            'supervisor',
            supervisorPermissions: const {'can_manage_whatsapp_chats': true},
          ),
        ),
        isTrue,
      );
      // An inactive supervisor record must not grant access.
      expect(
        canAccessWhatsAppChats(
          _user(
            'supervisor',
            supervisorPermissions: const {'can_manage_whatsapp_chats': true},
            supervisorIsActive: false,
          ),
        ),
        isFalse,
      );
    });

    test('employee and doctor follow the per-user toggle', () {
      expect(canAccessWhatsAppChats(_user('employee')), isTrue);
      expect(
        canAccessWhatsAppChats(_user('employee', whatsappChatEnabled: false)),
        isFalse,
      );
      expect(canAccessWhatsAppChats(_user('doctor')), isTrue);
      expect(
        canAccessWhatsAppChats(_user('doctor', whatsappChatEnabled: false)),
        isFalse,
      );
    });
  });

  group('canOpenManualWhatsAppChats', () {
    test('assignment-scoped staff cannot open unknown numbers', () {
      expect(canOpenManualWhatsAppChats(_user('employee')), isFalse);
      expect(canOpenManualWhatsAppChats(_user('doctor')), isFalse);
    });

    test('owners and permitted supervisors can', () {
      expect(canOpenManualWhatsAppChats(_user('admin')), isTrue);
      expect(
        canOpenManualWhatsAppChats(
          _user(
            'supervisor',
            supervisorPermissions: const {'can_manage_whatsapp_chats': true},
          ),
        ),
        isTrue,
      );
    });

    test('requires chat access first', () {
      expect(canOpenManualWhatsAppChats(_user('supervisor')), isFalse);
      expect(canOpenManualWhatsAppChats(null), isFalse);
    });
  });

  group('WhatsAppAccountStatus.fromJson', () {
    test('connected account exposes phone number id', () {
      final s = WhatsAppAccountStatus.fromJson({
        'status': 'connected',
        'metadata': {'phone_number_id': '123', 'display_name_status': 'APPROVED'},
      });
      expect(s.connected, isTrue);
      expect(s.phoneNumberId, '123');
      expect(s.displayNameBlocked, isFalse);
    });

    test('inactive account is not connected', () {
      final s = WhatsAppAccountStatus.fromJson({
        'status': 'connected',
        'is_active': false,
        'metadata': {'phone_number_id': '123'},
      });
      expect(s.connected, isFalse);
    });

    test('disconnected account is not connected', () {
      final s = WhatsAppAccountStatus.fromJson({'status': 'disconnected'});
      expect(s.connected, isFalse);
      expect(s.phoneNumberId, isNull);
    });

    test('pending or declined display name blocks sending', () {
      for (final status in ['PENDING', 'PENDING_REVIEW', 'DECLINED', 'EXPIRED']) {
        final s = WhatsAppAccountStatus.fromJson({
          'status': 'connected',
          'metadata': {'display_name_status': status},
        });
        expect(s.displayNameBlocked, isTrue, reason: status);
      }
    });

    test('display_name_approved false blocks sending', () {
      final s = WhatsAppAccountStatus.fromJson({
        'status': 'connected',
        'metadata': {'display_name_approved': false},
      });
      expect(s.displayNameBlocked, isTrue);
    });

    test('display name is not flagged on a disconnected account', () {
      final s = WhatsAppAccountStatus.fromJson({
        'status': 'disconnected',
        'metadata': {'display_name_status': 'PENDING'},
      });
      expect(s.displayNameBlocked, isFalse);
    });
  });

  group('composerAlertKeyForError', () {
    const cases = <String, String>{
      '131047: Re-engagement message': 'whatsappOutsideSessionUseTemplate',
      'whatsapp_outside_session_use_template':
          'whatsappOutsideSessionUseTemplate',
      '131037 display name': 'whatsapp_display_name_not_approved',
      'whatsapp_voice_note_requires_ogg': 'whatsapp_voice_note_requires_ogg',
      'error 132001 not found': 'whatsapp_template_not_found_or_language',
      'whatsapp_template_not_approved': 'whatsapp_template_not_found_or_language',
      '132000 param count': 'whatsapp_template_parameter_count',
      '131026 undeliverable': 'whatsapp_recipient_not_deliverable',
      '131049 limit': 'whatsapp_ecosystem_engagement_limit',
      'whatsapp_contact_not_found': 'whatsappContactNotFound',
      'whatsapp_access_disabled': 'whatsappChatAccessDisabled',
      'no_connected account': 'whatsappReconnectRequired',
    };

    cases.forEach((raw, expected) {
      test('maps "$raw"', () {
        expect(WhatsAppChatThreadCubit.composerAlertKeyForError(raw), expected);
      });
    });

    test('unknown errors produce no sticky alert', () {
      expect(
        WhatsAppChatThreadCubit.composerAlertKeyForError('Exception: boom'),
        isNull,
      );
      expect(WhatsAppChatThreadCubit.composerAlertKeyForError(''), isNull);
    });

    test('session errors win over the reconnect fallback', () {
      // A 131047 body that also mentions "reconnect" must still read as
      // out-of-session, not as a disconnected account.
      expect(
        WhatsAppChatThreadCubit.composerAlertKeyForError(
          '131047 outside session, please reconnect',
        ),
        'whatsappOutsideSessionUseTemplate',
      );
    });
  });

  group('localizeMetaDeliveryError', () {
    String fakeT(String key) => 'T:$key';

    test('leading Meta code resolves to a translation key', () {
      expect(
        metaDeliveryErrorTranslationKey('131047: Re-engagement message'),
        'whatsappOutsideSessionUseTemplate',
      );
      expect(
        localizeMetaDeliveryError('131047: Re-engagement message', fakeT),
        'T:whatsappOutsideSessionUseTemplate',
      );
    });

    test('embedded Meta code is found too', () {
      expect(
        metaDeliveryErrorTranslationKey('Graph error (#132001) template'),
        'whatsapp_template_not_found_or_language',
      );
    });

    test('unknown text falls back to the raw string', () {
      expect(localizeMetaDeliveryError('Something odd', fakeT), 'Something odd');
    });

    test('empty input yields empty output', () {
      expect(localizeMetaDeliveryError(null, fakeT), '');
      expect(localizeMetaDeliveryError('   ', fakeT), '');
    });

    test('untranslated key falls back to the raw string', () {
      expect(
        localizeMetaDeliveryError('131047 boom', (k) => k),
        '131047 boom',
      );
    });
  });
}
