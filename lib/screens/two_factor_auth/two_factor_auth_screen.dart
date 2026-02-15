import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/bloc/theme/theme_bloc.dart';
import '../../core/bloc/language/language_bloc.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  final String username;
  final String password;
  final String? token;
  
  const TwoFactorAuthScreen({
    super.key,
    required this.username,
    required this.password,
    this.token,
  });

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isRequesting = false;
  String? _errorMessage;
  String? _successMessage;
  int _countdown = 0;
  Timer? _countdownTimer;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Load cooldown from SharedPreferences
    _loadCountdown();
    // When any code field gains focus, place cursor at start (left) for both RTL and LTR
    for (int i = 0; i < 6; i++) {
      final idx = i;
      _focusNodes[i].addListener(() {
        if (_focusNodes[idx].hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _codeControllers[idx].selection = TextSelection.collapsed(offset: 0);
          });
        }
      });
    }
    // Auto-focus first input and place cursor at start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      _codeControllers[0].selection = TextSelection.collapsed(offset: 0);
    });
  }

  Future<void> _loadCountdown() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('2fa_resend_cooldown');
    if (stored != null) {
      try {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        final timestamp = data['timestamp'] as int? ?? 0;
        final storedUsername = data['username'] as String? ?? '';
        
        if (storedUsername == widget.username) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - timestamp;
          final remaining = (60000 - elapsed) ~/ 1000;
          if (remaining > 0) {
            setState(() {
              _countdown = remaining;
            });
            _startCountdown();
          }
        }
      } catch (e) {
        // Invalid data, clear it
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('2fa_resend_cooldown');
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
        if (_countdown == 0) {
          timer.cancel();
          final prefs = SharedPreferences.getInstance();
          prefs.then((p) => p.remove('2fa_resend_cooldown'));
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _requestCode() async {
    if (_countdown > 0) {
      final localizations = AppLocalizations.of(context);
      setState(() {
        _errorMessage = localizations?.translate('pleaseWaitBeforeResend') ?? 
            'Please wait $_countdown seconds before resending';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isRequesting = true;
    });

    try {
      final languageBloc = context.read<LanguageBloc>();
      final language = languageBloc.state.locale.languageCode;
      
      await _apiService.requestTwoFactorAuth(widget.username, widget.password, language);
      
      setState(() {
        _successMessage = AppLocalizations.of(context)?.translate('twoFactorCodeSent') ?? 
            'Two-factor authentication code has been sent to your email';
        _countdown = 60;
      });
      
      _startCountdown();
      
      // Save cooldown
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('2fa_resend_cooldown', jsonEncode({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'username': widget.username,
      }));
    } catch (e) {
      final errorString = e.toString();
      final lowerError = errorString.toLowerCase();
      final isNetworkError = lowerError.contains('socketexception') ||
          lowerError.contains('failed host lookup') ||
          lowerError.contains('host lookup') ||
          lowerError.contains('no address associated with hostname') ||
          lowerError.contains('socketfailed') ||
          lowerError.contains('network is unreachable') ||
          lowerError.contains('connection refused') ||
          lowerError.contains('connection timed out') ||
          lowerError.contains('connection reset') ||
          lowerError.contains('timed out') ||
          lowerError.contains('clientexception');
      if (isNetworkError) {
        setState(() {
          _errorMessage = '${AppLocalizations.of(context)?.translate('noInternetConnection') ?? 'No Internet Connection'}. ${AppLocalizations.of(context)?.translate('noInternetMessage') ?? 'Please check your internet connection and try again.'}';
        });
      } else if (errorString.contains('ACCOUNT_TEMPORARILY_INACTIVE')) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)?.translate('accountTemporarilyInactive') ?? 
              'Your account is temporarily inactive';
        });
      } else if (errorString.contains('SUBSCRIPTION_INACTIVE')) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)?.translate('noActiveSubscription') ?? 
              'No active subscription found';
        });
      } else {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      setState(() {
        _isRequesting = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();
    
    if (code.length != 6) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)?.translate('pleaseEnter2FACode') ?? 
            'Please enter the 6-digit two-factor authentication code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Verify 2FA code (backend also checks subscription during verification)
      final languageBloc = context.read<LanguageBloc>();
      await _apiService.verifyTwoFactorAuth(
        username: widget.username,
        password: widget.password,
        code: code,
        token: widget.token,
        locale: languageBloc.state.locale,
      );
      
      // Step 2: Get user data
      final user = await _apiService.getCurrentUser();
      
      // Step 3: Check subscription status again (safety check)
      // Employees don't need subscriptions, only admins/owners do
      final subscription = user.company?.subscription;
      if (subscription != null && !subscription.isActive && user.role.toLowerCase() != 'employee') {
        // Subscription is inactive - this should have been caught earlier, but double-check
        setState(() {
          _errorMessage = AppLocalizations.of(context)?.translate('noActiveSubscription') ?? 
              'No active subscription found. Please contact support.';
          _isLoading = false;
        });
        return;
      }
      
      // Save login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.isLoggedInKey, true);
      await prefs.setString(
        AppConstants.currentUserKey,
        jsonEncode(user.toJson()),
      );
      
      // Clear cooldown
      await prefs.remove('2fa_resend_cooldown');
      
      // Send FCM token to server after successful login
      try {
        final notificationService = NotificationService();
        await notificationService.sendTokenToServerIfLoggedIn();
        debugPrint('FCM Token sent to server after login');
      } catch (e) {
        debugPrint('Warning: Failed to send FCM token after login: $e');
        // Don't block login if FCM token sending fails
      }
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorString = e.toString();
      final lowerError = errorString.toLowerCase();
      String errorMsg;
      
      final isNetworkError = lowerError.contains('socketexception') ||
          lowerError.contains('failed host lookup') ||
          lowerError.contains('host lookup') ||
          lowerError.contains('no address associated with hostname') ||
          lowerError.contains('socketfailed') ||
          lowerError.contains('network is unreachable') ||
          lowerError.contains('connection refused') ||
          lowerError.contains('connection timed out') ||
          lowerError.contains('connection reset') ||
          lowerError.contains('timed out') ||
          lowerError.contains('clientexception');
      if (isNetworkError) {
        errorMsg = '${AppLocalizations.of(context)?.translate('noInternetConnection') ?? 'No Internet Connection'}. ${AppLocalizations.of(context)?.translate('noInternetMessage') ?? 'Please check your internet connection and try again.'}';
      } else if (errorString.contains('ACCOUNT_TEMPORARILY_INACTIVE')) {
        errorMsg = AppLocalizations.of(context)?.translate('accountTemporarilyInactive') ?? 
            'Your account is temporarily inactive';
      } else if (errorString.contains('SUBSCRIPTION_INACTIVE')) {
        errorMsg = AppLocalizations.of(context)?.translate('noActiveSubscription') ?? 
            'No active subscription found';
      } else if (lowerError.contains('invalid credentials') || 
                 lowerError.contains('invalid username') ||
                 lowerError.contains('invalid password')) {
        errorMsg = AppLocalizations.of(context)?.translate('invalidCredentials') ?? 
            'Invalid credentials. Please go back and check your username and password.';
      } else if (lowerError.contains('expired')) {
        errorMsg = AppLocalizations.of(context)?.translate('twoFactorCodeExpired') ?? 
            'Two-factor authentication code has expired. Please request a new one';
      } else if (lowerError.contains('invalid')) {
        errorMsg = AppLocalizations.of(context)?.translate('twoFactorCodeInvalid') ?? 
            'Invalid two-factor authentication code';
      } else {
        errorMsg = e.toString().replaceAll('Exception: ', '');
      }
      
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  void _handleCodeChange(int index, String value) {
    if (value.isEmpty) {
      _codeControllers[index].clear();
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    } else {
      final digit = value.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 1);
      _codeControllers[index].text = digit;
      
      if (index < 5 && digit.isNotEmpty) {
        _focusNodes[index + 1].requestFocus();
      } else if (index == 5 && digit.isNotEmpty) {
        _focusNodes[index].unfocus();
        _verifyCode();
      }
    }
    
    setState(() {
      _errorMessage = null;
    });
  }

  void _handlePaste(String pastedText) {
    final digits = pastedText.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 6);
    for (int i = 0; i < 6; i++) {
      if (i < digits.length) {
        _codeControllers[i].text = digits[i];
      } else {
        _codeControllers[i].clear();
      }
    }
    if (digits.length == 6) {
      _focusNodes[5].unfocus();
      _verifyCode();
    } else if (digits.isNotEmpty) {
      _focusNodes[digits.length].requestFocus();
    }
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _countdownTimer?.cancel();
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
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60), // Space for top buttons
                    // Title
                    Text(
                      localizations?.translate('twoFactorAuthTitle') ?? 'Two-Factor Authentication',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations?.translate('enter2FACode') ?? 
                          'Enter the 6-digit code sent to your email',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Success Message
                    if (_successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Code Input Fields - always LTR so first digit is on the left (no RTL flip)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate available width and adjust field size
                        final availableWidth = constraints.maxWidth;
                        final spacing = 4.0;
                        final totalSpacing = spacing * 10; // 5 gaps between 6 fields
                        final fieldWidth = ((availableWidth - totalSpacing) / 6).clamp(40.0, 50.0);
                        
                        return Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(6, (index) {
                            return Container(
                              width: fieldWidth,
                              height: 60,
                              margin: EdgeInsets.only(
                                left: index == 0 ? 0 : spacing / 2,
                                right: index == 5 ? 0 : spacing / 2,
                              ),
                              child: TextField(
                                controller: _codeControllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.ltr,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                style: TextStyle(
                                  fontSize: fieldWidth > 45 ? 24 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (value) => _handleCodeChange(index, value),
                                onTap: () {
                                  Clipboard.getData(Clipboard.kTextPlain).then((clipboard) {
                                    if (clipboard?.text != null && index == 0) {
                                      _handlePaste(clipboard!.text!);
                                    }
                                  });
                                },
                              ),
                            );
                          }),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Verify Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              localizations?.translate('verify') ?? 'Verify',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Resend Code
                    Center(
                      child: TextButton(
                        onPressed: (_isRequesting || _countdown > 0) ? null : _requestCode,
                        child: Text(
                          _countdown > 0
                              ? '${localizations?.translate('resendCodeIn') ?? 'Resend code in'} $_countdown ${localizations?.translate('seconds') ?? 'seconds'}'
                              : (localizations?.translate('resendCode') ?? 'Resend Code'),
                          style: TextStyle(
                            color: (_isRequesting || _countdown > 0) 
                                ? Colors.grey 
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    
                    // Back to Login
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: Text(
                          localizations?.translate('backToLogin') ?? 'Back to Login',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Top-right buttons for language, theme, etc.
            Positioned(
              top: 16,
              right: isRTL ? null : 16,
              left: isRTL ? 16 : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Language Toggle Button
                  IconButton(
                    icon: Icon(
                      currentLocale.languageCode == 'ar' 
                          ? Icons.translate 
                          : Icons.language,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    tooltip: currentLocale.languageCode == 'ar' 
                        ? (localizations?.translate('switchToEnglish') ?? 'Switch to English')
                        : (localizations?.translate('switchToArabic') ?? 'Switch to Arabic'),
                    onPressed: () {
                      final newLocale = currentLocale.languageCode == 'ar'
                          ? const Locale('en')
                          : const Locale('ar');
                      languageBloc.add(ChangeLanguage(newLocale));
                    },
                  ),
                  // Theme Toggle Button
                  IconButton(
                    icon: Icon(
                      currentTheme == ThemeMode.dark 
                          ? Icons.light_mode 
                          : Icons.dark_mode,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    tooltip: currentTheme == ThemeMode.dark
                        ? (localizations?.translate('switchToLightMode') ?? 'Switch to Light Mode')
                        : (localizations?.translate('switchToDarkMode') ?? 'Switch to Dark Mode'),
                    onPressed: () {
                      themeBloc.add(const ToggleTheme());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

