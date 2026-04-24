class ClientVisitModel {
  final int id;
  final int client;
  final int? visitType;
  final String summary;
  final DateTime? visitDatetime;
  final DateTime? upcomingVisitDate;
  final int createdBy;
  final DateTime createdAt;

  ClientVisitModel({
    required this.id,
    required this.client,
    this.visitType,
    required this.summary,
    this.visitDatetime,
    this.upcomingVisitDate,
    required this.createdBy,
    required this.createdAt,
  });

  factory ClientVisitModel.fromJson(Map<String, dynamic> json) {
    return ClientVisitModel(
      id: json['id'] as int,
      client: json['client'] as int,
      visitType: json['visit_type'] != null
          ? (json['visit_type'] is int
              ? json['visit_type'] as int
              : (json['visit_type'] as Map<String, dynamic>)['id'] as int)
          : null,
      summary: json['summary'] as String? ?? '',
      visitDatetime: json['visit_datetime'] != null
          ? DateTime.parse(json['visit_datetime'] as String)
          : null,
      upcomingVisitDate: json['upcoming_visit_date'] != null
          ? DateTime.parse(json['upcoming_visit_date'] as String)
          : null,
      createdBy: json['created_by'] as int? ?? json['createdBy'] as int? ?? 0,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ??
            (json['createdAt'] as String?) ??
            '1970-01-01T00:00:00.000Z',
      ),
    );
  }
}
