import '../../models/lead_whatsapp_message_model.dart';
import '../../models/whatsapp_account_status_model.dart';
import '../../models/whatsapp_conversation_model.dart';
import '../../models/whatsapp_template_model.dart';
import '../../services/api_service.dart';

abstract class WhatsAppChatRepository {
  Future<List<WhatsAppConversationModel>> getConversations();
  Future<List<LeadWhatsAppMessageModel>> getMessages({int? clientId, String? phone});
  Future<void> sendMessage({required String to, required String message, int? clientId});
  Future<void> sendMedia({
    required String to,
    required String filePath,
    int? clientId,
    String? caption,
    bool isVoiceNote = false,
  });
  Future<void> sendLocation({
    required String to,
    required double latitude,
    required double longitude,
    int? clientId,
    String? name,
    String? address,
  });
  Future<void> sendTemplate({
    required String to,
    required int templateId,
    int? clientId,
    List<String>? bodyParameters,
  });
  Future<void> markConversationRead({int? clientId, String? phone});
  Future<int> getUnreadCount();
  Future<WhatsAppSessionWindow> getSessionWindow({int? clientId, String? phone});
  Future<void> deleteMessage(int messageId);
  Future<void> deleteConversation({int? clientId, String? phone});
  Future<Map<String, dynamic>?> getContactByPhone(String phone);
  Future<List<WhatsAppTemplateModel>> getApprovedTemplates();
  Future<String?> getConnectedPhoneNumberId();
  Future<WhatsAppAccountStatus?> getAccountStatus();
  String attachmentUrl(int messageId);
}

class ApiWhatsAppChatRepository implements WhatsAppChatRepository {
  ApiWhatsAppChatRepository([ApiService? api]) : _api = api ?? ApiService();

  final ApiService _api;

  @override
  Future<List<WhatsAppConversationModel>> getConversations() =>
      _api.getWhatsAppConversations();

  @override
  Future<List<LeadWhatsAppMessageModel>> getMessages({int? clientId, String? phone}) {
    if (clientId != null) {
      return _api.getWhatsAppMessages(clientId);
    }
    return _api.getWhatsAppMessagesByParams(phone: phone);
  }

  @override
  Future<void> sendMessage({required String to, required String message, int? clientId}) =>
      _api.sendWhatsAppMessage(to: to, message: message, clientId: clientId);

  @override
  Future<void> sendMedia({
    required String to,
    required String filePath,
    int? clientId,
    String? caption,
    bool isVoiceNote = false,
  }) =>
      _api.sendWhatsAppMedia(
        to: to,
        filePath: filePath,
        clientId: clientId,
        caption: caption,
        isVoiceNote: isVoiceNote,
      );

  @override
  Future<void> sendLocation({
    required String to,
    required double latitude,
    required double longitude,
    int? clientId,
    String? name,
    String? address,
  }) =>
      _api.sendWhatsAppLocation(
        to: to,
        latitude: latitude,
        longitude: longitude,
        clientId: clientId,
        name: name,
        address: address,
      );

  @override
  Future<void> sendTemplate({
    required String to,
    required int templateId,
    int? clientId,
    List<String>? bodyParameters,
  }) =>
      _api.sendWhatsAppTemplate(
        to: to,
        templateId: templateId,
        clientId: clientId,
        bodyParameters: bodyParameters,
      );

  @override
  Future<void> markConversationRead({int? clientId, String? phone}) =>
      _api.markWhatsAppConversationRead(clientId: clientId, phone: phone);

  @override
  Future<int> getUnreadCount() => _api.getWhatsAppUnreadCount();

  @override
  Future<WhatsAppSessionWindow> getSessionWindow({int? clientId, String? phone}) =>
      _api.getWhatsAppSessionWindowByParams(clientId: clientId, phone: phone);

  @override
  Future<void> deleteMessage(int messageId) => _api.deleteWhatsAppMessage(messageId);

  @override
  Future<void> deleteConversation({int? clientId, String? phone}) =>
      _api.deleteWhatsAppConversation(clientId: clientId, phone: phone);

  @override
  Future<Map<String, dynamic>?> getContactByPhone(String phone) =>
      _api.getWhatsAppContactByPhone(phone);

  @override
  Future<List<WhatsAppTemplateModel>> getApprovedTemplates() =>
      _api.getWhatsAppApprovedTemplates();

  @override
  Future<String?> getConnectedPhoneNumberId() =>
      _api.getConnectedWhatsAppPhoneNumberId();

  @override
  Future<WhatsAppAccountStatus?> getAccountStatus() =>
      _api.getWhatsAppAccountStatus();

  @override
  String attachmentUrl(int messageId) => _api.whatsappMessageAttachmentUrl(messageId);
}
