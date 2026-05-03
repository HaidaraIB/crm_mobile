import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/bloc/theme/theme_bloc.dart';
import '../../core/bloc/language/language_bloc.dart';
import '../../core/storage/auth_token_storage.dart';
import '../../core/utils/app_locales.dart';
import '../../core/utils/api_error_helper.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../services/api_service.dart';
import '../../widgets/login_verification_gate_card.dart';
import '../../models/user_model.dart';
import '../home/home_screen.dart';
import '../two_factor_auth/two_factor_auth_screen.dart';
import '../payment/subscription_payment_screen.dart';

class LoginScreen extends StatefulWidget {
  /// When set (e.g. after auto-logout), a message is shown to the user.
  final String? logoutReason;

  const LoginScreen({super.key, this.logoutReason});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isSubscriptionError = false;
  LoginVerificationRequiredException? _verificationGate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showLogoutReasonIfAny(),
    );
  }

  void _showLogoutReasonIfAny() {
    final reason = widget.logoutReason;
    if (reason == null || !mounted) return;
    final t = AppLocalizations.of(context)?.translate;
    final message = reason == 'session_expired'
        ? (t?.call('sessionExpired') ?? 'Session expired. Please login again.')
        : reason == 'subscription_inactive'
        ? (t?.call('subscriptionInactive') ??
              'Your subscription is not active. Please contact support or renew.')
        : null;
    if (message != null) {
      SnackbarHelper.showError(context, message);
    }
  }

  /// استخراج subscriptionId من استثناء الاشتراك غير المفعل (يرسله الـ API مع 403)
  int? _getSubscriptionId(Object e) {
    if (e is SubscriptionInactiveException) {
      return e.subscriptionId;
    }
    try {
      final dynamic err = e;
      final v = err.subscriptionId;
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSubscriptionError = false;
      _verificationGate = null;
    });

    try {
      final apiService = ApiService();
      final languageBloc = context.read<LanguageBloc>();
      final locale = languageBloc.state.locale;

      // Step 1: Validate credentials on the backend.
      // Backend enforces owners-only 2FA and may return `requires_two_factor`.
      final loginResponse = await apiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
        locale: locale,
      );

      // If the backend says 2FA is required, show the 2FA screen.
      if (!mounted) return;

      final requiresTwoFactorRaw = loginResponse['requires_two_factor'];
      final requiresTwoFactor =
          requiresTwoFactorRaw == true ||
          requiresTwoFactorRaw?.toString().toLowerCase() == 'true';

      if (requiresTwoFactor) {
        final token = loginResponse['token'] as String?;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TwoFactorAuthScreen(
              username: _usernameController.text.trim(),
              password: _passwordController.text,
              token: token,
            ),
          ),
        );
        return;
      }

      // Normal login (employees, or owners with trusted-device).
      final user = loginResponse['user'] as UserModel;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.isLoggedInKey, true);
      await AuthTokenStorage.instance.writeUserJson(jsonEncode(user.toJson()));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;

      if (e is LoginVerificationRequiredException) {
        setState(() {
          _verificationGate = e;
          _errorMessage = null;
          _isSubscriptionError = false;
          _isLoading = false;
        });
        return;
      }

      String errorMsg;

      // Extract the error message from the exception
      // The exception message should contain the backend error message
      final exceptionString = e.toString();
      final cleanError = ApiErrorHelper.cleanException(exceptionString);

      // Determine error type by checking the error message content
      // We don't access .code property to avoid NoSuchMethodError
      final lowerError = cleanError.toLowerCase();
      bool isSubscriptionError = false;

      // Check for network/offline errors first (ClientException, SocketException, host lookup, etc.)
      if (lowerError.contains('socketexception') ||
          lowerError.contains('failed host lookup') ||
          lowerError.contains('host lookup') ||
          lowerError.contains('no address associated with hostname') ||
          lowerError.contains('socketfailed') ||
          lowerError.contains('network is unreachable') ||
          lowerError.contains('connection refused') ||
          lowerError.contains('connection timed out') ||
          lowerError.contains('connection reset') ||
          lowerError.contains('timed out') ||
          lowerError.contains('clientexception')) {
        errorMsg =
            AppLocalizations.of(context)?.translate('noInternetConnection') ??
            'No Internet Connection';
        errorMsg += '. ';
        errorMsg +=
            AppLocalizations.of(context)?.translate('noInternetMessage') ??
            'Please check your internet connection and try again.';
      }
      // Check for subscription errors → redirect to complete payment
      else if (lowerError.contains('subscription is not active') ||
          lowerError.contains('subscription') &&
              (lowerError.contains('not active') ||
                  lowerError.contains('inactive')) ||
          (e is Exception && _getSubscriptionId(e) != null)) {
        final subscriptionId = _getSubscriptionId(e);
        if (subscriptionId != null) {
          setState(() => _isLoading = false);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SubscriptionPaymentScreen(
                subscriptionId: subscriptionId,
                loginUsername: _usernameController.text.trim(),
                loginPassword: _passwordController.text,
              ),
            ),
          );
          return;
        }
        if (cleanError.isNotEmpty &&
            !cleanError.toLowerCase().contains('failed to request') &&
            !cleanError.toLowerCase().contains('status 403') &&
            !cleanError.toLowerCase().contains('subscription_inactive')) {
          errorMsg = cleanError;
        } else {
          errorMsg =
              AppLocalizations.of(
                context,
              )?.translate('subscriptionNotActive') ??
              'Your subscription is not active. Please contact support or Complete Your Payment to access the system.';
        }
        isSubscriptionError = true;
      }
      // Check for account temporarily inactive errors
      else if (lowerError.contains('account is temporarily inactive') ||
          lowerError.contains('account_temporarily_inactive')) {
        if (cleanError.isNotEmpty &&
            !cleanError.toLowerCase().contains('failed to request')) {
          errorMsg = cleanError;
        } else {
          errorMsg =
              AppLocalizations.of(
                context,
              )?.translate('accountTemporarilyInactive') ??
              'Your account is temporarily inactive';
        }
      }
      // Check for invalid credentials errors
      else if (lowerError.contains('invalid credentials') ||
          lowerError.contains('invalid username') ||
          lowerError.contains('invalid password') ||
          lowerError.contains('user not found') ||
          lowerError.contains('unable to log in') ||
          lowerError.contains('no active account')) {
        // Use the actual backend error message, with localization fallback
        if (cleanError.isNotEmpty &&
            !cleanError.toLowerCase().contains('failed to request')) {
          errorMsg = cleanError;
        } else if (lowerError.contains('user not found')) {
          errorMsg =
              AppLocalizations.of(context)?.translate('userNotFound') ??
              'User not found';
        } else {
          errorMsg =
              AppLocalizations.of(context)?.translate('invalidCredentials') ??
              'Invalid username or password. Please check your credentials and try again.';
        }
      }
      // For any other error, use the exception message
      else {
        errorMsg = cleanError.isNotEmpty
            ? cleanError
            : (AppLocalizations.of(context)?.translate('anErrorOccurred') ??
                  'An error occurred. Please try again.');
      }

      setState(() {
        _errorMessage = errorMsg;
        _isSubscriptionError = isSubscriptionError;
        _isLoading = false;
      });
    }
  }

  /// فتح شاشة الدفع عند النقر على "إتمام الدفع" في رسالة الاشتراك
  Future<void> _onCompletePaymentTap() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      final languageBloc = context.read<LanguageBloc>();
      final language = languageBloc.state.locale.languageCode;
      await apiService.requestTwoFactorAuth(
        _usernameController.text.trim(),
        _passwordController.text,
        language,
      );
    } catch (e) {
      final subscriptionId = _getSubscriptionId(e);
      if (mounted && subscriptionId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SubscriptionPaymentScreen(
              subscriptionId: subscriptionId,
              loginUsername: _usernameController.text.trim(),
              loginPassword: _passwordController.text,
            ),
          ),
        );
        return;
      }
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('unableToOpenPayment') ??
              'Unable to open payment. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isRTL = localizations?.isRTL ?? false;
    final themeBloc = context.read<ThemeBloc>();
    final languageBloc = context.read<LanguageBloc>();
    final currentTheme = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    final currentLocale = languageBloc.state.locale;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(
              currentLocale.languageCode == 'ar'
                  ? Icons.translate
                  : Icons.language,
              color: Theme.of(context).iconTheme.color,
            ),
            tooltip: currentLocale.languageCode == 'ar'
                ? (localizations?.translate('switchToEnglish') ??
                      'Switch to English')
                : (localizations?.translate('switchToArabic') ??
                      'Switch to Arabic'),
            onPressed: () {
              final newLocale = currentLocale.languageCode == 'ar'
                  ? AppLocales.english
                  : AppLocales.arabic;
              languageBloc.add(ChangeLanguage(newLocale));
            },
          ),
          IconButton(
            icon: Icon(
              currentTheme == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Theme.of(context).iconTheme.color,
            ),
            tooltip: currentTheme == ThemeMode.dark
                ? (localizations?.translate('switchToLightMode') ??
                      'Switch to Light Mode')
                : (localizations?.translate('switchToDarkMode') ??
                      'Switch to Dark Mode'),
            onPressed: () {
              themeBloc.add(const ToggleTheme());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo or App Name
                  Text(
                    localizations?.translate('appName') ?? 'LOOP CRM',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRTL ? 'سجّل دخولك للمتابعة' : 'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: isRTL
                          ? 'اسم المستخدم أو البريد الإلكتروني'
                          : 'Username or Email',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textDirection: isRTL
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations?.translate(
                              'pleaseEnterUsername',
                            ) ??
                            'Please enter username';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      setState(() {
                        _verificationGate = null;
                        _errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText:
                          localizations?.translate('password') ?? 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textDirection: isRTL
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations?.translate(
                              'pleaseEnterPassword',
                            ) ??
                            'Please enter password';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      setState(() {
                        _verificationGate = null;
                        _errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  if (_verificationGate != null) ...[
                    LoginVerificationGateCard(
                      gate: _verificationGate!,
                      onDismiss: () {
                        setState(() => _verificationGate = null);
                      },
                      preloginUsername: _usernameController.text.trim(),
                      preloginPassword: _passwordController.text,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: _isSubscriptionError
                            ? Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          localizations?.translate(
                                            'subscriptionNotActiveBeforeLink',
                                          ) ??
                                          'Your subscription is not active. Please contact support or ',
                                    ),
                                    TextSpan(
                                      text:
                                          localizations?.translate(
                                            'subscriptionNotActiveLink',
                                          ) ??
                                          'Complete Your Payment',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _onCompletePaymentTap,
                                    ),
                                    TextSpan(
                                      text:
                                          localizations?.translate(
                                            'subscriptionNotActiveAfterLink',
                                          ) ??
                                          ' to access the system.',
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                textDirection: isRTL
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                              )
                            : Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            localizations?.translate('signIn') ?? 'Sign In',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
