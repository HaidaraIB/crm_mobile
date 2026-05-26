import '../../chat_engine/cubit/chat_thread_cubit.dart';
import '../../models/tenant_chat_models.dart';
import '../../services/api_service.dart';
import 'tenant_chat_message_adapter.dart';

class TenantChatRepository implements ChatThreadRepository<TenantEngineMessage> {
  TenantChatRepository({
    required this.api,
    required this.conversationId,
    this.pageSize = 80,
  });

  final ApiService api;
  final int conversationId;
  final int pageSize;

  @override
  Future<ChatFetchPageResult<TenantEngineMessage>> fetchAround({required int messageId}) async {
    final page = await api.getTenantChatMessages(
      conversationId,
      ordering: 'created_at',
      pageSize: pageSize,
      aroundId: messageId,
    );
    return _toResult(page);
  }

  @override
  Future<ChatFetchPageResult<TenantEngineMessage>> fetchNewer({required int afterMessageId}) async {
    final page = await api.getTenantChatMessages(
      conversationId,
      ordering: 'created_at',
      pageSize: pageSize,
      afterId: afterMessageId,
    );
    return _toResult(page);
  }

  @override
  Future<ChatFetchPageResult<TenantEngineMessage>> fetchOlder({required int beforeMessageId}) async {
    final page = await api.getTenantChatMessages(
      conversationId,
      ordering: 'created_at',
      pageSize: pageSize,
      beforeId: beforeMessageId,
    );
    return _toResult(page);
  }

  @override
  Future<ChatFetchPageResult<TenantEngineMessage>> fetchTailWindow() async {
    // Backward-compatible fallback: get count with tiny page, then fetch last page.
    final head = await api.getTenantChatMessages(
      conversationId,
      ordering: 'created_at',
      pageSize: 1,
      page: 1,
    );
    final count = head.count;
    final lastPage = count <= 0 ? 1 : ((count - 1) ~/ pageSize) + 1;
    final page = await api.getTenantChatMessages(
      conversationId,
      ordering: 'created_at',
      pageSize: pageSize,
      page: lastPage,
    );
    return _toResult(page);
  }

  ChatFetchPageResult<TenantEngineMessage> _toResult(TenantChatMessagesPage page) {
    final out = page.results.map(TenantEngineMessage.new).toList(growable: false);
    return ChatFetchPageResult(
      messages: out,
      hasOlder: page.hasOlder || page.previous != null,
      hasNewer: page.hasNewer || page.next != null,
    );
  }
}

