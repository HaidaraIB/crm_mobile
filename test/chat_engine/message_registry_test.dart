import 'package:flutter_test/flutter_test.dart';

import 'package:crm_mobile/chat_engine/models/chat_message.dart';
import 'package:crm_mobile/chat_engine/registry/message_registry.dart';

class _Msg implements ChatMessage {
  _Msg(this.id, {DateTime? createdAt})
      : createdAt = createdAt ?? DateTime(2024, 1, 1);

  @override
  final int id;
  @override
  int get senderId => 1;
  @override
  final DateTime createdAt;
  @override
  String get body => '';
  @override
  int? get replyToMessageId => null;
}

void main() {
  test('MessageRegistry.remove drops optimistic ids', () {
    final registry = MessageRegistry<_Msg>();
    registry.upsertNewer([_Msg(1), _Msg(-1), _Msg(2)]);
    expect(registry.length, 3);
    expect(registry.remove(-1), isTrue);
    expect(registry.contains(-1), isFalse);
    expect(registry.orderedIds, [1, 2]);
    expect(registry.remove(-1), isFalse);
  });
}
