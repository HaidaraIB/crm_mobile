import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/notification_settings_model.dart' as app_settings;
import '../../models/notification_model.dart';
import '../../services/notification_router.dart';
import '../../services/api_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import 'widgets/settings_group.dart';

/// Notification types that are actually wired to backend events.
/// Keep enum values for future use; only show these in settings UI.
const Set<NotificationType> kVisibleNotificationSettingsTypes = {
  NotificationType.newLead,
  NotificationType.leadNoFollowUp,
  NotificationType.leadStatusChanged,
  NotificationType.leadAssigned,
  NotificationType.leadTransferred,
  NotificationType.leadReminder,
  NotificationType.teamActivity,
  NotificationType.whatsappMessageReceived,
  NotificationType.whatsappWaitingResponse,
  NotificationType.campaignLowPerformance,
  NotificationType.campaignBudgetAlert,
  NotificationType.taskReminder,
  NotificationType.callReminder,
  NotificationType.visitReminder,
  NotificationType.receptionVisitReminder,
  NotificationType.dealCreated,
  NotificationType.dealClosed,
  NotificationType.dealReminder,
  NotificationType.dailyReport,
  NotificationType.weeklyReport,
  NotificationType.topEmployee,
  NotificationType.subscriptionExpiring,
  NotificationType.subscriptionExpired,
};

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  app_settings.NotificationSettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;

      if (isLoggedIn) {
        final apiService = ApiService();
        final serverSettings = await apiService.getNotificationSettings(
          forceRefresh: forceRefresh,
        );

        if (serverSettings != null) {
          final settings = app_settings.NotificationSettings.fromServerMap(
            serverSettings,
          );
          await settings.save(syncToServer: false);
          setState(() {
            _settings = settings;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to load settings from server: $e');
    }

    final settings = await app_settings.NotificationSettings.load();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_settings != null) {
      await _settings!.save();
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        SnackbarHelper.showSuccess(
          context,
          localizations?.translate('settingsSavedSuccessfully') ??
              'Settings saved successfully',
        );
      }
    }
  }

  List<NotificationType> _visible(List<NotificationType> types) {
    return types
        .where(kVisibleNotificationSettingsTypes.contains)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localizations?.translate('notificationSettings') ??
                'Notification Settings',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localizations?.translate('notificationSettings') ??
                'Notification Settings',
          ),
        ),
        body: Center(
          child: Text(
            localizations?.translate('errorLoadingSettings') ??
                'Error loading settings',
          ),
        ),
      );
    }

    final masterEnabled = _settings!.enabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations?.translate('notificationSettings') ??
              'Notification Settings',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadSettings(forceRefresh: true),
            tooltip: localizations?.translate('refresh') ?? 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SettingsGroup(
            children: [
              SettingsRow(
                leading: SettingsLeadingIcon(
                  icon: masterEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: masterEnabled ? Colors.green : Colors.grey,
                ),
                title: localizations?.translate('enableNotifications') ??
                    'Enable Notifications',
                subtitle: localizations
                        ?.translate('enableOrDisableAllNotifications') ??
                    'Enable or disable all notifications',
                trailing: Switch.adaptive(
                  value: masterEnabled,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() => _settings!.enabled = value);
                    _saveSettings();
                  },
                ),
              ),
            ],
          ),
          SettingsGroup(
            header: localizations?.translate('companyOwnerNotifications') ??
                'Company',
            footer: localizations?.translate('teamActivityHint') ??
                'Team activity alerts for employee actions on leads, including overdue follow-ups.',
            children: [
              _typeSwitch(
                NotificationType.teamActivity,
                enabled: masterEnabled,
                localizations: localizations,
              ),
            ],
          ),
          _sectionGroup(
            header: localizations?.translate('leadNotifications') ??
                'Lead Notifications',
            types: _visible([
              NotificationType.newLead,
              NotificationType.leadNoFollowUp,
              NotificationType.leadStatusChanged,
              NotificationType.leadAssigned,
              NotificationType.leadTransferred,
              NotificationType.leadReminder,
            ]),
            masterEnabled: masterEnabled,
            localizations: localizations,
          ),
          _sectionGroup(
            header: localizations?.translate('whatsappNotifications') ??
                'WhatsApp Notifications',
            types: _visible([
              NotificationType.whatsappMessageReceived,
              NotificationType.whatsappWaitingResponse,
            ]),
            masterEnabled: masterEnabled,
            localizations: localizations,
          ),
          _sectionGroup(
            header: localizations?.translate('campaignNotifications') ??
                'Campaign Notifications',
            types: _visible([
              NotificationType.campaignLowPerformance,
              NotificationType.campaignBudgetAlert,
            ]),
            masterEnabled: masterEnabled,
            localizations: localizations,
          ),
          _sectionGroup(
            header: localizations?.translate('teamAndTasksNotifications') ??
                'Team & Tasks Notifications',
            types: _visible([
              NotificationType.taskReminder,
              NotificationType.callReminder,
              NotificationType.visitReminder,
              NotificationType.receptionVisitReminder,
            ]),
            masterEnabled: masterEnabled,
            localizations: localizations,
          ),
          _sectionGroup(
            header: localizations?.translate('dealNotifications') ??
                'Deal Notifications',
            types: _visible([
              NotificationType.dealCreated,
              NotificationType.dealClosed,
              NotificationType.dealReminder,
            ]),
            masterEnabled: masterEnabled,
            localizations: localizations,
          ),
          _sectionGroup(
            header: localizations?.translate('reportsNotifications') ??
                'Report Notifications',
            types: _visible([
              NotificationType.dailyReport,
              NotificationType.weeklyReport,
              NotificationType.topEmployee,
            ]),
            masterEnabled: masterEnabled,
            localizations: localizations,
          ),
          _sectionGroup(
            header: localizations?.translate('systemNotifications') ??
                'System & Subscription Notifications',
            types: _visible([
              NotificationType.subscriptionExpiring,
              NotificationType.subscriptionExpired,
            ]),
            masterEnabled: masterEnabled,
            localizations: localizations,
          ),
          SettingsGroup(
            header: localizations?.translate('sendTimeSettings') ??
                'Send Time Settings',
            footer: _settings!.timeSettings.restrictTime
                ? (localizations?.translate('restrictedToSpecificTime') ??
                    'Restricted to specific time')
                : (localizations?.translate('active24Hours') ??
                    'Active 24 hours'),
            children: [
              SettingsRow(
                leading: const SettingsLeadingIcon(icon: Icons.access_time),
                title: localizations?.translate('restrictSendTime') ??
                    'Restrict Send Time',
                trailing: Switch.adaptive(
                  value: _settings!.timeSettings.restrictTime,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _settings!.timeSettings.restrictTime = value;
                    });
                    _saveSettings();
                  },
                ),
              ),
              if (_settings!.timeSettings.restrictTime) ...[
                SettingsRow(
                  leading: const SettingsLeadingIcon(icon: Icons.schedule),
                  title: localizations?.translate('startTime') ?? 'Start Time',
                  trailing: Text(
                    '${_settings!.timeSettings.startHour}:00',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  onTap: () => _selectTime(true),
                ),
                SettingsRow(
                  leading: const SettingsLeadingIcon(icon: Icons.schedule),
                  title: localizations?.translate('endTime') ?? 'End Time',
                  trailing: Text(
                    '${_settings!.timeSettings.endHour}:00',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  onTap: () => _selectTime(false),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionGroup({
    required String header,
    required List<NotificationType> types,
    required bool masterEnabled,
    required AppLocalizations? localizations,
  }) {
    if (types.isEmpty) return const SizedBox.shrink();
    return SettingsGroup(
      header: header,
      children: types
          .map(
            (type) => _typeSwitch(
              type,
              enabled: masterEnabled,
              localizations: localizations,
            ),
          )
          .toList(),
    );
  }

  Widget _typeSwitch(
    NotificationType type, {
    required bool enabled,
    required AppLocalizations? localizations,
  }) {
    final typeEnabled = _settings!.isNotificationEnabled(type);
    final typeKey = _getNotificationTypeKey(type);
    final typeName =
        localizations?.translate(typeKey) ?? NotificationRouter.getTypeName(type);

    return SettingsRow(
      leading: SettingsLeadingIcon(
        icon: NotificationRouter.getIconForType(type),
        color: typeEnabled
            ? NotificationRouter.getColorForType(type)
            : Colors.grey,
      ),
      title: typeName,
      enabled: enabled,
      trailing: Switch.adaptive(
        value: typeEnabled,
        activeThumbColor: AppTheme.primaryColor,
        onChanged: enabled
            ? (value) {
                setState(() {
                  _settings!.setNotificationEnabled(type, value);
                });
                _saveSettings();
              }
            : null,
      ),
    );
  }

  String _getNotificationTypeKey(NotificationType type) {
    switch (type) {
      case NotificationType.newLead:
        return 'newLead';
      case NotificationType.leadNoFollowUp:
        return 'leadNoFollowUp';
      case NotificationType.leadReengaged:
        return 'leadReengaged';
      case NotificationType.leadContactFailed:
        return 'leadContactFailed';
      case NotificationType.leadStatusChanged:
        return 'leadStatusChanged';
      case NotificationType.leadAssigned:
        return 'leadAssigned';
      case NotificationType.leadTransferred:
        return 'leadTransferred';
      case NotificationType.leadUpdated:
        return 'leadUpdated';
      case NotificationType.leadReminder:
        return 'leadReminder';
      case NotificationType.teamActivity:
        return 'teamActivity';
      case NotificationType.whatsappMessageReceived:
        return 'whatsappMessageReceived';
      case NotificationType.whatsappTemplateSent:
        return 'whatsappTemplateSent';
      case NotificationType.whatsappSendFailed:
        return 'whatsappSendFailed';
      case NotificationType.whatsappWaitingResponse:
        return 'whatsappWaitingResponse';
      case NotificationType.campaignPerformance:
        return 'campaignPerformance';
      case NotificationType.campaignLowPerformance:
        return 'campaignLowPerformance';
      case NotificationType.campaignStopped:
        return 'campaignStopped';
      case NotificationType.campaignBudgetAlert:
        return 'campaignBudgetAlert';
      case NotificationType.taskCreated:
        return 'taskCreated';
      case NotificationType.taskReminder:
        return 'taskReminder';
      case NotificationType.taskCompleted:
        return 'taskCompleted';
      case NotificationType.callReminder:
        return 'callReminder';
      case NotificationType.visitReminder:
        return 'visitReminder';
      case NotificationType.receptionVisitReminder:
        return 'receptionVisitReminder';
      case NotificationType.tenantChat:
        return 'teamChat';
      case NotificationType.dealCreated:
        return 'dealCreated';
      case NotificationType.dealUpdated:
        return 'dealUpdated';
      case NotificationType.dealClosed:
        return 'dealClosed';
      case NotificationType.dealReminder:
        return 'dealReminder';
      case NotificationType.dailyReport:
        return 'dailyReport';
      case NotificationType.weeklyReport:
        return 'weeklyReport';
      case NotificationType.topEmployee:
        return 'topEmployee';
      case NotificationType.loginFromNewDevice:
        return 'loginFromNewDevice';
      case NotificationType.systemUpdate:
        return 'systemUpdate';
      case NotificationType.subscriptionExpiring:
        return 'subscriptionExpiring';
      case NotificationType.paymentFailed:
        return 'paymentFailed';
      case NotificationType.subscriptionExpired:
        return 'subscriptionExpired';
      default:
        return 'general';
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final initialTime = TimeOfDay(
      hour: isStart
          ? _settings!.timeSettings.startHour
          : _settings!.timeSettings.endHour,
      minute: 0,
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      setState(() {
        if (isStart) {
          _settings!.timeSettings.startHour = selectedTime.hour;
        } else {
          _settings!.timeSettings.endHour = selectedTime.hour;
        }
      });
      _saveSettings();
    }
  }
}
