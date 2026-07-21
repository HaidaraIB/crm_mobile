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
import 'widgets/settings_group.dart';

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

  Future<void> _showLanguagePicker(Locale current) async {
    final localizations = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  localizations?.translate('english') ?? 'English',
                  style: theme.textTheme.bodyLarge,
                ),
                trailing: current.languageCode == 'en'
                    ? Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () => Navigator.pop(ctx, AppLocales.english),
              ),
              ListTile(
                title: Text(
                  localizations?.translate('arabic') ?? 'Arabic',
                  style: theme.textTheme.bodyLarge,
                ),
                trailing: current.languageCode == 'ar'
                    ? Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () => Navigator.pop(ctx, AppLocales.arabic),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      context.read<LanguageBloc>().add(ChangeLanguage(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final showTwoFactorSetting =
        !_isLoadingUser && (_currentUser?.canManageLoginTwoFactor ?? false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SettingsGroup(
          header: localizations?.translate('preferences') ?? 'Preferences',
          children: [
            BlocBuilder<LanguageBloc, LanguageState>(
              builder: (context, languageState) {
                final isArabic = languageState.locale.languageCode == 'ar';
                return SettingsRow(
                  leading: const SettingsLeadingIcon(icon: Icons.language_outlined),
                  title: localizations?.translate('language') ?? 'Language',
                  subtitle: isArabic
                      ? (localizations?.translate('arabic') ?? 'Arabic')
                      : (localizations?.translate('english') ?? 'English'),
                  trailing: const SettingsChevron(),
                  onTap: () => _showLanguagePicker(languageState.locale),
                );
              },
            ),
            BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, themeState) {
                final isDarkMode = themeState.themeMode == ThemeMode.dark;
                return SettingsRow(
                  leading: SettingsLeadingIcon(
                    icon: isDarkMode
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                  title: localizations?.translate('theme') ?? 'Theme',
                  subtitle: isDarkMode
                      ? (localizations?.translate('darkMode') ?? 'Dark Mode')
                      : (localizations?.translate('lightMode') ?? 'Light Mode'),
                  trailing: Switch.adaptive(
                    value: isDarkMode,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (_) {
                      context.read<ThemeBloc>().add(const ToggleTheme());
                    },
                  ),
                  onTap: () {
                    context.read<ThemeBloc>().add(const ToggleTheme());
                  },
                );
              },
            ),
          ],
        ),
        if (showTwoFactorSetting)
          SettingsGroup(
            header: localizations?.translate('security') ?? 'Security',
            footer: localizations?.translate('loginTwoFactorSettingHint') ??
                'When enabled, you will receive a verification code by email each time you sign in on a new device.',
            children: [
              SettingsRow(
                leading: const SettingsLeadingIcon(icon: Icons.security_outlined),
                title: localizations?.translate('loginTwoFactorSettingTitle') ??
                    'Require two-factor authentication at login',
                trailing: _isUpdatingTwoFactor
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch.adaptive(
                        value: _loginTwoFactorEnabled,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: _handleLoginTwoFactorToggle,
                      ),
              ),
            ],
          ),
        SettingsGroup(
          header: localizations?.translate('notifications') ?? 'Notifications',
          children: [
            SettingsRow(
              leading: const SettingsLeadingIcon(icon: Icons.notifications_outlined),
              title: localizations?.translate('notificationSettings') ??
                  'Notification Settings',
              subtitle: localizations?.translate('customizeNotificationsByTypeAndTime') ??
                  'Customize notifications by type and time',
              trailing: const SettingsChevron(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
