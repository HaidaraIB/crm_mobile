import 'package:flutter/foundation.dart';

/// Debug-only timeline logs correlated with backend `call_id` / `call_uuid`.
class SoftphoneTiming {
  SoftphoneTiming._();
  static final SoftphoneTiming instance = SoftphoneTiming._();

  String? _callId;

  void bindCall(String? callId) {
    _callId = callId?.trim().isNotEmpty == true ? callId!.trim() : null;
  }

  void log(String stage) {
    if (!kDebugMode) return;
    final id = _callId ?? '-';
    debugPrint('[softphone_timing] call_id=$id stage=$stage ts=${DateTime.now().toIso8601String()}');
  }

  void reset() {
    _callId = null;
  }
}
