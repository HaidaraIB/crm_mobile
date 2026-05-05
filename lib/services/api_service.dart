import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_envelope.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/auth_token_storage.dart';
import '../core/localization/app_localizations.dart';
import '../core/utils/api_error_helper.dart';
import '../core/utils/app_locales.dart';
import '../models/lead_model.dart';
import '../models/user_model.dart';
import '../models/settings_model.dart';
import '../models/client_task_model.dart';
import '../models/client_call_model.dart';
import '../models/client_visit_model.dart';
import '../models/task_model.dart';
import '../models/inventory_model.dart';
import '../models/deal_model.dart';
import '../models/support_ticket_model.dart';
import '../models/mobile_app_version_policy.dart';
import 'device_fcm_token.dart'
    show clearLocalPushRegistrationAfterLogout, resolveDeviceFcmTokenForUnregister;
import 'error_logger.dart';

/// طبقة HTTP موحّدة للتطبيق: [AuthTokenStorage] للرموز، [ApiEnvelope] لفك المظروف،
/// والرأس `X-API-Key` من [AppConstants.mobileApiKey] (`API_KEY_MOBILE` / `--dart-define`).
///
/// استثناء عند كون الاشتراك غير مفعّل؛ يحمل [subscriptionId] إن أرسله الـ API
class SubscriptionInactiveException implements Exception {
  SubscriptionInactiveException(this.message, {this.subscriptionId});
  final String message;
  final int? subscriptionId;
  @override
  String toString() => message;
}

/// Owner email/phone verification required before login or 2FA (matches CRM API envelope).
class LoginVerificationAction {
  const LoginVerificationAction({
    required this.id,
    required this.label,
    required this.href,
    required this.description,
  });

  final String id;
  final String label;
  final String href;
  final String description;
}

class LoginVerificationRequiredException implements Exception {
  LoginVerificationRequiredException({
    required this.message,
    required this.businessCode,
    this.hint,
    this.actions = const [],
    this.changeCredentialsNote,
    this.verifyEmailUrl,
    this.verifyPhoneUrl,
  });

  final String message;
  final String businessCode;
  final String? hint;
  final List<LoginVerificationAction> actions;
  final String? changeCredentialsNote;
  final String? verifyEmailUrl;
  final String? verifyPhoneUrl;

  @override
  String toString() => message;

  static bool isBusinessCode(dynamic code) {
    return ApiEnvelope.codeEquals(code, 'email_not_verified') ||
        ApiEnvelope.codeEquals(code, 'phone_not_verified') ||
        ApiEnvelope.codeEquals(code, 'email_phone_not_verified');
  }

  static List<LoginVerificationAction> _parseActions(dynamic raw) {
    if (raw is! List) return const [];
    final out = <LoginVerificationAction>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      out.add(
        LoginVerificationAction(
          id: m['id']?.toString() ?? '',
          label: m['label']?.toString() ?? 'Open',
          href: m['href']?.toString() ?? '',
          description: m['description']?.toString() ?? '',
        ),
      );
    }
    return out;
  }

  /// Build from [ApiEnvelope.errorContextFromBody] map when login/2FA returns 403 with structured error.
  static LoginVerificationRequiredException? tryParse(Map<String, dynamic> error) {
    if (!isBusinessCode(error['code'])) return null;
    final rawMsg = '${error['message'] ?? error['error'] ?? ''}'.trim();
    final msg = rawMsg.isNotEmpty
        ? rawMsg
        : 'Verification required before you can sign in.';
    return LoginVerificationRequiredException(
      message: msg,
      businessCode: error['code']?.toString() ?? 'email_not_verified',
      hint: error['hint']?.toString(),
      actions: _parseActions(error['actions']),
      changeCredentialsNote: error['change_credentials_note']?.toString(),
      verifyEmailUrl: error['verify_email_url']?.toString(),
      verifyPhoneUrl: error['verify_phone_url']?.toString(),
    );
  }
}

/// استثناء إرسال SMS من التكامل (Twilio)؛ يحمل [errorKey] للترجمة في الواجهة
class SmsException implements Exception {
  SmsException(this.errorKey, this.fallbackMessage);
  final String errorKey;
  final String fallbackMessage;
  @override
  String toString() => fallbackMessage;
}

/// استثناء من الـ API مع رسالة وأخطاء حقول (لتسجيل الدخول/التوفر) — يحتوي على [fields] فعلياً ليتوافق مع iOS.
class ApiFieldException implements Exception {
  ApiFieldException(this.message, [this.fields]);
  final String message;
  final Map<String, dynamic>? fields;
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  static const Duration _defaultCacheTtl = Duration(seconds: 60);
  /// Matches CRM web full-sync default; capped by API [DRF_MAX_PAGE_SIZE].
  static const int _defaultFullFetchPageSize = 100;
  final Map<String, _CacheEntry<dynamic>> _memoryCache = {};

  String get baseUrl => AppConstants.baseUrl;

  String _cacheKey(String resource, [Map<String, Object?> params = const {}]) {
    if (params.isEmpty) return resource;
    final sortedKeys = params.keys.toList()..sort();
    final query = sortedKeys
        .map((key) => '$key=${params[key] ?? ''}')
        .join('&');
    return '$resource?$query';
  }

  void _logCacheEvent(String message) {
    assert(() {
      debugPrint('[ApiCache] $message');
      return true;
    }());
  }

  T? _cacheGet<T>(String key, {bool forceRefresh = false}) {
    if (forceRefresh) {
      _memoryCache.remove(key);
      _logCacheEvent('BYPASS key=$key reason=forceRefresh');
      return null;
    }
    final entry = _memoryCache[key];
    if (entry == null) {
      _logCacheEvent('MISS key=$key reason=not_found');
      return null;
    }
    if (entry.isExpired) {
      _memoryCache.remove(key);
      _logCacheEvent('MISS key=$key reason=expired');
      return null;
    }
    _logCacheEvent('HIT key=$key');
    return entry.value as T;
  }

  void _cacheSet<T>(
    String key,
    T value, {
    Duration ttl = _defaultCacheTtl,
  }) {
    _memoryCache[key] = _CacheEntry<T>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
    _logCacheEvent('SET key=$key ttl=${ttl.inSeconds}s');
  }

  void _cacheInvalidateByPrefix(String prefix) {
    final keysToRemove = _memoryCache.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _logCacheEvent('INVALIDATE key=$key prefix=$prefix');
    }
  }

  void _invalidateUserCache() => _cacheInvalidateByPrefix('current_user');
  void _invalidateLeadsCache() => _cacheInvalidateByPrefix('leads');
  void _invalidateDealsCache() => _cacheInvalidateByPrefix('deals');
  void _invalidateNotificationsCache() =>
      _cacheInvalidateByPrefix('notifications');
  void _invalidateSettingsCache() => _cacheInvalidateByPrefix('settings_');
  void _invalidateInventoryCache() => _cacheInvalidateByPrefix('inventory_');
  void _invalidateSupportCache() => _cacheInvalidateByPrefix('support_');

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

  String _resolveApiErrorMessage(
    Map<String, dynamic> error, {
    required String fallbackKey,
  }) {
    final errorKey = error['error_key']?.toString();
    final rawMessage = (error['detail'] ?? error['error'] ?? error['message'])
        ?.toString()
        .trim();

    // Plan and entitlement related keys should map to localized app messages.
    if (errorKey != null && errorKey.isNotEmpty) {
      final mapped = _translateError(errorKey, locale: null);
      if (mapped != errorKey) return mapped;
    }

    if (rawMessage != null && rawMessage.isNotEmpty) {
      return rawMessage;
    }
    return _translateError(fallbackKey, locale: null);
  }

  Future<String?> _getAccessToken() =>
      AuthTokenStorage.instance.readAccessToken();

  Future<String?> _getRefreshToken() =>
      AuthTokenStorage.instance.readRefreshToken();

  /// Returns true if an access token is stored (user can be considered "logged in" for API calls).
  Future<bool> hasStoredAccessToken() async {
    final token = await _getAccessToken();
    return token != null && token.toString().trim().isNotEmpty;
  }

  /// Same rule as web: only staff roles report presence (not company owner/admin).
  static bool _roleReportsPresence(String? role) {
    var token = (role ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    return token == 'employee' ||
        token == 'data_entry' ||
        token == 'supervisor';
  }

  Future<void> sendPresenceHeartbeat({String source = 'mobile'}) async {
    final hasToken = await hasStoredAccessToken();
    if (!hasToken) return;
    final storedUserJson = await AuthTokenStorage.instance.readUserJson();
    if (storedUserJson == null || storedUserJson.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(storedUserJson);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final role = decoded['role']?.toString();
      if (!_roleReportsPresence(role)) {
        return;
      }
    } catch (_) {
      return;
    }

    try {
      await _makeRequest(
        'POST',
        '/users/presence_heartbeat/',
        body: <String, dynamic>{'source': source},
      );
    } catch (_) {
      // Presence is best-effort; ignore failures.
    }
  }

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Add API Key to all requests for application authentication
    final apiKey = AppConstants.apiKey;
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }
    headers['X-Client-Platform'] = 'mobile';

    // Send user language so backend can use it for emails and responses
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(AppConstants.languageKey) ?? 'en';
    headers['X-Language'] = (languageCode == 'ar' || languageCode == 'en') ? languageCode : 'en';

    if (includeAuth) {
      final token = await _getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final trustedDeviceToken =
        await AuthTokenStorage.instance.readTrustedDeviceToken();
    if (trustedDeviceToken != null && trustedDeviceToken.trim().isNotEmpty) {
      headers['X-Owner-Trusted-Device'] = trustedDeviceToken.trim();
    }

    return headers;
  }

  Map<String, dynamic> _unwrapResponseMap(http.Response response) =>
      ApiEnvelope.decodeAndUnwrapMapForStatus(response.body, response.statusCode);

  dynamic _unwrapResponseDynamic(http.Response response) =>
      ApiEnvelope.decodeAndUnwrapForStatus(response.body, response.statusCode);

  Map<String, dynamic> _errorContextFromBody(String body) =>
      ApiEnvelope.errorContextFromBody(body);

  bool _isPaginatedBody(dynamic data) {
    if (data is! Map<String, dynamic>) return false;
    return data['results'] is List &&
        (data.containsKey('next')) &&
        (data.containsKey('previous')) &&
        (data.containsKey('count'));
  }

  String _withDefaultListPageSizeIfNeeded(String cleanEndpoint) {
    if (cleanEndpoint.contains('page=')) return cleanEndpoint;
    if (cleanEndpoint.contains(RegExp(r'[&?]page_size='))) {
      return cleanEndpoint;
    }
    final joiner = cleanEndpoint.contains('?') ? '&' : '?';
    return '$cleanEndpoint${joiner}page_size=$_defaultFullFetchPageSize';
  }

  Uri? _resolveNextPageUri(String nextUrl, String cleanBaseUrl) {
    if (nextUrl.isEmpty) return null;
    if (nextUrl.startsWith('http://') || nextUrl.startsWith('https://')) {
      return Uri.tryParse(nextUrl);
    }
    if (nextUrl.startsWith('/')) {
      return Uri.tryParse('$cleanBaseUrl$nextUrl');
    }
    return Uri.tryParse('$cleanBaseUrl/$nextUrl');
  }

  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool retryOn401 = true,
    Duration? timeout,
    bool includeAuth = true,
  }) async {
    // Ensure endpoint starts with / and baseUrl doesn't end with /
    var cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (method.toUpperCase() == 'GET' &&
        !cleanEndpoint.contains(RegExp(r'[&?]page='))) {
      cleanEndpoint = _withDefaultListPageSizeIfNeeded(cleanEndpoint);
    }
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

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
    if (response.statusCode == 401 && retryOn401 && includeAuth) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry the request with new token
        return _makeRequest(
          method,
          endpoint,
          body: body,
          retryOn401: false,
          includeAuth: includeAuth,
        );
      } else {
        // Refresh failed: clear tokens and auto-logout to login screen (like web)
        await _clearTokens();
        _navigateToLogin('session_expired');
        throw Exception(
          _translateError('sessionExpired', locale: null),
        );
      }
    }

    // Handle 403 Forbidden - subscription inactive (like web: clear and redirect)
    // Skip for /users/me/ which is used to check subscription status
    if (response.statusCode == 403 && !cleanEndpoint.contains('users/me')) {
      String? errorMessage;
      try {
        final raw = ApiEnvelope.tryDecodeMap(response.body);
        if (raw != null) {
          errorMessage = ApiEnvelope.errorMessageFromRoot(raw);
        }
      } catch (_) {}
      final lower = (errorMessage ?? '').toLowerCase();
      final isSubscriptionInactive = lower.contains('subscription') ||
          lower.contains('اشتراك') ||
          lower.contains('active') ||
          lower.contains('not active');
      if (isSubscriptionInactive) {
        await _savePendingSubscriptionIdIfAny();
        await _clearTokens();
        _navigateToLogin('subscription_inactive');
        throw SubscriptionInactiveException(
          _translateError('subscriptionInactive', locale: null),
          subscriptionId: await _getStoredPendingSubscriptionId(),
        );
      }
    }

    if (method.toUpperCase() == 'GET' &&
        !cleanEndpoint.contains(RegExp(r'[&?]page=')) &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      try {
        final firstData = _unwrapResponseDynamic(response);
        if (_isPaginatedBody(firstData)) {
          final mergedResults = <dynamic>[...(firstData['results'] as List)];
          final initialCount = (firstData['count'] as num?)?.toInt() ?? mergedResults.length;
          final initialPrevious = firstData['previous'];
          String? nextUrl = firstData['next']?.toString();
          var safetyCounter = 0;
          var currentHeaders = headers;

          while (nextUrl != null && nextUrl.isNotEmpty && safetyCounter < 200) {
            safetyCounter += 1;
            final nextUri = _resolveNextPageUri(nextUrl, cleanBaseUrl);
            if (nextUri == null) break;

            var nextResponse = await http
                .get(nextUri, headers: currentHeaders)
                .timeout(requestTimeout);

            if (nextResponse.statusCode == 401 && includeAuth) {
              final refreshed = await _refreshToken();
              if (!refreshed) break;
              currentHeaders = await _getHeaders(includeAuth: includeAuth);
              nextResponse = await http
                  .get(nextUri, headers: currentHeaders)
                  .timeout(requestTimeout);
            }

            if (nextResponse.statusCode < 200 || nextResponse.statusCode >= 300) break;

            final nextData = _unwrapResponseDynamic(nextResponse);
            if (!_isPaginatedBody(nextData)) break;

            mergedResults.addAll((nextData['results'] as List));
            nextUrl = nextData['next']?.toString();
          }

          final mergedBody = <String, dynamic>{
            'count': initialCount > mergedResults.length ? initialCount : mergedResults.length,
            'next': null,
            'previous': initialPrevious,
            'results': mergedResults,
          };

          return http.Response(
            jsonEncode(mergedBody),
            response.statusCode,
            headers: response.headers,
            reasonPhrase: response.reasonPhrase,
            request: response.request,
          );
        }
      } catch (_) {
        // Fallback to original response if pagination merge fails.
      }
    }

    return response;
  }

  /// Navigate to login and clear stack (auto-logout like web).
  void _navigateToLogin(String reason) {
    final key = AppConstants.navigatorKey;
    if (key?.currentContext == null) return;
    Navigator.of(key!.currentContext!).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
      arguments: <String, String>{'reason': reason},
    );
  }

  Future<void> _savePendingSubscriptionIdIfAny() async {
    try {
      final userJson = await AuthTokenStorage.instance.readUserJson();
      if (userJson == null) return;
      final user = jsonDecode(userJson) as Map<String, dynamic>?;
      final company = user?['company'] as Map<String, dynamic>?;
      final sub = company?['subscription'];
      if (sub != null) {
        final id = sub is Map ? sub['id'] : null;
        if (id != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            AppConstants.pendingSubscriptionIdKey,
            id.toString(),
          );
        }
      }
    } catch (_) {}
  }

  Future<int?> _getStoredPendingSubscriptionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(AppConstants.pendingSubscriptionIdKey);
      if (s == null) return null;
      return int.tryParse(s);
    } catch (_) {
      return null;
    }
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
        final data = _unwrapResponseMap(response);
        final newAccessToken = data['access'] as String?;

        if (newAccessToken != null) {
          await AuthTokenStorage.instance.writeAccessToken(newAccessToken);
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _clearTokens() async {
    await _removeCurrentDeviceFcmTokenBeforeLogout();
    // Keep trusted-device token on normal logout so owner can skip 2FA
    // on the same mobile within trust window.
    await AuthTokenStorage.instance.clearSessionDataKeepTrustedDevice();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.isLoggedInKey);
    // Drop FCM registration locally after session flags cleared so pushes stop
    // for this install (handlers also ignore payloads when logged out).
    await clearLocalPushRegistrationAfterLogout();
  }

  /// مسح الجلسة (رموز + تفضيلات تسجيل الدخول) — للاستخدام من واجهة تسجيل الخروج.
  Future<void> clearAuthSession() async {
    await _clearTokens();
    _memoryCache.clear();
  }

  // ==================== Registration APIs ====================

  /// GET /api/auth/register/phone-otp-requirement/
  Future<Map<String, dynamic>> getPhoneOtpRequirement({
    String language = 'en',
  }) async {
    final cleanEndpoint = '/auth/register/phone-otp-requirement/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');
    final locale = language == 'ar' ? AppLocales.arabic : AppLocales.english;
    try {
      final headers = await _getHeaders(includeAuth: false);
      headers['Accept-Language'] = language;
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return _unwrapResponseMap(response);
      }
      final err = _errorContextFromBody(response.body);
      throw ApiFieldException(
        err['detail']?.toString() ??
            err['message']?.toString() ??
            _translateError('registrationFailed', locale: locale),
        err,
      );
    } catch (e) {
      if (e is ApiFieldException) rethrow;
      rethrow;
    }
  }

  /// POST /api/auth/register/phone/send-otp/
  Future<Map<String, dynamic>> registerPhoneSendOtp({
    required String phone,
    String language = 'en',
  }) async {
    final cleanEndpoint = '/auth/register/phone/send-otp/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');
    final locale = language == 'ar' ? AppLocales.arabic : AppLocales.english;
    try {
      final headers = await _getHeaders(includeAuth: false);
      headers['Accept-Language'] = language;
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'phone': phone}),
      );
      if (response.statusCode == 200) {
        return _unwrapResponseMap(response);
      }
      final err = _errorContextFromBody(response.body);
      throw ApiFieldException(
        err['detail']?.toString() ??
            err['message']?.toString() ??
            _translateError('registrationFailed', locale: locale),
        err,
      );
    } catch (e) {
      if (e is ApiFieldException) rethrow;
      rethrow;
    }
  }

  /// POST /api/auth/register/phone/verify-otp/
  Future<Map<String, dynamic>> registerPhoneVerifyOtp({
    required String phone,
    required String code,
    String language = 'en',
  }) async {
    final cleanEndpoint = '/auth/register/phone/verify-otp/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');
    final locale = language == 'ar' ? AppLocales.arabic : AppLocales.english;
    try {
      final headers = await _getHeaders(includeAuth: false);
      headers['Accept-Language'] = language;
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'phone': phone, 'code': code}),
      );
      if (response.statusCode == 200) {
        return _unwrapResponseMap(response);
      }
      final err = _errorContextFromBody(response.body);
      throw ApiFieldException(
        err['detail']?.toString() ??
            err['message']?.toString() ??
            _translateError('verificationFailed', locale: locale),
        err,
      );
    } catch (e) {
      if (e is ApiFieldException) rethrow;
      rethrow;
    }
  }

  /// تسجيل شركة جديدة مع المالك
  /// POST /api/auth/register/
  Future<Map<String, dynamic>> registerCompany({
    required Map<String, dynamic> company,
    required Map<String, dynamic> owner,
    required String phoneVerificationToken,
    int? planId,
    String billingCycle = 'monthly',
    String language = 'en',
  }) async {
    final cleanEndpoint = '/auth/register/';
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl$cleanEndpoint');

    final locale = language == 'ar' ? AppLocales.arabic : AppLocales.english;

    try {
      final requestBody = <String, dynamic>{
        'company': company,
        'owner': owner,
        'phone_verification_token': phoneVerificationToken,
      };

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
        final data = _unwrapResponseMap(response);

        // Save tokens if available
        if (data['access'] != null && data['refresh'] != null) {
          await AuthTokenStorage.instance.writeTokens(
            access: data['access'] as String,
            refresh: data['refresh'] as String,
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
          final error = _errorContextFromBody(response.body);
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

        ErrorLogger().logError(
          error: errorMessage,
          endpoint: cleanEndpoint,
          method: 'POST',
          statusCode: response.statusCode,
          responseBody: response.body,
        );

        throw ApiFieldException(errorMessage, fieldErrors);
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
          final error = _errorContextFromBody(response.body);
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

        throw ApiFieldException(errorMessage, fieldErrors);
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
        final data = _unwrapResponseDynamic(response);
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
    final data = _unwrapResponseDynamic(response);
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
        final err = _errorContextFromBody(response.body);
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
    return _unwrapResponseMap(response);
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
        return _unwrapResponseMap(response);
      } else {
        String errorMessage = 'Email verification failed';
        try {
          final error = _errorContextFromBody(response.body);
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

  /// POST /auth/pre-login/email/resend/ — password + username, no JWT.
  Future<Map<String, dynamic>> preLoginEmailResend({
    required String username,
    required String password,
  }) async {
    final cleanBaseUrl =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBaseUrl/auth/pre-login/email/resend/');
    final response = await http.post(
      url,
      headers: await _getHeaders(includeAuth: false),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapResponseMap(response);
    }
    final ctx = _errorContextFromBody(response.body);
    throw Exception(ctx['message']?.toString() ?? 'Failed to resend verification email');
  }

  /// POST /auth/pre-login/email/change/
  Future<Map<String, dynamic>> preLoginEmailChange({
    required String username,
    required String password,
    required String newEmail,
  }) async {
    final cleanBaseUrl =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBaseUrl/auth/pre-login/email/change/');
    final response = await http.post(
      url,
      headers: await _getHeaders(includeAuth: false),
      body: jsonEncode({
        'username': username,
        'password': password,
        'new_email': newEmail.trim().toLowerCase(),
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapResponseMap(response);
    }
    final ctx = _errorContextFromBody(response.body);
    throw Exception(ctx['message']?.toString() ?? 'Failed to update email');
  }

  /// POST /auth/pre-login/phone/send-otp/
  Future<Map<String, dynamic>> preLoginPhoneSendOtp({
    required String username,
    required String password,
  }) async {
    final cleanBaseUrl =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBaseUrl/auth/pre-login/phone/send-otp/');
    final response = await http.post(
      url,
      headers: await _getHeaders(includeAuth: false),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapResponseMap(response);
    }
    final ctx = _errorContextFromBody(response.body);
    throw Exception(ctx['message']?.toString() ?? 'Failed to send verification code');
  }

  /// POST /auth/pre-login/phone/verify-otp/
  Future<Map<String, dynamic>> preLoginPhoneVerifyOtp({
    required String username,
    required String password,
    required String code,
  }) async {
    final cleanBaseUrl =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBaseUrl/auth/pre-login/phone/verify-otp/');
    final response = await http.post(
      url,
      headers: await _getHeaders(includeAuth: false),
      body: jsonEncode({
        'username': username,
        'password': password,
        'code': code.trim(),
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapResponseMap(response);
    }
    final ctx = _errorContextFromBody(response.body);
    throw Exception(ctx['message']?.toString() ?? 'Verification failed');
  }

  /// POST /auth/pre-login/phone/change/
  Future<Map<String, dynamic>> preLoginPhoneChange({
    required String username,
    required String password,
    required String newPhone,
  }) async {
    final cleanBaseUrl =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBaseUrl/auth/pre-login/phone/change/');
    final response = await http.post(
      url,
      headers: await _getHeaders(includeAuth: false),
      body: jsonEncode({
        'username': username,
        'password': password,
        'new_phone': newPhone.trim(),
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapResponseMap(response);
    }
    final ctx = _errorContextFromBody(response.body);
    throw Exception(ctx['message']?.toString() ?? 'Failed to update phone');
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
      return _unwrapResponseMap(response);
    }
    String errorMessage = 'Failed to create payment session';
    try {
      final error = _errorContextFromBody(response.body);
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

      // Use shared header builder so trusted-device token is sent for login too.
      final headers = await _getHeaders(includeAuth: false);
      if ((headers['X-API-Key'] ?? '').isNotEmpty) {
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
        final data = _unwrapResponseMap(response);

        final requiresTwoFactorRaw = data['requires_two_factor'];
        final requiresTwoFactor = requiresTwoFactorRaw == true ||
            requiresTwoFactorRaw?.toString().toLowerCase() == 'true';

        // Owner-only: if backend requires 2FA, it will return a 2FA token but
        // typically not access/refresh tokens yet.
        if (requiresTwoFactor) {
          final tokenRaw = data['token'];
          final token = tokenRaw is String ? tokenRaw : tokenRaw?.toString();
          if (token == null || token.trim().isEmpty) {
            throw Exception('2FA token missing from login response');
          }
          return {
            'requires_two_factor': true,
            'token': token,
            'user': data['user'],
            'sent': data['sent'],
            'message': data['message'],
          };
        }

        // Normal login: Save tokens then fetch user snapshot.
        final accessRaw = data['access'];
        final refreshRaw = data['refresh'];
        final access = accessRaw is String ? accessRaw : accessRaw?.toString();
        final refresh = refreshRaw is String ? refreshRaw : refreshRaw?.toString();

        if (access == null || access.trim().isEmpty || refresh == null || refresh.trim().isEmpty) {
          throw Exception('Login succeeded but tokens were missing');
        }

        await AuthTokenStorage.instance.writeTokens(
          access: access,
          refresh: refresh,
        );

        final userResponse = await getCurrentUser();
        return {
          'success': true,
          'requires_two_factor': false,
          'user': userResponse,
        };
      } else {
        String errorMessage;
        SubscriptionInactiveException? subscriptionInactiveException;
        try {
          final error = _errorContextFromBody(response.body);
          final loginVerification = LoginVerificationRequiredException.tryParse(error);
          if (loginVerification != null) {
            ErrorLogger().logError(
              error: loginVerification.message,
              endpoint: '/auth/login/',
              method: 'POST',
              requestData: {'username': username},
              statusCode: response.statusCode,
              responseBody: response.body,
            );
            throw loginVerification;
          }
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

            // subscription_inactive is used for subscription gating (owners/admins).
            if (ApiEnvelope.codeEquals(error['code'], 'subscription_inactive') ||
                backendError.toString().toLowerCase().contains('subscription') ||
                backendError.toString().toLowerCase().contains('not active')) {
              final subIdRaw = error['subscriptionId'] ?? error['subscription_id'];
              int? subId;
              if (subIdRaw is int) {
                subId = subIdRaw;
              } else if (subIdRaw is num) {
                subId = subIdRaw.toInt();
              } else if (subIdRaw is String) {
                subId = int.tryParse(subIdRaw);
              }

              errorMessage = backendError.isNotEmpty
                  ? backendError.toString()
                  : _translateError(
                      'subscriptionNotActive',
                      locale: locale ?? const Locale('en'),
                    );
              subscriptionInactiveException = SubscriptionInactiveException(
                errorMessage,
                subscriptionId: subId,
              );
            } else {
              errorMessage = backendError.isNotEmpty
                  ? backendError.toString()
                  : _translateError(
                      'loginFailed',
                      locale: locale ?? const Locale('en'),
                    );
            }
          }
          debugPrint('Login error: $errorMessage');
          debugPrint('Response body: ${response.body}');
        } catch (e) {
          if (e is LoginVerificationRequiredException) {
            rethrow;
          }
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

        if (subscriptionInactiveException != null) {
          throw subscriptionInactiveException;
        }
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
    final locale = language == 'ar' ? AppLocales.arabic : AppLocales.english;

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
        final data = _unwrapResponseMap(response);
        return data;
      } else {
        String errorMessage = _translateError(
          'failedToRequest2FACode',
          locale: locale,
        );
        Exception? customException;

        try {
          final error = _errorContextFromBody(response.body);

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
          final loginVerification = LoginVerificationRequiredException.tryParse(error);
          if (loginVerification != null) {
            customException = loginVerification;
          } else if (ApiEnvelope.codeEquals(error['code'], 'subscription_inactive') ||
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
          } else if (ApiEnvelope.codeEquals(
                error['code'],
                'account_temporarily_inactive',
              )) {
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
              (customException != null
                  ? ApiErrorHelper.cleanException(customException)
                  : null) ??
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
      if (e is LoginVerificationRequiredException) {
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
    bool? trustDevice,
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
      if (trustDevice != null) {
        requestBody['trust_device'] = trustDevice;
      }

      // Get headers with API Key (no auth token needed for 2FA verification)
      final headers = await _getHeaders(includeAuth: false);

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = _unwrapResponseMap(response);

        // Save tokens
        if (data['access'] != null && data['refresh'] != null) {
          await AuthTokenStorage.instance.writeTokens(
            access: data['access'] as String,
            refresh: data['refresh'] as String,
          );
        }

        // Persist owner trusted-device token for future login attempts on mobile.
        final trustedDeviceTokenRaw = data['trusted_device_token'];
        final trustedDeviceToken = trustedDeviceTokenRaw is String
            ? trustedDeviceTokenRaw.trim()
            : trustedDeviceTokenRaw?.toString().trim();
        if (trustedDeviceToken != null && trustedDeviceToken.isNotEmpty) {
          await AuthTokenStorage.instance.writeTrustedDeviceToken(
            trustedDeviceToken,
          );
        }

        return data;
      } else {
        String errorMessage = _translateError(
          'failedToVerify2FACode',
          locale: locale ?? const Locale('en'),
        );
        try {
          final error = _errorContextFromBody(response.body);
          errorMessage =
              error['detail'] ??
              error['error'] ??
              error['message'] ??
              errorMessage;

          final loginVerification = LoginVerificationRequiredException.tryParse(error);
          if (loginVerification != null) {
            throw loginVerification;
          }

          // Handle special error codes
          if (ApiEnvelope.codeEquals(
                error['code'],
                'account_temporarily_inactive',
              )) {
            final accountError = Exception('ACCOUNT_TEMPORARILY_INACTIVE');
            (accountError as dynamic).code = 'ACCOUNT_TEMPORARILY_INACTIVE';
            throw accountError;
          }

          if (ApiEnvelope.codeEquals(error['code'], 'subscription_inactive') ||
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
          if (e is LoginVerificationRequiredException) {
            rethrow;
          }
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
      if (e is LoginVerificationRequiredException) {
        rethrow;
      }
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

  /// Public mobile policy (no JWT). Used for forced-update gate.
  Future<MobileAppVersionPolicy> fetchMobileAppVersionPolicy() async {
    final response = await _makeRequest(
      'GET',
      '/public/mobile-app-version/',
      includeAuth: false,
      retryOn401: false,
    );
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      return MobileAppVersionPolicy.fromJson(data);
    }
    throw Exception('Mobile app version policy HTTP ${response.statusCode}');
  }

  // Get current user
  Future<UserModel> getCurrentUser({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'current_user';
    final cached = _cacheGet<UserModel>(cacheKey, forceRefresh: forceRefresh);
    if (cached != null) return cached;

    final response = await _makeRequest('GET', '/users/me/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final user = UserModel.fromJson(data);
      _cacheSet<UserModel>(cacheKey, user, ttl: cacheTtl);
      return user;
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
        final data = _unwrapResponseMap(response);
        final user = UserModel.fromJson(data);
        _invalidateUserCache();
        return user;
      } else {
        String errorMessage = _translateError(
          'failedToUpdateProfile',
          locale: null,
        );
        try {
          final error = _errorContextFromBody(response.body);
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
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    // Get current user to check role
    final currentUser = await getCurrentUser(forceRefresh: forceRefresh);
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
    final cacheKey = _cacheKey('leads', queryParams);
    final cachedResponse = _cacheGet<Map<String, dynamic>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cachedResponse != null) return cachedResponse;

    final response = await _makeRequest('GET', '/clients/$queryString');

    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final resultsList = data['results'] as List?;
      final results = resultsList != null
          ? resultsList
                .map((e) => LeadModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : <LeadModel>[];

      final result = {
        'results': results,
        'count': (data['count'] as num?)?.toInt() ?? 0,
        'next': data['next'] as String?,
        'previous': data['previous'] as String?,
      };
      _cacheSet<Map<String, dynamic>>(cacheKey, result, ttl: cacheTtl);
      return result;
    } else {
      throw Exception(_translateError('failedToGetLeads', locale: null));
    }
  }

  // Get lead by ID
  Future<LeadModel> getLeadById(int id) async {
    final response = await _makeRequest('GET', '/clients/$id/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
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
      final error = _errorContextFromBody(response.body);
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
      final data = _unwrapResponseMap(response);
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
      final data = _unwrapResponseMap(response);
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
      final error = _errorContextFromBody(response.body);
      throw Exception(
        error['detail'] ??
            error['message'] ??
            _translateError('failedToAddCall', locale: null),
      );
    }
  }

  /// Send SMS to a lead via Twilio (CRM integration).
  /// POST /integrations/twilio/send/
  Future<void> sendLeadSMS({
    required int leadId,
    required String phoneNumber,
    required String body,
  }) async {
    final response = await _makeRequest(
      'POST',
      '/integrations/twilio/send/',
      body: <String, dynamic>{
        'lead_id': leadId,
        'phone_number': phoneNumber,
        'body': body,
      },
      timeout: const Duration(seconds: 15),
    );

    if (response.statusCode != 201) {
      final data = _errorContextFromBody(response.body);
      final errorKey = data['error_key'] as String?;
      final fallback = _resolveApiErrorMessage(
        data,
        fallbackKey: errorKey ?? 'failedToSendSms',
      );
      throw SmsException(errorKey ?? 'failedToSendSms', fallback);
    }
  }

  // Get client calls for a lead
  Future<List<ClientCallModel>> getClientCalls(int leadId) async {
    final response = await _makeRequest('GET', '/client-calls/?client=$leadId');

    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
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

  /// Log a site/office visit (real_estate / services companies only).
  Future<void> addVisitToLead({
    required int leadId,
    required int visitType,
    required String summary,
    required DateTime visitDatetime,
    DateTime? upcomingVisitDate,
  }) async {
    final body = <String, dynamic>{
      'client': leadId,
      'visit_type': visitType,
      'summary': summary,
      'visit_datetime': visitDatetime.toIso8601String(),
    };
    if (upcomingVisitDate != null) {
      body['upcoming_visit_date'] = upcomingVisitDate.toIso8601String();
    }

    final response = await _makeRequest('POST', '/client-visits/', body: body);

    if (response.statusCode != 201) {
      final error = _errorContextFromBody(response.body);
      throw Exception(
        error['detail'] ??
            error['message'] ??
            _translateError('failedToAddVisit', locale: null),
      );
    }
  }

  Future<List<ClientVisitModel>> getClientVisits(int leadId) async {
    final response = await _makeRequest('GET', '/client-visits/?client=$leadId');

    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final resultsList = data['results'] as List?;
      final results = resultsList != null
          ? resultsList
              .map((e) => ClientVisitModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : <ClientVisitModel>[];
      return results;
    } else {
      throw Exception(_translateError('failedToGetClientVisits', locale: null));
    }
  }

  // Get all client calls for calendar
  Future<List<ClientCallModel>> getAllClientCalls() async {
    final response = await _makeRequest('GET', '/client-calls/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
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
      final data = _unwrapResponseMap(response);
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
    double? budgetMax,
    int? assignedTo,
    required String type,
    String? communicationWay, // Deprecated: use communicationWayId instead
    int? communicationWayId, // Preferred: channel ID
    String? priority,
    String? status, // Deprecated: use statusId instead
    int? statusId, // Preferred: status ID
    String? leadCompanyName,
    String? profession,
    String? notes,
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
    if (budgetMax != null) body['budget_max'] = budgetMax;
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

    // Always send lead_company_name when provided (including null/empty to clear)
    if (leadCompanyName != null) {
      body['lead_company_name'] = leadCompanyName.trim().isEmpty ? null : leadCompanyName.trim();
    }
    if (profession != null) {
      body['profession'] = profession.trim().isEmpty ? null : profession.trim();
    }
    if (notes != null) {
      body['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }

    final response = await _makeRequest('POST', '/clients/', body: body);

    if (response.statusCode == 201) {
      final data = _unwrapResponseMap(response);
      final lead = LeadModel.fromJson(data);
      _invalidateLeadsCache();
      return lead;
    } else {
      String errorMessage = _translateError('failedToCreateLead', locale: null);
      try {
        final error = _errorContextFromBody(response.body);
        errorMessage = _resolveApiErrorMessage(
          error,
          fallbackKey: 'failedToCreateLead',
        );
      } catch (_) {}
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
    double? budgetMax,
    bool sendBudgetMax = false,
    int? assignedTo,
    String? type,
    String? communicationWay, // Deprecated: use communicationWayId instead
    int? communicationWayId, // Preferred: channel ID
    String? priority,
    String? status, // Deprecated: use statusId instead
    int? statusId, // Preferred: status ID
    String? leadCompanyName,
    String? profession,
    String? notes,
  }) async {
    final body = <String, dynamic>{};

    if (name != null) body['name'] = name;
    if (phone != null) body['phone_number'] = phone;
    if (phoneNumbers != null) body['phone_numbers'] = phoneNumbers;
    if (budget != null) body['budget'] = budget;
    if (sendBudgetMax) {
      body['budget_max'] = budgetMax;
    }
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

    // Always send lead_company_name when provided (so API can set or clear the field)
    if (leadCompanyName != null) {
      body['lead_company_name'] = leadCompanyName.trim().isEmpty ? null : leadCompanyName.trim();
    }
    if (profession != null) {
      body['profession'] = profession.trim().isEmpty ? null : profession.trim();
    }
    if (notes != null) {
      body['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }

    final response = await _makeRequest('PATCH', '/clients/$id/', body: body);

    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final lead = LeadModel.fromJson(data);
      _invalidateLeadsCache();
      return lead;
    } else {
      final error = _errorContextFromBody(response.body);
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
      final error = _errorContextFromBody(response.body);
      throw Exception(
        error['detail'] ??
            error['message'] ??
            _translateError('failedToDeleteLead', locale: null),
      );
    }
    _invalidateLeadsCache();
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
      final error = _errorContextFromBody(response.body);
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
      final data = _unwrapResponseMap(response);
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
      final data = _unwrapResponseMap(response);
      return UserModel.fromJson(data);
    } else {
      throw Exception(_translateError('failedToGetUser', locale: null));
    }
  }

  // Get deals (legacy method - kept for backward compatibility)
  Future<Map<String, dynamic>> getDeals({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'deals_legacy';
    final cached = _cacheGet<Map<String, dynamic>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;

    final response = await _makeRequest('GET', '/deals/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final resultsList = data['results'] as List?;

      final result = {
        'results': resultsList ?? [],
        'count': (data['count'] as num?)?.toInt() ?? 0,
      };
      _cacheSet<Map<String, dynamic>>(cacheKey, result, ttl: cacheTtl);
      return result;
    } else {
      throw Exception(_translateError('failedToGetDeals', locale: null));
    }
  }

  // Get deals as list of DealModel
  Future<List<DealModel>> getDealsList({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'deals_list';
    final cached = _cacheGet<List<DealModel>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;

    final response = await _makeRequest('GET', '/deals/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final deals = results
          .map((json) => DealModel.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<DealModel>>(cacheKey, deals, ttl: cacheTtl);
      return deals;
    }
    throw Exception(_translateError('failedToLoadDeals', locale: null));
  }

  Future<DealModel> getDeal(int dealId) async {
    final response = await _makeRequest('GET', '/deals/$dealId/');
    if (response.statusCode == 200) {
      final json = _unwrapResponseMap(response);
      return DealModel.fromJson(json);
    }
    String errorMessage = _translateError('failedToLoadDeals', locale: null);
    try {
      final error = _errorContextFromBody(response.body);
      errorMessage = _resolveApiErrorMessage(
        error,
        fallbackKey: 'failedToLoadDeals',
      );
    } catch (_) {
      errorMessage =
          'Failed to load deal with status ${response.statusCode}';
    }
    throw Exception(errorMessage);
  }

  // Update deal
  Future<DealModel> createDeal(Map<String, dynamic> data) async {
    final response = await _makeRequest('POST', '/deals/', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = _unwrapResponseMap(response);
      final deal = DealModel.fromJson(json);
      _invalidateDealsCache();
      return deal;
    } else {
      String errorMessage = _translateError('failedToCreateDeal', locale: null);
      try {
        final error = _errorContextFromBody(response.body);
        errorMessage = _resolveApiErrorMessage(
          error,
          fallbackKey: 'failedToCreateDeal',
        );
      } catch (_) {
        errorMessage = _translateError('failedToCreateDealWithStatus', locale: null);
      }
      throw Exception(errorMessage);
    }
  }

  Future<DealModel> updateDeal(int dealId, Map<String, dynamic> data) async {
    final response = await _makeRequest('PUT', '/deals/$dealId/', body: data);
    if (response.statusCode == 200) {
      final json = _unwrapResponseMap(response);
      final deal = DealModel.fromJson(json);
      _invalidateDealsCache();
      return deal;
    } else {
      String errorMessage = 'Failed to update deal';
      try {
        final error = _errorContextFromBody(response.body);
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
        final error = _errorContextFromBody(response.body);
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete deal with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
    _invalidateDealsCache();
  }

  // ==================== Settings APIs (Channels, Stages, Statuses) ====================

  // Channels CRUD
  Future<List<ChannelModel>> getChannels({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'settings_channels';
    final cached = _cacheGet<List<ChannelModel>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;

    final response = await _makeRequest('GET', '/settings/channels/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseDynamic(response);
      if (data is List) {
        final channels = data
            .map((item) => ChannelModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _cacheSet<List<ChannelModel>>(cacheKey, channels, ttl: cacheTtl);
        return channels;
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        final channels = results
            .map((item) => ChannelModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _cacheSet<List<ChannelModel>>(cacheKey, channels, ttl: cacheTtl);
        return channels;
      }
      _cacheSet<List<ChannelModel>>(cacheKey, <ChannelModel>[], ttl: cacheTtl);
      return [];
    } else {
      throw Exception(_translateError('failedToGetChannels', locale: null));
    }
  }

  Future<ChannelModel> createChannel({
    required String name,
    required String type,
    required String priority,
    bool isDefault = false,
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
        'is_default': isDefault,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final channel = ChannelModel.fromJson(data);
      _invalidateSettingsCache();
      return channel;
    } else {
      String errorMessage = 'Failed to create channel';
      try {
        final error = _errorContextFromBody(response.body);
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
    bool isDefault = false,
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
        'is_default': isDefault,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final channel = ChannelModel.fromJson(data);
      _invalidateSettingsCache();
      return channel;
    } else {
      String errorMessage = 'Failed to update channel';
      try {
        final error = _errorContextFromBody(response.body);
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
        final error = _errorContextFromBody(response.body);
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete channel with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
    _invalidateSettingsCache();
  }

  // Stages CRUD
  Future<List<StageModel>> getStages({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'settings_stages';
    final cached = _cacheGet<List<StageModel>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/settings/stages/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseDynamic(response);
      if (data is List) {
        final stages = data
            .map((item) => StageModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _cacheSet<List<StageModel>>(cacheKey, stages, ttl: cacheTtl);
        return stages;
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        final stages = results
            .map((item) => StageModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _cacheSet<List<StageModel>>(cacheKey, stages, ttl: cacheTtl);
        return stages;
      }
      _cacheSet<List<StageModel>>(cacheKey, <StageModel>[], ttl: cacheTtl);
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
    bool isDefault = false,
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
        'is_default': isDefault,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final stage = StageModel.fromJson(data);
      _invalidateSettingsCache();
      return stage;
    } else {
      String errorMessage = 'Failed to create stage';
      try {
        final error = _errorContextFromBody(response.body);
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
    bool isDefault = false,
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
        'is_default': isDefault,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final stage = StageModel.fromJson(data);
      _invalidateSettingsCache();
      return stage;
    } else {
      String errorMessage = 'Failed to update stage';
      try {
        final error = _errorContextFromBody(response.body);
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
        final error = _errorContextFromBody(response.body);
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete stage with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
    _invalidateSettingsCache();
  }

  // Statuses CRUD
  Future<List<StatusModel>> getStatuses({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'settings_statuses';
    final cached = _cacheGet<List<StatusModel>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/settings/statuses/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseDynamic(response);
      if (data is List) {
        final statuses = data
            .map((item) => StatusModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _cacheSet<List<StatusModel>>(cacheKey, statuses, ttl: cacheTtl);
        return statuses;
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        final statuses = results
            .map((item) => StatusModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _cacheSet<List<StatusModel>>(cacheKey, statuses, ttl: cacheTtl);
        return statuses;
      }
      _cacheSet<List<StatusModel>>(cacheKey, <StatusModel>[], ttl: cacheTtl);
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
    int? autoDeleteAfterHours,
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

    final body = <String, dynamic>{
      'name': name,
      'description': description,
      'category': normalizedCategory,
      'color': color,
      'is_default': isDefault,
      'is_hidden': isHidden,
      'company': currentUser.company!.id,
    };
    if (autoDeleteAfterHours != null) {
      body['auto_delete_after_hours'] = autoDeleteAfterHours;
    }

    final response = await _makeRequest(
      'POST',
      '/settings/statuses/',
      body: body,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final status = StatusModel.fromJson(data);
      _invalidateSettingsCache();
      return status;
    } else {
      String errorMessage = 'Failed to create status';
      try {
        final error = _errorContextFromBody(response.body);
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
    bool includeAutoDeleteAfterHours = false,
    int? autoDeleteAfterHours,
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

    final body = <String, dynamic>{
      'name': name,
      'description': description,
      'category': normalizedCategory,
      'color': color,
      'is_default': isDefault,
      'is_hidden': isHidden,
      'company': currentUser.company!.id,
    };
    if (includeAutoDeleteAfterHours) {
      body['auto_delete_after_hours'] = autoDeleteAfterHours;
    }

    final response = await _makeRequest(
      'PATCH',
      '/settings/statuses/$statusId/',
      body: body,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final status = StatusModel.fromJson(data);
      _invalidateSettingsCache();
      return status;
    } else {
      String errorMessage = 'Failed to update status';
      try {
        final error = _errorContextFromBody(response.body);
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
        final error = _errorContextFromBody(response.body);
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete status with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
    _invalidateSettingsCache();
  }

  // Call Methods CRUD
  Future<List<CallMethodModel>> getCallMethods({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'settings_call_methods';
    final cached = _cacheGet<List<CallMethodModel>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/settings/call-methods/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseDynamic(response);
      if (data is List) {
        final methods = data
            .map(
              (item) => CallMethodModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        _cacheSet<List<CallMethodModel>>(cacheKey, methods, ttl: cacheTtl);
        return methods;
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        final methods = results
            .map(
              (item) => CallMethodModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        _cacheSet<List<CallMethodModel>>(cacheKey, methods, ttl: cacheTtl);
        return methods;
      }
      _cacheSet<List<CallMethodModel>>(
        cacheKey,
        <CallMethodModel>[],
        ttl: cacheTtl,
      );
      return [];
    } else {
      throw Exception(_translateError('failedToGetCallMethods', locale: null));
    }
  }

  Future<CallMethodModel> createCallMethod({
    required String name,
    String? description,
    required String color,
    bool isDefault = false,
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
        'is_default': isDefault,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final method = CallMethodModel.fromJson(data);
      _invalidateSettingsCache();
      return method;
    } else {
      String errorMessage = 'Failed to create call method';
      try {
        final error = _errorContextFromBody(response.body);
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
    bool isDefault = false,
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
        'is_default': isDefault,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final method = CallMethodModel.fromJson(data);
      _invalidateSettingsCache();
      return method;
    } else {
      String errorMessage = 'Failed to update call method';
      try {
        final error = _errorContextFromBody(response.body);
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
        final error = _errorContextFromBody(response.body);
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete call method with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
    _invalidateSettingsCache();
  }

  // Visit types CRUD (settings; real_estate / services)
  Future<List<VisitTypeModel>> getVisitTypes({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'settings_visit_types';
    final cached = _cacheGet<List<VisitTypeModel>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/settings/visit-types/');

    if (response.statusCode == 200) {
      final data = _unwrapResponseDynamic(response);
      if (data is List) {
        final visitTypes = data
            .map((item) => VisitTypeModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _cacheSet<List<VisitTypeModel>>(cacheKey, visitTypes, ttl: cacheTtl);
        return visitTypes;
      } else if (data is Map && data['results'] != null) {
        final results = data['results'] as List;
        final visitTypes = results
            .map((item) => VisitTypeModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _cacheSet<List<VisitTypeModel>>(cacheKey, visitTypes, ttl: cacheTtl);
        return visitTypes;
      }
      _cacheSet<List<VisitTypeModel>>(cacheKey, <VisitTypeModel>[], ttl: cacheTtl);
      return [];
    } else {
      throw Exception(_translateError('failedToGetVisitTypes', locale: null));
    }
  }

  Future<VisitTypeModel> createVisitType({
    required String name,
    String? description,
    required String color,
    bool isDefault = false,
  }) async {
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final response = await _makeRequest(
      'POST',
      '/settings/visit-types/',
      body: {
        'name': name,
        'description': description,
        'color': color,
        'company': currentUser.company!.id,
        'is_default': isDefault,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final visitType = VisitTypeModel.fromJson(data);
      _invalidateSettingsCache();
      return visitType;
    } else {
      String errorMessage = 'Failed to create visit type';
      try {
        final error = _errorContextFromBody(response.body);
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to create visit type with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<VisitTypeModel> updateVisitType({
    required int visitTypeId,
    required String name,
    String? description,
    required String color,
    bool isDefault = false,
  }) async {
    final currentUser = await getCurrentUser();
    if (currentUser.company == null) {
      throw Exception(
        _translateError('userMustBeAssociatedWithCompany', locale: null),
      );
    }

    final response = await _makeRequest(
      'PUT',
      '/settings/visit-types/$visitTypeId/',
      body: {
        'name': name,
        'description': description,
        'color': color,
        'company': currentUser.company!.id,
        'is_default': isDefault,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _unwrapResponseMap(response);
      final visitType = VisitTypeModel.fromJson(data);
      _invalidateSettingsCache();
      return visitType;
    } else {
      String errorMessage = 'Failed to update visit type';
      try {
        final error = _errorContextFromBody(response.body);
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to update visit type with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteVisitType(int visitTypeId) async {
    final response = await _makeRequest(
      'DELETE',
      '/settings/visit-types/$visitTypeId/',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Failed to delete visit type';
      try {
        final error = _errorContextFromBody(response.body);
        errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
      } catch (_) {
        errorMessage =
            'Failed to delete visit type with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
    _invalidateSettingsCache();
  }

  // ==================== Real Estate Inventory APIs ====================

  // Developers
  Future<List<Developer>> getDevelopers({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_developers';
    final cached = _cacheGet<List<Developer>>(cacheKey, forceRefresh: forceRefresh);
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/developers/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final developers = results
          .map((json) => Developer.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<Developer>>(cacheKey, developers, ttl: cacheTtl);
      return developers;
    }
    throw Exception(_translateError('failedToLoadDevelopers', locale: null));
  }

  // Projects
  Future<List<Project>> getProjects({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_projects';
    final cached = _cacheGet<List<Project>>(cacheKey, forceRefresh: forceRefresh);
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/projects/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final projects = results
          .map((json) => Project.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<Project>>(cacheKey, projects, ttl: cacheTtl);
      return projects;
    }
    throw Exception(_translateError('failedToLoadProjects', locale: null));
  }

  // Units
  Future<List<Unit>> getUnits({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_units';
    final cached = _cacheGet<List<Unit>>(cacheKey, forceRefresh: forceRefresh);
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/units/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final units = results
          .map((json) => Unit.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<Unit>>(cacheKey, units, ttl: cacheTtl);
      return units;
    }
    throw Exception(_translateError('failedToLoadUnits', locale: null));
  }

  // Owners
  Future<List<Owner>> getOwners({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_owners';
    final cached = _cacheGet<List<Owner>>(cacheKey, forceRefresh: forceRefresh);
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/owners/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final owners = results
          .map((json) => Owner.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<Owner>>(cacheKey, owners, ttl: cacheTtl);
      return owners;
    }
    throw Exception(_translateError('failedToLoadOwners', locale: null));
  }

  // ==================== Services Inventory APIs ====================

  // Services
  Future<List<Service>> getServices({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_services';
    final cached = _cacheGet<List<Service>>(cacheKey, forceRefresh: forceRefresh);
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/services/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final services = results
          .map((json) => Service.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<Service>>(cacheKey, services, ttl: cacheTtl);
      return services;
    }
    throw Exception(_translateError('failedToLoadServices', locale: null));
  }

  // Service Packages
  Future<List<ServicePackage>> getServicePackages({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_service_packages';
    final cached = _cacheGet<List<ServicePackage>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/service-packages/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final packages = results
          .map((json) => ServicePackage.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<ServicePackage>>(cacheKey, packages, ttl: cacheTtl);
      return packages;
    }
    throw Exception(
      _translateError('failedToLoadServicePackages', locale: null),
    );
  }

  // Service Providers
  Future<List<ServiceProvider>> getServiceProviders({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_service_providers';
    final cached = _cacheGet<List<ServiceProvider>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/service-providers/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final providers = results
          .map((json) => ServiceProvider.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<ServiceProvider>>(cacheKey, providers, ttl: cacheTtl);
      return providers;
    }
    throw Exception(
      _translateError('failedToLoadServiceProviders', locale: null),
    );
  }

  // ==================== Products Inventory APIs ====================

  // Products
  Future<List<Product>> getProducts({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_products';
    final cached = _cacheGet<List<Product>>(cacheKey, forceRefresh: forceRefresh);
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/products/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final products = results
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<Product>>(cacheKey, products, ttl: cacheTtl);
      return products;
    }
    throw Exception(_translateError('failedToLoadProducts', locale: null));
  }

  // Product Categories
  Future<List<ProductCategory>> getProductCategories({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_product_categories';
    final cached = _cacheGet<List<ProductCategory>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/product-categories/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final categories = results
          .map((json) => ProductCategory.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<ProductCategory>>(cacheKey, categories, ttl: cacheTtl);
      return categories;
    }
    throw Exception(
      _translateError('failedToLoadProductCategories', locale: null),
    );
  }

  // Suppliers
  Future<List<Supplier>> getSuppliers({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    const cacheKey = 'inventory_suppliers';
    final cached = _cacheGet<List<Supplier>>(cacheKey, forceRefresh: forceRefresh);
    if (cached != null) return cached;
    final response = await _makeRequest('GET', '/suppliers/');
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final suppliers = results
          .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
          .toList();
      _cacheSet<List<Supplier>>(cacheKey, suppliers, ttl: cacheTtl);
      return suppliers;
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
      final data = _unwrapResponseMap(response);
      final product = Product.fromJson(data);
      _invalidateInventoryCache();
      return product;
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
      final data = _unwrapResponseMap(response);
      final product = Product.fromJson(data);
      _invalidateInventoryCache();
      return product;
    }
    throw Exception('Failed to update product');
  }

  Future<void> deleteProduct(int id) async {
    final response = await _makeRequest('DELETE', '/products/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete product');
    }
    _invalidateInventoryCache();
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
      final data = _unwrapResponseMap(response);
      final category = ProductCategory.fromJson(data);
      _invalidateInventoryCache();
      return category;
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
      final data = _unwrapResponseMap(response);
      final category = ProductCategory.fromJson(data);
      _invalidateInventoryCache();
      return category;
    }
    throw Exception('Failed to update product category');
  }

  Future<void> deleteProductCategory(int id) async {
    final response = await _makeRequest('DELETE', '/product-categories/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete product category');
    }
    _invalidateInventoryCache();
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
      final data = _unwrapResponseMap(response);
      final supplier = Supplier.fromJson(data);
      _invalidateInventoryCache();
      return supplier;
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
      final data = _unwrapResponseMap(response);
      final supplier = Supplier.fromJson(data);
      _invalidateInventoryCache();
      return supplier;
    }
    throw Exception('Failed to update supplier');
  }

  Future<void> deleteSupplier(int id) async {
    final response = await _makeRequest('DELETE', '/suppliers/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete supplier');
    }
    _invalidateInventoryCache();
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
      final data = _unwrapResponseMap(response);
      final service = Service.fromJson(data);
      _invalidateInventoryCache();
      return service;
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
      final data = _unwrapResponseMap(response);
      final service = Service.fromJson(data);
      _invalidateInventoryCache();
      return service;
    }
    throw Exception('Failed to update service');
  }

  Future<void> deleteService(int id) async {
    final response = await _makeRequest('DELETE', '/services/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete service');
    }
    _invalidateInventoryCache();
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
      final data = _unwrapResponseMap(response);
      final package = ServicePackage.fromJson(data);
      _invalidateInventoryCache();
      return package;
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
      final data = _unwrapResponseMap(response);
      final package = ServicePackage.fromJson(data);
      _invalidateInventoryCache();
      return package;
    }
    throw Exception('Failed to update service package');
  }

  Future<void> deleteServicePackage(int id) async {
    final response = await _makeRequest('DELETE', '/service-packages/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete service package');
    }
    _invalidateInventoryCache();
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
      final data = _unwrapResponseMap(response);
      final provider = ServiceProvider.fromJson(data);
      _invalidateInventoryCache();
      return provider;
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
      final data = _unwrapResponseMap(response);
      final provider = ServiceProvider.fromJson(data);
      _invalidateInventoryCache();
      return provider;
    }
    throw Exception('Failed to update service provider');
  }

  Future<void> deleteServiceProvider(int id) async {
    final response = await _makeRequest('DELETE', '/service-providers/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete service provider');
    }
    _invalidateInventoryCache();
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
      final data = _unwrapResponseMap(response);
      final developer = Developer.fromJson(data);
      _invalidateInventoryCache();
      return developer;
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
      final data = _unwrapResponseMap(response);
      final developer = Developer.fromJson(data);
      _invalidateInventoryCache();
      return developer;
    }
    throw Exception('Failed to update developer');
  }

  Future<void> deleteDeveloper(int id) async {
    final response = await _makeRequest('DELETE', '/developers/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete developer');
    }
    _invalidateInventoryCache();
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
      final data = _unwrapResponseMap(response);
      final project = Project.fromJson(data);
      _invalidateInventoryCache();
      return project;
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
      final data = _unwrapResponseMap(response);
      final project = Project.fromJson(data);
      _invalidateInventoryCache();
      return project;
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
    _invalidateInventoryCache();
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
      final data = _unwrapResponseMap(response);
      final unit = Unit.fromJson(data);
      _invalidateInventoryCache();
      return unit;
    }
    throw Exception('Failed to create unit');
  }

  Future<Unit> updateUnit(int id, Map<String, dynamic> unitData) async {
    final response = await _makeRequest('PATCH', '/units/$id/', body: unitData);
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final unit = Unit.fromJson(data);
      _invalidateInventoryCache();
      return unit;
    }
    throw Exception('Failed to update unit');
  }

  Future<void> deleteUnit(int id) async {
    final response = await _makeRequest('DELETE', '/units/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete unit');
    }
    _invalidateInventoryCache();
  }

  // ==================== Support Tickets ====================

  /// GET /api/support-tickets/ - list current user's support tickets (paginated).
  Future<Map<String, dynamic>> getSupportTickets({
    int? page,
    int? pageSize,
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();
    if (pageSize != null) queryParams['page_size'] = pageSize.toString();
    final queryString =
        queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final cacheKey = _cacheKey('support_tickets', queryParams);
    final cached = _cacheGet<Map<String, dynamic>>(
      cacheKey,
      forceRefresh: forceRefresh,
    );
    if (cached != null) return cached;
    final response = await _makeRequest(
      'GET',
      '/support-tickets/$queryString',
      timeout: const Duration(seconds: 15),
    );
    if (response.statusCode == 200) {
      final data = _unwrapResponseMap(response);
      final results = data['results'] as List<dynamic>? ?? [];
      final tickets = results
          .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
          .toList();
      final payload = {
        'count': data['count'] as int? ?? tickets.length,
        'next': data['next'] as String?,
        'previous': data['previous'] as String?,
        'results': tickets,
      };
      _cacheSet<Map<String, dynamic>>(cacheKey, payload, ttl: cacheTtl);
      return payload;
    }
    throw Exception(
      _translateError('failedToLoadSupportTickets', locale: null),
    );
  }

  /// POST /api/support-tickets/ - create a support ticket (optionally with screenshot files).
  /// [screenshotPaths] - list of file paths (e.g. from image_picker) to upload as screenshots.
  Future<SupportTicket> createSupportTicket(
    String title,
    String description, {
    List<String>? screenshotPaths,
  }) async {
    final hasFiles = screenshotPaths != null && screenshotPaths.isNotEmpty;
    if (!hasFiles) {
      final response = await _makeRequest(
        'POST',
        '/support-tickets/',
        body: {'title': title, 'description': description},
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode == 201) {
        final data = _unwrapResponseMap(response);
        final ticket = SupportTicket.fromJson(data);
        _invalidateSupportCache();
        return ticket;
      }
      throw Exception(
        _translateError('failedToCreateSupportTicket', locale: null),
      );
    }

    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$cleanBaseUrl/support-tickets/');
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception(_translateError('notAuthenticated', locale: null));
    }

    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      final apiKey = AppConstants.apiKey;
      if (apiKey.isNotEmpty) {
        request.headers['X-API-Key'] = apiKey;
      }
      request.fields['title'] = title;
      request.fields['description'] = description;
      for (final path in screenshotPaths) {
        if (path.isEmpty) continue;
        final file = await http.MultipartFile.fromPath('screenshots', path);
        request.files.add(file);
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) {
        final data = _unwrapResponseMap(response);
        final ticket = SupportTicket.fromJson(data);
        _invalidateSupportCache();
        return ticket;
      }
      String msg = _translateError('failedToCreateSupportTicket', locale: null);
      try {
        final err = _errorContextFromBody(response.body);
        final detail = err['detail'] ?? err['message'];
        if (detail != null) msg = detail.toString();
      } catch (_) {}
      throw Exception(msg);
    } catch (e, stackTrace) {
      ErrorLogger().logError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        endpoint: '/support-tickets/',
        method: 'POST',
      );
      rethrow;
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
      final data = _unwrapResponseMap(response);
      final owner = Owner.fromJson(data);
      _invalidateInventoryCache();
      return owner;
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
      final data = _unwrapResponseMap(response);
      final owner = Owner.fromJson(data);
      _invalidateInventoryCache();
      return owner;
    }
    throw Exception('Failed to update owner');
  }

  Future<void> deleteOwner(int id) async {
    final response = await _makeRequest('DELETE', '/owners/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete owner');
    }
    _invalidateInventoryCache();
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
          final error = _errorContextFromBody(response.body);
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

  /// تحديث FCM Token وإرجاع النتيجة للتشخيص (status_code, success, message)
  Future<Map<String, dynamic>> updateFCMTokenAndGetResult(
    String fcmToken, {
    String? language,
  }) async {
    try {
      final body = {'fcm_token': fcmToken};
      if (language != null) body['language'] = language;
      final response = await _makeRequest(
        'POST',
        '/users/update-fcm-token/',
        body: body,
      );
      final success = response.statusCode >= 200 && response.statusCode < 300;
      String message = response.body;
      try {
        if (success) {
          final decoded = _unwrapResponseMap(response);
          message =
              (decoded['message'] ?? decoded['detail'] ?? decoded['error'] ?? '')
                  .toString();
          if (message.isEmpty) {
            message = response.body;
          }
        } else {
          final raw = ApiEnvelope.tryDecodeMap(response.body);
          if (raw != null) {
            message = ApiEnvelope.errorMessageFromRoot(raw);
          }
        }
      } catch (_) {}
      return {
        'success': success,
        'status_code': response.statusCode,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'status_code': null,
        'message': e.toString(),
      };
    }
  }

  /// Unregister this install's FCM token on the server (no JWT; uses ``X-API-Key``).
  ///
  /// Required when clearing the session because the access token may be missing
  /// or expired, so [/users/remove-fcm-token/] would return 401.
  Future<void> removeFCMTokenFromServerViaApiKey(String fcmToken) async {
    if (fcmToken.trim().isEmpty) return;
    try {
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final url = Uri.parse('$cleanBaseUrl/users/remove-fcm-token-device/');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Client-Platform': 'mobile',
      };
      final apiKey = AppConstants.apiKey;
      if (apiKey.isNotEmpty) {
        headers['X-API-Key'] = apiKey;
      }
      await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({'fcm_token': fcmToken.trim()}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Best-effort (logout / session expiry).
    }
  }

  /// إزالة FCM token من الخادم (نفس الطريقة الموحّدة، تعمل بدون جلسة صالحة).
  Future<void> removeFCMTokenFromServer(String fcmToken) async {
    await removeFCMTokenFromServerViaApiKey(fcmToken);
  }

  Future<void> _removeCurrentDeviceFcmTokenBeforeLogout() async {
    try {
      final raw = await resolveDeviceFcmTokenForUnregister();
      final token = raw?.trim() ?? '';
      if (token.isEmpty) return;
      await removeFCMTokenFromServerViaApiKey(token);
    } catch (_) {
      // Best-effort (logout / session expiry).
    }
  }

  /// إرسال تقرير تشخيص FCM الكامل للخادم (جميع الخطوات)
  Future<void> sendFcmDiagnosticsFull(Map<String, dynamic> payload) async {
    try {
      await _makeRequest(
        'POST',
        '/users/fcm-diagnostics-full/',
        body: payload,
      );
    } catch (e) {
      debugPrint('Failed to send FCM full diagnostics: $e');
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
          final error = _errorContextFromBody(response.body);
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
  Future<Map<String, dynamic>?> getNotificationSettings({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    try {
      const cacheKey = 'settings_notification_settings';
      final cached = _cacheGet<Map<String, dynamic>>(
        cacheKey,
        forceRefresh: forceRefresh,
      );
      if (cached != null) return cached;
      final response = await _makeRequest('GET', '/notifications/settings/');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final settings = _unwrapResponseMap(response);
        _cacheSet<Map<String, dynamic>>(cacheKey, settings, ttl: cacheTtl);
        return settings;
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
        _invalidateSettingsCache();
      } else {
        String errorMessage = 'Failed to update notification settings';
        try {
          final error = _errorContextFromBody(response.body);
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
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
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
      final cacheKey = _cacheKey('notifications', {
        'read': read,
        'type': type,
      });
      final cached = _cacheGet<List<Map<String, dynamic>>>(
        cacheKey,
        forceRefresh: forceRefresh,
      );
      if (cached != null) return cached;

      final response = await _makeRequest('GET', endpoint);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = _unwrapResponseDynamic(response);
        if (payload is List) {
          final notifications = payload
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cacheSet<List<Map<String, dynamic>>>(
            cacheKey,
            notifications,
            ttl: cacheTtl,
          );
          return notifications;
        }
        if (payload is Map) {
          final m = Map<String, dynamic>.from(payload);
          final r = m['results'] as List?;
          if (r != null) {
            final notifications = r
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            _cacheSet<List<Map<String, dynamic>>>(
              cacheKey,
              notifications,
              ttl: cacheTtl,
            );
            return notifications;
          }
        }
        return [];
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
        return _unwrapResponseMap(response);
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
        _invalidateNotificationsCache();
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
        _invalidateNotificationsCache();
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
  Future<int> getUnreadNotificationsCount({
    bool forceRefresh = false,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    try {
      const cacheKey = 'notifications_unread_count';
      final cached = _cacheGet<int>(cacheKey, forceRefresh: forceRefresh);
      if (cached != null) return cached;

      final response = await _makeRequest(
        'GET',
        '/notifications/unread_count/',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _unwrapResponseMap(response);
        final count = data['unread_count'] as int? ?? 0;
        _cacheSet<int>(cacheKey, count, ttl: cacheTtl);
        return count;
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
        _invalidateNotificationsCache();
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

class _CacheEntry<T> {
  _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final T value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
