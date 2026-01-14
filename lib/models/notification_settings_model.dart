import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'notification_model.dart';
import '../services/api_service.dart';
import '../core/constants/app_constants.dart';

/// نموذج إعدادات الإشعارات
class NotificationSettings {
  /// تفعيل/إيقاف جميع الإشعارات
  bool enabled;
  
  /// إعدادات حسب نوع الإشعار
  Map<NotificationType, bool> notificationTypes;
  
  /// إعدادات حسب وقت الإرسال
  NotificationTimeSettings timeSettings;
  
  /// إعدادات حسب مصدر العميل المحتمل
  Map<String, bool> sourceSettings;
  
  /// إعدادات حسب نوع المستخدم
  Map<String, bool> userRoleSettings;

  NotificationSettings({
    this.enabled = true,
    Map<NotificationType, bool>? notificationTypes,
    NotificationTimeSettings? timeSettings,
    Map<String, bool>? sourceSettings,
    Map<String, bool>? userRoleSettings,
  })  : notificationTypes = notificationTypes ?? _getDefaultNotificationTypes(),
        timeSettings = timeSettings ?? NotificationTimeSettings(),
        sourceSettings = sourceSettings ?? {},
        userRoleSettings = userRoleSettings ?? {};

  /// الحصول على الإعدادات الافتراضية
  static Map<NotificationType, bool> _getDefaultNotificationTypes() {
    return {
      // إشعارات العملاء المحتملين - مفعلة افتراضياً
      NotificationType.newLead: true,
      NotificationType.leadNoFollowUp: true,
      NotificationType.leadReengaged: true,
      NotificationType.leadContactFailed: true,
      NotificationType.leadStatusChanged: true,
      NotificationType.leadAssigned: true,
      NotificationType.leadTransferred: true,
      NotificationType.leadUpdated: true,
      NotificationType.leadReminder: true,
      
      // إشعارات واتساب - مفعلة افتراضياً
      NotificationType.whatsappMessageReceived: true,
      NotificationType.whatsappTemplateSent: true,
      NotificationType.whatsappSendFailed: true,
      NotificationType.whatsappWaitingResponse: true,
      
      // إشعارات الحملات - مفعلة للمالك والمدير فقط
      NotificationType.campaignPerformance: true,
      NotificationType.campaignLowPerformance: true,
      NotificationType.campaignStopped: true,
      NotificationType.campaignBudgetAlert: true,
      
      // إشعارات الفريق والمهام - مفعلة افتراضياً
      NotificationType.taskCreated: true,
      NotificationType.taskReminder: true,
      NotificationType.taskCompleted: true,
      NotificationType.callReminder: true,
      
      // إشعارات الصفقات - مفعلة افتراضياً
      NotificationType.dealCreated: true,
      NotificationType.dealUpdated: true,
      NotificationType.dealClosed: true,
      NotificationType.dealReminder: true,
      
      // إشعارات التقارير - مفعلة للمالك والمدير فقط
      NotificationType.dailyReport: true,
      NotificationType.weeklyReport: true,
      NotificationType.topEmployee: true,
      
      // إشعارات النظام - مفعلة افتراضياً
      NotificationType.loginFromNewDevice: true,
      NotificationType.systemUpdate: true,
      NotificationType.subscriptionExpiring: true,
      NotificationType.paymentFailed: true,
      NotificationType.subscriptionExpired: true,
      
      // إشعارات عامة
      NotificationType.general: true,
    };
  }

  /// التحقق من تفعيل نوع إشعار معين
  bool isNotificationEnabled(NotificationType type) {
    if (!enabled) return false;
    return notificationTypes[type] ?? true;
  }

  /// تفعيل/إيقاف نوع إشعار معين
  void setNotificationEnabled(NotificationType type, bool enabled) {
    notificationTypes[type] = enabled;
  }

  /// حفظ الإعدادات محلياً وعلى الخادم
  Future<void> save({bool syncToServer = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    
    // حفظ إعدادات الأنواع
    final typesMap = <String, bool>{};
    notificationTypes.forEach((key, value) {
      typesMap[key.name] = value;
    });
    await prefs.setString('notification_types', jsonEncode(typesMap));
    
    // حفظ إعدادات الوقت
    await prefs.setString('notification_time_settings', jsonEncode(timeSettings.toJson()));
    
    // حفظ إعدادات المصادر
    await prefs.setString('notification_sources', jsonEncode(sourceSettings));
    
    // حفظ إعدادات الأدوار
    await prefs.setString('notification_user_roles', jsonEncode(userRoleSettings));
    
    // مزامنة مع الخادم إذا كان المستخدم مسجل دخول
    if (syncToServer) {
      try {
        final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
        if (isLoggedIn) {
          debugPrint('Syncing notification settings to server...');
          await _syncToServer();
          debugPrint('Notification settings synced to server successfully');
        } else {
          debugPrint('User not logged in, skipping server sync');
        }
      } catch (e) {
        // لا نعرض خطأ للمستخدم لأن الإعدادات المحلية تم حفظها
        debugPrint('Warning: Failed to sync notification settings to server: $e');
      }
    }
  }
  
  /// مزامنة الإعدادات مع الخادم
  Future<void> _syncToServer() async {
    try {
      final apiService = ApiService();
      final settingsMap = toServerMap();
      debugPrint('Syncing notification settings to server: ${settingsMap.keys}');
      await apiService.updateNotificationSettings(settingsMap);
      debugPrint('✓ Notification settings synced successfully');
    } catch (e, stackTrace) {
      debugPrint('Error syncing notification settings to server: $e');
      debugPrint('Stack trace: $stackTrace');
      // لا نرمي exception لأن الإعدادات المحلية تم حفظها
    }
  }
  
  /// تحويل الإعدادات إلى خريطة للخادم
  Map<String, dynamic> toServerMap() {
    final typesMap = <String, bool>{};
    notificationTypes.forEach((key, value) {
      typesMap[key.name] = value;
    });
    
    return {
      'enabled': enabled,
      'notification_types': typesMap,
      'restrict_time': timeSettings.restrictTime,
      'start_hour': timeSettings.startHour,
      'end_hour': timeSettings.endHour,
      'enabled_days': timeSettings.enabledDays,
      'source_settings': sourceSettings,
      'user_role_settings': userRoleSettings,
    };
  }
  
  /// تحميل الإعدادات من خريطة الخادم
  static NotificationSettings fromServerMap(Map<String, dynamic> map) {
    // تحويل notification_types من Map<String, bool> إلى Map<NotificationType, bool>
    Map<NotificationType, bool> types = {};
    if (map['notification_types'] != null) {
      final typesMap = map['notification_types'] as Map<String, dynamic>;
      typesMap.forEach((key, value) {
        final type = NotificationType.values.firstWhere(
          (e) => e.name == key,
          orElse: () => NotificationType.unknown,
        );
        if (type != NotificationType.unknown) {
          types[type] = value as bool;
        }
      });
    }
    
    // تحميل إعدادات الوقت
    NotificationTimeSettings timeSettings = NotificationTimeSettings();
    if (map['restrict_time'] != null) {
      timeSettings = NotificationTimeSettings(
        restrictTime: map['restrict_time'] as bool? ?? false,
        startHour: map['start_hour'] as int? ?? 9,
        endHour: map['end_hour'] as int? ?? 18,
        enabledDays: map['enabled_days'] != null
            ? List<bool>.from(map['enabled_days'] as List)
            : List.filled(7, true),
      );
    }
    
    return NotificationSettings(
      enabled: map['enabled'] as bool? ?? true,
      notificationTypes: types.isEmpty ? null : types,
      timeSettings: timeSettings,
      sourceSettings: map['source_settings'] != null
          ? Map<String, bool>.from(map['source_settings'] as Map)
          : {},
      userRoleSettings: map['user_role_settings'] != null
          ? Map<String, bool>.from(map['user_role_settings'] as Map)
          : {},
    );
  }

  /// تحميل الإعدادات من التخزين المحلي
  static Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    
    // تحميل إعدادات الأنواع
    Map<NotificationType, bool> types = {};
    final typesJson = prefs.getString('notification_types');
    if (typesJson != null) {
      final typesMap = jsonDecode(typesJson) as Map<String, dynamic>;
      typesMap.forEach((key, value) {
        final type = NotificationType.values.firstWhere(
          (e) => e.name == key,
          orElse: () => NotificationType.unknown,
        );
        if (type != NotificationType.unknown) {
          types[type] = value as bool;
        }
      });
    }
    
    // تحميل إعدادات الوقت
    NotificationTimeSettings timeSettings = NotificationTimeSettings();
    final timeJson = prefs.getString('notification_time_settings');
    if (timeJson != null) {
      timeSettings = NotificationTimeSettings.fromJson(
        jsonDecode(timeJson) as Map<String, dynamic>,
      );
    }
    
    // تحميل إعدادات المصادر
    Map<String, bool> sources = {};
    final sourcesJson = prefs.getString('notification_sources');
    if (sourcesJson != null) {
      sources = Map<String, bool>.from(
        jsonDecode(sourcesJson) as Map<String, dynamic>,
      );
    }
    
    // تحميل إعدادات الأدوار
    Map<String, bool> roles = {};
    final rolesJson = prefs.getString('notification_user_roles');
    if (rolesJson != null) {
      roles = Map<String, bool>.from(
        jsonDecode(rolesJson) as Map<String, dynamic>,
      );
    }
    
    return NotificationSettings(
      enabled: enabled,
      notificationTypes: types.isEmpty ? null : types,
      timeSettings: timeSettings,
      sourceSettings: sources.isEmpty ? null : sources,
      userRoleSettings: roles.isEmpty ? null : roles,
    );
  }

  /// إعادة تعيين الإعدادات للقيم الافتراضية
  void resetToDefaults() {
    enabled = true;
    notificationTypes = _getDefaultNotificationTypes();
    timeSettings = NotificationTimeSettings();
    sourceSettings = {};
    userRoleSettings = {};
  }
}

/// إعدادات وقت الإرسال
class NotificationTimeSettings {
  /// تفعيل الإشعارات في أوقات معينة فقط
  bool restrictTime;
  
  /// وقت البداية (ساعة)
  int startHour;
  
  /// وقت النهاية (ساعة)
  int endHour;
  
  /// أيام الأسبوع المفعّلة (0 = الأحد، 6 = السبت)
  List<bool> enabledDays;

  NotificationTimeSettings({
    this.restrictTime = false,
    this.startHour = 9,
    this.endHour = 18,
    List<bool>? enabledDays,
  }) : enabledDays = enabledDays ?? List.filled(7, true);

  /// التحقق من إمكانية إرسال إشعار في الوقت الحالي
  bool canSendNow() {
    if (!restrictTime) return true;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentDay = now.weekday % 7; // 0 = الأحد
    
    // التحقق من اليوم
    if (!enabledDays[currentDay]) return false;
    
    // التحقق من الوقت
    if (startHour <= endHour) {
      return currentHour >= startHour && currentHour < endHour;
    } else {
      // إذا كان الوقت يمتد على يومين (مثلاً 22:00 - 06:00)
      return currentHour >= startHour || currentHour < endHour;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'restrict_time': restrictTime,
      'start_hour': startHour,
      'end_hour': endHour,
      'enabled_days': enabledDays,
    };
  }

  factory NotificationTimeSettings.fromJson(Map<String, dynamic> json) {
    return NotificationTimeSettings(
      restrictTime: json['restrict_time'] as bool? ?? false,
      startHour: json['start_hour'] as int? ?? 9,
      endHour: json['end_hour'] as int? ?? 18,
      enabledDays: json['enabled_days'] != null
          ? List<bool>.from(json['enabled_days'] as List)
          : List.filled(7, true),
    );
  }
}
