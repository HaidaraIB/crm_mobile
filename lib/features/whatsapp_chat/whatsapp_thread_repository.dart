import '../../chat_engine/cubit/chat_thread_cubit.dart';
import '../../models/lead_whatsapp_message_model.dart';
import '../whatsapp_chat/whatsapp_chat_repository.dart';
import 'whatsapp_message_adapter.dart';

/// Full-window adapter — WhatsApp API has no cursor pagination yet.
class WhatsAppThreadRepository
    implements ChatThreadRepository<WhatsAppEngineMessage> {
  WhatsAppThreadRepository({
    required this.repository,
    this.clientId,
    required this.phoneNumber,
  });

  final WhatsAppChatRepository repository;
  final int? clientId;
  final String phoneNumber;

  Future<List<WhatsAppEngineMessage>> _fetchAll() async {
    final newestFirst = await repository.getMessages(
      clientId: clientId,
      phone: clientId == null ? phoneNumber : null,
    );
    final oldestFirst = newestFirst.reversed.toList();
    return oldestFirst.map(WhatsAppEngineMessage.new).toList(growable: false);
  }

  ChatFetchPageResult<WhatsAppEngineMessage> _result(
    List<WhatsAppEngineMessage> messages,
  ) {
    return ChatFetchPageResult(
      messages: messages,
      hasOlder: false,
      hasNewer: false,
    );
  }

  @override
  Future<ChatFetchPageResult<WhatsAppEngineMessage>> fetchAround({
    required int messageId,
  }) async =>
      _result(await _fetchAll());

  @override
  Future<ChatFetchPageResult<WhatsAppEngineMessage>> fetchNewer({
    required int afterMessageId,
  }) async {
    final all = await _fetchAll();
    final newer = all.where((m) => m.id > afterMessageId).toList(growable: false);
    // Also return updates to known ids (delivery ticks) via full merge:
    // callers use mergePoll / upsertNewer which update by id.
    return _result(newer.isEmpty ? all : newer);
  }

  @override
  Future<ChatFetchPageResult<WhatsAppEngineMessage>> fetchOlder({
    required int beforeMessageId,
  }) async =>
      const ChatFetchPageResult(messages: [], hasOlder: false);

  @override
  Future<ChatFetchPageResult<WhatsAppEngineMessage>> fetchTailRefresh({
    required int throughMessageId,
  }) async =>
      _result(await _fetchAll());

  @override
  Future<ChatFetchPageResult<WhatsAppEngineMessage>> fetchTailWindow() async =>
      _result(await _fetchAll());
}

/// Prefer cubit-owned optimistic rows when syncing into the engine.
List<WhatsAppEngineMessage> adaptWhatsAppMessages(
  List<LeadWhatsAppMessageModel> messages,
) =>
    messages.map(WhatsAppEngineMessage.new).toList(growable: false);
