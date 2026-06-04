import '../models/maintenance_status.dart';
import 'api_service.dart';

enum MaintenanceGateOutcome {
  allowed,
  blocked,
}

class MaintenanceGateResult {
  const MaintenanceGateResult({
    required this.outcome,
    this.message = '',
  });

  const MaintenanceGateResult.allowed()
      : outcome = MaintenanceGateOutcome.allowed,
        message = '';

  const MaintenanceGateResult.blocked(String msg)
      : outcome = MaintenanceGateOutcome.blocked,
        message = msg;

  final MaintenanceGateOutcome outcome;
  final String message;
}

/// Startup gate: block app when platform maintenance mode is on.
class MaintenanceGate {
  MaintenanceGate._();

  static Future<MaintenanceGateResult> evaluate() async {
    MaintenanceStatus status;
    try {
      status = await ApiService().fetchMaintenanceStatus();
    } catch (_) {
      return const MaintenanceGateResult.allowed();
    }
    if (status.maintenanceMode) {
      return MaintenanceGateResult.blocked(status.message);
    }
    return const MaintenanceGateResult.allowed();
  }
}
