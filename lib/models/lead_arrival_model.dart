/// Front-desk "customer arrived" announcement (CALL_CENTER role).
class LeadArrivalModel {
  final int id;
  final int client;
  final String clientName;
  final String? clientPhone;
  final int? announcedBy;
  final String? announcedByName;
  final DateTime announcedAt;
  final String notes;
  final String routing;
  final bool leadCreated;
  final int? assigneeAtArrival;
  final List<String> notifiedUserNames;
  final DateTime? escalationDueAt;
  final DateTime? escalatedAt;
  final DateTime? acknowledgedAt;
  final int? acknowledgedBy;
  final String? acknowledgedByName;
  final String status; // 'waiting' | 'acknowledged' | 'escalated'

  const LeadArrivalModel({
    required this.id,
    required this.client,
    required this.clientName,
    this.clientPhone,
    this.announcedBy,
    this.announcedByName,
    required this.announcedAt,
    this.notes = '',
    required this.routing,
    this.leadCreated = false,
    this.assigneeAtArrival,
    this.notifiedUserNames = const [],
    this.escalationDueAt,
    this.escalatedAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.acknowledgedByName,
    required this.status,
  });

  bool get isAcknowledged => acknowledgedAt != null;
  bool get isEscalated => escalatedAt != null && acknowledgedAt == null;
  bool get isAssigneeOffShift => routing == 'owner_assignee_off_shift';

  factory LeadArrivalModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return LeadArrivalModel(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      client: json['client'] is int
          ? json['client'] as int
          : int.parse(json['client'].toString()),
      clientName: json['client_name']?.toString() ?? '',
      clientPhone: json['client_phone']?.toString(),
      announcedBy: json['announced_by'] == null
          ? null
          : int.tryParse(json['announced_by'].toString()),
      announcedByName: json['announced_by_name']?.toString(),
      announcedAt: parseDate(json['announced_at']) ?? DateTime.now(),
      notes: json['notes']?.toString() ?? '',
      routing: json['routing']?.toString() ?? '',
      leadCreated: json['lead_created'] == true,
      assigneeAtArrival: json['assignee_at_arrival'] == null
          ? null
          : int.tryParse(json['assignee_at_arrival'].toString()),
      notifiedUserNames: (json['notified_user_names'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      escalationDueAt: parseDate(json['escalation_due_at']),
      escalatedAt: parseDate(json['escalated_at']),
      acknowledgedAt: parseDate(json['acknowledged_at']),
      acknowledgedBy: json['acknowledged_by'] == null
          ? null
          : int.tryParse(json['acknowledged_by'].toString()),
      acknowledgedByName: json['acknowledged_by_name']?.toString(),
      status: json['status']?.toString() ?? 'waiting',
    );
  }
}
