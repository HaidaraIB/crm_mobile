import '../../chat_engine/models/chat_message.dart';
import '../../models/tenant_chat_models.dart';

class TenantEngineMessage implements ChatMessage {
  const TenantEngineMessage(this.raw);

  final TenantChatMessage raw;

  @override
  String get body => raw.body;

  @override
  DateTime get createdAt => DateTime.tryParse(raw.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  int get id => raw.id;

  @override
  int? get replyToMessageId => raw.replyTo?.id;

  @override
  int get senderId => raw.sender.id;
}

