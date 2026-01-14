import 'package:flutter/material.dart';
import '../models/notification_model.dart';

/// مسؤول عن توجيه المستخدم إلى الشاشة المناسبة بناءً على نوع الإشعار
class NotificationRouter {
  static final NotificationRouter _instance = NotificationRouter._internal();
  factory NotificationRouter() => _instance;
  NotificationRouter._internal();

  /// التنقل بناءً على نوع الإشعار
  /// يمكن توسيع هذه الطريقة بسهولة لإضافة أنواع جديدة من الإشعارات
  static Future<void> navigateFromNotification(
    BuildContext? context,
    NotificationPayload payload,
  ) async {
    if (context == null) return;

    // التحقق من أن context يحتوي على Navigator
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      debugPrint('Warning: Navigator not found in context. Cannot navigate from notification.');
      return;
    }

    switch (payload.type) {
      // ==================== إشعارات العملاء المحتملين ====================
      case NotificationType.newLead:
      case NotificationType.leadAssigned:
      case NotificationType.leadUpdated:
      case NotificationType.leadStatusChanged:
      case NotificationType.leadTransferred:
        final leadId = payload.data?['lead_id'] as int?;
        if (leadId != null) {
          navigator.pushNamed('/leads/details', arguments: leadId);
        } else {
          navigator.pushNamed('/leads');
        }
        break;

      case NotificationType.leadNoFollowUp:
      case NotificationType.leadReengaged:
      case NotificationType.leadContactFailed:
      case NotificationType.leadReminder:
        final leadId = payload.data?['lead_id'] as int?;
        if (leadId != null) {
          navigator.pushNamed('/leads/details', arguments: leadId);
        } else {
          navigator.pushNamed('/calendar');
        }
        break;

      // ==================== إشعارات واتساب ====================
      case NotificationType.whatsappMessageReceived:
      case NotificationType.whatsappTemplateSent:
      case NotificationType.whatsappSendFailed:
      case NotificationType.whatsappWaitingResponse:
        final leadId = payload.data?['lead_id'] as int?;
        if (leadId != null) {
          navigator.pushNamed('/leads/details', arguments: leadId);
        } else {
          navigator.pushNamed('/leads');
        }
        break;

      // ==================== إشعارات الحملات الإعلانية ====================
      case NotificationType.campaignPerformance:
      case NotificationType.campaignLowPerformance:
      case NotificationType.campaignStopped:
      case NotificationType.campaignBudgetAlert:
        // يمكن إضافة شاشة الحملات هنا
        navigator.pushNamed('/home');
        break;

      // ==================== إشعارات الفريق والمهام ====================
      case NotificationType.taskCreated:
      case NotificationType.taskCompleted:
      case NotificationType.taskReminder:
      case NotificationType.callReminder:
        navigator.pushNamed('/calendar');
        break;

      // ==================== إشعارات الصفقات ====================
      case NotificationType.dealCreated:
      case NotificationType.dealUpdated:
      case NotificationType.dealClosed:
        final dealId = payload.data?['deal_id'] as int?;
        if (dealId != null) {
          navigator.pushNamed('/deals/view', arguments: dealId);
        } else {
          navigator.pushNamed('/deals');
        }
        break;

      case NotificationType.dealReminder:
        final dealId = payload.data?['deal_id'] as int?;
        if (dealId != null) {
          navigator.pushNamed('/deals/view', arguments: dealId);
        } else {
          navigator.pushNamed('/calendar');
        }
        break;

      // ==================== إشعارات التقارير ====================
      case NotificationType.dailyReport:
      case NotificationType.weeklyReport:
      case NotificationType.topEmployee:
        // يمكن إضافة شاشة التقارير هنا
        navigator.pushNamed('/home');
        break;

      // ==================== إشعارات النظام ====================
      case NotificationType.loginFromNewDevice:
      case NotificationType.systemUpdate:
      case NotificationType.subscriptionExpiring:
      case NotificationType.paymentFailed:
      case NotificationType.subscriptionExpired:
        navigator.pushNamed('/settings');
        break;

      // ==================== إشعارات عامة ====================
      case NotificationType.general:
      case NotificationType.unknown:
      // لا يوجد تنقل محدد
        break;
    }
  }

  /// الحصول على أيقونة الإشعار بناءً على نوعه
  static IconData getIconForType(NotificationType type) {
    switch (type) {
      // إشعارات العملاء المحتملين
      case NotificationType.newLead:
        return Icons.person_add;
      case NotificationType.leadAssigned:
      case NotificationType.leadUpdated:
        return Icons.person;
      case NotificationType.leadStatusChanged:
        return Icons.swap_horiz;
      case NotificationType.leadTransferred:
        return Icons.swap_calls;
      case NotificationType.leadNoFollowUp:
        return Icons.access_time;
      case NotificationType.leadReengaged:
        return Icons.refresh;
      case NotificationType.leadContactFailed:
        return Icons.error_outline;
      case NotificationType.leadReminder:
        return Icons.notifications_active;
      
      // إشعارات واتساب
      case NotificationType.whatsappMessageReceived:
        return Icons.message;
      case NotificationType.whatsappTemplateSent:
        return Icons.send;
      case NotificationType.whatsappSendFailed:
        return Icons.error;
      case NotificationType.whatsappWaitingResponse:
        return Icons.hourglass_empty;
      
      // إشعارات الحملات
      case NotificationType.campaignPerformance:
        return Icons.trending_up;
      case NotificationType.campaignLowPerformance:
        return Icons.trending_down;
      case NotificationType.campaignStopped:
        return Icons.stop_circle;
      case NotificationType.campaignBudgetAlert:
        return Icons.account_balance_wallet;
      
      // إشعارات المهام
      case NotificationType.taskCreated:
        return Icons.task;
      case NotificationType.taskCompleted:
        return Icons.check_circle;
      case NotificationType.taskReminder:
        return Icons.alarm;
      case NotificationType.callReminder:
        return Icons.phone;
      
      // إشعارات الصفقات
      case NotificationType.dealCreated:
      case NotificationType.dealUpdated:
        return Icons.handshake;
      case NotificationType.dealClosed:
        return Icons.check_circle;
      case NotificationType.dealReminder:
        return Icons.event;
      
      // إشعارات التقارير
      case NotificationType.dailyReport:
      case NotificationType.weeklyReport:
        return Icons.assessment;
      case NotificationType.topEmployee:
        return Icons.emoji_events;
      
      // إشعارات النظام
      case NotificationType.loginFromNewDevice:
        return Icons.devices;
      case NotificationType.systemUpdate:
        return Icons.system_update;
      case NotificationType.subscriptionExpiring:
      case NotificationType.subscriptionExpired:
        return Icons.payment;
      case NotificationType.paymentFailed:
        return Icons.payment;
      
      // إشعارات عامة
      case NotificationType.general:
        return Icons.info;
      case NotificationType.unknown:
      return Icons.notifications;
    }
  }

  /// الحصول على لون الإشعار بناءً على نوعه
  static Color getColorForType(NotificationType type) {
    switch (type) {
      // إشعارات العملاء المحتملين
      case NotificationType.newLead:
      case NotificationType.leadAssigned:
        return Colors.blue;
      case NotificationType.leadUpdated:
        return Colors.blueAccent;
      case NotificationType.leadStatusChanged:
        return Colors.orange;
      case NotificationType.leadTransferred:
        return Colors.purple;
      case NotificationType.leadNoFollowUp:
        return Colors.amber;
      case NotificationType.leadReengaged:
        return Colors.green;
      case NotificationType.leadContactFailed:
        return Colors.red;
      case NotificationType.leadReminder:
        return Colors.redAccent;
      
      // إشعارات واتساب
      case NotificationType.whatsappMessageReceived:
      case NotificationType.whatsappTemplateSent:
        return Colors.green;
      case NotificationType.whatsappSendFailed:
        return Colors.red;
      case NotificationType.whatsappWaitingResponse:
        return Colors.orange;
      
      // إشعارات الحملات
      case NotificationType.campaignPerformance:
        return Colors.green;
      case NotificationType.campaignLowPerformance:
        return Colors.orange;
      case NotificationType.campaignStopped:
        return Colors.red;
      case NotificationType.campaignBudgetAlert:
        return Colors.amber;
      
      // إشعارات المهام
      case NotificationType.taskCreated:
        return Colors.purple;
      case NotificationType.taskCompleted:
        return Colors.green;
      case NotificationType.taskReminder:
        return Colors.red;
      case NotificationType.callReminder:
        return Colors.green;
      
      // إشعارات الصفقات
      case NotificationType.dealCreated:
      case NotificationType.dealUpdated:
        return Colors.green;
      case NotificationType.dealClosed:
        return Colors.teal;
      case NotificationType.dealReminder:
        return Colors.amber;
      
      // إشعارات التقارير
      case NotificationType.dailyReport:
      case NotificationType.weeklyReport:
        return Colors.blue;
      case NotificationType.topEmployee:
        return Colors.amber;
      
      // إشعارات النظام
      case NotificationType.loginFromNewDevice:
        return Colors.blueGrey;
      case NotificationType.systemUpdate:
        return Colors.blue;
      case NotificationType.subscriptionExpiring:
        return Colors.orange;
      case NotificationType.subscriptionExpired:
      case NotificationType.paymentFailed:
        return Colors.red;
      
      // إشعارات عامة
      case NotificationType.general:
        return Colors.grey;
      case NotificationType.unknown:
      return Colors.grey;
    }
  }

  /// الحصول على اسم نوع الإشعار بالعربية
  static String getTypeName(NotificationType type) {
    switch (type) {
      case NotificationType.newLead:
        return 'عميل محتمل جديد';
      case NotificationType.leadNoFollowUp:
        return 'بدون متابعة';
      case NotificationType.leadReengaged:
        return 'إعادة تفاعل';
      case NotificationType.leadContactFailed:
        return 'فشل التواصل';
      case NotificationType.leadStatusChanged:
        return 'تغيير الحالة';
      case NotificationType.leadAssigned:
        return 'تعيين عميل محتمل';
      case NotificationType.leadTransferred:
        return 'نقل عميل محتمل';
      case NotificationType.leadUpdated:
        return 'تحديث عميل';
      case NotificationType.leadReminder:
        return 'تذكير عميل';
      
      case NotificationType.whatsappMessageReceived:
        return 'رسالة واتساب واردة';
      case NotificationType.whatsappTemplateSent:
        return 'إرسال قالب واتساب';
      case NotificationType.whatsappSendFailed:
        return 'فشل إرسال واتساب';
      case NotificationType.whatsappWaitingResponse:
        return 'بانتظار الرد';
      
      case NotificationType.campaignPerformance:
        return 'أداء الحملة';
      case NotificationType.campaignLowPerformance:
        return 'انخفاض الأداء';
      case NotificationType.campaignStopped:
        return 'إيقاف حملة';
      case NotificationType.campaignBudgetAlert:
        return 'تنبيه الميزانية';
      
      case NotificationType.taskCreated:
        return 'مهمة جديدة';
      case NotificationType.taskCompleted:
        return 'مهمة مكتملة';
      case NotificationType.taskReminder:
        return 'تذكير مهمة';
      case NotificationType.callReminder:
        return 'تذكير مكالمة';
      
      case NotificationType.dealCreated:
        return 'صفقة جديدة';
      case NotificationType.dealUpdated:
        return 'تحديث صفقة';
      case NotificationType.dealClosed:
        return 'إغلاق صفقة';
      case NotificationType.dealReminder:
        return 'تذكير صفقة';
      
      case NotificationType.dailyReport:
        return 'تقرير يومي';
      case NotificationType.weeklyReport:
        return 'تقرير أسبوعي';
      case NotificationType.topEmployee:
        return 'أفضل موظف';
      
      case NotificationType.loginFromNewDevice:
        return 'تسجيل دخول جديد';
      case NotificationType.systemUpdate:
        return 'تحديث النظام';
      case NotificationType.subscriptionExpiring:
        return 'تنبيه الاشتراك';
      case NotificationType.paymentFailed:
        return 'فشل الدفع';
      case NotificationType.subscriptionExpired:
        return 'انتهاء الاشتراك';
      
      case NotificationType.general:
        return 'إشعار عام';
      case NotificationType.unknown:
      return 'إشعار غير معروف';
    }
  }
}
