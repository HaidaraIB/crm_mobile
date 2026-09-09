import '../../chat_engine/cubit/chat_thread_cubit.dart';
import '../social_inbox/social_inbox_repository.dart';
import 'social_message_adapter.dart';

/// Full-window adapter — inbox messages API has no cursor pagination yet.
class SocialInboxThreadRepository
    implements ChatThreadRepository<SocialEngineMessage> {
  SocialInboxThreadRepository({
    required this.repository,
    required this.conversationId,
  });

  final SocialInboxRepository repository;
  final int conversationId;

  Future<List<SocialEngineMessage>> _fetchAll() async {
    final messages = await repository.getMessages(conversationId);
    return adaptSocialMessages(messages);
  }

  ChatFetchPageResult<SocialEngineMessage> _result(
    List<SocialEngineMessage> messages,
  ) =>
      ChatFetchPageResult(messages: messages, hasOlder: false, hasNewer: false);

  @override
  Future<ChatFetchPageResult<SocialEngineMessage>> fetchAround({
    required int messageId,
  }) async =>
      _result(await _fetchAll());

  @override
  Future<ChatFetchPageResult<SocialEngineMessage>> fetchNewer({
    required int afterMessageId,
  }) async {
    final all = await _fetchAll();
    final newer =
        all.where((m) => m.id > afterMessageId).toList(growable: false);
    return _result(newer.isEmpty ? all : newer);
  }

  @override
  Future<ChatFetchPageResult<SocialEngineMessage>> fetchOlder({
    required int beforeMessageId,
  }) async =>
      const ChatFetchPageResult(messages: [], hasOlder: false);

  @override
  Future<ChatFetchPageResult<SocialEngineMessage>> fetchTailRefresh({
    required int throughMessageId,
  }) async =>
      _result(await _fetchAll());

  @override
  Future<ChatFetchPageResult<SocialEngineMessage>> fetchTailWindow() async =>
      _result(await _fetchAll());
}
