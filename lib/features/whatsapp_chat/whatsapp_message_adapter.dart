import '../../chat_engine/models/chat_message.dart';
import '../../models/lead_whatsapp_message_model.dart';

class WhatsAppEngineMessage implements ChatMessage {
  const WhatsAppEngineMessage(this.raw);

  final LeadWhatsAppMessageModel raw;

  @override
  String get body => raw.body;

  @override
  DateTime get createdAt => raw.createdAt;

  @override
  int get id => raw.id;

  @override
  int? get replyToMessageId => null;

  /// Inbound = 0; outbound = createdBy or -1.
  @override
  int get senderId {
    if (raw.isInbound) return 0;
    return raw.createdBy ?? -1;
  }
}
