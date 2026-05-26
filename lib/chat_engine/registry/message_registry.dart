import '../models/chat_list_row.dart';
import '../models/chat_message.dart';
import 'message_index_map.dart';

class MessageRegistry<T extends ChatMessage> {
  final List<int> _orderedIds = <int>[];
  final Map<int, T> _messages = <int, T>{};
  MessageIndexMap _indexMap = MessageIndexMap.fromOrderedIds(const []);
  int _version = 0;

  int get version => _version;
  int get length => _orderedIds.length;
  List<int> get orderedIds => List.unmodifiable(_orderedIds);
  Iterable<T> get messages => _orderedIds.map((id) => _messages[id]!).whereType<T>();

  void clear() {
    _orderedIds.clear();
    _messages.clear();
    _indexMap = MessageIndexMap.fromOrderedIds(const []);
    _version++;
  }

  bool contains(int messageId) => _messages.containsKey(messageId);

  T? byId(int messageId) => _messages[messageId];

  int? indexOf(int messageId) => _indexMap.indexOf(messageId);

  int upsertOlder(List<T> batch) {
    if (batch.isEmpty) return 0;
    final prependIds = <int>[];
    for (final m in batch) {
      if (_messages.containsKey(m.id)) {
        _messages[m.id] = m;
      } else {
        prependIds.add(m.id);
        _messages[m.id] = m;
      }
    }
    if (prependIds.isNotEmpty) {
      _orderedIds.insertAll(0, prependIds);
      _rebuildIndex();
    }
    _version++;
    return prependIds.length;
  }

  int upsertNewer(List<T> batch) {
    if (batch.isEmpty) return 0;
    var inserted = 0;
    for (final m in batch) {
      if (_messages.containsKey(m.id)) {
        _messages[m.id] = m;
      } else {
        _orderedIds.add(m.id);
        _messages[m.id] = m;
        inserted++;
      }
    }
    if (inserted > 0) _rebuildIndex();
    _version++;
    return inserted;
  }

  /// Used for poll payloads where messages may be mixed updates/additions.
  void mergePoll(List<T> batch) {
    if (batch.isEmpty) return;
    final sorted = [...batch]..sort((a, b) => a.id.compareTo(b.id));
    upsertNewer(sorted);
  }

  List<ChatListRow> buildRows({
    required bool Function(T current, T? previous) sameSender,
    required bool Function(T message) isFirstUnreadPeerMessage,
  }) {
    final rows = <ChatListRow>[];
    T? prev;
    var unreadInserted = false;
    DateTime? prevDay;
    for (final id in _orderedIds) {
      final m = _messages[id];
      if (m == null) continue;
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (prevDay == null || day != prevDay) {
        rows.add(ChatDaySeparatorRow(day));
        prevDay = day;
      }
      if (!unreadInserted && isFirstUnreadPeerMessage(m)) {
        rows.add(const ChatUnreadSeparatorRow());
        unreadInserted = true;
      }
      rows.add(ChatMessageRow(m, sameSenderAsPrevious: sameSender(m, prev)));
      prev = m;
    }
    return rows;
  }

  void _rebuildIndex() {
    _indexMap = MessageIndexMap.fromOrderedIds(_orderedIds);
  }
}

