import 'package:flutter/material.dart';

import '../api/api_envelope.dart';
import '../api/api_exceptions.dart';
import '../localization/app_localizations.dart';
import 'form_api_errors.dart';

class ApiErrorHelper {
  static const String noInternetCode = 'NO_INTERNET';
  static const String connectionTimeoutCode = 'CONNECTION_TIMEOUT';

  static String cleanException(dynamic error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  static bool isNoInternetError(dynamic error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('host lookup') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('clientexception');
  }

  static bool isTimeoutError(dynamic error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('timeout') || lower.contains('timed out');
  }

  /// Returns:
  /// - NO_INTERNET for offline/network issues
  /// - CONNECTION_TIMEOUT for timeout issues
  /// - otherwise cleaned API/backend message
  static String toDisplayCodeOrMessage(dynamic error) {
    if (isNoInternetError(error)) return noInternetCode;
    if (isTimeoutError(error)) return connectionTimeoutCode;
    return cleanException(error);
  }

  static String? _firstFieldDetailMessage(Map<String, dynamic>? fields) {
    if (fields == null || fields.isEmpty) return null;
    for (final entry in fields.entries) {
      if (kApiFieldMetaKeys.contains(entry.key)) continue;
      final msg = normalizeErrorMessage(entry.value);
      if (msg.isNotEmpty) return msg;
    }
    final nonField = normalizeErrorMessage(fields['non_field_errors']);
    if (nonField.isNotEmpty) return nonField;
    return null;
  }

  /// Best for snackbars/toasts (and banners when field mapping is unavailable).
  static String toUserMessage(
    BuildContext context,
    dynamic error, {
    String? fallback,
  }) {
    final loc = AppLocalizations.of(context);
    String t(String key) => loc?.translate(key) ?? key;

    if (isNoInternetError(error)) {
      final title = loc?.translate('noInternetConnection') ?? 'No Internet Connection';
      final body = loc?.translate('noInternetMessage') ??
          'Please check your internet connection and try again';
      return '$title. $body';
    }
    if (isTimeoutError(error)) {
      return loc?.translate('connectionErrorMessage') ??
          'Unable to connect to the server. Please try again later';
    }

    String? code;
    Map<String, dynamic>? fields;
    late final String rawMessage;

    if (error is ApiFieldException) {
      code = error.code;
      fields = error.fields;
      rawMessage = error.message;
    } else if (error is ApiEnvelopeException) {
      code = error.details?['error_key']?.toString() ?? error.code;
      fields = error.details;
      rawMessage = error.message;
    } else {
      rawMessage = cleanException(error);
    }

    if (code != null && code.isNotEmpty && loc != null) {
      final byCode = loc.translate(code);
      if (byCode != code) return byCode;
    }

    final fieldDetail = _firstFieldDetailMessage(fields);
    if (fieldDetail != null && fieldDetail.isNotEmpty) {
      if (loc != null) {
        final byKey = loc.translate(fieldDetail);
        if (byKey != fieldDetail) return byKey;
        // Prefer localized duplicate phone over English API string.
        final lower = fieldDetail.toLowerCase();
        if (lower.contains('in your company') ||
            lower.contains('lead with this phone')) {
          return t('duplicate_lead_phone');
        }
      }
      if (!isGenericValidationMessage(fieldDetail)) {
        return fieldDetail;
      }
    }

    if (rawMessage.isNotEmpty && loc != null) {
      final byKey = loc.translate(rawMessage);
      if (byKey != rawMessage) return byKey;
      if (rawMessage == 'You do not have permission to delete customers.' ||
          rawMessage == 'You do not have permission to delete customers') {
        return loc.translate('cannot_delete_clients');
      }
    }

    if (rawMessage.isNotEmpty && !isGenericValidationMessage(rawMessage)) {
      return rawMessage;
    }

    if (isGenericValidationMessage(rawMessage)) {
      return loc?.translate('pleaseFixErrors') ??
          'Please fix the following errors:';
    }

    if (rawMessage.isNotEmpty) return rawMessage;
    return fallback ??
        (loc?.translate('anErrorOccurred') ?? 'An error occurred. Please try again.');
  }
}
