import 'api_envelope.dart';

/// تمثيل موحّد لخطأ الـ API: `{ "success": false, "error": { "code", "message", "details"? } }`.
class ApiErrorPayload {
  const ApiErrorPayload({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  /// يعيد null إن لم يكن الجسم خطأ مظروفاً أو لا يمكن فكّه.
  static ApiErrorPayload? tryParseBody(String body) {
    final m = ApiEnvelope.tryDecodeMap(body);
    if (m == null || m['success'] != false) {
      return null;
    }
    final err = m['error'];
    if (err is! Map) {
      return null;
    }
    final e = Map<String, dynamic>.from(err);
    Map<String, dynamic>? det;
    final d = e['details'];
    if (d is Map) {
      det = Map<String, dynamic>.from(d);
    }
    return ApiErrorPayload(
      code: e['code']?.toString() ?? 'error',
      message: e['message']?.toString() ?? 'Error',
      details: det,
    );
  }
}
