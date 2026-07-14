import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
import 'device_fcm_token.dart';
import 'team_chat_away_service.dart';
import 'softphone_push_handler.dart';
import 'softphone_service.dart';

const int _kTenantChatMergedNotifIdBase = 1900000000;
const int _kTenantChatMergeMaxLines = 5;
const String _kTenantChatMergePrefsPrefix = 'tenant_chat_push_merge_v1_';

/// Bump this when Android channels must be deleted and recreated (e.g. custom
/// sounds not applied because channels existed with default sound first).
const String _kAndroidChannelSoundMigrationPrefsKey =
    'android_notif_channel_sound_v2_done';

const List<String> _kAllAndroidNotificationChannelIds = <String>[
  'general',
  'leads',
  'deals',
  'tasks',
  'reminders',
  'whatsapp',
  'campaigns',
  'reports',
  'system',
  'tenant_chat',
];

/// Android `res/raw` basename without extension; null = platform default sound.
String? _androidRawSoundBasenameForChannelId(String channelId) {
  switch (channelId) {
    case 'tenant_chat':
      return 'notif_tenant_chat';
    case 'leads':
      return 'notif_leads';
    case 'whatsapp':
      return 'notif_whatsapp';
    case 'campaigns':
      return 'notif_campaigns';
    case 'deals':
      return 'notif_deals';
    case 'tasks':
      return 'notif_tasks';
    case 'reminders':
      return 'notif_reminders';
    case 'reports':
      return 'notif_reports';
    case 'system':
      return 'notif_system';
    case 'general':
      return null;
    default:
      return null;
  }
}

RawResourceAndroidNotificationSound? _androidSoundForChannelId(
  String channelId,
) {
  final base = _androidRawSoundBasenameForChannelId(channelId);
  if (base == null) return null;
  return RawResourceAndroidNotificationSound(base);
}

String? _iosSoundFileForChannelId(String channelId) {
  final base = _androidRawSoundBasenameForChannelId(channelId);
  if (base == null) return null;
  return '$base.wav';
}

Future<void> _migrateAndroidNotificationChannelsForCustomSoundsOnce(
  AndroidFlutterLocalNotificationsPlugin androidPlugin,
) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kAndroidChannelSoundMigrationPrefsKey) ?? false) {
    return;
  }
  for (final id in _kAllAndroidNotificationChannelIds) {
    try {
      await androidPlugin.deleteNotificationChannel(id);
    } catch (e, st) {
      debugPrint('deleteNotificationChannel($id) failed: $e\n$st');
    }
  }
  await prefs.setBool(_kAndroidChannelSoundMigrationPrefsKey, true);
}

String _tenantChatMergePrefsKey(int conversationId) =>
    '$_kTenantChatMergePrefsPrefix$conversationId';

String _tenantChatSinglePreviewLine(String raw) {
  var s = raw.replaceAll('\n', ' ').trim();
  if (s.length > 500) {
    s = '${s.substring(0, 497)}...';
  }
  return s;
}

Future<List<String>> _readTenantChatMergeLines(
  SharedPreferences prefs,
  int conversationId,
) async {
  final raw = prefs.getString(_tenantChatMergePrefsKey(conversationId));
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .map((e) => e.toString())
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return [];
}

/// Stable Android/iOS notification id so the same conversation replaces one tray item.
int _tenantChatMergedNotificationId(int conversationId) =>
    _kTenantChatMergedNotifIdBase + conversationId;

Future<List<String>> _appendTenantChatMergeLine(
  SharedPreferences prefs,
  int conversationId,
  String line,
) async {
  final preview = _tenantChatSinglePreviewLine(line);
  if (preview.isEmpty) {
    return _readTenantChatMergeLines(prefs, conversationId);
  }
  final cur = await _readTenantChatMergeLines(prefs, conversationId);
  final next = [...cur, preview];
  final trimmed = next.length > _kTenantChatMergeMaxLines
      ? next.sublist(next.length - _kTenantChatMergeMaxLines)
      : next;
  await prefs.setString(
    _tenantChatMergePrefsKey(conversationId),
    jsonEncode(trimmed),
  );
  return trimmed;
}

/// Android truncates plain [NotificationCompat] text in the shade; inbox / big text templates do not.
StyleInformation? _androidMergedTenantChatStyle(List<String> lines) {
  if (lines.isEmpty) return null;
  if (lines.length > 1) {
    return InboxStyleInformation(
      lines,
      summaryText: '${lines.length} messages',
    );
  }
  final only = lines.first;
  if (only.length > 80) {
    return BigTextStyleInformation(only);
  }
  return null;
}

final FlutterLocalNotificationsPlugin _fcmBackgroundLocalNotifications =
    FlutterLocalNotificationsPlugin();
bool _fcmBackgroundLocalNotificationsInitialized = false;

Future<void> _ensureFcmBackgroundLocalNotificationsInitialized() async {
  if (_fcmBackgroundLocalNotificationsInitialized) return;

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _fcmBackgroundLocalNotifications.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  final androidPlugin = _fcmBackgroundLocalNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    final tenantSound = _androidSoundForChannelId('tenant_chat');
    final tenantChatChannel = AndroidNotificationChannel(
      'tenant_chat',
      'Team chat',
      description: 'Messages from teammates (same sound as in-app chat alert)',
      importance: Importance.high,
      playSound: true,
      sound: tenantSound,
      enableVibration: true,
    );
    await androidPlugin.createNotificationChannel(tenantChatChannel);
  }

  _fcmBackgroundLocalNotificationsInitialized = true;
}

Future<void> _showTenantChatMergedFromBackground(NotificationPayload payload) async {
  final cid = NotificationService._conversationIdFromPayload(payload);
  if (cid == null) return;

  await _ensureFcmBackgroundLocalNotificationsInitialized();
  final prefs = await SharedPreferences.getInstance();
  final lines = await _appendTenantChatMergeLine(prefs, cid, payload.body);
  if (lines.isEmpty) return;

  final title = payload.title.isNotEmpty ? payload.title : 'Team chat';
  final mergedBody = lines.join('\n');
  final nid = _tenantChatMergedNotificationId(cid);
  final androidStyle = _androidMergedTenantChatStyle(lines);

  await _fcmBackgroundLocalNotifications.show(
    nid,
    title,
    mergedBody,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'tenant_chat',
        'Team chat',
        channelDescription: 'Messages from teammates',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: _androidSoundForChannelId('tenant_chat'),
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: androidStyle,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: _iosSoundFileForChannelId('tenant_chat'),
        subtitle: lines.length > 1 ? '${lines.length} messages' : null,
      ),
    ),
    payload: NotificationService.notificationPayloadJsonForLocalTap(payload),
  );
}

/// معالج الإشعارات في الخلفية (يجب أن يكون top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('FCM background: Firebase.initializeApp failed: $e');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(AppConstants.isLoggedInKey) ?? false)) {
      debugPrint(
        '[FCM] Background remote message discarded — user not logged in',
      );
      return;
    }
  } catch (e) {
    debugPrint('FCM background: login check failed — discarding ($e)');
    return;
  }

  debugPrint('Handling background message: ${message.messageId}');

  final payload = NotificationPayload.fromRemoteMessage(message);
  if (payload.data?['kind'] == 'softphone_incoming_call' ||
      payload.type == NotificationType.softphoneIncomingCall) {
    try {
      await SoftphonePushHandler.instance.handleIncomingPush(
        Map<String, dynamic>.from(payload.data ?? {}),
      );
    } catch (e, st) {
      debugPrint('[FCM] Background softphone push failed: $e');
      debugPrint('$st');
    }
    return;
  }
  if (NotificationService.isTenantChatPush(payload)) {
    // iOS team chat is delivered as an APNs alert with custom sound; Android merges locally.
    if (Platform.isIOS) {
      debugPrint(
        '[FCM] Background tenant_chat skipped on iOS — APNs alert handles tray + sound',
      );
      return;
    }
    try {
      await _showTenantChatMergedFromBackground(payload);
    } catch (e, st) {
      debugPrint('[FCM] Background tenant_chat local notification failed: $e');
      debugPrint('$st');
    }
    return;
  }

  // Non-chat pushes include a system notification payload; avoid duplicate locals.
  if (message.notification != null) {
    debugPrint(
      '[FCM] Background non-chat skipped — system notification already present',
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static void _forgetCachedDeviceTokenAfterLogout() {
    _instance._fcmToken = null;
  }

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
    onLocalFcmRegistrationCleared = _forgetCachedDeviceTokenAfterLogout;
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

    // إعدادات iOS: لا نطلب الإذن هنا لتجنب ظهور نافذة الإذن مرتين.
    // طلب الإذن يتم مرة واحدة فقط عبر Firebase في requestPermissions().
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
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

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await _migrateAndroidNotificationChannelsForCustomSoundsOnce(
        androidPlugin,
      );
    }

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
      sound: RawResourceAndroidNotificationSound('notif_leads'),
      enableVibration: true,
    );

    // قناة إشعارات الصفقات
    const dealsChannel = AndroidNotificationChannel(
      'deals',
      'Deal Notifications',
      description: 'Notifications about deals',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notif_deals'),
      enableVibration: true,
    );

    // قناة إشعارات المهام
    const tasksChannel = AndroidNotificationChannel(
      'tasks',
      'Task Notifications',
      description: 'Task and reminder notifications',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notif_tasks'),
      enableVibration: true,
    );

    // قناة التذكيرات
    const remindersChannel = AndroidNotificationChannel(
      'reminders',
      'Reminders',
      description: 'Reminder notifications',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notif_reminders'),
      enableVibration: true,
    );

    // قناة إشعارات واتساب
    const whatsappChannel = AndroidNotificationChannel(
      'whatsapp',
      'WhatsApp Notifications',
      description: 'WhatsApp message notifications',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notif_whatsapp'),
      enableVibration: true,
    );

    // قناة إشعارات الحملات
    const campaignsChannel = AndroidNotificationChannel(
      'campaigns',
      'Campaign Notifications',
      description: 'Campaign performance notifications',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notif_campaigns'),
      enableVibration: true,
    );

    // قناة إشعارات التقارير
    const reportsChannel = AndroidNotificationChannel(
      'reports',
      'Report Notifications',
      description: 'Report and analytics notifications',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notif_reports'),
      enableVibration: true,
    );

    // قناة إشعارات النظام
    const systemChannel = AndroidNotificationChannel(
      'system',
      'System Notifications',
      description: 'System and subscription notifications',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notif_system'),
      enableVibration: true,
    );

    // قناة إشعارات دردشة الفريق (نفس ملف الصوت المستخدم في التطبيق عند وصول رسالة)
    const tenantChatChannel = AndroidNotificationChannel(
      'tenant_chat',
      'Team chat',
      description: 'Messages from teammates (same sound as in-app chat alert)',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notif_tenant_chat'),
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
      await androidPlugin.createNotificationChannel(tenantChatChannel);
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

      // Match Point: suppress FCM auto-banner in foreground; we show local notifications
      // with the correct per-type sound instead of the default APNs presentation.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // تسجيل معالج الإشعارات في الخلفية
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // معالج الإشعارات عند فتح التطبيق
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // معالج النقر على الإشعار عند فتح التطبيق
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

      // التحقق من وجود إشعار عند فتح التطبيق
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final prefs = await SharedPreferences.getInstance();
        final loggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
        if (loggedIn) {
          _handleNotificationOpened(initialMessage);
        }
      }
        } catch (e) {
      debugPrint('⚠ Error initializing Firebase Messaging: $e');
      debugPrint('⚠ Local notifications will still work');
    }
  }

  /// معالج الإشعارات في الواجهة الأمامية
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(AppConstants.isLoggedInKey) ?? false)) {
      debugPrint(
        '[FCM] Foreground push ignored — user not logged in',
      );
      return;
    }

    debugPrint('Received foreground message: ${message.messageId}');
    debugPrint('Notification title: ${message.notification?.title}');
    debugPrint('Notification body: ${message.notification?.body}');
    debugPrint('Message data: ${message.data}');

    // استخدام RemoteMessage مباشرة (سيتم استخراج notification و data تلقائياً)
    final payload = NotificationPayload.fromRemoteMessage(message);

    if (payload.data?['kind'] == 'softphone_incoming_call' ||
        payload.type == NotificationType.softphoneIncomingCall) {
      await SoftphonePushHandler.instance.handleIncomingPush(
        Map<String, dynamic>.from(payload.data ?? {}),
      );
      return;
    }

    // عرض إشعار محلي
    // استخدام title و body من payload (تم استخراجهما من message.notification)
    if (_shouldSkipForegroundLocalNotificationForActiveTeamChat(payload)) {
      debugPrint(
        '[FCM] Foreground local notification skipped — team chat thread is open',
      );
      return;
    }
    await showLocalNotification(
      title: payload.title.isNotEmpty ? payload.title : 'Notification',
      body: payload.body.isNotEmpty ? payload.body : '',
      payload: payload,
    );
  }

  static int? _conversationIdFromPayload(NotificationPayload p) {
    final raw = p.data?['conversation_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }

  static bool _shouldSkipForegroundLocalNotificationForActiveTeamChat(
    NotificationPayload payload,
  ) {
    if (!_isTenantChatPush(payload)) return false;
    final cid = _conversationIdFromPayload(payload);
    return TeamChatAwayService.instance
        .shouldSuppressForegroundTenantChatNotification(cid);
  }

  /// معالج فتح الإشعار
  void _handleNotificationOpened(RemoteMessage message) {
    SharedPreferences.getInstance().then((prefs) {
      if (!(prefs.getBool(AppConstants.isLoggedInKey) ?? false)) {
        debugPrint(
          '[FCM] NotificationOpened ignored — user not logged in',
        );
        return;
      }
      debugPrint('Notification opened: ${message.messageId}');
      debugPrint('Notification title: ${message.notification?.title}');
      debugPrint('Notification body: ${message.notification?.body}');
      debugPrint('Message data: ${message.data}');

      final payload = NotificationPayload.fromRemoteMessage(message);
      _notificationStreamController?.add(payload);
    });
  }

  /// معالج النقر على الإشعار المحلي
  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');

    final raw = response.payload;
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      final payload = NotificationPayload.fromJson(map);
      _notificationStreamController?.add(payload);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  static String? _notificationPayloadString(NotificationPayload? payload) {
    if (payload == null) return null;
    try {
      return jsonEncode(payload.toJson());
    } catch (e) {
      debugPrint('Failed to encode notification payload: $e');
      return null;
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
        await prefs.setString(kSharedPrefsFcmTokenKey, _fcmToken!);
        // إرسال التوكن فور الحصول عليه إذا كان المستخدم مسجل دخول (مهم خاصة على iOS حيث قد يتأخر التوكن)
        _sendTokenToServer(_fcmToken);
      }

      // الاستماع لتحديثات Token
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: ${newToken.substring(0, 20)}...');
        _saveFCMToken(newToken);
        _sendTokenToServer(newToken);
        unawaited(SoftphoneService.instance.refreshDeviceRegistration());
      });

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
    await prefs.setString(kSharedPrefsFcmTokenKey, token);
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
  
  /// تشغيل تشخيص FCM كامل (كل الخطوات) وإرجاع قائمة النتائج لإرسالها للخادم.
  Future<List<Map<String, dynamic>>> runFullFcmDiagnostic() async {
    final steps = <Map<String, dynamic>>[];
    void addStep(String stepId, String stepName, bool success, String message, [String? detail]) {
      steps.add({
        'step_id': stepId,
        'step_name': stepName,
        'success': success,
        'message': message,
        if (detail != null && detail.isNotEmpty) 'detail': detail,
      });
    }

    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'other');
    addStep('1_platform', 'Platform', true, platform);

    final firebaseOk = Firebase.apps.isNotEmpty;
    addStep('2_firebase_init', 'Firebase initialized', firebaseOk,
        firebaseOk ? 'Firebase.apps is not empty' : 'Firebase.apps is empty');

    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        addStep('3_service_init', 'NotificationService initialized', false, 'initialize() threw', e.toString());
      }
    }
    addStep('3_service_init', 'NotificationService initialized', _initialized,
        _initialized ? 'Service initialized' : 'Service not initialized');

    final messaging = _messaging;
    final messagingOk = messaging != null;
    addStep('4_messaging_available', 'Firebase Messaging available', messagingOk,
        messagingOk ? 'FirebaseMessaging instance exists' : 'FirebaseMessaging is null');

    if (messaging != null) {
      try {
        final settings = await messaging.getNotificationSettings();
        final status = settings.authorizationStatus;
        final statusStr = status.toString().split('.').last;
        final permissionOk = status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
        addStep('5_permission', 'Notification permission', permissionOk,
            'authorizationStatus=$statusStr',
            'authorized=show notifications, denied=user denied, notDetermined=not asked yet');
      } catch (e) {
        addStep('5_permission', 'Notification permission', false, 'getNotificationSettings failed', e.toString());
      }
    } else {
      addStep('5_permission', 'Notification permission', false, 'Skipped (no Messaging)', '');
    }

    if (platform == 'ios' && messaging != null) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        final hasApns = apns != null && apns.isNotEmpty;
        addStep('5b_apns_token', 'APNS token (iOS)', hasApns,
            hasApns ? 'APNS token received' : 'APNS token is null or empty',
            apns != null ? 'length=${apns.length}' : 'No APNS token — check entitlements & provisioning profile');
      } catch (e) {
        addStep('5b_apns_token', 'APNS token (iOS)', false, 'getAPNSToken() threw', e.toString());
      }
    } else if (platform != 'ios') {
      addStep('5b_apns_token', 'APNS token (iOS)', true, 'N/A (Android)', '');
    }

    String? tokenResult;
    String? tokenDetail;
    try {
      final token = await getFCMToken();
      if (token != null && token.isNotEmpty) {
        tokenResult = 'Token received';
        tokenDetail = 'length=${token.length} prefix=${token.length > 12 ? token.substring(0, 12) : token}';
        addStep('6_get_token', 'FCM getToken()', true, tokenResult, tokenDetail);
      } else {
        tokenResult = 'Token is null or empty';
        addStep('6_get_token', 'FCM getToken()', false, tokenResult, 'Common on iOS if APNs not configured or permission denied');
      }
    } catch (e) {
      tokenResult = 'getToken threw';
      tokenDetail = e.toString();
      addStep('6_get_token', 'FCM getToken()', false, tokenResult, tokenDetail);
    }

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
    addStep('7_logged_in', 'User logged in', isLoggedIn,
        isLoggedIn ? 'isLoggedInKey=true' : 'isLoggedInKey=false or missing',
        'Token is only sent to server when user is logged in');

    if (_fcmToken != null && _fcmToken!.isNotEmpty && isLoggedIn) {
      try {
        final languageCode = prefs.getString(AppConstants.languageKey) ?? 'ar';
        final result = await ApiService().updateFCMTokenAndGetResult(
          _fcmToken!,
          language: languageCode,
        );
        final ok = result['success'] == true;
        final statusCode = result['status_code'];
        final msg = result['message'] ?? '';
        addStep('8_send_token_to_server', 'POST update-fcm-token', ok,
            'status_code=$statusCode message=$msg',
            ok ? 'Token accepted by server' : 'Check server logs and network');
      } catch (e) {
        addStep('8_send_token_to_server', 'POST update-fcm-token', false,
            'Request threw', e.toString());
      }
    } else {
      addStep('8_send_token_to_server', 'POST update-fcm-token', false,
          'Skipped', _fcmToken == null || _fcmToken!.isEmpty
              ? 'No token to send'
              : 'User not logged in');
    }

    final storedToken = prefs.getString(kSharedPrefsFcmTokenKey);
    final hasStored = storedToken != null && storedToken.isNotEmpty;
    addStep('9_token_in_prefs', 'Token in SharedPreferences', hasStored,
        hasStored ? 'Stored (length=${storedToken.length})' : 'Not stored or empty',
        'App uses this to resend on next launch if needed');

    return steps;
  }

  /// تشغيل التشخيص الكامل وإرسال كل النتائج للخادم (زر واحد).
  Future<void> runFullFcmDiagnosticAndSendToServer({String appVersion = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
    if (!isLoggedIn) {
      debugPrint('FCM diagnostic: user not logged in, cannot send to server');
      return;
    }
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'other');
    final steps = await runFullFcmDiagnostic();
    await ApiService().sendFcmDiagnosticsFull({
      'platform': platform,
      'app_version': appVersion,
      'steps': steps,
    });
  }

  /// إرسال FCM Token إلى الخادم (للاستخدام بعد تسجيل الدخول)
  /// على iOS قد يتأخر استلام التوكن؛ استدعِ هذه الدالة عند الدخول للصفحة الرئيسية أو عند استئناف التطبيق.
  Future<void> sendTokenToServerIfLoggedIn() async {
    if (_fcmToken == null) {
      // محاولة الحصول على Token إذا لم يكن موجوداً (مهم على iOS حيث قد يتأخر)
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

  static bool _isTenantChatPush(NotificationPayload? payload) {
    final k = payload?.data?['kind'];
    return k == 'tenant_chat';
  }

  /// Exposed for the FCM background isolate entrypoint in this library.
  static bool isTenantChatPush(NotificationPayload? payload) =>
      _isTenantChatPush(payload);

  static String? notificationPayloadJsonForLocalTap(NotificationPayload? payload) =>
      _notificationPayloadString(payload);

  /// Clears the merged push body cache for [conversationId] (e.g. when the user opens that thread).
  Future<void> clearTenantChatPushMergeBuffer(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantChatMergePrefsKey(conversationId));
    if (_initialized) {
      try {
        await _localNotifications.cancel(
          _tenantChatMergedNotificationId(conversationId),
        );
      } catch (e) {
        debugPrint('clearTenantChatPushMergeBuffer cancel failed: $e');
      }
    }
  }

  String _resolveAndroidChannelId(NotificationPayload? payload, String? explicitChannelId) {
    if (explicitChannelId != null && explicitChannelId.isNotEmpty) {
      return explicitChannelId;
    }
    if (_isTenantChatPush(payload)) return 'tenant_chat';
    return _getChannelForType(payload?.type);
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

    final tenantChat = _isTenantChatPush(payload);

    // إشعارات دردشة الفريق تتبع السيرفر (skip_settings_check) — لا تخفيها إذا كان "عام" معطلاً
    if (!tenantChat && payload?.type != null) {
      final settings = await app_settings.NotificationSettings.load();

      if (!settings.enabled) {
        debugPrint('⚠ Notifications are disabled in settings');
        return;
      }

      if (!settings.isNotificationEnabled(payload!.type)) {
        debugPrint('⚠ Notification type ${payload.type.name} is disabled in settings');
        return;
      }

      if (!settings.timeSettings.canSendNow()) {
        debugPrint('⚠ Cannot send notification outside allowed time');
        return;
      }
    }

    final notificationChannel = _resolveAndroidChannelId(payload, channelId);
    final notificationImportance = importance ?? Importance.high;
    final androidSound = _androidSoundForChannelId(notificationChannel);
    final iosSound = _iosSoundFileForChannelId(notificationChannel);

    var displayTitle = title;
    var displayBody = body;
    var notificationId = payload?.notificationId ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    List<String>? tenantMergeLines;

    if (tenantChat && payload != null) {
      final cid = _conversationIdFromPayload(payload);
      if (cid != null) {
        final prefs = await SharedPreferences.getInstance();
        final lines = await _appendTenantChatMergeLine(prefs, cid, body);
        tenantMergeLines = lines;
        if (lines.isNotEmpty) {
          displayBody = lines.join('\n');
        }
        notificationId = _tenantChatMergedNotificationId(cid);
      }
    }

    StyleInformation? androidStyle;
    if (tenantMergeLines != null && tenantMergeLines.isNotEmpty) {
      androidStyle = _androidMergedTenantChatStyle(tenantMergeLines);
    } else if (tenantChat && displayBody.length > 80) {
      androidStyle = BigTextStyleInformation(displayBody);
    }

    await _localNotifications.show(
      notificationId,
      displayTitle,
      displayBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannel,
          _getChannelName(notificationChannel),
          channelDescription: _getChannelDescription(notificationChannel),
          importance: notificationImportance,
          priority: Priority.high,
          playSound: true,
          sound: androidSound,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          styleInformation: androidStyle,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: iosSound,
          subtitle: tenantMergeLines != null && tenantMergeLines.length > 1
              ? '${tenantMergeLines.length} messages'
              : null,
        ),
      ),
      payload: _notificationPayloadString(payload),
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
      case NotificationType.callReminder:
      case NotificationType.visitReminder:
      case NotificationType.receptionVisitReminder:
        return 'tasks';

      case NotificationType.tenantChat:
        return 'tenant_chat';

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
      case 'tenant_chat':
        return 'Team chat';
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
      case 'tenant_chat':
        return 'Messages from teammates';
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
          sound: _androidSoundForChannelId(notificationChannel),
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: _iosSoundFileForChannelId(notificationChannel),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: _notificationPayloadString(payload),
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