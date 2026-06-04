class MaintenanceStatus {
  const MaintenanceStatus({
    required this.maintenanceMode,
    required this.message,
  });

  final bool maintenanceMode;
  final String message;

  factory MaintenanceStatus.fromJson(Map<String, dynamic> json) {
    return MaintenanceStatus(
      maintenanceMode: json['maintenance_mode'] == true,
      message: (json['message'] as String? ?? '').trim(),
    );
  }
}
