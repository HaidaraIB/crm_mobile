import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/language/language_bloc.dart';
import '../../core/bloc/theme/theme_bloc.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/storage/auth_token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/api_error_helper.dart';
import '../../core/utils/app_locales.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import 'notification_settings_screen.dart';

/// Icon tile used for Language / Theme / Notifications — readable on dark theme.
Widget _settingsAccentIconBox(BuildContext context, {required Widget child}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark
          ? AppTheme.primaryColor.withValues(alpha: 0.30)
          : AppTheme.primaryColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.65 : 0.40),
        width: isDark ? 1.5 : 1,
      ),
    ),
    child: IconTheme(
      data: IconThemeData(
        size: 26,
        color: isDark ? Colors.white : AppTheme.primaryColor,
      ),
      child: child,
    ),
  );
}

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  final ApiService _apiService = ApiService();
  UserModel? _currentUser;
  bool _isLoadingUser = true;
  bool _isUpdatingTwoFactor = false;
  bool _loginTwoFactorEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _loginTwoFactorEnabled = user.loginTwoFactorEnabled ?? true;
        _isLoadingUser = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _handleLoginTwoFactorToggle(bool enabled) async {
    final user = _currentUser;
    if (user == null || !user.canManageLoginTwoFactor) return;

    final previous = _loginTwoFactorEnabled;
    setState(() {
      _loginTwoFactorEnabled = enabled;
      _isUpdatingTwoFactor = true;
    });

    try {
      final updatedUser = await _apiService.updateUser(
        userId: user.id,
        loginTwoFactorEnabled: enabled,
      );
      if (!mounted) return;
      setState(() {
        _currentUser = updatedUser;
        _loginTwoFactorEnabled = updatedUser.loginTwoFactorEnabled ?? enabled;
      });
      await AuthTokenStorage.instance.writeUserJson(jsonEncode(updatedUser.toJson()));
      if (!mounted) return;

      final localizations = AppLocalizations.of(context);
      SnackbarHelper.showSuccess(
        context,
        enabled
            ? (localizations?.translate('loginTwoFactorEnabledSuccess') ??
                'Two-factor authentication enabled for your account.')
            : (localizations?.translate('loginTwoFactorDisabledSuccess') ??
                'Two-factor authentication disabled for your account.'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loginTwoFactorEnabled = previous);
      SnackbarHelper.showError(
        context,
        ApiErrorHelper.toUserMessage(context, e),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingTwoFactor = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showTwoFactorSetting =
        !_isLoadingUser && (_currentUser?.canManageLoginTwoFactor ?? false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Language Section
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _settingsAccentIconBox(
                      context,
                      child: const Icon(Icons.language_outlined),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations?.translate('language') ?? 'Language',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          BlocBuilder<LanguageBloc, LanguageState>(
                            builder: (context, languageState) {
                              return DropdownButtonFormField<Locale>(
                                initialValue: languageState.locale,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                ),
                                items: [
                                  DropdownMenuItem<Locale>(
                                    value: AppLocales.english,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 8),
                                        Text(
                                          localizations?.translate('english') ?? 'English',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem<Locale>(
                                    value: AppLocales.arabic,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 8),
                                        Text(
                                          localizations?.translate('arabic') ?? 'Arabic',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (Locale? newLocale) {
                                  if (newLocale != null) {
                                    context.read<LanguageBloc>().add(ChangeLanguage(newLocale));
                                  }
                                },
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: theme.colorScheme.onSurface,
                                ),
                                isExpanded: true,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Theme Section
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              context.read<ThemeBloc>().add(const ToggleTheme());
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BlocBuilder<ThemeBloc, ThemeState>(
                        builder: (context, themeState) {
                          final isDarkMode = themeState.themeMode == ThemeMode.dark;
                          return _settingsAccentIconBox(
                            context,
                            child: Icon(
                              isDarkMode
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations?.translate('theme') ?? 'Theme',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            BlocBuilder<ThemeBloc, ThemeState>(
                              builder: (context, themeState) {
                                final isDarkMode = themeState.themeMode == ThemeMode.dark;
                                return Text(
                                  isDarkMode
                                      ? (localizations?.translate('darkMode') ?? 'Dark Mode')
                                      : (localizations?.translate('lightMode') ?? 'Light Mode'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      BlocBuilder<ThemeBloc, ThemeState>(
                        builder: (context, themeState) {
                          final isDarkMode = themeState.themeMode == ThemeMode.dark;
                          return Switch(
                            value: isDarkMode,
                            onChanged: (value) {
                              context.read<ThemeBloc>().add(const ToggleTheme());
                            },
                            activeThumbColor: AppTheme.primaryColor,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (showTwoFactorSetting) ...[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _settingsAccentIconBox(
                    context,
                    child: const Icon(Icons.security_outlined),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations?.translate('loginTwoFactorSettingTitle') ??
                              'Require two-factor authentication at login',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations?.translate('loginTwoFactorSettingHint') ??
                              'When enabled, you will receive a verification code by email each time you sign in on a new device.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isUpdatingTwoFactor
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _loginTwoFactorEnabled,
                          onChanged: _handleLoginTwoFactorToggle,
                          activeThumbColor: AppTheme.primaryColor,
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Notifications Section
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _settingsAccentIconBox(
                    context,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations?.translate('notificationSettings') ?? 'Notification Settings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations?.translate('customizeNotificationsByTypeAndTime') ??
                              'Customize notifications by type and time',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
