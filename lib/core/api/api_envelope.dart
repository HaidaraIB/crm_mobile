import 'dart:convert';

/// يتوافق مع مظروف JSON الموحّد في الـ API:
/// نجاح من الـ renderer: `{ "success": true, "data": <payload> }`
/// نجاح من `success_response`: `{ "success": true, "data"?: ..., "message"?: ... }` (لا يُعاد لفّه)
/// خطأ: `{ "success": false, "error": { "code", "message", "details"? } }`
class ApiEnvelopeException implements Exception {
  ApiEnvelopeException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  factory ApiEnvelopeException.fromSuccessFalseBody(Map<String, dynamic> body) {
    final err = body['error'];
    if (err is Map) {
      final e = Map<String, dynamic>.from(err);
      Map<String, dynamic>? det;
      final d = e['details'];
      if (d is Map) {
        det = Map<String, dynamic>.from(d);
      }
      return ApiEnvelopeException(
        code: e['code']?.toString() ?? 'error',
        message: e['message']?.toString() ?? 'Error',
        details: det,
      );
    }
    return ApiEnvelopeException(
      code: 'error',
      message: err?.toString() ?? 'Error',
    );
  }

  @override
  String toString() => message;
}

class ApiEnvelope {
  ApiEnvelope._();

  /// يزيل المظروف عند النجاح؛ يرمي [ApiEnvelopeException] عند `success == false`.
  static dynamic unwrap(dynamic decoded) {
    if (decoded is! Map) {
      return decoded;
    }
    final m = Map<String, dynamic>.from(decoded);
    if (!m.containsKey('success')) {
      return m;
    }
    final s = m['success'];
    if (s == true) {
      if (m.containsKey('data')) {
        return m['data'];
      }
      final copy = Map<String, dynamic>.from(m);
      copy.remove('success');
      return copy;
    }
    if (s == false) {
      throw ApiEnvelopeException.fromSuccessFalseBody(m);
    }
    return m;
  }

  static dynamic decodeAndUnwrap(String body) {
    final t = body.trim();
    if (t.isEmpty) {
      return null;
    }
    return unwrap(jsonDecode(body));
  }

  /// لا تُفك أجسام 204/205 كـ JSON (جسم فارغ).
  static bool isNoContentStatus(int statusCode) =>
      statusCode == 204 || statusCode == 205;

  /// فك المظروف مع احترام 204 والجسم الفارغ على الاستجابات الناجحة.
  static dynamic decodeAndUnwrapForStatus(String body, int statusCode) {
    if (isNoContentStatus(statusCode)) {
      return null;
    }
    if (body.trim().isEmpty) {
      return null;
    }
    return decodeAndUnwrap(body);
  }

  static Map<String, dynamic> decodeAndUnwrapMapForStatus(
    String body,
    int statusCode,
  ) {
    if (isNoContentStatus(statusCode)) {
      return {};
    }
    final t = body.trim();
    if (t.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return {};
      }
      throw const FormatException('Empty API JSON payload');
    }
    return decodeAndUnwrapMap(body);
  }

  static Map<String, dynamic> decodeAndUnwrapMap(String body) {
    final u = decodeAndUnwrap(body);
    if (u == null) {
      throw const FormatException('Empty API JSON payload');
    }
    if (u is Map<String, dynamic>) {
      return u;
    }
    if (u is Map) {
      return Map<String, dynamic>.from(u);
    }
    throw FormatException('Expected JSON object, got ${u.runtimeType}');
  }

  static Map<String, dynamic>? tryDecodeMap(String body) {
    try {
      final t = body.trim();
      if (t.isEmpty) {
        return null;
      }
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) {
        return d;
      }
      if (d is Map) {
        return Map<String, dynamic>.from(d);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// رسالة خطأ للعرض من جسم الاستجابة (مظروف أو قديم).
  static String errorMessageFromRoot(Map<String, dynamic> root) {
    if (root['success'] == false && root['error'] is Map) {
      final e = root['error'] as Map;
      final m = e['message']?.toString();
      if (m != null && m.isNotEmpty) {
        return m;
      }
    }
    final detail = root['detail']?.toString();
    if (detail != null && detail.isNotEmpty) {
      return detail;
    }
    final msg = root['message']?.toString();
    if (msg != null && msg.isNotEmpty) {
      return msg;
    }
    final err = root['error'];
    if (err is String && err.isNotEmpty) {
      return err;
    }
    if (err is Map && err['message'] != null) {
      return err['message'].toString();
    }
    return 'Error';
  }

  static Map<String, dynamic> errorContextMap(Map<String, dynamic> root) {
    if (root['success'] == false && root['error'] is Map) {
      final e = Map<String, dynamic>.from(root['error'] as Map);
      final out = <String, dynamic>{
        if (e['code'] != null) 'code': e['code'],
        if (e['message'] != null) 'message': e['message'],
        'error': e['message'],
      };
      final d = e['details'];
      if (d is Map) {
        out.addAll(Map<String, dynamic>.from(d));
      }
      e.forEach((key, value) {
        if (key == 'message' || key == 'code' || key == 'details') {
          return;
        }
        out.putIfAbsent(key, () => value);
      });
      return out;
    }
    return Map<String, dynamic>.from(root);
  }

  static Map<String, dynamic> errorContextFromBody(String body) {
    final root = tryDecodeMap(body);
    if (root == null) {
      return {};
    }
    return errorContextMap(root);
  }

  /// قائمة من `data` بعد فك المظروف (قائمة مباشرة أو صفحة DRF).
  static List<Map<String, dynamic>> asMapList(dynamic payload) {
    if (payload is List) {
      return payload
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (payload is Map && payload['results'] is List) {
      return (payload['results'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  /// مقارنة مرنة مع أكواد الـ API (مثل `subscription_inactive` مقابل `SUBSCRIPTION_INACTIVE`).
  static bool codeEquals(dynamic code, String snakeCase) {
    final a = code?.toString().toLowerCase().replaceAll('-', '_');
    final b = snakeCase.toLowerCase().replaceAll('-', '_');
    return a == b;
  }
}
