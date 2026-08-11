/// One row of `GET /integrations/templates/` (Messaging Center).
class WhatsAppTemplateModel {
  final int id;
  final String name;
  final String channelType;
  final String content;
  final String? language;
  final String? metaStatus;
  final String? headerText;
  final String? footer;

  const WhatsAppTemplateModel({
    required this.id,
    required this.name,
    required this.channelType,
    required this.content,
    this.language,
    this.metaStatus,
    this.headerText,
    this.footer,
  });

  bool get isWhatsApp =>
      channelType.toLowerCase() == 'whatsapp' || channelType.toLowerCase() == 'wa';

  bool get isApproved => (metaStatus ?? '').toUpperCase() == 'APPROVED';

  factory WhatsAppTemplateModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppTemplateModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      channelType: json['channel_type'] as String? ?? '',
      content: json['content'] as String? ?? '',
      language: json['language'] as String?,
      metaStatus: json['meta_status'] as String?,
      headerText: json['header_text'] as String?,
      footer: json['footer'] as String?,
    );
  }
}
