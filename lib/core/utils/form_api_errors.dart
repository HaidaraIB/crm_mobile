import 'package:flutter/material.dart';

import '../api/api_envelope.dart';
import '../api/api_exceptions.dart';
import '../localization/app_localizations.dart';

/// Meta keys that are not form fields.
const Set<String> kApiFieldMetaKeys = {
  'non_field_errors',
  'detail',
  'error_key',
  'code',
  'message',
  'error',
  'success',
};

/// Map API field keys → lead form UI error keys.
const Map<String, String> kLeadApiFieldMap = {
  'phone_number': 'phone',
  'phone_numbers': 'phone',
  'communication_way': 'communicationWay',
  'assigned_to': 'assignedTo',
  'lead_company_name': 'leadCompanyName',
  'budget_max': 'budgetMax',
  'interested_developer': 'interestedDeveloper',
  'interested_project': 'interestedProject',
  'interested_unit': 'interestedUnit',
  'name': 'name',
  'type': 'type',
  'status': 'status',
  'priority': 'priority',
  'budget': 'budget',
  'profession': 'profession',
  'notes': 'notes',
};

bool isGenericValidationMessage(String? message) {
  if (message == null || message.isEmpty) return true;
  final lower = message.toLowerCase().trim();
  return lower == 'validation failed.' ||
      lower == 'validation failed' ||
      lower.contains('validation failed');
}

/// Normalize API detail values (string or list) to a single display string.
String normalizeErrorMessage(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    if (value.isEmpty) return '';
    return normalizeErrorMessage(value.first);
  }
  if (value is String) return value.trim();
  if (value is Map) {
    if (value['detail'] != null) return normalizeErrorMessage(value['detail']);
    if (value['message'] != null) {
      return normalizeErrorMessage(value['message']);
    }
    if (value.isNotEmpty) {
      return normalizeErrorMessage(value.values.first);
    }
    return '';
  }
  return value.toString().trim();
}

String? _firstNonFieldError(Map<String, dynamic>? fields) {
  if (fields == null) return null;
  final raw = fields['non_field_errors'];
  final msg = normalizeErrorMessage(raw);
  return msg.isEmpty ? null : msg;
}

/// Map raw API field bag onto UI keys using [fieldMap].
Map<String, String> mapApiFieldsToUiErrors(
  Map<String, dynamic>? fields,
  String Function(String key) translate, {
  Map<String, String> fieldMap = const {},
}) {
  if (fields == null || fields.isEmpty) return {};
  final out = <String, String>{};

  fields.forEach((apiKey, value) {
    if (kApiFieldMetaKeys.contains(apiKey)) return;
    final msg = normalizeErrorMessage(value);
    if (msg.isEmpty) return;

    final uiKey = fieldMap[apiKey] ?? apiKey;
    final localized = _localizeFieldMessage(msg, translate, fieldHint: apiKey);
    if (!out.containsKey(uiKey) || out[uiKey]!.isEmpty) {
      out[uiKey] = localized;
    }
  });

  return out;
}

String _localizeFieldMessage(
  String message,
  String Function(String key) translate, {
  String? fieldHint,
}) {
  final lower = message.toLowerCase();
  final hint = (fieldHint ?? '').toLowerCase();

  if (lower.contains('in your company') ||
      lower.contains('lead with this phone') ||
      lower.contains('already exists in your company')) {
    final t = translate('duplicate_lead_phone');
    if (t != 'duplicate_lead_phone') return t;
  }

  final isTaken = lower.contains('already exists') ||
      lower.contains('already exist') ||
      lower.contains('already taken') ||
      lower.contains('already registered');

  if (isTaken && (hint.contains('phone') || lower.contains('phone'))) {
    final t = translate('duplicate_lead_phone');
    if (t != 'duplicate_lead_phone') return t;
  }

  final byKey = translate(message);
  if (byKey != message) return byKey;
  return message;
}

String? _extractCode(dynamic error) {
  if (error is ApiFieldException) {
    return error.code;
  }
  if (error is ApiEnvelopeException) {
    final fromDetails = error.details?['error_key']?.toString();
    if (fromDetails != null && fromDetails.isNotEmpty) return fromDetails;
    return error.code;
  }
  return null;
}

Map<String, dynamic>? _extractFields(dynamic error) {
  if (error is ApiFieldException) {
    return error.fields;
  }
  if (error is ApiEnvelopeException) {
    return error.details;
  }
  return null;
}

String? _extractRawMessage(dynamic error) {
  if (error is ApiFieldException) return error.message;
  if (error is ApiEnvelopeException) return error.message;
  return error.toString().replaceFirst('Exception: ', '').trim();
}

/// Map create/update lead API errors onto inline form field keys (localized).
Map<String, String> mapLeadApiErrorToFieldErrors(
  BuildContext context,
  dynamic error, {
  String fallbackGeneralKey = 'failedToCreateLead',
}) {
  final loc = AppLocalizations.of(context);
  String t(String key) => loc?.translate(key) ?? key;

  final code = _extractCode(error);
  final fields = _extractFields(error);
  final rawMessage = _extractRawMessage(error);

  if (code == 'employee_weekly_day_off') {
    return {
      'assignedTo': t('employeeWeeklyDayOffAssignError'),
    };
  }

  if (code == 'duplicate_lead_phone') {
    return {
      'phone': t('duplicate_lead_phone'),
    };
  }

  final fieldErrors = mapApiFieldsToUiErrors(
    fields,
    t,
    fieldMap: kLeadApiFieldMap,
  );
  if (fieldErrors.isNotEmpty) {
    return fieldErrors;
  }

  final nonField = _firstNonFieldError(fields);
  if (nonField != null && !isGenericValidationMessage(nonField)) {
    return {'general': _localizeFieldMessage(nonField, t)};
  }

  if (rawMessage != null &&
      rawMessage.isNotEmpty &&
      !isGenericValidationMessage(rawMessage)) {
    final localized = t(rawMessage);
    if (localized != rawMessage) {
      return {'general': localized};
    }
    // Prefer translating known business codes embedded as message.
    if (code != null && code.isNotEmpty) {
      final byCode = t(code);
      if (byCode != code) return {'general': byCode};
    }
    return {'general': rawMessage};
  }

  if (code != null && code.isNotEmpty) {
    final byCode = t(code);
    if (byCode != code) return {'general': byCode};
  }

  return {
    'general': t(fallbackGeneralKey),
  };
}

/// Whether this error was mapped to form fields (skip snackbar when true).
bool hasFormFieldErrors(Map<String, String> errors) {
  return errors.keys.any((k) => k != 'general');
}
