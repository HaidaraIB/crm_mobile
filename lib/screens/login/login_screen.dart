import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/bloc/theme/theme_bloc.dart';
import '../../core/bloc/language/language_bloc.dart';
import '../../services/api_service.dart';
import '../two_factor_auth/two_factor_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final apiService = ApiService();
      final languageBloc = context.read<LanguageBloc>();
      final language = languageBloc.state.locale.languageCode;
      
      // Step 1: Validate credentials and check subscription status, then request 2FA code
      // The request-2fa endpoint validates credentials and checks subscription status on the backend
      // If credentials are invalid or subscription is inactive, it will throw an error here
      // This prevents navigation to 2FA screen if credentials are invalid or subscription is not active
      final twoFAResponse = await apiService.requestTwoFactorAuth(
        _usernameController.text.trim(),
        _passwordController.text,
        language,
      );
      
      // Step 2: Only navigate to 2FA screen if credentials are valid AND request was successful
      // If requestTwoFactorAuth throws an exception (invalid credentials, subscription inactive, etc.),
      // we will NOT reach this point - the catch block will handle the error instead
      // This ensures we never navigate to 2FA screen with invalid credentials
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TwoFactorAuthScreen(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            token: twoFAResponse['token'] as String?,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg;
      
      // Extract the error message from the exception
      // The exception message should contain the backend error message
      final exceptionString = e.toString();
      final cleanError = exceptionString.replaceAll('Exception: ', '');
      
      // Determine error type by checking the error message content
      // We don't access .code property to avoid NoSuchMethodError
      final lowerError = cleanError.toLowerCase();
      
      // Check for subscription errors
      if (lowerError.contains('subscription is not active') ||
          lowerError.contains('subscription') && 
          (lowerError.contains('not active') || lowerError.contains('inactive'))) {
        // Use the actual backend error message if it's meaningful
        if (cleanError.isNotEmpty && 
            !cleanError.toLowerCase().contains('failed to request') &&
            !cleanError.toLowerCase().contains('status 403') &&
            !cleanError.toLowerCase().contains('subscription_inactive')) {
          errorMsg = cleanError;
        } else {
          errorMsg = AppLocalizations.of(context)?.translate('subscriptionNotActive') ?? 
              'Your subscription is not active. Please contact support or complete your payment to access the system.';
        }
      } 
      // Check for account temporarily inactive errors
      else if (lowerError.contains('account is temporarily inactive') ||
               lowerError.contains('account_temporarily_inactive')) {
        if (cleanError.isNotEmpty && 
            !cleanError.toLowerCase().contains('failed to request')) {
          errorMsg = cleanError;
        } else {
          errorMsg = AppLocalizations.of(context)?.translate('accountTemporarilyInactive') ?? 
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
          errorMsg = AppLocalizations.of(context)?.translate('userNotFound') ?? 
              'User not found';
        } else {
          errorMsg = AppLocalizations.of(context)?.translate('invalidCredentials') ?? 
              'Invalid username or password. Please check your credentials and try again.';
        }
      } 
      // For any other error, use the exception message
      else {
        errorMsg = cleanError.isNotEmpty ? cleanError : 
            (AppLocalizations.of(context)?.translate('anErrorOccurred') ?? 
             'An error occurred. Please try again.');
      }
      
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
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
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60), // Space for top buttons
                      // Logo or App Name
                      Text(
                        localizations?.translate('appName') ?? 'LOOP CRM',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                  
                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: localizations?.translate('username') ?? 'Username',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations?.translate('pleaseEnterUsername') ?? 'Please enter username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: localizations?.translate('password') ?? 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
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
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations?.translate('pleaseEnterPassword') ?? 'Please enter password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

