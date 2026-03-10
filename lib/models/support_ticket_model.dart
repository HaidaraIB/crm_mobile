/// Attachment for a support ticket (screenshot/image).
class SupportTicketAttachment {
  final int id;
  final String? file;
  final String? url;
  final String? createdAt;

  SupportTicketAttachment({
    required this.id,
    this.file,
    this.url,
    this.createdAt,
  });

  factory SupportTicketAttachment.fromJson(Map<String, dynamic> json) {
    return SupportTicketAttachment(
      id: json['id'] as int,
      file: json['file'] as String?,
      url: json['url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file': file,
      'url': url,
      'created_at': createdAt,
    };
  }
}

/// Support ticket (user's ticket to support).
class SupportTicket {
  final int id;
  final String title;
  final String description;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final List<SupportTicketAttachment> attachments;

  SupportTicket({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.attachments = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    List<SupportTicketAttachment> attachmentsList = [];
    if (json['attachments'] is List) {
      attachmentsList = (json['attachments'] as List)
          .map((e) => SupportTicketAttachment.fromJson(
              e as Map<String, dynamic>))
          .toList();
    }
    return SupportTicket(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      attachments: attachmentsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'attachments': attachments.map((e) => e.toJson()).toList(),
    };
  }
}
