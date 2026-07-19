import '../models/notification_model.dart';
import 'notification_service.dart';

/// مساعد لإنشاء وإرسال الإشعارات بسهولة
/// يوفر واجهة بسيطة لإرسال أنواع مختلفة من الإشعارات
class NotificationHelper {
  static final NotificationService _notificationService = NotificationService();

  /// إرسال إشعار تعيين عميل
  static Future<void> notifyLeadAssigned({
    required int leadId,
    required String leadName,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تم تعيين عميل جديد',
      body: 'تم تعيين العميل $leadName لك',
      payload: NotificationPayload(
        type: NotificationType.leadAssigned,
        title: 'تم تعيين عميل جديد',
        body: 'تم تعيين العميل $leadName لك',
        data: {'lead_id': leadId, 'lead_name': leadName},
      ),
    );
  }

  /// إرسال إشعار تحديث عميل
  static Future<void> notifyLeadUpdated({
    required int leadId,
    required String leadName,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تم تحديث العميل',
      body: 'تم تحديث معلومات العميل $leadName',
      payload: NotificationPayload(
        type: NotificationType.leadUpdated,
        title: 'تم تحديث العميل',
        body: 'تم تحديث معلومات العميل $leadName',
        data: {'lead_id': leadId, 'lead_name': leadName},
      ),
    );
  }

  /// إرسال إشعار تغيير حالة العميل
  static Future<void> notifyLeadStatusChanged({
    required int leadId,
    required String leadName,
    required String newStatus,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تغيرت حالة العميل',
      body: 'تم تغيير حالة العميل $leadName إلى $newStatus',
      payload: NotificationPayload(
        type: NotificationType.leadStatusChanged,
        title: 'تغيرت حالة العميل',
        body: 'تم تغيير حالة العميل $leadName إلى $newStatus',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'new_status': newStatus,
        },
      ),
    );
  }

  /// جدولة تذكير بموعد متابعة عميل
  static Future<void> scheduleLeadReminder({
    required int leadId,
    required String leadName,
    required DateTime reminderDate,
    String? notes,
  }) async {
    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _notificationService.scheduleReminder(
      id: notificationId,
      title: 'تذكير: متابعة العميل $leadName',
      body: notes ?? 'موعد متابعة العميل',
      scheduledDate: reminderDate,
      payload: NotificationPayload(
        type: NotificationType.leadReminder,
        title: 'تذكير: متابعة العميل $leadName',
        body: notes ?? 'موعد متابعة العميل',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'notes': notes,
        },
        notificationId: notificationId,
      ),
    );
  }

  /// إرسال إشعار إنشاء صفقة
  static Future<void> notifyDealCreated({
    required int dealId,
    required String dealTitle,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تم إنشاء صفقة جديدة',
      body: 'تم إنشاء الصفقة: $dealTitle',
      payload: NotificationPayload(
        type: NotificationType.dealCreated,
        title: 'تم إنشاء صفقة جديدة',
        body: 'تم إنشاء الصفقة: $dealTitle',
        data: {'deal_id': dealId, 'deal_title': dealTitle},
      ),
    );
  }

  /// إرسال إشعار تحديث صفقة
  static Future<void> notifyDealUpdated({
    required int dealId,
    required String dealTitle,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تم تحديث الصفقة',
      body: 'تم تحديث الصفقة: $dealTitle',
      payload: NotificationPayload(
        type: NotificationType.dealUpdated,
        title: 'تم تحديث الصفقة',
        body: 'تم تحديث الصفقة: $dealTitle',
        data: {'deal_id': dealId, 'deal_title': dealTitle},
      ),
    );
  }

  /// إرسال إشعار إغلاق صفقة
  static Future<void> notifyDealClosed({
    required int dealId,
    required String dealTitle,
    required double amount,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تم إغلاق الصفقة',
      body: 'تم إغلاق الصفقة $dealTitle بقيمة $amount',
      payload: NotificationPayload(
        type: NotificationType.dealClosed,
        title: 'تم إغلاق الصفقة',
        body: 'تم إغلاق الصفقة $dealTitle بقيمة $amount',
        data: {
          'deal_id': dealId,
          'deal_title': dealTitle,
          'amount': amount,
        },
      ),
    );
  }

  /// إرسال إشعار مهمة جديدة
  static Future<void> notifyTaskCreated({
    required int taskId,
    required String taskTitle,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تم إنشاء مهمة جديدة',
      body: 'مهمة جديدة: $taskTitle',
      payload: NotificationPayload(
        type: NotificationType.taskCreated,
        title: 'تم إنشاء مهمة جديدة',
        body: 'مهمة جديدة: $taskTitle',
        data: {'task_id': taskId, 'task_title': taskTitle},
      ),
    );
  }

  /// إرسال إشعار إكمال مهمة
  static Future<void> notifyTaskCompleted({
    required int taskId,
    required String taskTitle,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تم إكمال المهمة',
      body: 'تم إكمال المهمة: $taskTitle',
      payload: NotificationPayload(
        type: NotificationType.taskCompleted,
        title: 'تم إكمال المهمة',
        body: 'تم إكمال المهمة: $taskTitle',
        data: {'task_id': taskId, 'task_title': taskTitle},
      ),
    );
  }

  /// إرسال إشعار عام
  static Future<void> notifyGeneral({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _notificationService.showLocalNotification(
      title: title,
      body: body,
      payload: NotificationPayload(
        type: NotificationType.general,
        title: title,
        body: body,
        data: data,
      ),
    );
  }

  /// إرسال إشعار انتهاء الاشتراك
  static Future<void> notifySubscriptionExpiring({
    required int daysLeft,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'انتهاء الاشتراك قريباً',
      body: 'سينتهي اشتراكك خلال $daysLeft يوم',
      payload: NotificationPayload(
        type: NotificationType.subscriptionExpiring,
        title: 'انتهاء الاشتراك قريباً',
        body: 'سينتهي اشتراكك خلال $daysLeft يوم',
        data: {'days_left': daysLeft},
      ),
    );
  }

  /// إرسال إشعار انتهاء الاشتراك
  static Future<void> notifySubscriptionExpired() async {
    await _notificationService.showLocalNotification(
      title: 'انتهى الاشتراك',
      body: 'انتهى اشتراكك. يرجى تجديد الاشتراك للاستمرار',
      payload: NotificationPayload(
        type: NotificationType.subscriptionExpired,
        title: 'انتهى الاشتراك',
        body: 'انتهى اشتراكك. يرجى تجديد الاشتراك للاستمرار',
      ),
    );
  }

  // ==================== إشعارات العملاء المحتملين الجديدة ====================
  
  /// 📥 عميل محتمل جديد
  static Future<void> notifyNewLead({
    required int leadId,
    required String leadName,
    String? campaignName,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'عميل محتمل جديد',
      body: campaignName != null
          ? 'تم إضافة عميل محتمل جديد من حملة $campaignName'
          : 'تم إضافة عميل محتمل جديد',
      payload: NotificationPayload(
        type: NotificationType.newLead,
        title: 'عميل محتمل جديد',
        body: campaignName != null
            ? 'تم إضافة عميل محتمل جديد من حملة $campaignName'
            : 'تم إضافة عميل محتمل جديد',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'campaign_name': campaignName,
        },
      ),
    );
  }

  /// ⏱️ بدون متابعة
  static Future<void> notifyLeadNoFollowUp({
    required int leadId,
    required String leadName,
    required int minutes,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'بدون متابعة',
      body: 'عميل محتمل لم يتم التواصل معه منذ $minutes دقيقة',
      payload: NotificationPayload(
        type: NotificationType.leadNoFollowUp,
        title: 'بدون متابعة',
        body: 'عميل محتمل لم يتم التواصل معه منذ $minutes دقيقة',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'minutes': minutes,
        },
      ),
    );
  }

  /// 🔁 إعادة تفاعل
  static Future<void> notifyLeadReengaged({
    required int leadId,
    required String leadName,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'إعادة تفاعل',
      body: 'عميل محتمل سابق عاد وتفاعل مرة أخرى',
      payload: NotificationPayload(
        type: NotificationType.leadReengaged,
        title: 'إعادة تفاعل',
        body: 'عميل محتمل سابق عاد وتفاعل مرة أخرى',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
        },
      ),
    );
  }

  /// ❌ فشل التواصل
  static Future<void> notifyLeadContactFailed({
    required int leadId,
    required String leadName,
    required int attempts,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'فشل التواصل',
      body: 'لم يتم الرد بعد $attempts محاولات اتصال',
      payload: NotificationPayload(
        type: NotificationType.leadContactFailed,
        title: 'فشل التواصل',
        body: 'لم يتم الرد بعد $attempts محاولات اتصال',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'attempts': attempts,
        },
      ),
    );
  }

  /// 🔁 نقل عميل محتمل
  static Future<void> notifyLeadTransferred({
    required int leadId,
    required String leadName,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'نقل عميل محتمل',
      body: 'تم نقل العميل $leadName منك',
      payload: NotificationPayload(
        type: NotificationType.leadTransferred,
        title: 'نقل عميل محتمل',
        body: 'تم نقل العميل $leadName منك',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
        },
      ),
    );
  }

  // ==================== إشعارات واتساب ====================
  
  /// 📨 رسالة واردة
  static Future<void> notifyWhatsAppMessageReceived({
    required int leadId,
    required String leadName,
    String? messagePreview,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'رسالة واتساب واردة',
      body: messagePreview != null
          ? '$leadName: $messagePreview'
          : 'رسالة جديدة من $leadName',
      payload: NotificationPayload(
        type: NotificationType.whatsappMessageReceived,
        title: 'رسالة واتساب واردة',
        body: messagePreview != null
            ? '$leadName: $messagePreview'
            : 'رسالة جديدة من $leadName',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'message_preview': messagePreview,
        },
      ),
    );
  }

  /// 📤 إرسال قالب
  static Future<void> notifyWhatsAppTemplateSent({
    required int leadId,
    required String leadName,
    required String templateName,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'إرسال قالب واتساب',
      body: 'تم إرسال رسالة الترحيب بنجاح إلى $leadName',
      payload: NotificationPayload(
        type: NotificationType.whatsappTemplateSent,
        title: 'إرسال قالب واتساب',
        body: 'تم إرسال رسالة الترحيب بنجاح إلى $leadName',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'template_name': templateName,
        },
      ),
    );
  }

  /// ⚠️ فشل الإرسال
  static Future<void> notifyWhatsAppSendFailed({
    required int leadId,
    required String leadName,
    String? errorMessage,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'فشل إرسال واتساب',
      body: errorMessage ?? 'فشل إرسال قالب واتساب',
      payload: NotificationPayload(
        type: NotificationType.whatsappSendFailed,
        title: 'فشل إرسال واتساب',
        body: errorMessage ?? 'فشل إرسال قالب واتساب',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'error_message': errorMessage,
        },
      ),
    );
  }

  /// ⏳ بانتظار الرد
  static Future<void> notifyWhatsAppWaitingResponse({
    required int leadId,
    required String leadName,
    required int hours,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'بانتظار الرد',
      body: 'لا يوجد رد من $leadName منذ $hours ساعة',
      payload: NotificationPayload(
        type: NotificationType.whatsappWaitingResponse,
        title: 'بانتظار الرد',
        body: 'لا يوجد رد من $leadName منذ $hours ساعة',
        data: {
          'lead_id': leadId,
          'lead_name': leadName,
          'hours': hours,
        },
      ),
    );
  }

  // ==================== إشعارات الحملات الإعلانية ====================
  
  /// 📊 أداء الحملة
  static Future<void> notifyCampaignPerformance({
    required String campaignName,
    required int leadsCount,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'أداء الحملة',
      body: 'الحملة $campaignName حققت $leadsCount عميل محتمل',
      payload: NotificationPayload(
        type: NotificationType.campaignPerformance,
        title: 'أداء الحملة',
        body: 'الحملة $campaignName حققت $leadsCount عميل محتمل',
        data: {
          'campaign_name': campaignName,
          'leads_count': leadsCount,
        },
      ),
    );
  }

  /// ⚠️ انخفاض الأداء
  static Future<void> notifyCampaignLowPerformance({
    required String campaignName,
    required int todayLeads,
    required int yesterdayLeads,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'انخفاض الأداء',
      body: 'انخفاض عدد العملاء المحتملين اليوم في $campaignName',
      payload: NotificationPayload(
        type: NotificationType.campaignLowPerformance,
        title: 'انخفاض الأداء',
        body: 'انخفاض عدد العملاء المحتملين اليوم في $campaignName',
        data: {
          'campaign_name': campaignName,
          'today_leads': todayLeads,
          'yesterday_leads': yesterdayLeads,
        },
      ),
    );
  }

  /// ⛔ إيقاف حملة
  static Future<void> notifyCampaignStopped({
    required String campaignName,
    String? reason,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'إيقاف حملة',
      body: reason ?? 'تم إيقاف الحملة $campaignName بسبب نفاد الميزانية',
      payload: NotificationPayload(
        type: NotificationType.campaignStopped,
        title: 'إيقاف حملة',
        body: reason ?? 'تم إيقاف الحملة $campaignName بسبب نفاد الميزانية',
        data: {
          'campaign_name': campaignName,
          'reason': reason,
        },
      ),
    );
  }

  /// 💰 تنبيه الميزانية
  static Future<void> notifyCampaignBudgetAlert({
    required String campaignName,
    required double remainingPercentage,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تنبيه الميزانية',
      body: 'الميزانية المتبقية في $campaignName أقل من ${remainingPercentage.toStringAsFixed(0)}%',
      payload: NotificationPayload(
        type: NotificationType.campaignBudgetAlert,
        title: 'تنبيه الميزانية',
        body: 'الميزانية المتبقية في $campaignName أقل من ${remainingPercentage.toStringAsFixed(0)}%',
        data: {
          'campaign_name': campaignName,
          'remaining_percentage': remainingPercentage,
        },
      ),
    );
  }

  // ==================== إشعارات التقارير ====================
  
  /// 📊 تقرير يومي
  static Future<void> notifyDailyReport({
    required int leadsCount,
    required int salesCount,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تقرير يومي',
      body: 'اليوم: $leadsCount عميل محتمل – $salesCount مبيعات',
      payload: NotificationPayload(
        type: NotificationType.dailyReport,
        title: 'تقرير يومي',
        body: 'اليوم: $leadsCount عميل محتمل – $salesCount مبيعات',
        data: {
          'leads_count': leadsCount,
          'sales_count': salesCount,
        },
      ),
    );
  }

  /// 📅 تقرير أسبوعي
  static Future<void> notifyWeeklyReport({
    required String reportUrl,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تقرير أسبوعي',
      body: 'تقرير الأداء الأسبوعي جاهز',
      payload: NotificationPayload(
        type: NotificationType.weeklyReport,
        title: 'تقرير أسبوعي',
        body: 'تقرير الأداء الأسبوعي جاهز',
        data: {
          'report_url': reportUrl,
        },
      ),
    );
  }

  /// 🏆 أفضل موظف
  static Future<void> notifyTopEmployee({
    required String employeeName,
    required int salesCount,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'أفضل موظف',
      body: '$employeeName هو أفضل موظف مبيعات لهذا الأسبوع بـ $salesCount مبيعات',
      payload: NotificationPayload(
        type: NotificationType.topEmployee,
        title: 'أفضل موظف',
        body: '$employeeName هو أفضل موظف مبيعات لهذا الأسبوع بـ $salesCount مبيعات',
        data: {
          'employee_name': employeeName,
          'sales_count': salesCount,
        },
      ),
    );
  }

  // ==================== إشعارات النظام ====================
  
  /// 🔐 تسجيل دخول
  static Future<void> notifyLoginFromNewDevice({
    required String deviceName,
    required String location,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تسجيل دخول جديد',
      body: 'تم تسجيل دخول من جهاز جديد: $deviceName في $location',
      payload: NotificationPayload(
        type: NotificationType.loginFromNewDevice,
        title: 'تسجيل دخول جديد',
        body: 'تم تسجيل دخول من جهاز جديد: $deviceName في $location',
        data: {
          'device_name': deviceName,
          'location': location,
        },
      ),
    );
  }

  /// ⚙️ تحديث النظام
  static Future<void> notifySystemUpdate({
    required String featureName,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'تحديث النظام',
      body: 'تم إضافة ميزة جديدة إلى Loop CRM: $featureName',
      payload: NotificationPayload(
        type: NotificationType.systemUpdate,
        title: 'تحديث النظام',
        body: 'تم إضافة ميزة جديدة إلى Loop CRM: $featureName',
        data: {
          'feature_name': featureName,
        },
      ),
    );
  }

  /// ❌ فشل الدفع
  static Future<void> notifyPaymentFailed({
    String? errorMessage,
  }) async {
    await _notificationService.showLocalNotification(
      title: 'فشل الدفع',
      body: errorMessage ?? 'فشل عملية الدفع، يرجى التحقق',
      payload: NotificationPayload(
        type: NotificationType.paymentFailed,
        title: 'فشل الدفع',
        body: errorMessage ?? 'فشل عملية الدفع، يرجى التحقق',
        data: {
          'error_message': errorMessage,
        },
      ),
    );
  }
}

