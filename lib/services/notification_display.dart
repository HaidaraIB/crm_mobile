/// Rebuild notification title/body from type + data in the current UI language.
/// Mirrors CRM-api-1/notifications/translations.py and web utils/notificationDisplay.ts.
library;

class NotificationDisplay {
  final String title;
  final String body;
  final String typeLabel;

  const NotificationDisplay({
    required this.title,
    required this.body,
    required this.typeLabel,
  });
}

typedef _Tpl = ({String title, String body, String? bodyWithCampaign});

const Map<String, Map<String, _Tpl>> _templates = {
  'new_lead': {
    'ar': (
      title: 'عميل محتمل جديد',
      body: 'أضاف {added_by} العميل المحتمل {lead_name}',
      bodyWithCampaign:
          'أضاف {added_by} العميل المحتمل {lead_name} من حملة {campaign_name}',
    ),
    'en': (
      title: 'New Lead',
      body: '{added_by} added lead {lead_name}',
      bodyWithCampaign:
          '{added_by} added lead {lead_name} from campaign {campaign_name}',
    ),
  },
  'lead_no_follow_up': {
    'ar': (
      title: 'بدون متابعة',
      body: 'عميل محتمل لم يتم التواصل معه منذ {hours} ساعة',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'No Follow Up',
      body: 'A lead has not been contacted for {hours} hours',
      bodyWithCampaign: null,
    ),
  },
  'lead_reengaged': {
    'ar': (
      title: 'إعادة تفاعل',
      body: 'عميل محتمل سابق عاد وتفاعل مرة أخرى',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Lead Reengaged',
      body: 'A previous lead has reengaged',
      bodyWithCampaign: null,
    ),
  },
  'lead_contact_failed': {
    'ar': (
      title: 'فشل التواصل',
      body: 'لم يتم الرد بعد {attempts} محاولات اتصال',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Contact Failed',
      body: 'No response after {attempts} contact attempts',
      bodyWithCampaign: null,
    ),
  },
  'lead_status_changed': {
    'ar': (
      title: 'تغيير الحالة',
      body: 'تم تغيير حالة العميل المحتمل إلى "{new_status}"',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Status Changed',
      body: 'Lead status has been changed to "{new_status}"',
      bodyWithCampaign: null,
    ),
  },
  'lead_assigned': {
    'ar': (
      title: 'تم تعيين عميل محتمل جديد',
      body: 'تم تعيين العميل {lead_name} لك',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Lead Assigned',
      body: 'Lead {lead_name} has been assigned to you',
      bodyWithCampaign: null,
    ),
  },
  'lead_transferred': {
    'ar': (
      title: 'نقل عميل محتمل',
      body: 'تم نقل العميل {lead_name} منك',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Lead Transferred',
      body: 'Lead {lead_name} has been transferred from you',
      bodyWithCampaign: null,
    ),
  },
  'lead_updated': {
    'ar': (
      title: 'تحديث عميل',
      body: 'تم تحديث معلومات العميل {lead_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Lead Updated',
      body: 'Lead {lead_name} has been updated',
      bodyWithCampaign: null,
    ),
  },
  'lead_reminder': {
    'ar': (
      title: 'تذكير عميل',
      body: 'تذكير بموعد متابعة العميل {lead_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Lead Reminder',
      body: 'Reminder to follow up with lead {lead_name}',
      bodyWithCampaign: null,
    ),
  },
  'whatsapp_message_received': {
    'ar': (
      title: 'رسالة واتساب واردة',
      body: '{lead_name}: {message_preview}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'WhatsApp Message Received',
      body: '{lead_name}: {message_preview}',
      bodyWithCampaign: null,
    ),
  },
  'whatsapp_template_sent': {
    'ar': (
      title: 'إرسال قالب واتساب',
      body: 'تم إرسال رسالة الترحيب بنجاح',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'WhatsApp Template Sent',
      body: 'Welcome message has been sent successfully',
      bodyWithCampaign: null,
    ),
  },
  'whatsapp_send_failed': {
    'ar': (
      title: 'فشل إرسال واتساب',
      body: 'فشل إرسال قالب واتساب',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'WhatsApp Send Failed',
      body: 'Failed to send WhatsApp template',
      bodyWithCampaign: null,
    ),
  },
  'whatsapp_waiting_response': {
    'ar': (
      title: 'بانتظار الرد',
      body: 'لا يوجد رد من العميل المحتمل منذ {hours} ساعة',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Waiting for Response',
      body: 'No response from lead for {hours} hours',
      bodyWithCampaign: null,
    ),
  },
  'campaign_performance': {
    'ar': (
      title: 'أداء الحملة',
      body: 'الحملة {campaign_name} حققت {leads_count} عميل محتمل',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Campaign Performance',
      body: 'Campaign {campaign_name} has achieved {leads_count} leads',
      bodyWithCampaign: null,
    ),
  },
  'campaign_low_performance': {
    'ar': (
      title: 'انخفاض الأداء',
      body: 'انخفاض عدد العملاء المحتملين اليوم في حملة {campaign_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Low Performance',
      body: 'Low number of leads today in campaign {campaign_name}',
      bodyWithCampaign: null,
    ),
  },
  'campaign_stopped': {
    'ar': (
      title: 'إيقاف حملة',
      body: 'تم إيقاف الحملة {campaign_name} بسبب {reason}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Campaign Stopped',
      body: 'Campaign {campaign_name} has been stopped due to {reason}',
      bodyWithCampaign: null,
    ),
  },
  'campaign_budget_alert': {
    'ar': (
      title: 'تنبيه الميزانية',
      body: 'الميزانية المتبقية في حملة {campaign_name} أقل من {remaining_percent}%',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Budget Alert',
      body:
          'Remaining budget in campaign {campaign_name} is less than {remaining_percent}%',
      bodyWithCampaign: null,
    ),
  },
  'task_created': {
    'ar': (
      title: 'مهمة جديدة',
      body: 'لديك مهمة متابعة جديدة: {task_title}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'New Task',
      body: 'You have a new follow-up task: {task_title}',
      bodyWithCampaign: null,
    ),
  },
  'task_reminder': {
    'ar': (
      title: 'تذكير مهمة',
      body: 'تبقى {minutes_remaining} دقيقة على موعد المتابعة: {task_title}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Task Reminder',
      body: '{minutes_remaining} minutes remaining for follow-up: {task_title}',
      bodyWithCampaign: null,
    ),
  },
  'call_reminder': {
    'ar': (
      title: 'تذكير مكالمة',
      body:
          'تبقى {minutes_remaining} دقيقة على موعد مكالمة المتابعة مع {lead_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Call Reminder',
      body:
          '{minutes_remaining} minutes remaining for follow-up call with {lead_name}',
      bodyWithCampaign: null,
    ),
  },
  'pbx_incoming_call': {
    'ar': (
      title: 'مكالمة واردة',
      body: 'مكالمة واردة من {phone}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Incoming Call',
      body: 'Incoming call from {phone}',
      bodyWithCampaign: null,
    ),
  },
  'pbx_call_missed': {
    'ar': (
      title: 'مكالمة فائتة',
      body: 'مكالمة فائتة من {phone}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Missed Call',
      body: 'Missed call from {phone}',
      bodyWithCampaign: null,
    ),
  },
  'visit_reminder': {
    'ar': (
      title: 'تذكير زيارة',
      body:
          'تبقى {minutes_remaining} دقيقة على موعد الزيارة القادمة مع {lead_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Visit Reminder',
      body:
          '{minutes_remaining} minutes remaining for upcoming visit with {lead_name}',
      bodyWithCampaign: null,
    ),
  },
  'reception_visit_reminder': {
    'ar': (
      title: 'تذكير زيارة (استقبال)',
      body: 'تبقى {minutes_remaining} دقيقة على موعد زيارة للمريض {lead_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Visit Reminder (Reception)',
      body: '{minutes_remaining} minutes until visit for patient {lead_name}',
      bodyWithCampaign: null,
    ),
  },
  'field_visit_reminder': {
    'ar': (
      title: 'تذكير زيارة ميدانية',
      body:
          'تبقى {minutes_remaining} دقيقة على موعد الزيارة الميدانية القادمة مع {lead_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Field Visit Reminder',
      body:
          '{minutes_remaining} minutes remaining for upcoming field visit with {lead_name}',
      bodyWithCampaign: null,
    ),
  },
  'reception_field_visit_reminder': {
    'ar': (
      title: 'تذكير زيارة ميدانية (استقبال)',
      body:
          'تبقى {minutes_remaining} دقيقة على موعد زيارة ميدانية للمريض {lead_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Field Visit Reminder (Reception)',
      body:
          '{minutes_remaining} minutes until field visit for patient {lead_name}',
      bodyWithCampaign: null,
    ),
  },
  'task_completed': {
    'ar': (
      title: 'مهمة مكتملة',
      body: 'تم إكمال المهمة: {task_title}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Task Completed',
      body: 'Task completed: {task_title}',
      bodyWithCampaign: null,
    ),
  },
  'deal_created': {
    'ar': (
      title: 'صفقة جديدة',
      body: 'تم إنشاء صفقة جديدة: {deal_title}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'New Deal',
      body: 'A new deal has been created: {deal_title}',
      bodyWithCampaign: null,
    ),
  },
  'deal_updated': {
    'ar': (
      title: 'تحديث صفقة',
      body: 'تم تحديث معلومات الصفقة: {deal_title}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Deal Updated',
      body: 'Deal has been updated: {deal_title}',
      bodyWithCampaign: null,
    ),
  },
  'deal_closed': {
    'ar': (
      title: 'إغلاق صفقة',
      body: 'تم إغلاق الصفقة {deal_title} بقيمة {value}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Deal Closed',
      body: 'Deal {deal_title} has been closed with value {value}',
      bodyWithCampaign: null,
    ),
  },
  'deal_reminder': {
    'ar': (
      title: 'تذكير صفقة',
      body: 'تذكير بموعد متابعة الصفقة: {deal_title}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Deal Reminder',
      body: 'Reminder to follow up on deal: {deal_title}',
      bodyWithCampaign: null,
    ),
  },
  'daily_report': {
    'ar': (
      title: 'تقرير يومي',
      body: 'اليوم: {leads_count} عميل محتمل – {deals_count} مبيعات',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Daily Report',
      body: 'Today: {leads_count} leads – {deals_count} sales',
      bodyWithCampaign: null,
    ),
  },
  'weekly_report': {
    'ar': (
      title: 'تقرير أسبوعي',
      body: 'تقرير الأداء الأسبوعي جاهز',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Weekly Report',
      body: 'Weekly performance report is ready',
      bodyWithCampaign: null,
    ),
  },
  'top_employee': {
    'ar': (
      title: 'أفضل موظف',
      body: 'أفضل موظف مبيعات لهذا الأسبوع: {employee_name}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Top Employee',
      body: 'Top sales employee this week: {employee_name}',
      bodyWithCampaign: null,
    ),
  },
  'login_from_new_device': {
    'ar': (
      title: 'تسجيل دخول جديد',
      body: 'تم تسجيل دخول من جهاز جديد: {device}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Login from New Device',
      body: 'Login detected from new device: {device}',
      bodyWithCampaign: null,
    ),
  },
  'system_update': {
    'ar': (
      title: 'تحديث النظام',
      body: 'تم إضافة ميزة جديدة إلى Loop CRM: {feature}',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'System Update',
      body: 'New feature added to Loop CRM: {feature}',
      bodyWithCampaign: null,
    ),
  },
  'subscription_expiring': {
    'ar': (
      title: 'تنبيه الاشتراك',
      body: 'اشتراكك ينتهي خلال {days_remaining} أيام',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Subscription Expiring',
      body: 'Your subscription expires in {days_remaining} days',
      bodyWithCampaign: null,
    ),
  },
  'payment_failed': {
    'ar': (
      title: 'فشل الدفع',
      body: 'فشل عملية الدفع، يرجى التحقق',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Payment Failed',
      body: 'Payment failed, please check',
      bodyWithCampaign: null,
    ),
  },
  'subscription_expired': {
    'ar': (
      title: 'انتهاء الاشتراك',
      body: 'انتهى الاشتراك، يرجى التجديد',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'Subscription Expired',
      body: 'Subscription has expired, please renew',
      bodyWithCampaign: null,
    ),
  },
  'general': {
    'ar': (
      title: 'إشعار عام',
      body: 'هذا إشعار عام',
      bodyWithCampaign: null,
    ),
    'en': (
      title: 'General Notification',
      body: 'This is a general notification',
      bodyWithCampaign: null,
    ),
  },
};

const Map<String, String> _teamActivityTitles = {
  'ar': 'نشاط الفريق',
  'en': 'Team activity',
};

const Map<String, Map<String, String>> _teamActivityBodies = {
  'status_change': {
    'ar':
        'قام الموظف {employee} بتغيير حالة العميل المحتمل {lead} من {old_status} إلى {new_status}',
    'en':
        'Employee {employee} changed the status of lead {lead} from {old_status} to {new_status}',
  },
  'assignment': {
    'ar':
        'قام الموظف {employee} بتغيير تعيين العميل المحتمل {lead} من {old_assignee} إلى {new_assignee}',
    'en':
        'Employee {employee} changed the assignment of lead {lead} from {old_assignee} to {new_assignee}',
  },
  'edit': {
    'ar': 'قام الموظف {employee} بتحديث العميل المحتمل {lead}: {detail}',
    'en': 'Employee {employee} updated lead {lead}: {detail}',
  },
  'lead_created': {
    'ar': 'قام الموظف {employee} بإنشاء عميل محتمل جديد {lead}',
    'en': 'Employee {employee} created lead {lead}',
  },
  'call_logged': {
    'ar': 'قام الموظف {employee} بتسجيل مكالمة على العميل المحتمل {lead}',
    'en': 'Employee {employee} logged a call on lead {lead}',
  },
  'visit_logged': {
    'ar': 'قام الموظف {employee} بتسجيل زيارة على العميل المحتمل {lead}',
    'en': 'Employee {employee} logged a visit on lead {lead}',
  },
  'field_visit_logged': {
    'ar':
        'قام الموظف {employee} بتسجيل زيارة ميدانية على العميل المحتمل {lead}',
    'en': 'Employee {employee} logged a field visit on lead {lead}',
  },
  'task_created': {
    'ar': 'قام الموظف {employee} بإضافة مهمة على العميل المحتمل {lead}',
    'en': 'Employee {employee} added a task on lead {lead}',
  },
  'deal_won': {
    'ar':
        'قام الموظف {employee} بإغلاق صفقة ناجحة للعميل المحتمل {lead} ({deal_title}) بقيمة {value}',
    'en':
        'Employee {employee} won a deal for lead {lead} ({deal_title}) with value {value}',
  },
  'no_follow_up': {
    'ar':
        'تأخر الموظف {employee} في متابعة العميل المحتمل {lead} لمدة {hours} ساعة',
    'en':
        'Employee {employee} is overdue following up on lead {lead} for {hours} hours',
  },
  'unknown': {
    'ar': 'قام الموظف {employee} بإجراء على العميل المحتمل {lead}: {detail}',
    'en': 'Employee {employee} performed an action on lead {lead}: {detail}',
  },
};

String _s(dynamic v) => v == null ? '' : '$v';

String _lang(String? languageCode) =>
    (languageCode ?? 'ar').toLowerCase().startsWith('en') ? 'en' : 'ar';

String _format(String template, Map<String, dynamic> data) {
  return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
    final key = m.group(1)!;
    return _s(data[key]);
  });
}

String _unassigned(String lang) => lang == 'en' ? 'Unassigned' : 'غير معيّن';

String _assignee(String lang, dynamic value) {
  final text = _s(value).trim();
  if (text.isEmpty ||
      text.toLowerCase() == 'unassigned' ||
      text.toLowerCase() == 'none') {
    return _unassigned(lang);
  }
  return text;
}

Map<String, dynamic> _flatten(Map<String, dynamic>? data) {
  final out = Map<String, dynamic>.from(data ?? const {});
  out['lead'] ??= out['lead_name'];
  out['lead_name'] ??= out['lead'];
  out['employee'] ??= out['employee_name'] ?? out['actor_name'];
  out['message_preview'] ??= out['message'];
  out['phone'] ??= out['caller'];
  return out;
}

NotificationDisplay _teamActivity(String lang, Map<String, dynamic> data) {
  final action = _s(data['action']).isEmpty ? 'unknown' : _s(data['action']);
  final bodies = _teamActivityBodies[action] ?? _teamActivityBodies['unknown']!;
  final title = _teamActivityTitles[lang]!;
  final body = _format(bodies[lang]!, {
    ...data,
    'employee': data['employee'] ?? data['employee_name'] ?? data['actor_name'] ?? '',
    'lead': data['lead'] ?? data['lead_name'] ?? '',
    'detail': data['detail'] ?? data['details'] ?? data['summary'] ?? '',
    'old_assignee': _assignee(lang, data['old_assignee']),
    'new_assignee': _assignee(lang, data['new_assignee']),
  });
  return NotificationDisplay(title: title, body: body, typeLabel: title);
}

/// Localized title/body for an inbox row. Recomputes on every build so language
/// switches update text without refetching.
NotificationDisplay getNotificationDisplay({
  required String type,
  String? apiTitle,
  String? apiBody,
  Map<String, dynamic>? data,
  String? languageCode,
}) {
  final lang = _lang(languageCode);
  final flat = _flatten(data);
  final storedTitle = _s(apiTitle).trim();
  final storedBody = _s(apiBody).trim();

  if (type == 'team_activity') {
    return _teamActivity(lang, flat);
  }

  final tplSet = _templates[type];
  if (tplSet == null) {
    return NotificationDisplay(
      title: storedTitle.isNotEmpty
          ? storedTitle
          : (lang == 'ar' ? 'إشعار' : 'Notification'),
      body: storedBody,
      typeLabel: storedTitle.isNotEmpty ? storedTitle : type,
    );
  }

  final tpl = tplSet[lang] ?? tplSet['ar']!;
  var bodyTpl = tpl.body;
  if (type == 'new_lead' &&
      _s(flat['campaign_name']).trim().isNotEmpty &&
      tpl.bodyWithCampaign != null) {
    bodyTpl = tpl.bodyWithCampaign!;
  }
  final body = _format(bodyTpl, flat);

  if (type == 'pbx_incoming_call' || type == 'pbx_call_missed') {
    final phone = _s(flat['phone']).trim();
    final clientName =
        _s(flat['client_name'] ?? flat['lead_name']).trim();
    final title =
        clientName.isNotEmpty ? clientName : (phone.isNotEmpty ? phone : tpl.title);
    final localizedBody =
        phone.isNotEmpty ? _format(tpl.body, {...flat, 'phone': phone}) : tpl.title;
    return NotificationDisplay(
      title: title,
      body: localizedBody,
      typeLabel: tpl.title,
    );
  }

  return NotificationDisplay(
    title: tpl.title,
    body: body.isNotEmpty ? body : storedBody,
    typeLabel: tpl.title,
  );
}
