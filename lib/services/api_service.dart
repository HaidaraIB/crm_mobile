import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/localization/app_localizations.dart';
import '../models/lead_model.dart';
import '../models/user_model.dart';
import '../models/settings_model.dart';
import '../models/client_task_model.dart';
import '../models/client_call_model.dart';
import '../models/task_model.dart';
import '../models/inventory_model.dart';
import '../models/deal_model.dart';
import 'error_logger.dart';

/// استثناء عند كون الاشتراك غير مفعّل؛ يحمل [subscriptionId] إن أرسله الـ API
class SubscriptionInactiveException implements Exception {
  SubscriptionInactiveException(this.message, {this.subscriptionId});
  final String message;
  final int? subscriptionId;
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get baseUrl => AppConstants.baseUrl;

  // Helper function to translate error messages
  // If locale is provided, it will use localization, otherwise returns English message
  String _translateError(String key, {Locale? locale}) {
    if (locale == null) {
      // Return English default if no locale provided
      return _getEnglishError(key);
    }

    final localizations = AppLocalizations(locale);
    final translated = localizations.translate(key);

    // If translation not found, return English
    if (translated == key) {
      return _getEnglishError(key);
    }

    return translated;
  }

  // Get English error message as fallback
  String _getEnglishError(String key) {
    final englishLocalizations = AppLocalizations(const Locale('en'));
    return englishLocalizations.translate(key);
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.accessTokenKey);
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.refreshTokenKey);
  }

  /// Returns true if an access token is stored (user can be considered "logged in" for API calls).
  Future<bool> hasStoredAccessToken() async {
    final token = await _getAccessToken();
    return token != null && token.toString().trim().isNotEmpty;
  }

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Add API Key to all requests for application authentication
    final apiKey = AppConstants.apiKey;
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }

    if (includeAuth) {
      final token = await _getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool retryOn401 = true,
    Duration? timeout,
  }) async {
    // Ensure endpoint starts with / and baseUrl doesn't end with /
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');
    final headers = await _getHeaders();

    // Default timeout of 5 seconds
    final requestTimeout = timeout ?? const Duration(seconds: 5);

    http.Response response;

    try {
      Future<http.Response> requestFuture;

      switch (method.toUpperCase()) {
        case 'GET':
          requestFuture = http.get(url, headers: headers);
          break;
        case 'POST':
          requestFuture = http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          requestFuture = http.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PATCH':
          requestFuture = http.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          requestFuture = http.delete(url, headers: headers);
          break;
        default:
          throw Exception(
            _translateError('unsupportedHttpMethod', locale: null),
          );
      }

      // Apply timeout to the request
      response = await requestFuture.timeout(
        requestTimeout,
        onTimeout: () {
          throw TimeoutException(
            '${_translateError('requestTimedOut', locale: null)} after ${requestTimeout.inSeconds} seconds',
          );
        },
      );
    } on TimeoutException catch (e, stackTrace) {
      // Log timeout errors
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: endpoint,
        method: method,
        requestData: body,
      );
      rethrow;
    } catch (e, stackTrace) {
      // Log connection errors
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: endpoint,
        method: method,
        requestData: body,
      );
      rethrow;
    }

    // Log non-2xx responses
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? responseBody;
      try {
        responseBody = response.body;
      } catch (_) {}

      ErrorLogger().logError(
        error: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        endpoint: endpoint,
        method: method,
        requestData: body,
        statusCode: response.statusCode,
        responseBody: responseBody,
      );
    }

    // Handle 401 Unauthorized - try to refresh token
    if (response.statusCode == 401 && retryOn401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry the request with new token
        return _makeRequest(method, endpoint, body: body, retryOn401: false);
      } else {
        // Refresh failed, clear tokens and logout
        await _clearTokens();
        throw Exception(
          _translateError('sessionExpired', locale: null),
        ); // Use English for system errors
      }
    }

    return response;
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null) return false;

      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final url = Uri.parse('$cleanBaseUrl/auth/refresh/');
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (AppConstants.apiKey.isNotEmpty) {
        headers['X-API-Key'] = AppConstants.apiKey;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access'] as String?;

        if (newAccessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.accessTokenKey, newAccessToken);
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.currentUserKey);
    await prefs.remove(AppConstants.isLoggedInKey);
  }

  // ==================== Registration APIs ====================

  /// تسجيل شركة جديدة مع المالك
  /// POST /api/auth/register/
  Future<Map<String, dynamic>> registerCompany({
    required Map<String, dynamic> company,
    required Map<String, dynamic> owner,
    int? planId,
    String billingCycle = 'monthly',
    String language = 'en',
  }) async {
    final cleanEndpoint = '/auth/register/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');

    final locale = language == 'ar' ? const Locale('ar') : const Locale('en');

    try {
      final requestBody = <String, dynamic>{'company': company, 'owner': owner};

      if (planId != null) {
        requestBody['plan_id'] = planId;
      }
      requestBody['billing_cycle'] = billingCycle;

      final headers = await _getHeaders(includeAuth: false);
      headers['Accept-Language'] = language;

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Save tokens if available
        if (data['access'] != null && data['refresh'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            AppConstants.accessTokenKey,
            data['access'] as String,
          );
          await prefs.setString(
            AppConstants.refreshTokenKey,
            data['refresh'] as String,
          );
        }

        return data;
      } else {
        String errorMessage = _translateError(
          'registrationFailed',
          locale: locale,
        );
        Map<String, dynamic>? fieldErrors;

        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage =
              error['detail'] ??
              error['error'] ??
              error['message'] ??
              errorMessage;
          fieldErrors = error;
        } catch (_) {
          errorMessage =
              '${_translateError('registrationFailedWithStatus', locale: locale)} ${response.statusCode}';
        }

        final exception = Exception(errorMessage);
        (exception as dynamic).fields = fieldErrors;

        ErrorLogger().logError(
          error: errorMessage,
          endpoint: cleanEndpoint,
          method: 'POST',
          statusCode: response.statusCode,
          responseBody: response.body,
        );

        throw exception;
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        rethrow;
      }

      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: cleanEndpoint,
        method: 'POST',
      );

      rethrow;
    }
  }

  /// التحقق من توفر البيانات أثناء التسجيل
  /// POST /api/auth/check-availability/
  Future<bool> checkRegistrationAvailability({
    String? companyDomain,
    String? email,
    String? username,
    String? phone,
  }) async {
    final cleanEndpoint = '/auth/check-availability/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');

    try {
      final requestBody = <String, dynamic>{};
      if (companyDomain != null && companyDomain.isNotEmpty) {
        requestBody['company_domain'] = companyDomain.trim();
      }
      if (email != null && email.isNotEmpty) {
        requestBody['email'] = email.trim();
      }
      if (username != null && username.isNotEmpty) {
        requestBody['username'] = username.trim();
      }
      if (phone != null && phone.isNotEmpty) {
        requestBody['phone'] = phone.trim();
      }

      final headers = await _getHeaders(includeAuth: false);

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        String errorMessage = 'Availability check failed';
        Map<String, dynamic>? fieldErrors;

        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage =
              error['detail'] ??
              error['error'] ??
              error['message'] ??
              errorMessage;
          fieldErrors = error['errors'] ?? error;
        } catch (_) {
          errorMessage =
              'Availability check failed with status ${response.statusCode}';
        }

        final exception = Exception(errorMessage);
        (exception as dynamic).fields = fieldErrors;

        throw exception;
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        rethrow;
      }

      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: cleanEndpoint,
        method: 'POST',
      );

      rethrow;
    }
  }

  /// الحصول على الخطط المتاحة علنياً
  /// GET /api/public/plans/
  Future<List<Map<String, dynamic>>> getPublicPlans() async {
    final cleanEndpoint = '/public/plans/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');

    try {
      final headers = await _getHeaders(includeAuth: false);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['results'] != null) {
          return (data['results'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      } else {
        throw Exception(
          'Failed to load plans with status ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: cleanEndpoint,
        method: 'GET',
      );
      rethrow;
    }
  }

  /// الحصول على بوابات الدفع المتاحة علنياً
  /// GET /api/public/payment-gateways/
  Future<List<Map<String, dynamic>>> getPublicPaymentGateways() async {
    final cleanEndpoint = '/public/payment-gateways/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');
    final headers = await _getHeaders(includeAuth: false);
    final response = await http.get(url, headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load payment gateways: ${response.statusCode}',
      );
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    if (data is Map && data['results'] != null) {
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// إنشاء جلسة دفع حسب البوابة المختارة (مثل CRM-project)
  /// يوجّه إلى create-paytabs / create-zaincash / create-stripe / create-qicard حسب اسم البوابة
  Future<Map<String, dynamic>> createPaymentSessionByGateway({
    required int subscriptionId,
    required int gatewayId,
    int? planId,
    String? billingCycle,
  }) async {
    final gateways = await getPublicPaymentGateways();
    final gateway = gateways.where((g) {
      final id = g['id'];
      if (id == null) return false;
      if (id is int) return id == gatewayId;
      return id.toString() == gatewayId.toString();
    }).toList();
    if (gateway.isEmpty) {
      throw Exception('Payment gateway not found');
    }
    final g = gateway.first;
    final name = (g['name'] as String? ?? '').toLowerCase();
    if (name.contains('paytabs')) {
      return createPaytabsPaymentSession(
        subscriptionId: subscriptionId,
        planId: planId,
        billingCycle: billingCycle,
      );
    }
    if (name.contains('zaincash') || name.contains('zain cash')) {
      return createZaincashPaymentSession(
        subscriptionId: subscriptionId,
        planId: planId,
        billingCycle: billingCycle,
      );
    }
    if (name.contains('stripe')) {
      return createStripePaymentSession(
        subscriptionId: subscriptionId,
        planId: planId,
        billingCycle: billingCycle,
      );
    }
    if (name.contains('qicard') ||
        name.contains('qi card') ||
        name.contains('qi-card')) {
      return createQicardPaymentSession(
        subscriptionId: subscriptionId,
        planId: planId,
        billingCycle: billingCycle,
      );
    }
    throw Exception('Payment gateway "${g['name']}" is not supported');
  }

  Future<Map<String, dynamic>> _createPaymentSession({
    required String endpoint,
    required int subscriptionId,
    int? planId,
    String? billingCycle,
  }) async {
    final body = <String, dynamic>{'subscription_id': subscriptionId};
    if (planId != null) body['plan_id'] = planId;
    if (billingCycle != null && billingCycle.isNotEmpty) {
      body['billing_cycle'] = billingCycle;
    }
    final response = await _makeRequest(
      'POST',
      endpoint,
      body: body,
      timeout: const Duration(seconds: 30),
    );
    if (response.statusCode != 200) {
      String msg = 'Failed to create payment session';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        msg = (err['detail'] ?? err['error'] ?? err['message'] ?? msg)
            .toString();
      } catch (_) {}
      ErrorLogger().logError(
        error: msg,
        endpoint: endpoint,
        method: 'POST',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw Exception(msg);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createZaincashPaymentSession({
    required int subscriptionId,
    int? planId,
    String? billingCycle,
  }) async => _createPaymentSession(
    endpoint: '/payments/create-zaincash-session/',
    subscriptionId: subscriptionId,
    planId: planId,
    billingCycle: billingCycle,
  );

  Future<Map<String, dynamic>> createStripePaymentSession({
    required int subscriptionId,
    int? planId,
    String? billingCycle,
  }) async => _createPaymentSession(
    endpoint: '/payments/create-stripe-session/',
    subscriptionId: subscriptionId,
    planId: planId,
    billingCycle: billingCycle,
  );

  Future<Map<String, dynamic>> createQicardPaymentSession({
    required int subscriptionId,
    int? planId,
    String? billingCycle,
  }) async => _createPaymentSession(
    endpoint: '/payments/create-qicard-session/',
    subscriptionId: subscriptionId,
    planId: planId,
    billingCycle: billingCycle,
  );

  /// التحقق من البريد الإلكتروني
  /// POST /api/auth/verify-email/
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    String? code,
    String? token,
  }) async {
    final cleanEndpoint = '/auth/verify-email/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');

    try {
      final requestBody = <String, dynamic>{'email': email.trim()};

      if (code != null && code.isNotEmpty) {
        requestBody['code'] = code.trim();
      }
      if (token != null && token.isNotEmpty) {
        requestBody['token'] = token.trim();
      }

      final headers = await _getHeaders(includeAuth: false);

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        String errorMessage = 'Email verification failed';
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage =
              error['detail'] ??
              error['error'] ??
              error['message'] ??
              errorMessage;
        } catch (_) {
          errorMessage =
              'Email verification failed with status ${response.statusCode}';
        }

        ErrorLogger().logError(
          error: errorMessage,
          endpoint: cleanEndpoint,
          method: 'POST',
          statusCode: response.statusCode,
          responseBody: response.body,
        );

        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        rethrow;
      }

      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: cleanEndpoint,
        method: 'POST',
      );

      rethrow;
    }
  }

  /// إنشاء جلسة دفع PayTabs للاشتراك
  /// POST /api/payments/create-paytabs-session/
  /// Returns: { payment_id, redirect_url, tran_ref }
  Future<Map<String, dynamic>> createPaytabsPaymentSession({
    required int subscriptionId,
    int? planId,
    String? billingCycle,
  }) async {
    final body = <String, dynamic>{'subscription_id': subscriptionId};
    if (planId != null) body['plan_id'] = planId;
    if (billingCycle != null && billingCycle.isNotEmpty) {
      body['billing_cycle'] = billingCycle;
    }
    final response = await _makeRequest(
      'POST',
      '/payments/create-paytabs-session/',
      body: body,
      timeout: const Duration(seconds: 30),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    String errorMessage = 'Failed to create payment session';
    try {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      errorMessage =
          (error['detail'] ??
                  error['error'] ??
                  error['message'] ??
                  errorMessage)
              .toString();
    } catch (_) {}
    ErrorLogger().logError(
      error: errorMessage,
      endpoint: '/payments/create-paytabs-session/',
      method: 'POST',
      statusCode: response.statusCode,
      responseBody: response.body,
    );
    throw Exception(errorMessage);
  }

  // Authentication
  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    Locale? locale,
  }) async {
    try {
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final url = Uri.parse('$cleanBaseUrl/auth/login/');
      final requestBody = {'username': username, 'password': password};

      final headers = <String, String>{'Content-Type': 'application/json'};

      // Add API Key
      final apiKey = AppConstants.apiKey;
      if (apiKey.isNotEmpty) {
        headers['X-API-Key'] = apiKey;
        debugPrint('✓ API Key added to login request');
      } else {
        debugPrint('⚠ WARNING: API Key is empty! Check .env file');
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Save tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          AppConstants.accessTokenKey,
          data['access'] as String,
        );
        await prefs.setString(
          AppConstants.refreshTokenKey,
          data['refresh'] as String,
        );

        // Get user data
        final userResponse = await getCurrentUser();
        return {'success': true, 'user': userResponse};
      } else {
        String errorMessage;
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          // Check for API key errors first
          if (error.containsKey('error') &&
              error['error'] == 'Missing API key') {
            errorMessage = _translateError(
              'missingApiKey',
              locale: locale ?? const Locale('en'),
            );
          } else {
            final backendError =
                error['detail'] ?? error['error'] ?? error['message'] ?? '';
            errorMessage = backendError.isNotEmpty
                ? backendError
                : _translateError(
                    'loginFailed',
                    locale: locale ?? const Locale('en'),
                  );
          }
          debugPrint('Login error: $errorMessage');
          debugPrint('Response body: ${response.body}');
        } catch (e) {
          errorMessage =
              '${_translateError('loginFailedWithStatus', locale: locale ?? const Locale('en'))} ${response.statusCode}';
          debugPrint('Failed to parse error response: $e');
        }

        ErrorLogger().logError(
          error: errorMessage,
          endpoint: '/auth/login/',
          method: 'POST',
          requestData: {'username': username}, // Don't log password
          statusCode: response.statusCode,
          responseBody: response.body,
        );

        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        rethrow;
      }

      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/auth/login/',
        method: 'POST',
        requestData: {'username': username},
      );

      rethrow;
    }
  }

  // Request 2FA code (with password validation)
  Future<Map<String, dynamic>> requestTwoFactorAuth(
    String username,
    String password,
    String language,
  ) async {
    final cleanEndpoint = '/auth/request-2fa/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');

    // Convert language string to Locale
    final locale = language == 'ar' ? const Locale('ar') : const Locale('en');

    try {
      // Get headers with API Key (no auth token needed for 2FA request)
      final headers = await _getHeaders(includeAuth: false);
      headers['Accept-Language'] = language;

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'username': username,
          'password': password, // Include password to validate credentials
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        String errorMessage = _translateError(
          'failedToRequest2FACode',
          locale: locale,
        );
        Exception? customException;

        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;

          // Extract the actual error message from the backend
          String backendErrorMessage =
              error['error'] ?? error['detail'] ?? error['message'] ?? '';

          // Handle field-specific errors (like username errors)
          if (error['username'] != null) {
            if (error['username'] is List &&
                (error['username'] as List).isNotEmpty) {
              backendErrorMessage = (error['username'] as List).first
                  .toString();
            } else if (error['username'] is String) {
              backendErrorMessage = error['username'] as String;
            }
          }

          // If we still don't have a message, use default
          if (backendErrorMessage.isEmpty) {
            backendErrorMessage =
                '${_translateError('failedToRequest2FACodeWithStatus', locale: locale)} ${response.statusCode}';
          }

          // Handle special error codes FIRST - before setting generic error message
          // IMPORTANT: Check subscription status FIRST - if inactive, prevent 2FA code from being sent
          if (error['code'] == 'SUBSCRIPTION_INACTIVE' ||
              (error['error']?.toString().toLowerCase().contains(
                    'subscription',
                  ) ??
                  false) ||
              backendErrorMessage.toLowerCase().contains('subscription')) {
            final subIdRaw =
                error['subscriptionId'] ?? error['subscription_id'];
            int? subId;
            if (subIdRaw != null) {
              if (subIdRaw is int) {
                subId = subIdRaw;
              } else if (subIdRaw is num) {
                subId = subIdRaw.toInt();
              } else if (subIdRaw is String) {
                subId = int.tryParse(subIdRaw);
              }
            }
            customException = SubscriptionInactiveException(
              backendErrorMessage,
              subscriptionId: subId,
            );
          } else if (error['code'] == 'ACCOUNT_TEMPORARILY_INACTIVE') {
            // Use the actual backend error message
            customException = Exception(backendErrorMessage);
            (customException as dynamic).code = 'ACCOUNT_TEMPORARILY_INACTIVE';
          } else if (backendErrorMessage.toLowerCase().contains(
                'invalid credentials',
              ) ||
              backendErrorMessage.toLowerCase().contains('invalid username') ||
              backendErrorMessage.toLowerCase().contains('invalid password') ||
              backendErrorMessage.toLowerCase().contains('user not found') ||
              backendErrorMessage.toLowerCase().contains('unable to log in') ||
              backendErrorMessage.toLowerCase().contains('no active account')) {
            // Use the actual backend error message for invalid credentials
            customException = Exception(backendErrorMessage);
          } else {
            // Use the backend error message for other errors
            errorMessage = backendErrorMessage;
          }
        } catch (e) {
          // If parsing failed, use generic message
          errorMessage =
              '${_translateError('failedToRequest2FACodeWithStatus', locale: locale)} ${response.statusCode}';
        }

        // Log the error
        ErrorLogger().logError(
          error:
              customException?.toString().replaceAll('Exception: ', '') ??
              errorMessage,
          endpoint: cleanEndpoint,
          method: 'POST',
          requestData: {'username': username},
          statusCode: response.statusCode,
          responseBody: response.body,
        );

        // Throw the custom exception if we have one, otherwise throw generic
        if (customException != null) {
          throw customException;
        } else {
          throw Exception(errorMessage);
        }
      }
    } catch (e, stackTrace) {
      // Rethrow subscription inactive (has subscriptionId) and other custom errors without logging
      if (e is SubscriptionInactiveException) {
        rethrow;
      }
      bool isCustomError = false;
      try {
        if (e is Exception) {
          final dynamic error = e;
          try {
            final code = error.code;
            if (code != null) isCustomError = true;
          } catch (_) {}
        }
      } catch (_) {}
      if (isCustomError) {
        rethrow;
      }

      // Only log and rethrow if it's not a custom error
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: cleanEndpoint,
        method: 'POST',
        requestData: {'username': username},
      );

      rethrow;
    }
  }

  // Verify 2FA code
  Future<Map<String, dynamic>> verifyTwoFactorAuth({
    required String username,
    required String password,
    required String code,
    String? token,
    Locale? locale,
  }) async {
    final cleanEndpoint = '/auth/verify-2fa/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');

    try {
      final requestBody = <String, dynamic>{
        'username': username,
        'password': password,
        'code': code,
      };
      if (token != null) {
        requestBody['token'] = token;
      }

      // Get headers with API Key (no auth token needed for 2FA verification)
      final headers = await _getHeaders(includeAuth: false);

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Save tokens
        if (data['access'] != null && data['refresh'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            AppConstants.accessTokenKey,
            data['access'] as String,
          );
          await prefs.setString(
            AppConstants.refreshTokenKey,
            data['refresh'] as String,
          );
        }

        return data;
      } else {
        String errorMessage = _translateError(
          'failedToVerify2FACode',
          locale: locale ?? const Locale('en'),
        );
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage =
              error['detail'] ??
              error['error'] ??
              error['message'] ??
              errorMessage;

          // Handle special error codes
          if (error['code'] == 'ACCOUNT_TEMPORARILY_INACTIVE') {
            final accountError = Exception('ACCOUNT_TEMPORARILY_INACTIVE');
            (accountError as dynamic).code = 'ACCOUNT_TEMPORARILY_INACTIVE';
            throw accountError;
          }

          if (error['code'] == 'SUBSCRIPTION_INACTIVE' ||
              (error['error']?.toString().toLowerCase().contains(
                    'subscription',
                  ) ??
                  false)) {
            final subscriptionError = Exception('SUBSCRIPTION_INACTIVE');
            (subscriptionError as dynamic).code = 'SUBSCRIPTION_INACTIVE';
            (subscriptionError as dynamic).subscriptionId =
                error['subscriptionId'];
            throw subscriptionError;
          }
        } catch (e) {
          // Check if this is a custom error with code property
          try {
            if (e is Exception) {
              final dynamic error = e;
              if (error.code != null) {
                rethrow;
              }
            }
          } catch (_) {
            // Not a custom error, continue with default error message
          }
          errorMessage =
              '${_translateError('failedToVerify2FACodeWithStatus', locale: locale ?? const Locale('en'))} ${response.statusCode}';
        }

        ErrorLogger().logError(
          error: errorMessage,
          endpoint: cleanEndpoint,
          method: 'POST',
          statusCode: response.statusCode,
          responseBody: response.body,
        );

        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      // Check if this is a custom error with code property
      try {
        if (e is Exception) {
          final dynamic error = e;
          if (error.code != null) {
            rethrow;
          }
        }
      } catch (_) {
        // Not a custom error, continue with error logging
      }

      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: cleanEndpoint,
        method: 'POST',
      );

      rethrow;
    }
  }

  // Get current user
  Future<UserModel> getCurrentUser() async {
    final response = await _makeRequest('GET', '/users/me/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } else {
      throw Exception(_translateError('failedToGetCurrentUser', locale: null));
    }
  }

  // Update user profile
  Future<UserModel> updateUser({
    required int userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? profilePhotoPath,
  }) async {
    final cleanEndpoint = '/users/$userId/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');

    final token = await _getAccessToken();
    if (token == null) {
      throw Exception(_translateError('notAuthenticated', locale: null));
    }

    try {
      final request = http.MultipartRequest('PATCH', url);
      request.headers['Authorization'] = 'Bearer $token';

      // Add API Key to all requests for application authentication
      final apiKey = AppConstants.apiKey;
      if (apiKey.isNotEmpty) {
        request.headers['X-API-Key'] = apiKey;
      }

      if (firstName != null && firstName.isNotEmpty) {
        request.fields['first_name'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        request.fields['last_name'] = lastName;
      }
      if (phone != null && phone.isNotEmpty) {
        request.fields['phone'] = phone;
      }

      if (profilePhotoPath != null && profilePhotoPath.isNotEmpty) {
        final file = await http.MultipartFile.fromPath(
          'profile_photo',
          profilePhotoPath,
        );
        request.files.add(file);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return UserModel.fromJson(data);
      } else {
        String errorMessage = _translateError(
          'failedToUpdateProfile',
          locale: null,
        );
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          final backendError = error['detail'] ?? error['message'] ?? '';
          errorMessage = backendError.isNotEmpty ? backendError : errorMessage;
        } catch (_) {
          errorMessage =
              '${_translateError('failedToUpdateProfileWithStatus', locale: null)} ${response.statusCode}';
        }
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: cleanEndpoint,
        method: 'PATCH',
      );
      rethrow;
    }
  }

  // Leads
  Future<Map<String, dynamic>> getLeads({
    String? status,
    String? type,
    String? search,
    int? page,
  }) async {
    // Get current user to check role
    final currentUser = await getCurrentUser();
    final isEmployee = currentUser.isEmployee;

    final queryParams = <String, String>{};
    if (status != null && status != 'All') queryParams['status'] = status;
    if (type != null && type != 'All') queryParams['type'] = type;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    // For employees, filter by assigned_to
    if (isEmployee) {
      queryParams['assigned_to'] = currentUser.id.toString();
    }

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

    final response = await _makeRequest('GET', '/clients/$queryString');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = data['results'] as List?;
      final results = resultsList != null
          ? resultsList
                .map((e) => LeadModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : <LeadModel>[];

      return {
        'results': results,
        'count': (data['count'] as num?)?.toInt() ?? 0,
        'next': data['next'] as String?,
        'previous': data['previous'] as String?,
      };
    } else {
      throw Exception(_translateError('failedToGetLeads', locale: null));
    }
  }

  // Get lead by ID
  Future<LeadModel> getLeadById(int id) async {
    final response = await _makeRequest('GET', '/clients/$id/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return LeadModel.fromJson(data);
    } else {
      throw Exception(_translateError('failedToGetLead', locale: null));
    }
  }

  // Add action to lead
  Future<void> addActionToLead({
    required int leadId,
    required int stage,
    required String notes,
    DateTime? reminderDate,
  }) async {
    final body = <String, dynamic>{
      'client': leadId,
      'stage': stage,
      'notes': notes,
    };

    if (reminderDate != null) {
      body['reminder_date'] = reminderDate.toIso8601String();
    }

    final response = await _makeRequest('POST', '/client-tasks/', body: body);

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        error['detail'] ??
            error['message'] ??
            _translateError('failedToAddAction', locale: null),
      );
    }
  }

  // Get client tasks (actions) for a lead
  Future<List<ClientTaskModel>> getClientTasks(int leadId) async {
    final response = await _makeRequest('GET', '/client-tasks/?client=$leadId');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = data['results'] as List?;
      final results = resultsList != null
          ? resultsList
                .map((e) => ClientTaskModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : <ClientTaskModel>[];
      return results;
    } else {
      throw Exception(_translateError('failedToGetClientTasks', locale: null));
    }
  }

  // Get all client tasks (actions) for calendar
  Future<List<ClientTaskModel>> getAllClientTasks() async {
    final response = await _makeRequest('GET', '/client-tasks/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = data['results'] as List?;
      final results = resultsList != null
          ? resultsList
                .map((e) => ClientTaskModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : <ClientTaskModel>[];
      return results;
    } else {
      throw Exception(
        _translateError('failedToGetAllClientTasks', locale: null),
      );
    }
  }

  // Add call to lead
  Future<void> addCallToLead({
    required int leadId,
    required int callMethod,
    required String notes,
    DateTime? callDatetime,
    DateTime? followUpDate,
  }) async {
    final body = <String, dynamic>{
      'client': leadId,
      'call_method': callMethod,
      'notes': notes,
    };

    if (callDatetime != null) {
      body['call_datetime'] = callDatetime.toIso8601String();
    }

    if (followUpDate != null) {
      body['follow_up_date'] = followUpDate.toIso8601String();
    }

    final response = await _makeRequest('POST', '/client-calls/', body: body);

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        error['detail'] ??
            error['message'] ??
            _translateError('failedToAddCall', locale: null),
      );
    }
  }

  // Get client calls for a lead
  Future<List<ClientCallModel>> getClientCalls(int leadId) async {
    final response = await _makeRequest('GET', '/client-calls/?client=$leadId');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = data['results'] as List?;
      final results = resultsList != null
          ? resultsList
                .map((e) => ClientCallModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : <ClientCallModel>[];
      return results;
    } else {
      throw Exception(_translateError('failedToGetClientCalls', locale: null));
    }
  }

  // Get all client calls for calendar
  Future<List<ClientCallModel>> getAllClientCalls() async {
    final response = await _makeRequest('GET', '/client-calls/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = data['results'] as List?;
      final results = resultsList != null
          ? resultsList
                .map((e) => ClientCallModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : <ClientCallModel>[];
      return results;
    } else {
      throw Exception(
        _translateError('failedToGetAllClientCalls', locale: null),
      );
    }
  }

  // Get all tasks (deal tasks) for calendar
  Future<List<TaskModel>> getAllTasks() async {
    final response = await _makeRequest('GET', '/tasks/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = data['results'] as List?;
      final results = resultsList != null
          ? resultsList
                .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : <TaskModel>[];
      return results;
    } else {
      throw Exception(_translateError('failedToGetAllTasks', locale: null));
    }
  }

  // Create lead
  Future<LeadModel> createLead({
    required String name,
    required String phone,
    List<Map<String, dynamic>>? phoneNumbers,
    double? budget,
    int? assignedTo,
    required String type,
    String? communicationWay, // Deprecated: use communicationWayId instead
    int? communicationWayId, // Preferred: channel ID
    String? priority,
    String? status, // Deprecated: use statusId instead
    int? statusId, // Preferred: status ID
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final body = <String, dynamic>{
      'name': name,
      'phone_number': phone,
      'type': type.toLowerCase(),
      'company': currentUser.company!.id, // Include company ID
    };

    if (phoneNumbers != null && phoneNumbers.isNotEmpty) {
      body['phone_numbers'] = phoneNumbers;
    }

    if (budget != null) body['budget'] = budget;
    if (assignedTo != null && assignedTo > 0) body['assigned_to'] = assignedTo;

    // Use ID if provided, otherwise fall back to string (for backward compatibility)
    if (communicationWayId != null) {
      body['communication_way'] = communicationWayId;
    } else if (communicationWay != null) {
      body['communication_way'] = communicationWay;
    }

    if (priority != null) body['priority'] = priority.toLowerCase();

    // Use ID if provided, otherwise fall back to string (for backward compatibility)
    if (statusId != null) {
      body['status'] = statusId;
    } else if (status != null) {
      body['status'] = status;
    }

    final response = await _makeRequest('POST', '/clients/', body: body);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return LeadModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to create lead';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        if (error.containsKey('company')) {
          final companyErrors = error['company'] as List?;
          if (companyErrors != null && companyErrors.isNotEmpty) {
            errorMessage = companyErrors.first.toString();
          } else {
            errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
          }
        } else {
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        }
      } catch (e) {
        // If error parsing fails, use default message
      }
      throw Exception(errorMessage);
    }
  }

  // Update lead
  Future<LeadModel> updateLead({
    required int id,
    String? name,
    String? phone,
    List<Map<String, dynamic>>? phoneNumbers,
    double? budget,
    int? assignedTo,
    String? type,
    String? communicationWay, // Deprecated: use communicationWayId instead
    int? communicationWayId, // Preferred: channel ID
    String? priority,
    String? status, // Deprecated: use statusId instead
    int? statusId, // Preferred: status ID
  }) async {
    final body = <String, dynamic>{};

    if (name != null) body['name'] = name;
    if (phone != null) body['phone_number'] = phone;
    if (phoneNumbers != null) body['phone_numbers'] = phoneNumbers;
    if (budget != null) body['budget'] = budget;
    if (assignedTo != null) {
      body['assigned_to'] = assignedTo > 0 ? assignedTo : null;
    }
    if (type != null) body['type'] = type.toLowerCase();

    // Use ID if provided, otherwise fall back to string (for backward compatibility)
    if (communicationWayId != null) {
      body['communication_way'] = communicationWayId;
    } else if (communicationWay != null) {
      body['communication_way'] = communicationWay;
    }

    if (priority != null) body['priority'] = priority.toLowerCase();

    // Use ID if provided, otherwise fall back to string (for backward compatibility)
    if (statusId != null) {
      body['status'] = statusId;
    } else if (status != null) {
      body['status'] = status;
    }

    final response = await _makeRequest('PATCH', '/clients/$id/', body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return LeadModel.fromJson(data);
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        error['detail'] ??
            error['message'] ??
            _translateError('failedToUpdateLead', locale: null),
      );
    }
  }

  // Delete lead
  Future<void> deleteLead(int id) async {
    final response = await _makeRequest('DELETE', '/clients/$id/');

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        error['detail'] ??
            error['message'] ??
            _translateError('failedToDeleteLead', locale: null),
      );
    }
  }

  // Assign lead(s)
  Future<void> assignLeads({required List<int> clientIds, int? userId}) async {
    final body = <String, dynamic>{'client_ids': clientIds, 'user_id': userId};

    final response = await _makeRequest(
      'POST',
      '/clients/bulk_assign/',
      body: body,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        error['detail'] ??
            error['message'] ??
            _translateError('failedToAssignLeads', locale: null),
      );
    }
  }

  // Get users
  Future<Map<String, dynamic>> getUsers() async {
    final response = await _makeRequest('GET', '/users/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = data['results'] as List?;
      final results = <UserModel>[];

      if (resultsList != null) {
        for (var item in resultsList) {
          if (item is Map<String, dynamic>) {
            try {
              results.add(UserModel.fromJson(item));
            } catch (e) {
              ErrorLogger().logError(
                error: 'Failed to parse user: $e\nItem: $item',
                endpoint: '/users/',
                method: 'GET',
              );
            }
          }
        }
      }

      return {
        'results': results,
        'count': (data['count'] as num?)?.toInt() ?? 0,
      };
    } else {
      throw Exception(_translateError('failedToGetUsers', locale: null));
    }
  }

  // Get user by ID
  Future<UserModel> getUserById(int userId) async {
    final response = await _makeRequest('GET', '/users/$userId/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } else {
      throw Exception(_translateError('failedToGetUser', locale: null));
    }
  }

  // Get deals (legacy method - kept for backward compatibility)
  Future<Map<String, dynamic>> getDeals() async {
    final response = await _makeRequest('GET', '/deals/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultsList = data['results'] as List?;

      return {
        'results': resultsList ?? [],
        'count': (data['count'] as num?)?.toInt() ?? 0,
      };
    } else {
      throw Exception(_translateError('failedToGetDeals', locale: null));
    }
  }

  // Get deals as list of DealModel
  Future<List<DealModel>> getDealsList() async {
    final response = await _makeRequest('GET', '/deals/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => DealModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_translateError('failedToLoadDeals', locale: null));
  }

  // Update deal
  Future<DealModel> createDeal(Map<String, dynamic> data) async {
    final response = await _makeRequest('POST', '/deals/', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DealModel.fromJson(json);
    } else {
      String errorMessage = 'Failed to create deal';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to create deal with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<DealModel> updateDeal(int dealId, Map<String, dynamic> data) async {
    final response = await _makeRequest('PUT', '/deals/$dealId/', body: data);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DealModel.fromJson(json);
    } else {
      String errorMessage = 'Failed to update deal';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to update deal with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  // Delete deal
  Future<void> deleteDeal(int dealId) async {
    final response = await _makeRequest('DELETE', '/deals/$dealId/');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Failed to delete deal';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete deal with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  // ==================== Settings APIs (Channels, Stages, Statuses) ====================

  // Channels CRUD
  Future<List<ChannelModel>> getChannels() async {
    final response = await _makeRequest('GET', '/settings/channels/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .map((item) => ChannelModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        return results
            .map((item) => ChannelModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } else {
      throw Exception(_translateError('failedToGetChannels', locale: null));
    }
  }

  Future<ChannelModel> createChannel({
    required String name,
    required String type,
    required String priority,
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final response = await _makeRequest(
      'POST',
      '/settings/channels/',
      body: {
        'name': name,
        'type': type,
        'priority': priority.toLowerCase(), // Convert to lowercase
        'company': currentUser.company!.id, // Include company ID
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ChannelModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to create channel';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        // Try to extract field-specific errors
        if (error.containsKey('priority')) {
          final priorityErrors = error['priority'] as List?;
          if (priorityErrors != null && priorityErrors.isNotEmpty) {
            errorMessage = priorityErrors.first.toString();
          }
        } else if (error.containsKey('company')) {
          final companyErrors = error['company'] as List?;
          if (companyErrors != null && companyErrors.isNotEmpty) {
            errorMessage = companyErrors.first.toString();
          }
        } else {
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        }
      } catch (_) {
        errorMessage =
            'Failed to create channel with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<ChannelModel> updateChannel({
    required int channelId,
    required String name,
    required String type,
    required String priority,
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final response = await _makeRequest(
      'PATCH',
      '/settings/channels/$channelId/',
      body: {
        'name': name,
        'type': type,
        'priority': priority.toLowerCase(), // Convert to lowercase
        'company': currentUser.company!.id, // Include company ID
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ChannelModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to update channel';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        // Try to extract field-specific errors
        if (error.containsKey('priority')) {
          final priorityErrors = error['priority'] as List?;
          if (priorityErrors != null && priorityErrors.isNotEmpty) {
            errorMessage = priorityErrors.first.toString();
          }
        } else if (error.containsKey('company')) {
          final companyErrors = error['company'] as List?;
          if (companyErrors != null && companyErrors.isNotEmpty) {
            errorMessage = companyErrors.first.toString();
          }
        } else {
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        }
      } catch (_) {
        errorMessage =
            'Failed to update channel with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteChannel(int channelId) async {
    final response = await _makeRequest(
      'DELETE',
      '/settings/channels/$channelId/',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Failed to delete channel';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete channel with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  // Stages CRUD
  Future<List<StageModel>> getStages() async {
    final response = await _makeRequest('GET', '/settings/stages/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .map((item) => StageModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        return results
            .map((item) => StageModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } else {
      throw Exception(_translateError('failedToGetStages', locale: null));
    }
  }

  Future<StageModel> createStage({
    required String name,
    String? description,
    required String color,
    required bool required,
    required bool autoAdvance,
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final response = await _makeRequest(
      'POST',
      '/settings/stages/',
      body: {
        'name': name,
        'description': description,
        'color': color,
        'required': required,
        'auto_advance': autoAdvance,
        'company': currentUser.company!.id, // Include company ID
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return StageModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to create stage';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        if (error.containsKey('company')) {
          final companyErrors = error['company'] as List?;
          if (companyErrors != null && companyErrors.isNotEmpty) {
            errorMessage = companyErrors.first.toString();
          }
        } else {
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        }
      } catch (_) {
        errorMessage =
            'Failed to create stage with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<StageModel> updateStage({
    required int stageId,
    required String name,
    String? description,
    required String color,
    required bool required,
    required bool autoAdvance,
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final response = await _makeRequest(
      'PATCH',
      '/settings/stages/$stageId/',
      body: {
        'name': name,
        'description': description,
        'color': color,
        'required': required,
        'auto_advance': autoAdvance,
        'company': currentUser.company!.id, // Include company ID
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return StageModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to update stage';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        if (error.containsKey('company')) {
          final companyErrors = error['company'] as List?;
          if (companyErrors != null && companyErrors.isNotEmpty) {
            errorMessage = companyErrors.first.toString();
          }
        } else {
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        }
      } catch (_) {
        errorMessage =
            'Failed to update stage with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteStage(int stageId) async {
    final response = await _makeRequest('DELETE', '/settings/stages/$stageId/');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Failed to delete stage';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete stage with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  // Statuses CRUD
  Future<List<StatusModel>> getStatuses() async {
    final response = await _makeRequest('GET', '/settings/statuses/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .map((item) => StatusModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        return results
            .map((item) => StatusModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } else {
      throw Exception(_translateError('failedToGetStatuses', locale: null));
    }
  }

  Future<StatusModel> createStatus({
    required String name,
    String? description,
    required String category,
    required String color,
    required bool isDefault,
    required bool isHidden,
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Normalize category to lowercase and handle "Follow Up" variations
    String normalizedCategory = category.toLowerCase();
    if (normalizedCategory == 'follow up' || normalizedCategory == 'followup') {
      normalizedCategory = 'follow_up';
    }

    final response = await _makeRequest(
      'POST',
      '/settings/statuses/',
      body: {
        'name': name,
        'description': description,
        'category': normalizedCategory, // Use normalized lowercase category
        'color': color,
        'is_default': isDefault,
        'is_hidden': isHidden,
        'company': currentUser.company!.id, // Include company ID
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return StatusModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to create status';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        if (error.containsKey('category')) {
          final categoryErrors = error['category'] as List?;
          if (categoryErrors != null && categoryErrors.isNotEmpty) {
            errorMessage = categoryErrors.first.toString();
          }
        } else if (error.containsKey('company')) {
          final companyErrors = error['company'] as List?;
          if (companyErrors != null && companyErrors.isNotEmpty) {
            errorMessage = companyErrors.first.toString();
          }
        } else {
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        }
      } catch (_) {
        errorMessage =
            'Failed to create status with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<StatusModel> updateStatus({
    required int statusId,
    required String name,
    String? description,
    required String category,
    required String color,
    required bool isDefault,
    required bool isHidden,
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Normalize category to lowercase and handle "Follow Up" variations
    String normalizedCategory = category.toLowerCase();
    if (normalizedCategory == 'follow up' || normalizedCategory == 'followup') {
      normalizedCategory = 'follow_up';
    }

    final response = await _makeRequest(
      'PATCH',
      '/settings/statuses/$statusId/',
      body: {
        'name': name,
        'description': description,
        'category': normalizedCategory, // Use normalized lowercase category
        'color': color,
        'is_default': isDefault,
        'is_hidden': isHidden,
        'company': currentUser.company!.id, // Include company ID
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return StatusModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to update status';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        if (error.containsKey('category')) {
          final categoryErrors = error['category'] as List?;
          if (categoryErrors != null && categoryErrors.isNotEmpty) {
            errorMessage = categoryErrors.first.toString();
          }
        } else if (error.containsKey('company')) {
          final companyErrors = error['company'] as List?;
          if (companyErrors != null && companyErrors.isNotEmpty) {
            errorMessage = companyErrors.first.toString();
          }
        } else {
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        }
      } catch (_) {
        errorMessage =
            'Failed to update status with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteStatus(int statusId) async {
    final response = await _makeRequest(
      'DELETE',
      '/settings/statuses/$statusId/',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Failed to delete status';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete status with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  // Call Methods CRUD
  Future<List<CallMethodModel>> getCallMethods() async {
    final response = await _makeRequest('GET', '/settings/call-methods/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .map(
              (item) => CallMethodModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        return results
            .map(
              (item) => CallMethodModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } else {
      throw Exception(_translateError('failedToGetCallMethods', locale: null));
    }
  }

  Future<CallMethodModel> createCallMethod({
    required String name,
    String? description,
    required String color,
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final response = await _makeRequest(
      'POST',
      '/settings/call-methods/',
      body: {
        'name': name,
        'description': description,
        'color': color,
        'company': currentUser.company!.id, // Include company ID
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CallMethodModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to create call method';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to create call method with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<CallMethodModel> updateCallMethod({
    required int callMethodId,
    required String name,
    String? description,
    required String color,
  }) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final response = await _makeRequest(
      'PUT',
      '/settings/call-methods/$callMethodId/',
      body: {
        'name': name,
        'description': description,
        'color': color,
        'company': currentUser.company!.id, // Include company ID
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CallMethodModel.fromJson(data);
    } else {
      String errorMessage = 'Failed to update call method';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to update call method with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteCallMethod(int callMethodId) async {
    final response = await _makeRequest(
      'DELETE',
      '/settings/call-methods/$callMethodId/',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Failed to delete call method';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete call method with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  // ==================== Real Estate Inventory APIs ====================

  // Developers
  Future<List<Developer>> getDevelopers() async {
    final response = await _makeRequest('GET', '/developers/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => Developer.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_translateError('failedToLoadDevelopers', locale: null));
  }

  // Projects
  Future<List<Project>> getProjects() async {
    final response = await _makeRequest('GET', '/projects/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => Project.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_translateError('failedToLoadProjects', locale: null));
  }

  // Units
  Future<List<Unit>> getUnits() async {
    final response = await _makeRequest('GET', '/units/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => Unit.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_translateError('failedToLoadUnits', locale: null));
  }

  // Owners
  Future<List<Owner>> getOwners() async {
    final response = await _makeRequest('GET', '/owners/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => Owner.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_translateError('failedToLoadOwners', locale: null));
  }

  // ==================== Services Inventory APIs ====================

  // Services
  Future<List<Service>> getServices() async {
    final response = await _makeRequest('GET', '/services/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => Service.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_translateError('failedToLoadServices', locale: null));
  }

  // Service Packages
  Future<List<ServicePackage>> getServicePackages() async {
    final response = await _makeRequest('GET', '/service-packages/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => ServicePackage.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      _translateError('failedToLoadServicePackages', locale: null),
    );
  }

  // Service Providers
  Future<List<ServiceProvider>> getServiceProviders() async {
    final response = await _makeRequest('GET', '/service-providers/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => ServiceProvider.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      _translateError('failedToLoadServiceProviders', locale: null),
    );
  }

  // ==================== Products Inventory APIs ====================

  // Products
  Future<List<Product>> getProducts() async {
    final response = await _makeRequest('GET', '/products/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_translateError('failedToLoadProducts', locale: null));
  }

  // Product Categories
  Future<List<ProductCategory>> getProductCategories() async {
    final response = await _makeRequest('GET', '/product-categories/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => ProductCategory.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      _translateError('failedToLoadProductCategories', locale: null),
    );
  }

  // Suppliers
  Future<List<Supplier>> getSuppliers() async {
    final response = await _makeRequest('GET', '/suppliers/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_translateError('failedToLoadSuppliers', locale: null));
  }

  // ==================== CRUD Operations for Inventory ====================

  // Products CRUD
  Future<Product> createProduct(Map<String, dynamic> productData) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(productData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/products/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Product.fromJson(data);
    }
    throw Exception('Failed to create product');
  }

  Future<Product> updateProduct(
    int id,
    Map<String, dynamic> productData,
  ) async {
    final response = await _makeRequest(
      'PATCH',
      '/products/$id/',
      body: productData,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Product.fromJson(data);
    }
    throw Exception('Failed to update product');
  }

  Future<void> deleteProduct(int id) async {
    final response = await _makeRequest('DELETE', '/products/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete product');
    }
  }

  // Product Categories CRUD
  Future<ProductCategory> createProductCategory(
    Map<String, dynamic> categoryData,
  ) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(categoryData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/product-categories/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ProductCategory.fromJson(data);
    }
    throw Exception('Failed to create product category');
  }

  Future<ProductCategory> updateProductCategory(
    int id,
    Map<String, dynamic> categoryData,
  ) async {
    final response = await _makeRequest(
      'PATCH',
      '/product-categories/$id/',
      body: categoryData,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ProductCategory.fromJson(data);
    }
    throw Exception('Failed to update product category');
  }

  Future<void> deleteProductCategory(int id) async {
    final response = await _makeRequest('DELETE', '/product-categories/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete product category');
    }
  }

  // Suppliers CRUD
  Future<Supplier> createSupplier(Map<String, dynamic> supplierData) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(supplierData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/suppliers/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Supplier.fromJson(data);
    }
    throw Exception('Failed to create supplier');
  }

  Future<Supplier> updateSupplier(
    int id,
    Map<String, dynamic> supplierData,
  ) async {
    final response = await _makeRequest(
      'PATCH',
      '/suppliers/$id/',
      body: supplierData,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Supplier.fromJson(data);
    }
    throw Exception('Failed to update supplier');
  }

  Future<void> deleteSupplier(int id) async {
    final response = await _makeRequest('DELETE', '/suppliers/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete supplier');
    }
  }

  // Services CRUD
  Future<Service> createService(Map<String, dynamic> serviceData) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(serviceData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/services/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Service.fromJson(data);
    }
    throw Exception('Failed to create service');
  }

  Future<Service> updateService(
    int id,
    Map<String, dynamic> serviceData,
  ) async {
    final response = await _makeRequest(
      'PATCH',
      '/services/$id/',
      body: serviceData,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Service.fromJson(data);
    }
    throw Exception('Failed to update service');
  }

  Future<void> deleteService(int id) async {
    final response = await _makeRequest('DELETE', '/services/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete service');
    }
  }

  // Service Packages CRUD
  Future<ServicePackage> createServicePackage(
    Map<String, dynamic> packageData,
  ) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(packageData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/service-packages/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ServicePackage.fromJson(data);
    }
    throw Exception('Failed to create service package');
  }

  Future<ServicePackage> updateServicePackage(
    int id,
    Map<String, dynamic> packageData,
  ) async {
    final response = await _makeRequest(
      'PATCH',
      '/service-packages/$id/',
      body: packageData,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ServicePackage.fromJson(data);
    }
    throw Exception('Failed to update service package');
  }

  Future<void> deleteServicePackage(int id) async {
    final response = await _makeRequest('DELETE', '/service-packages/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete service package');
    }
  }

  // Service Providers CRUD
  Future<ServiceProvider> createServiceProvider(
    Map<String, dynamic> providerData,
  ) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(providerData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/service-providers/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ServiceProvider.fromJson(data);
    }
    throw Exception('Failed to create service provider');
  }

  Future<ServiceProvider> updateServiceProvider(
    int id,
    Map<String, dynamic> providerData,
  ) async {
    final response = await _makeRequest(
      'PATCH',
      '/service-providers/$id/',
      body: providerData,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ServiceProvider.fromJson(data);
    }
    throw Exception('Failed to update service provider');
  }

  Future<void> deleteServiceProvider(int id) async {
    final response = await _makeRequest('DELETE', '/service-providers/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete service provider');
    }
  }

  // Developers CRUD
  Future<Developer> createDeveloper(Map<String, dynamic> developerData) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(developerData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/developers/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Developer.fromJson(data);
    }
    throw Exception('Failed to create developer');
  }

  Future<Developer> updateDeveloper(
    int id,
    Map<String, dynamic> developerData,
  ) async {
    final response = await _makeRequest(
      'PATCH',
      '/developers/$id/',
      body: developerData,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Developer.fromJson(data);
    }
    throw Exception('Failed to update developer');
  }

  Future<void> deleteDeveloper(int id) async {
    final response = await _makeRequest('DELETE', '/developers/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete developer');
    }
  }

  // Projects CRUD
  Future<Project> createProject(Map<String, dynamic> projectData) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(projectData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/projects/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Project.fromJson(data);
    }
    throw Exception('Failed to create project');
  }

  Future<Project> updateProject(
    int id,
    Map<String, dynamic> projectData,
  ) async {
    debugPrint('updateProject - ID: $id, Data: $projectData');
    final response = await _makeRequest(
      'PATCH',
      '/projects/$id/',
      body: projectData,
    );
    debugPrint(
      'updateProject - Status: ${response.statusCode}, Body: ${response.body}',
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Project.fromJson(data);
    } else {
      final errorBody = response.body;
      debugPrint('updateProject - Error: $errorBody');
      throw Exception('Failed to update project: $errorBody');
    }
  }

  Future<void> deleteProject(int id) async {
    final response = await _makeRequest('DELETE', '/projects/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete project');
    }
  }

  // Units CRUD
  Future<Unit> createUnit(Map<String, dynamic> unitData) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(unitData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/units/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Unit.fromJson(data);
    }
    throw Exception('Failed to create unit');
  }

  Future<Unit> updateUnit(int id, Map<String, dynamic> unitData) async {
    final response = await _makeRequest('PATCH', '/units/$id/', body: unitData);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Unit.fromJson(data);
    }
    throw Exception('Failed to update unit');
  }

  Future<void> deleteUnit(int id) async {
    final response = await _makeRequest('DELETE', '/units/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete unit');
    }
  }

  // Owners CRUD
  Future<Owner> createOwner(Map<String, dynamic> ownerData) async {
    // Get current user to retrieve company ID
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    // Add company ID to the data
    final dataWithCompany = Map<String, dynamic>.from(ownerData);
    dataWithCompany['company'] = currentUser.company!.id;

    final response = await _makeRequest(
      'POST',
      '/owners/',
      body: dataWithCompany,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Owner.fromJson(data);
    }
    throw Exception('Failed to create owner');
  }

  Future<Owner> updateOwner(int id, Map<String, dynamic> ownerData) async {
    final response = await _makeRequest(
      'PATCH',
      '/owners/$id/',
      body: ownerData,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Owner.fromJson(data);
    }
    throw Exception('Failed to update owner');
  }

  Future<void> deleteOwner(int id) async {
    final response = await _makeRequest('DELETE', '/owners/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete owner');
    }
  }

  // ==================== FCM Token Management ====================

  /// تحديث FCM Token للمستخدم الحالي
  Future<void> updateFCMToken(String fcmToken, {String? language}) async {
    try {
      final body = {'fcm_token': fcmToken};

      // إضافة اللغة إذا كانت متوفرة
      if (language != null) {
        body['language'] = language;
      }

      final response = await _makeRequest(
        'POST',
        '/users/update-fcm-token/',
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✓ FCM Token sent to server successfully');
      } else {
        String errorMessage = 'Failed to update FCM token';
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        } catch (_) {
          errorMessage =
              'Failed to update FCM token with status ${response.statusCode}';
        }
        debugPrint('⚠ Warning: $errorMessage');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/users/update-fcm-token/',
        method: 'POST',
      );
      debugPrint('⚠ Error sending FCM token to server: $e');
      // لا نرمي exception هنا لأن الإشعارات المحلية ستعمل حتى بدون إرسال Token
    }
  }

  // ==================== User Preferences ====================

  /// تحديث لغة المستخدم
  Future<void> updateLanguage(String languageCode) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/users/update-language/',
        body: {'language': languageCode},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Language updated on server successfully');
      } else {
        String errorMessage = 'Failed to update language';
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        } catch (_) {
          errorMessage =
              'Failed to update language with status ${response.statusCode}';
        }
        debugPrint('Warning: $errorMessage');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/users/update-language/',
        method: 'POST',
      );
      debugPrint('Warning: Error updating language on server: $e');
      // لا نرمي exception هنا لأن تغيير اللغة المحلي يعمل حتى بدون تحديث الخادم
    }
  }

  // ==================== Notifications Management ====================

  /// جلب إعدادات الإشعارات من الخادم
  Future<Map<String, dynamic>?> getNotificationSettings() async {
    try {
      final response = await _makeRequest('GET', '/notifications/settings/');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Warning: Failed to load notification settings from server');
        return null;
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/notifications/settings/',
        method: 'GET',
      );
      debugPrint(
        'Warning: Error loading notification settings from server: $e',
      );
      // لا نرمي exception هنا لأن الإعدادات المحلية تعمل حتى بدون الخادم
      return null;
    }
  }

  /// تحديث إعدادات الإشعارات على الخادم
  Future<void> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      debugPrint('Sending notification settings to server: $settings');
      final response = await _makeRequest(
        'PUT',
        '/notifications/settings/',
        body: settings,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✓ Notification settings updated on server successfully');
      } else {
        String errorMessage = 'Failed to update notification settings';
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
        } catch (_) {
          errorMessage =
              'Failed to update notification settings with status ${response.statusCode}';
        }
        debugPrint('Warning: $errorMessage');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/notifications/settings/',
        method: 'PUT',
      );
      debugPrint('Error updating notification settings on server: $e');
      rethrow; // نرمي exception هنا لنرى الخطأ في السجلات
    }
  }

  /// جلب جميع الإشعارات للمستخدم الحالي
  Future<List<Map<String, dynamic>>> getNotifications({
    bool? read,
    String? type,
  }) async {
    try {
      String endpoint = '/notifications/';
      Map<String, String> queryParams = {};

      if (read != null) {
        queryParams['read'] = read.toString();
      }
      if (type != null) {
        queryParams['type'] = type;
      }

      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
            )
            .join('&');
        endpoint += '?$queryString';
      }

      final response = await _makeRequest('GET', endpoint);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results =
            data['results'] as List<dynamic>? ?? data as List<dynamic>;
        return results.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/notifications/',
        method: 'GET',
      );
      rethrow;
    }
  }

  /// جلب إشعار محدد
  Future<Map<String, dynamic>> getNotification(int notificationId) async {
    try {
      final response = await _makeRequest(
        'GET',
        '/notifications/$notificationId/',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load notification');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/notifications/$notificationId/',
        method: 'GET',
      );
      rethrow;
    }
  }

  /// تحديد إشعار كمقروء
  Future<void> markNotificationAsRead(int notificationId) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/notifications/$notificationId/mark_read/',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✓ Notification marked as read');
      } else {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/notifications/$notificationId/mark_read/',
        method: 'POST',
      );
      rethrow;
    }
  }

  /// تحديد جميع الإشعارات كمقروءة
  Future<void> markAllNotificationsAsRead() async {
    try {
      final response = await _makeRequest(
        'POST',
        '/notifications/mark_all_read/',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✓ All notifications marked as read');
      } else {
        throw Exception('Failed to mark all notifications as read');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/notifications/mark_all_read/',
        method: 'POST',
      );
      rethrow;
    }
  }

  /// جلب عدد الإشعارات غير المقروءة
  Future<int> getUnreadNotificationsCount() async {
    try {
      final response = await _makeRequest(
        'GET',
        '/notifications/unread_count/',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['unread_count'] as int? ?? 0;
      } else {
        throw Exception('Failed to get unread count');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/notifications/unread_count/',
        method: 'GET',
      );
      return 0; // Return 0 on error to avoid breaking the UI
    }
  }

  /// حذف جميع الإشعارات المقروءة
  Future<void> deleteAllReadNotifications() async {
    try {
      final response = await _makeRequest(
        'DELETE',
        '/notifications/delete_all_read/',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✓ All read notifications deleted');
      } else {
        throw Exception('Failed to delete read notifications');
      }
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/notifications/delete_all_read/',
        method: 'DELETE',
      );
      rethrow;
    }
  }
}
