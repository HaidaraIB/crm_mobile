import 'package:firebase_messaging/firebase_messaging.dart';

/// أنواع الإشعارات القابلة للتوسع
/// يمكن إضافة أنواع جديدة بسهولة هنا
enum NotificationType {
  // ==================== إشعارات العملاء المحتملين (Core Notifications) ====================
  /// 📥 عميل محتمل جديد
  newLead, // تم إضافة عميل محتمل جديد من حملة
  /// ⏱️ بدون متابعة
  leadNoFollowUp, // عميل محتمل لم يتم التواصل معه منذ فترة
  /// 🔁 إعادة تفاعل
  leadReengaged, // عميل محتمل سابق عاد وتفاعل مرة أخرى
  /// ❌ فشل التواصل
  leadContactFailed, // لم يتم الرد بعد محاولات اتصال
  /// 🔄 تغيير الحالة
  leadStatusChanged, // تم تغيير حالة العميل المحتمل
  /// 👤 تعيين عميل محتمل
  leadAssigned, // تم تعيين عميل محتمل جديد لك
  /// 🔁 نقل عميل محتمل
  leadTransferred, // تم نقل العميل المحتمل إلى موظف آخر
  /// تم تحديث عميل
  leadUpdated, // تم تحديث معلومات العميل
  /// تذكير بموعد متابعة عميل
  leadReminder, // تذكير بموعد متابعة عميل
  /// نشاط فريق الشركة (للمالك)
  teamActivity, // إشعار نشاط عضو من الفريق
  
  // ==================== إشعارات واتساب (WhatsApp Automation) ====================
  /// 📨 رسالة واردة
  whatsappMessageReceived, // رسالة جديدة من عميل محتمل عبر واتساب
  /// 📤 إرسال قالب
  whatsappTemplateSent, // تم إرسال رسالة الترحيب بنجاح
  /// ⚠️ فشل الإرسال
  whatsappSendFailed, // فشل إرسال قالب واتساب
  /// ⏳ بانتظار الرد
  whatsappWaitingResponse, // لا يوجد رد من العميل المحتمل منذ فترة
  
  // ==================== إشعارات الحملات الإعلانية (Ads Performance) ====================
  /// 📊 أداء الحملة
  campaignPerformance, // الحملة حققت عدد معين من العملاء المحتملين
  /// ⚠️ انخفاض الأداء
  campaignLowPerformance, // انخفاض عدد العملاء المحتملين اليوم
  /// ⛔ إيقاف حملة
  campaignStopped, // تم إيقاف الحملة بسبب نفاد الميزانية
  /// 💰 تنبيه الميزانية
  campaignBudgetAlert, // الميزانية المتبقية أقل من نسبة معينة
  
  // ==================== إشعارات الفريق والمهام (Team & Tasks) ====================
  /// 📌 مهمة جديدة
  taskCreated, // لديك مهمة متابعة جديدة
  /// ⏰ تذكير
  taskReminder, // تبقى وقت معين على موعد المتابعة
  /// تم إكمال مهمة
  taskCompleted, // تم إكمال مهمة
  /// 📞 تذكير مكالمة
  callReminder, // تذكير بموعد مكالمة متابعة
  
  // ==================== إشعارات الصفقات ====================
  /// تم إنشاء صفقة جديدة
  dealCreated, // تم إنشاء صفقة جديدة
  /// تم تحديث صفقة
  dealUpdated, // تم تحديث صفقة
  /// تم إغلاق صفقة
  dealClosed, // تم إغلاق صفقة
  /// تذكير بموعد صفقة
  dealReminder, // تذكير بموعد صفقة
  
  // ==================== إشعارات التقارير (Reports & Insights) ====================
  /// 📊 تقرير يومي
  dailyReport, // تقرير الأداء اليومي
  /// 📅 تقرير أسبوعي
  weeklyReport, // تقرير الأداء الأسبوعي جاهز
  /// 🏆 أفضل موظف
  topEmployee, // أفضل موظف مبيعات لهذا الأسبوع
  
  // ==================== إشعارات الحساب والنظام (System & Subscription) ====================
  /// 🔐 تسجيل دخول
  loginFromNewDevice, // تم تسجيل دخول من جهاز جديد
  /// ⚙️ تحديث النظام
  systemUpdate, // تم إضافة ميزة جديدة إلى Loop CRM
  /// 💳 تنبيه الاشتراك
  subscriptionExpiring, // اشتراكك ينتهي خلال أيام
  /// ❌ فشل الدفع
  paymentFailed, // فشل عملية الدفع، يرجى التحقق
  /// انتهاء الاشتراك
  subscriptionExpired, // انتهاء الاشتراك
  
  // ==================== إشعارات عامة ====================
  /// إشعار عام
  general, // إشعار عام
  /// نوع غير معروف (للتوافق مع المستقبل)
  unknown,
}

/// نموذج بيانات الإشعار
class NotificationPayload {
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? imageUrl;
  final DateTime? timestamp;
  final int? notificationId;

  NotificationPayload({
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.imageUrl,
    DateTime? timestamp,
    this.notificationId,
  }) : timestamp = timestamp ?? DateTime.now();

  static NotificationType _parseNotificationType(String? rawType) {
    final value = (rawType ?? 'unknown').trim();
    if (value.isEmpty) return NotificationType.unknown;

    final direct = NotificationType.values.where((e) => e.name == value);
    if (direct.isNotEmpty) return direct.first;

    final parts = value.split('_');
    final camel = parts.first +
        parts.skip(1).map((p) {
          if (p.isEmpty) return '';
          return p[0].toUpperCase() + p.substring(1);
        }).join();
    final normalized = NotificationType.values.where((e) => e.name == camel);
    if (normalized.isNotEmpty) return normalized.first;

    return NotificationType.unknown;
  }

  /// إنشاء من JSON (من FCM)
  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String? ?? 'unknown';
    final type = _parseNotificationType(typeString);

    return NotificationPayload(
      type: type,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
      imageUrl: json['image_url'] as String?,
      notificationId: json['notification_id'] as int?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      'data': data,
      'image_url': imageUrl,
      'notification_id': notificationId,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  /// إنشاء من RemoteMessage (FCM)
  factory NotificationPayload.fromRemoteMessage(RemoteMessage message) {
    // استخراج notification (يحتوي على title و body)
    final notification = message.notification;
    final title = notification?.title ?? '';
    final body = notification?.body ?? '';
    final imageUrl = notification?.android?.imageUrl ?? notification?.apple?.imageUrl;
    
    // استخراج data (يحتوي على type وبيانات إضافية)
    final data = Map<String, dynamic>.from(message.data);
    
    // إذا لم يكن title/body في notification، استخدم data
    final finalTitle = title.isNotEmpty ? title : (data['title'] as String? ?? '');
    final finalBody = body.isNotEmpty ? body : (data['body'] as String? ?? '');

    final typeString = data['type'] as String? ?? 'unknown';
    final type = _parseNotificationType(typeString);

    return NotificationPayload(
      type: type,
      title: finalTitle,
      body: finalBody,
      data: data,
      imageUrl: imageUrl ?? data['image_url'] as String?,
      notificationId: data['notification_id'] != null
          ? int.tryParse(data['notification_id'] as String)
          : null,
    );
  }
}
