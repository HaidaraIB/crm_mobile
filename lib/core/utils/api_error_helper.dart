import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

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

  /// Best for snackbars/toasts.
  static String toUserMessage(
    BuildContext context,
    dynamic error, {
    String? fallback,
  }) {
    final loc = AppLocalizations.of(context);
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
    final cleaned = cleanException(error);
    if (cleaned.isNotEmpty) return cleaned;
    return fallback ??
        (loc?.translate('anErrorOccurred') ?? 'An error occurred. Please try again.');
  }
}

