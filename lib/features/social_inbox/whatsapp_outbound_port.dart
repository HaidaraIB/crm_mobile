/// Shared outbound contract for WhatsApp threads (CRM chats vs inbox).
abstract class WhatsAppOutboundPort {
  Future<void> sendText({required String text});

  Future<void> sendMedia({
    required String filePath,
    String? caption,
    bool isVoiceNote,
  });

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
    String? name,
    String? address,
  });

  Future<void> sendTemplate({
    required int templateId,
    List<String>? bodyParameters,
  });
}
