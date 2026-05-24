class ClientFieldVisitModel {
  final int id;
  final int client;
  final String? clientName;
  final String summary;
  final DateTime? visitDatetime;
  final DateTime? upcomingVisitDate;
  final String? employeeLatitude;
  final String? employeeLongitude;
  final String? clientLocationPhotoUrl;
  final int? createdBy;
  final String? createdByUsername;
  final DateTime createdAt;

  ClientFieldVisitModel({
    required this.id,
    required this.client,
    this.clientName,
    required this.summary,
    this.visitDatetime,
    this.upcomingVisitDate,
    this.employeeLatitude,
    this.employeeLongitude,
    this.clientLocationPhotoUrl,
    this.createdBy,
    this.createdByUsername,
    required this.createdAt,
  });

  factory ClientFieldVisitModel.fromJson(Map<String, dynamic> json) {
    return ClientFieldVisitModel(
      id: json['id'] as int,
      client: json['client'] as int,
      clientName: json['client_name'] as String?,
      summary: json['summary'] as String? ?? '',
      visitDatetime: json['visit_datetime'] != null
          ? DateTime.parse(json['visit_datetime'] as String)
          : null,
      upcomingVisitDate: json['upcoming_visit_date'] != null
          ? DateTime.parse(json['upcoming_visit_date'] as String)
          : null,
      employeeLatitude: json['employee_latitude']?.toString(),
      employeeLongitude: json['employee_longitude']?.toString(),
      clientLocationPhotoUrl: json['client_location_photo_url'] as String?,
      createdBy: json['created_by'] as int?,
      createdByUsername: json['created_by_username'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ??
            (json['createdAt'] as String?) ??
            '1970-01-01T00:00:00.000Z',
      ),
    );
  }
}
