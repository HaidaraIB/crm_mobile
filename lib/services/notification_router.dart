import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import 'notification_display.dart';

/// مسؤول عن توجيه المستخدم إلى الشاشة المناسبة بناءً على نوع الإشعار
class NotificationRouter {
  static final NotificationRouter _instance = NotificationRouter._internal();
  factory NotificationRouter() => _instance;
  NotificationRouter._internal();

  /// FCM / API payloads often send numeric ids as [String]; avoid `as int?` casts.
  static int? _intFromPayload(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// Types that must not deep-link (recipient typically lost access to the entity).
  static bool canNavigate(NotificationType type) {
    switch (type) {
      case NotificationType.leadTransferred:
      case NotificationType.softphoneIncomingCall:
      case NotificationType.general:
      case NotificationType.unknown:
        return false;
      default:
        return true;
    }
  }

  /// التنقل بناءً على نوع الإشعار
  /// يمكن توسيع هذه الطريقة بسهولة لإضافة أنواع جديدة من الإشعارات
  static Future<void> navigateFromNotification(
    BuildContext? context,
    NotificationPayload payload,
  ) async {
    if (context == null) return;
    if (!canNavigate(payload.type)) return;

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
      case NotificationType.teamActivity:
      case NotificationType.teamActivityAction:
      case NotificationType.teamActivityStatus:
      case NotificationType.teamActivityOverdue:
        final leadId = _intFromPayload(payload.data?['lead_id']);
        if (leadId != null) {
          navigator.pushNamed('/leads/details', arguments: leadId);
        } else {
          navigator.pushNamed('/leads');
        }
        break;

      case NotificationType.leadTransferred:
        // Informational only: previous assignee usually lost view access.
        break;

      case NotificationType.leadNoFollowUp:
      case NotificationType.leadReengaged:
      case NotificationType.leadContactFailed:
      case NotificationType.leadReminder:
        final leadId = _intFromPayload(payload.data?['lead_id']);
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
        final leadId = _intFromPayload(payload.data?['lead_id']);
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
        navigator.pushNamed('/calendar');
        break;

      case NotificationType.callReminder:
      case NotificationType.visitReminder:
      case NotificationType.receptionVisitReminder:
      case NotificationType.fieldVisitReminder:
      case NotificationType.receptionFieldVisitReminder:
        final leadId = _intFromPayload(payload.data?['lead_id']);
        if (leadId != null) {
          navigator.pushNamed('/leads/details', arguments: leadId);
        } else {
          navigator.pushNamed('/calendar');
        }
        break;

      case NotificationType.softphoneIncomingCall:
        // CallKit UI is shown by SoftphonePushHandler; no navigation needed.
        break;

      case NotificationType.pbxIncomingCall:
      case NotificationType.pbxCallMissed:
        final pbxLeadId = _intFromPayload(payload.data?['lead_id'] ?? payload.data?['client_id']);
        if (pbxLeadId != null) {
          navigator.pushNamed('/leads/details', arguments: pbxLeadId);
        } else {
          navigator.pushNamed('/leads');
        }
        break;

      case NotificationType.tenantChat:
        final conversationId = _intFromPayload(payload.data?['conversation_id']);
        navigator.pushNamed('/team-chat', arguments: conversationId);
        break;

      // ==================== إشعارات الصفقات ====================
      case NotificationType.dealCreated:
      case NotificationType.dealUpdated:
      case NotificationType.dealClosed:
        final dealId = _intFromPayload(payload.data?['deal_id']);
        if (dealId != null) {
          navigator.pushNamed('/deals/view', arguments: dealId);
        } else {
          navigator.pushNamed('/deals');
        }
        break;

      case NotificationType.dealReminder:
        final dealId = _intFromPayload(payload.data?['deal_id']);
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
      case NotificationType.teamActivity:
      case NotificationType.teamActivityAction:
      case NotificationType.teamActivityStatus:
      case NotificationType.teamActivityOverdue:
        return Icons.groups;
      
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
      case NotificationType.pbxIncomingCall:
      case NotificationType.softphoneIncomingCall:
        return Icons.phone_in_talk;
      case NotificationType.pbxCallMissed:
        return Icons.phone_missed;
      case NotificationType.visitReminder:
        return Icons.event_available;
      case NotificationType.receptionVisitReminder:
        return Icons.support_agent;
      case NotificationType.fieldVisitReminder:
        return Icons.map_outlined;
      case NotificationType.receptionFieldVisitReminder:
        return Icons.support_agent;
      case NotificationType.tenantChat:
        return Icons.chat_bubble_outline;

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
      case NotificationType.teamActivity:
      case NotificationType.teamActivityAction:
      case NotificationType.teamActivityStatus:
      case NotificationType.teamActivityOverdue:
        return Colors.indigo;
      
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
      case NotificationType.pbxIncomingCall:
      case NotificationType.softphoneIncomingCall:
        return Colors.green;
      case NotificationType.pbxCallMissed:
        return Colors.red;
      case NotificationType.visitReminder:
        return Colors.teal;
      case NotificationType.receptionVisitReminder:
        return Colors.cyan;
      case NotificationType.fieldVisitReminder:
        return const Color(0xFF059669);
      case NotificationType.receptionFieldVisitReminder:
        return Colors.cyan;
      case NotificationType.tenantChat:
        return Colors.indigo;

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

  /// Localized type label for the current UI language (falls back to AR).
  static String getTypeName(NotificationType type, {String? languageCode}) {
    final lang =
        (languageCode ?? 'ar').toLowerCase().startsWith('en') ? 'en' : 'ar';

    // Settings-only preference keys — not inbox types.
    if (type == NotificationType.teamActivityAction) {
      return lang == 'en' ? 'Employee actions' : 'إجراءات الموظف';
    }
    if (type == NotificationType.teamActivityStatus) {
      return lang == 'en' ? 'Status updates' : 'تحديث الحالة';
    }
    if (type == NotificationType.teamActivityOverdue) {
      return lang == 'en' ? 'Follow-up overdue' : 'تأخر المتابعة';
    }
    if (type == NotificationType.tenantChat) {
      return lang == 'en' ? 'Team chat' : 'دردشة الفريق';
    }
    if (type == NotificationType.unknown) {
      return lang == 'en' ? 'Unknown notification' : 'إشعار غير معروف';
    }

    final apiType = _typeToApiString(type);
    return getNotificationDisplay(
      type: apiType,
      languageCode: languageCode,
    ).typeLabel;
  }

  static String _typeToApiString(NotificationType type) {
    final name = type.name;
    final buf = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      final isUpper = ch.toUpperCase() == ch && ch.toLowerCase() != ch;
      if (isUpper && i > 0) buf.write('_');
      buf.write(ch.toLowerCase());
    }
    return buf.toString();
  }
}
