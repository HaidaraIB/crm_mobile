import '../../chat_engine/models/chat_message.dart';
import '../../models/social_message_model.dart';

class SocialEngineMessage implements ChatMessage {
  const SocialEngineMessage(this.raw);

  final SocialMessageModel raw;

  @override
  String get body => raw.body;

  @override
  DateTime get createdAt => raw.timestamp;

  @override
  int get id => raw.id;

  @override
  int? get replyToMessageId => null;

  @override
  int get senderId => raw.isOutbound ? -1 : 0;
}

List<SocialEngineMessage> adaptSocialMessages(List<SocialMessageModel> messages) =>
    messages.map(SocialEngineMessage.new).toList(growable: false);
