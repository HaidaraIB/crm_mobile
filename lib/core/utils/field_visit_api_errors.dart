/// Parses field-visit create API errors into localized message keys (not raw API text).
class FieldVisitCreateException implements Exception {
  FieldVisitCreateException({
    this.generalMessageKey,
    this.fieldMessageKeys = const {},
  });

  /// AppLocalizations key for the banner error (null if only field errors).
  final String? generalMessageKey;

  /// Form field id → AppLocalizations key (`summary`, `visitDatetime`, `clientLocationPhoto`).
  final Map<String, String> fieldMessageKeys;

  factory FieldVisitCreateException.fromApiError(Map<String, dynamic> err) {
    return parseFieldVisitCreateError(err);
  }

  @override
  String toString() =>
      generalMessageKey ?? fieldMessageKeys.values.join(', ');
}

FieldVisitCreateException parseFieldVisitCreateError(
  Map<String, dynamic> err,
) {
  final code = err['code']?.toString();
  if (code == 'field_visit_disabled') {
    return FieldVisitCreateException(
      generalMessageKey: 'fieldVisitDisabledByAdmin',
    );
  }

  final details = _mergedValidationDetails(err);
  final fieldKeys = <String, String>{};
  String? generalKey;

  final nonField = _asStringList(details['non_field_errors']);
  for (final item in nonField) {
    final lower = item.toLowerCase();
    if (lower.contains('field_visit_too_far')) {
      generalKey = 'fieldVisitTooFar';
    } else if (lower.contains('field_visit_disabled')) {
      generalKey = 'fieldVisitDisabledByAdmin';
    }
  }

  if (details.containsKey('distance_meters') ||
      details.containsKey('max_allowed_meters')) {
    generalKey ??= 'fieldVisitTooFar';
  }

  if (_hasFieldError(details, 'summary')) {
    fieldKeys['summary'] = 'visitSummaryRequired';
  }
  if (_hasFieldError(details, 'visit_datetime')) {
    fieldKeys['visitDatetime'] = 'visitDatetimeRequired';
  }
  if (_hasFieldError(details, 'employee_latitude') ||
      _hasFieldError(details, 'employee_longitude')) {
    generalKey ??= 'employeeLocationRequired';
  }

  if (_hasFieldError(details, 'client_location_photo')) {
    fieldKeys['clientLocationPhoto'] = _clientLocationPhotoErrorKey(
      _asStringList(details['client_location_photo']),
    );
  }

  if (generalKey == null && fieldKeys.isEmpty) {
    final rawMessage = (err['message'] ?? err['detail'] ?? err['error'])
        ?.toString()
        .trim();
    if (!_isGenericValidationMessage(rawMessage)) {
      // Unknown API message — use friendly fallback, never show raw English.
      generalKey = 'failedToAddFieldVisit';
    } else {
      generalKey = 'fieldVisitCheckForm';
    }
  }

  return FieldVisitCreateException(
    generalMessageKey: generalKey,
    fieldMessageKeys: fieldKeys,
  );
}

Map<String, dynamic> _mergedValidationDetails(Map<String, dynamic> err) {
  final out = <String, dynamic>{};
  final nested = err['details'];
  if (nested is Map) {
    out.addAll(Map<String, dynamic>.from(nested));
  }
  const keys = [
    'summary',
    'visit_datetime',
    'employee_latitude',
    'employee_longitude',
    'client_location_photo',
    'non_field_errors',
    'distance_meters',
    'max_allowed_meters',
    'client',
  ];
  for (final key in keys) {
    if (err.containsKey(key)) {
      out[key] = err[key];
    }
  }
  return out;
}

bool _hasFieldError(Map<String, dynamic> details, String field) {
  final v = details[field];
  if (v == null) return false;
  if (v is List) return v.isNotEmpty;
  return v.toString().trim().isNotEmpty;
}

List<String> _asStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return [value.toString()];
}

bool _isGenericValidationMessage(String? message) {
  if (message == null || message.isEmpty) return true;
  final lower = message.toLowerCase();
  return lower == 'validation failed.' ||
      lower == 'validation failed' ||
      lower.contains('validation failed');
}

String _clientLocationPhotoErrorKey(List<String> messages) {
  final joined = messages.join(' ').toLowerCase();
  if (joined.contains('5 mb') ||
      joined.contains('exceed') ||
      joined.contains('too large') ||
      joined.contains('limit')) {
    return 'clientLocationPhotoTooLarge';
  }
  return 'clientLocationPhotoInvalidType';
}
