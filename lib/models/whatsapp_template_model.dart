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

  /// Which CRM variable each Meta `{{n}}` stands for, in order — recorded when the
  /// template was submitted. Without it, filling `{{1}}` is a guess by position.
  final List<String> bodyVariables;

  const WhatsAppTemplateModel({
    required this.id,
    required this.name,
    required this.channelType,
    required this.content,
    this.language,
    this.metaStatus,
    this.headerText,
    this.footer,
    this.bodyVariables = const [],
  });

  /// Backend stores `whatsapp_api` (MessageTemplate.CHANNEL_WHATSAPP_API);
  /// accept the shorter spellings too, like the web Chats page does.
  bool get isWhatsApp {
    final ch = channelType.toLowerCase();
    return ch == 'whatsapp' || ch == 'whatsapp_api' || ch == 'wa';
  }

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
      bodyVariables: _bodyVariablesFrom(json['meta_variable_map']),
    );
  }

  static List<String> _bodyVariablesFrom(dynamic map) {
    if (map is! Map) return const [];
    final body = map['body'];
    if (body is! List) return const [];
    return body.map((e) => e.toString()).toList();
  }
}
