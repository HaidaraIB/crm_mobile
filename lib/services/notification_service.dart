import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/notification_settings_model.dart' as app_settings;
import '../core/constants/app_constants.dart';
import 'api_service.dart';

/// معالج الإشعارات في الخلفية (يجب أن يكون top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Notification title: ${message.notification?.title}');
  debugPrint('Notification body: ${message.notification?.body}');
  debugPrint('Message data: ${message.data}');
  // يمكن إضافة معالجة إضافية هنا
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _firebaseMessaging;
  
  bool _initialized = false;
  String? _fcmToken;
  StreamController<NotificationPayload>? _notificationStreamController;
  
  /// الحصول على FirebaseMessaging instance (lazy initialization)
  FirebaseMessaging? get _messaging {
    if (_firebaseMessaging == null && Firebase.apps.isNotEmpty) {
      _firebaseMessaging = FirebaseMessaging.instance;
    }
    return _firebaseMessaging;
  }
  
  /// Stream للإشعارات الواردة (للاستخدام في الواجهة)
  Stream<NotificationPayload> get notificationStream {
    _notificationStreamController ??= StreamController<NotificationPayload>.broadcast();
    return _notificationStreamController!.stream;
  }

  /// الحصول على FCM Token
  String? get fcmToken => _fcmToken;
  
  /// الحصول على FCM Token (public method)
  Future<String?> getFCMToken() async {
    if (_fcmToken != null) {
      return _fcmToken;
    }
    return await _getFCMToken();
  }

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // تهيئة المناطق الزمنية
      tz.initializeTimeZones();

      // تهيئة الإشعارات المحلية
      await _initializeLocalNotifications();

      // تهيئة Firebase Messaging
      await _initializeFirebaseMessaging();

      // طلب الأذونات
      await requestPermissions();

      // الحصول على FCM Token
      await _getFCMToken();

      _initialized = true;
      debugPrint('✓ NotificationService initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('✗ Error initializing NotificationService: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// تهيئة الإشعارات المحلية
  Future<void> _initializeLocalNotifications() async {
    // إعدادات Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // إعدادات iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // إعدادات التهيئة
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // تهيئة الإشعارات المحلية
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // إنشاء قنوات الإشعارات
    await _createNotificationChannels();
  }

  /// إنشاء قنوات الإشعارات (Android)
  Future<void> _createNotificationChannels() async {
    // قناة الإشعارات العامة
    const generalChannel = AndroidNotificationChannel(
      'general',
      'General Notifications',
      description: 'General notifications from CRM',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة إشعارات العملاء
    const leadsChannel = AndroidNotificationChannel(
      'leads',
      'Lead Notifications',
      description: 'Notifications about leads and clients',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة إشعارات الصفقات
    const dealsChannel = AndroidNotificationChannel(
      'deals',
      'Deal Notifications',
      description: 'Notifications about deals',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة إشعارات المهام
    const tasksChannel = AndroidNotificationChannel(
      'tasks',
      'Task Notifications',
      description: 'Task and reminder notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة التذكيرات
    const remindersChannel = AndroidNotificationChannel(
      'reminders',
      'Reminders',
      description: 'Reminder notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة إشعارات واتساب
    const whatsappChannel = AndroidNotificationChannel(
      'whatsapp',
      'WhatsApp Notifications',
      description: 'WhatsApp message notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة إشعارات الحملات
    const campaignsChannel = AndroidNotificationChannel(
      'campaigns',
      'Campaign Notifications',
      description: 'Campaign performance notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة إشعارات التقارير
    const reportsChannel = AndroidNotificationChannel(
      'reports',
      'Report Notifications',
      description: 'Report and analytics notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // قناة إشعارات النظام
    const systemChannel = AndroidNotificationChannel(
      'system',
      'System Notifications',
      description: 'System and subscription notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // إنشاء القنوات
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(generalChannel);
      await androidPlugin.createNotificationChannel(leadsChannel);
      await androidPlugin.createNotificationChannel(dealsChannel);
      await androidPlugin.createNotificationChannel(tasksChannel);
      await androidPlugin.createNotificationChannel(remindersChannel);
      await androidPlugin.createNotificationChannel(whatsappChannel);
      await androidPlugin.createNotificationChannel(campaignsChannel);
      await androidPlugin.createNotificationChannel(reportsChannel);
      await androidPlugin.createNotificationChannel(systemChannel);
    }
  }

  /// تهيئة Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // التحقق من أن Firebase تم تهيئته
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠ Firebase not initialized, skipping FCM setup');
        return;
      }

      // التحقق من أن FirebaseMessaging متاح (سيتم تهيئته تلقائياً عبر getter)
      final messaging = _messaging;
      if (messaging == null) {
        debugPrint('⚠ FirebaseMessaging not available');
        return;
      }

      // تسجيل معالج الإشعارات في الخلفية
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // معالج الإشعارات عند فتح التطبيق
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // معالج النقر على الإشعار عند فتح التطبيق
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

      // التحقق من وجود إشعار عند فتح التطبيق
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpened(initialMessage);
      }
        } catch (e) {
      debugPrint('⚠ Error initializing Firebase Messaging: $e');
      debugPrint('⚠ Local notifications will still work');
    }
  }

  /// معالج الإشعارات في الواجهة الأمامية
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');
    debugPrint('Notification title: ${message.notification?.title}');
    debugPrint('Notification body: ${message.notification?.body}');
    debugPrint('Message data: ${message.data}');

    // استخدام RemoteMessage مباشرة (سيتم استخراج notification و data تلقائياً)
    final payload = NotificationPayload.fromRemoteMessage(message);

    // إرسال الإشعار إلى Stream
    _notificationStreamController?.add(payload);

    // عرض إشعار محلي
    // استخدام title و body من payload (تم استخراجهما من message.notification)
    await showLocalNotification(
      title: payload.title.isNotEmpty ? payload.title : 'Notification',
      body: payload.body.isNotEmpty ? payload.body : '',
      payload: payload,
    );
  }

  /// معالج فتح الإشعار
  void _handleNotificationOpened(RemoteMessage message) {
    debugPrint('Notification opened: ${message.messageId}');
    debugPrint('Notification title: ${message.notification?.title}');
    debugPrint('Notification body: ${message.notification?.body}');
    debugPrint('Message data: ${message.data}');

    // استخدام RemoteMessage مباشرة (سيتم استخراج notification و data تلقائياً)
    final payload = NotificationPayload.fromRemoteMessage(message);

    // إرسال الإشعار إلى Stream للتنقل
    _notificationStreamController?.add(payload);
  }

  /// معالج النقر على الإشعار المحلي
  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        // يمكن إضافة معالجة إضافية هنا
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// طلب أذونات الإشعارات
  Future<bool> requestPermissions() async {
    try {
      // التحقق من أن Firebase تم تهيئته
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠ Firebase not initialized, requesting local notification permissions only');
        // يمكن طلب أذونات الإشعارات المحلية هنا إذا لزم الأمر
        return true;
      }

      // طلب الأذونات من Firebase
      final messaging = _messaging;
      if (messaging == null) {
        return false;
      }
      
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✓ User granted notification permissions');
        return true;
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠ User granted provisional notification permissions');
        return true;
      } else {
        debugPrint('✗ User denied notification permissions');
        return false;
      }
    } catch (e) {
      debugPrint('⚠ Error requesting permissions: $e');
      debugPrint('⚠ Local notifications will still work');
      return false;
    }
  }

  /// الحصول على FCM Token
  Future<String?> _getFCMToken() async {
    try {
      // التحقق من أن Firebase تم تهيئته
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠ Firebase not initialized, FCM token unavailable');
        return null;
      }

      final messaging = _messaging;
      if (messaging == null) {
        debugPrint('⚠ FirebaseMessaging not available');
        return null;
      }

      _fcmToken = await messaging.getToken();
      debugPrint('✓ FCM Token: ${_fcmToken?.substring(0, 20)}...');

      // حفظ Token في SharedPreferences
      if (_fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
      }

      // الاستماع لتحديثات Token
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: ${newToken.substring(0, 20)}...');
        _saveFCMToken(newToken);
        _sendTokenToServer(newToken);
      });

      // إرسال Token إلى الخادم (سيتم إرساله بعد تسجيل الدخول)
      // لا نرسله هنا لأن المستخدم قد لا يكون مسجل دخول بعد
      // سيتم إرساله في two_factor_auth_screen بعد تسجيل الدخول الناجح

      return _fcmToken;
    } catch (e) {
      debugPrint('⚠ Error getting FCM token: $e');
      debugPrint('⚠ Local notifications will still work');
      return null;
    }
  }

  /// حفظ FCM Token محلياً
  Future<void> _saveFCMToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// إرسال FCM Token إلى الخادم
  Future<void> _sendTokenToServer(String? token) async {
    if (token == null) return;

    try {
      // التحقق من أن المستخدم مسجل دخول
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
      
      if (!isLoggedIn) {
        debugPrint('User not logged in, skipping FCM token send. Will send after login.');
        return;
      }

      // الحصول على اللغة الحالية من SharedPreferences
      final languageCode = prefs.getString(AppConstants.languageKey) ?? 'ar';

      await ApiService().updateFCMToken(token, language: languageCode);
      debugPrint('FCM Token and language sent to server successfully');
    } catch (e) {
      debugPrint('Warning: Error sending FCM token to server: $e');
      // لا نرمي exception هنا لأن الإشعارات المحلية ستعمل حتى بدون إرسال Token
    }
  }
  
  /// إرسال FCM Token إلى الخادم (للاستخدام بعد تسجيل الدخول)
  Future<void> sendTokenToServerIfLoggedIn() async {
    if (_fcmToken == null) {
      // محاولة الحصول على Token إذا لم يكن موجوداً
      try {
        final token = await getFCMToken();
        if (token != null) {
          await _sendTokenToServer(token);
        }
      } catch (e) {
        debugPrint('Warning: Failed to get FCM token: $e');
      }
    } else {
      await _sendTokenToServer(_fcmToken);
    }
  }

  /// عرض إشعار محلي
  Future<void> showLocalNotification({
    required String title,
    required String body,
    NotificationPayload? payload,
    String? channelId,
    Importance? importance,
  }) async {
    if (!_initialized) await initialize();

    // التحقق من الإعدادات قبل إرسال الإشعار
    if (payload?.type != null) {
      final settings = await app_settings.NotificationSettings.load();
      
      // التحقق من تفعيل الإشعارات بشكل عام
      if (!settings.enabled) {
        debugPrint('⚠ Notifications are disabled in settings');
        return;
      }
      
      // التحقق من تفعيل نوع الإشعار المحدد
      if (!settings.isNotificationEnabled(payload!.type)) {
        debugPrint('⚠ Notification type ${payload.type.name} is disabled in settings');
        return;
      }
      
      // التحقق من وقت الإرسال
      if (!settings.timeSettings.canSendNow()) {
        debugPrint('⚠ Cannot send notification outside allowed time');
        return;
      }
    }

    // تحديد قناة الإشعار بناءً على النوع
    final notificationChannel = channelId ?? _getChannelForType(payload?.type);
    final notificationImportance = importance ?? Importance.high;

    final notificationId = payload?.notificationId ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannel,
          _getChannelName(notificationChannel),
          channelDescription: _getChannelDescription(notificationChannel),
          importance: notificationImportance,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload?.toJson().toString(),
    );
  }

  /// تحديد قناة الإشعار بناءً على النوع
  String _getChannelForType(NotificationType? type) {
    if (type == null) return 'general';

    switch (type) {
      // إشعارات العملاء المحتملين
      case NotificationType.newLead:
      case NotificationType.leadAssigned:
      case NotificationType.leadUpdated:
      case NotificationType.leadStatusChanged:
      case NotificationType.leadReminder:
      case NotificationType.leadNoFollowUp:
      case NotificationType.leadReengaged:
      case NotificationType.leadContactFailed:
      case NotificationType.leadTransferred:
        return 'leads';
      
      // إشعارات واتساب
      case NotificationType.whatsappMessageReceived:
      case NotificationType.whatsappTemplateSent:
      case NotificationType.whatsappSendFailed:
      case NotificationType.whatsappWaitingResponse:
        return 'whatsapp';
      
      // إشعارات الحملات
      case NotificationType.campaignPerformance:
      case NotificationType.campaignLowPerformance:
      case NotificationType.campaignStopped:
      case NotificationType.campaignBudgetAlert:
        return 'campaigns';
      
      // إشعارات الصفقات
      case NotificationType.dealCreated:
      case NotificationType.dealUpdated:
      case NotificationType.dealClosed:
      case NotificationType.dealReminder:
        return 'deals';
      
      // إشعارات المهام
      case NotificationType.taskCreated:
      case NotificationType.taskCompleted:
      case NotificationType.taskReminder:
        return 'tasks';
      
      // إشعارات التقارير
      case NotificationType.dailyReport:
      case NotificationType.weeklyReport:
      case NotificationType.topEmployee:
        return 'reports';
      
      // إشعارات النظام
      case NotificationType.loginFromNewDevice:
      case NotificationType.systemUpdate:
      case NotificationType.subscriptionExpiring:
      case NotificationType.paymentFailed:
      case NotificationType.subscriptionExpired:
        return 'system';
      
      default:
        return 'general';
    }
  }

  /// الحصول على اسم القناة
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'leads':
        return 'Lead Notifications';
      case 'whatsapp':
        return 'WhatsApp Notifications';
      case 'campaigns':
        return 'Campaign Notifications';
      case 'deals':
        return 'Deal Notifications';
      case 'tasks':
        return 'Task Notifications';
      case 'reports':
        return 'Report Notifications';
      case 'system':
        return 'System Notifications';
      case 'reminders':
        return 'Reminders';
      default:
        return 'General Notifications';
    }
  }

  /// الحصول على وصف القناة
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'leads':
        return 'Notifications about leads and clients';
      case 'whatsapp':
        return 'WhatsApp message notifications';
      case 'campaigns':
        return 'Campaign performance notifications';
      case 'deals':
        return 'Notifications about deals';
      case 'tasks':
        return 'Task and reminder notifications';
      case 'reports':
        return 'Report and analytics notifications';
      case 'system':
        return 'System and subscription notifications';
      case 'reminders':
        return 'Reminder notifications';
      default:
        return 'General notifications from CRM';
    }
  }

  /// جدولة إشعار تذكير
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    NotificationPayload? payload,
    String? channelId,
  }) async {
    if (!_initialized) await initialize();

    final notificationChannel = channelId ?? 'reminders';

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannel,
          _getChannelName(notificationChannel),
          channelDescription: _getChannelDescription(notificationChannel),
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload?.toJson().toString(),
    );
  }

  /// إلغاء إشعار مجدول
  Future<void> cancelReminder(int id) async {
    await _localNotifications.cancel(id);
  }

  /// إلغاء جميع الإشعارات
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  /// الاشتراك في موضوع (topic)
  Future<void> subscribeToTopic(String topic) async {
    try {
      final messaging = _messaging;
      if (messaging == null) {
        debugPrint('⚠ Firebase not initialized, cannot subscribe to topic');
        return;
      }
      await messaging.subscribeToTopic(topic);
      debugPrint('✓ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('✗ Error subscribing to topic $topic: $e');
    }
  }

  /// إلغاء الاشتراك من موضوع
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      final messaging = _messaging;
      if (messaging == null) {
        debugPrint('⚠ Firebase not initialized, cannot unsubscribe from topic');
        return;
      }
      await messaging.unsubscribeFromTopic(topic);
      debugPrint('✓ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('✗ Error unsubscribing from topic $topic: $e');
    }
  }

  /// تنظيف الموارد
  void dispose() {
    _notificationStreamController?.close();
    _notificationStreamController = null;
  }
}