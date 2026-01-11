import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/notification_settings_model.dart' as app_settings;
import '../../models/notification_model.dart';
import '../../services/notification_router.dart';
import '../../services/api_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/constants/app_constants.dart';

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

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    // محاولة تحميل الإعدادات من الخادم أولاً
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;

      if (isLoggedIn) {
        final apiService = ApiService();
        final serverSettings = await apiService.getNotificationSettings();

        if (serverSettings != null) {
          // استخدام الإعدادات من الخادم
          final settings = app_settings.NotificationSettings.fromServerMap(
            serverSettings,
          );
          // حفظها محلياً أيضاً
          await settings.save(syncToServer: false);
          setState(() {
            _settings = settings;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      // في حالة فشل التحميل من الخادم، نستخدم الإعدادات المحلية
      debugPrint('Warning: Failed to load settings from server: $e');
    }

    // تحميل الإعدادات المحلية كبديل
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
        _showSuccessSnackBar(
          localizations?.translate('settingsSavedSuccessfully') ??
              'Settings saved successfully',
        );
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      final theme = Theme.of(context);
      final isDarkMode = theme.brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_settings == null) {
      return Scaffold(
        body: Center(
          child: Text(
            localizations?.translate('errorLoadingSettings') ??
                'Error loading settings',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations?.translate('notificationSettings') ??
              'Notification Settings',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // تفعيل/إيقاف جميع الإشعارات
          Card(
            child: SwitchListTile(
              title: Text(
                localizations?.translate('enableNotifications') ??
                    'Enable Notifications',
              ),
              subtitle: Text(
                localizations?.translate('enableOrDisableAllNotifications') ??
                    'Enable or disable all notifications',
              ),
              value: _settings!.enabled,
              onChanged: (value) {
                setState(() {
                  _settings!.enabled = value;
                });
                _saveSettings();
              },
              secondary: Icon(
                _settings!.enabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _settings!.enabled ? Colors.green : Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // إشعارات العملاء المحتملين
          _buildSection(
            context: context,
            title:
                '👤 ${localizations?.translate('leadNotifications') ?? 'Lead Notifications'}',
            subtitle:
                localizations?.translate('coreNotifications') ??
                'Core Notifications – appear first',
            types: [
              NotificationType.newLead,
              NotificationType.leadNoFollowUp,
              NotificationType.leadReengaged,
              NotificationType.leadContactFailed,
              NotificationType.leadStatusChanged,
              NotificationType.leadAssigned,
              NotificationType.leadTransferred,
              NotificationType.leadUpdated,
              NotificationType.leadReminder,
            ],
          ),

          // إشعارات واتساب
          _buildSection(
            context: context,
            title:
                '💬 ${localizations?.translate('whatsappNotifications') ?? 'WhatsApp Notifications'}',
            subtitle:
                localizations?.translate('whatsappAutomation') ??
                'WhatsApp Automation',
            types: [
              NotificationType.whatsappMessageReceived,
              NotificationType.whatsappTemplateSent,
              NotificationType.whatsappSendFailed,
              NotificationType.whatsappWaitingResponse,
            ],
          ),

          // إشعارات الحملات الإعلانية
          _buildSection(
            context: context,
            title:
                '📢 ${localizations?.translate('campaignNotifications') ?? 'Campaign Notifications'}',
            subtitle:
                localizations?.translate('adsPerformance') ?? 'Ads Performance',
            types: [
              NotificationType.campaignPerformance,
              NotificationType.campaignLowPerformance,
              NotificationType.campaignStopped,
              NotificationType.campaignBudgetAlert,
            ],
          ),

          // إشعارات الفريق والمهام
          _buildSection(
            context: context,
            title:
                '👥 ${localizations?.translate('teamAndTasksNotifications') ?? 'Team & Tasks Notifications'}',
            subtitle:
                localizations?.translate('teamAndTasks') ?? 'Team & Tasks',
            types: [
              NotificationType.taskCreated,
              NotificationType.taskReminder,
              NotificationType.taskCompleted,
            ],
          ),

          // إشعارات الصفقات
          _buildSection(
            context: context,
            title:
                '🤝 ${localizations?.translate('dealNotifications') ?? 'Deal Notifications'}',
            subtitle: localizations?.translate('deals') ?? 'Deals',
            types: [
              NotificationType.dealCreated,
              NotificationType.dealUpdated,
              NotificationType.dealClosed,
              NotificationType.dealReminder,
            ],
          ),

          // إشعارات التقارير
          _buildSection(
            context: context,
            title:
                '📈 ${localizations?.translate('reportsNotifications') ?? 'Report Notifications'}',
            subtitle:
                localizations?.translate('reportsAndInsights') ??
                'Reports & Insights',
            types: [
              NotificationType.dailyReport,
              NotificationType.weeklyReport,
              NotificationType.topEmployee,
            ],
          ),

          // إشعارات النظام
          _buildSection(
            context: context,
            title:
                '🧾 ${localizations?.translate('systemNotifications') ?? 'System & Subscription Notifications'}',
            subtitle:
                localizations?.translate('systemAndSubscription') ??
                'System & Subscription',
            types: [
              NotificationType.loginFromNewDevice,
              NotificationType.systemUpdate,
              NotificationType.subscriptionExpiring,
              NotificationType.paymentFailed,
              NotificationType.subscriptionExpired,
            ],
          ),

          const SizedBox(height: 24),

          // إعدادات الوقت
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.access_time),
              title: Text(
                localizations?.translate('sendTimeSettings') ??
                    'Send Time Settings',
              ),
              subtitle: Text(
                _settings!.timeSettings.restrictTime
                    ? (localizations?.translate('restrictedToSpecificTime') ??
                          'Restricted to specific time')
                    : (localizations?.translate('active24Hours') ??
                          'Active 24 hours'),
              ),
              children: [
                SwitchListTile(
                  title: Text(
                    localizations?.translate('restrictSendTime') ??
                        'Restrict Send Time',
                  ),
                  value: _settings!.timeSettings.restrictTime,
                  onChanged: (value) {
                    setState(() {
                      _settings!.timeSettings.restrictTime = value;
                    });
                    _saveSettings();
                  },
                ),
                if (_settings!.timeSettings.restrictTime) ...[
                  ListTile(
                    title: Text(
                      localizations?.translate('startTime') ?? 'Start Time',
                    ),
                    trailing: Text('${_settings!.timeSettings.startHour}:00'),
                    onTap: () => _selectTime(true),
                  ),
                  ListTile(
                    title: Text(
                      localizations?.translate('endTime') ?? 'End Time',
                    ),
                    trailing: Text('${_settings!.timeSettings.endHour}:00'),
                    onTap: () => _selectTime(false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<NotificationType> types,
  }) {
    final localizations = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(
          NotificationRouter.getIconForType(types.first),
          color: NotificationRouter.getColorForType(types.first),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        children: types.map((type) {
          final enabled = _settings!.isNotificationEnabled(type);
          // الحصول على اسم النوع من الترجمة
          final typeKey = _getNotificationTypeKey(type);
          final typeName =
              localizations?.translate(typeKey) ??
              NotificationRouter.getTypeName(type);

          return SwitchListTile(
            title: Text(typeName),
            value: enabled,
            onChanged: _settings!.enabled
                ? (value) {
                    setState(() {
                      _settings!.setNotificationEnabled(type, value);
                    });
                    _saveSettings();
                  }
                : null,
            secondary: Icon(
              NotificationRouter.getIconForType(type),
              color: enabled
                  ? NotificationRouter.getColorForType(type)
                  : Colors.grey,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// الحصول على مفتاح الترجمة لنوع الإشعار
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
