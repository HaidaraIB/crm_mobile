import 'package:flutter_test/flutter_test.dart';

import 'package:crm_mobile/features/whatsapp_chat/cubit/whatsapp_chat_thread_cubit.dart';
import 'package:crm_mobile/features/whatsapp_chat/cubit/whatsapp_chat_thread_state.dart';
import 'package:crm_mobile/features/whatsapp_chat/whatsapp_chat_repository.dart';
import 'package:crm_mobile/models/lead_whatsapp_message_model.dart';
import 'package:crm_mobile/models/whatsapp_account_status_model.dart';
import 'package:crm_mobile/models/whatsapp_conversation_model.dart';
import 'package:crm_mobile/models/whatsapp_template_model.dart';

LeadWhatsAppMessageModel _msg({
  int id = 1,
  String direction = 'inbound',
}) {
  return LeadWhatsAppMessageModel(
    id: id,
    client: 1,
    phoneNumber: '+96550001234',
    body: 'hi',
    direction: direction,
    createdAt: DateTime.utc(2026, 8, 1, 20, 17),
  );
}

void main() {
  test('bootstrap does not reveal 24h lock before a disconnected account', () async {
    final cubit = WhatsAppChatThreadCubit(
      repository: _FakeWhatsAppRepo(
        messages: [_msg()],
        session: const WhatsAppSessionWindow(inSession: false),
        accountStatus: const WhatsAppAccountStatus(
          connected: false,
          displayNameBlocked: false,
        ),
        accountDelay: const Duration(milliseconds: 40),
      ),
      clientId: 1,
      phoneNumber: '+96550001234',
    );
    addTearDown(cubit.close);

    final seen = <WhatsAppChatThreadState>[cubit.state];
    final sub = cubit.stream.listen(seen.add);
    addTearDown(sub.cancel);

    final done = cubit.bootstrap();
    // Messages + session resolve immediately; account status is still in flight.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cubit.state.composerReady, isFalse);
    expect(cubit.state.sessionWindow, isNull);

    await done;

    expect(cubit.state.composerReady, isTrue);
    expect(cubit.state.sendBlocked, isTrue);
    expect(cubit.state.sessionWindow?.inSession, isFalse);
    expect(
      seen.where((s) => s.sessionWindow != null && !s.composerReady),
      isEmpty,
      reason: 'session must not paint until composer chrome is ready',
    );
    expect(
      seen.where((s) => s.composerReady && !s.sendBlocked),
      isEmpty,
      reason: 'must not flash a sendable composer before disconnected',
    );
  });

  test('bootstrap connected + closed session is ready in one emit', () async {
    final cubit = WhatsAppChatThreadCubit(
      repository: _FakeWhatsAppRepo(
        messages: [_msg()],
        session: const WhatsAppSessionWindow(inSession: false),
        accountStatus: const WhatsAppAccountStatus(
          connected: true,
          displayNameBlocked: false,
          phoneNumberId: '123',
        ),
      ),
      clientId: 1,
      phoneNumber: '+96550001234',
    );
    addTearDown(cubit.close);

    await cubit.bootstrap();

    expect(cubit.state.composerReady, isTrue);
    expect(cubit.state.sendBlocked, isFalse);
    expect(cubit.state.sessionWindow?.inSession, isFalse);
    expect(cubit.state.connectedPhoneNumberId, '123');
  });

  test('account status failure still opens the composer without blocking send', () async {
    final cubit = WhatsAppChatThreadCubit(
      repository: _FakeWhatsAppRepo(
        messages: [_msg()],
        session: const WhatsAppSessionWindow(inSession: true, hoursRemaining: 12),
        accountThrows: true,
      ),
      clientId: 1,
      phoneNumber: '+96550001234',
    );
    addTearDown(cubit.close);

    await cubit.bootstrap();

    expect(cubit.state.composerReady, isTrue);
    expect(cubit.state.sendBlocked, isFalse);
    expect(cubit.state.sessionWindow?.inSession, isTrue);
  });
}

class _FakeWhatsAppRepo implements WhatsAppChatRepository {
  _FakeWhatsAppRepo({
    this.messages = const [],
    this.session = const WhatsAppSessionWindow(inSession: false),
    this.accountStatus,
    this.accountDelay = Duration.zero,
    this.accountThrows = false,
  });

  final List<LeadWhatsAppMessageModel> messages;
  final WhatsAppSessionWindow session;
  final WhatsAppAccountStatus? accountStatus;
  final Duration accountDelay;
  final bool accountThrows;

  @override
  Future<List<LeadWhatsAppMessageModel>> getMessages({
    int? clientId,
    String? phone,
  }) async =>
      messages;

  @override
  Future<WhatsAppSessionWindow> getSessionWindow({
    int? clientId,
    String? phone,
  }) async =>
      session;

  @override
  Future<WhatsAppAccountStatus?> getAccountStatus() async {
    if (accountDelay > Duration.zero) {
      await Future<void>.delayed(accountDelay);
    }
    if (accountThrows) throw Exception('account down');
    return accountStatus;
  }

  @override
  Future<void> markConversationRead({int? clientId, String? phone}) async {}

  @override
  Future<WhatsAppConversationsPage> getConversations({
    String? status,
    String? assignment,
    int? agentId,
    bool? starred,
    bool? unreplied,
    String? search,
    int? limit,
    int? offset,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> updateConversationState({
    required int clientId,
    String? status,
    String? snoozedUntil,
    bool? isStarred,
    bool? isUnsubscribed,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendMessage({
    required String to,
    required String message,
    int? clientId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendMedia({
    required String to,
    required String filePath,
    int? clientId,
    String? caption,
    bool isVoiceNote = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendLocation({
    required String to,
    required double latitude,
    required double longitude,
    int? clientId,
    String? name,
    String? address,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendTemplate({
    required String to,
    required int templateId,
    int? clientId,
    List<String>? bodyParameters,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> getUnreadCount() => throw UnimplementedError();

  @override
  Future<void> deleteMessage(int messageId) => throw UnimplementedError();

  @override
  Future<void> deleteConversation({int? clientId, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getContactByPhone(String phone) =>
      throw UnimplementedError();

  @override
  Future<List<WhatsAppTemplateModel>> getApprovedTemplates() async => const [];

  @override
  Future<String?> getConnectedPhoneNumberId() => throw UnimplementedError();

  @override
  String attachmentUrl(int messageId) => '';
}
