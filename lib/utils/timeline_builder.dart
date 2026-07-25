import 'package:flutter/material.dart';

import '../core/utils/lead_location.dart';
import '../models/client_call_model.dart';
import '../models/client_event_model.dart';
import '../models/client_field_visit_model.dart';
import '../models/client_task_model.dart';
import '../models/client_visit_model.dart';
import '../models/lead_sms_message_model.dart';
import '../models/lead_whatsapp_message_model.dart';
import '../models/settings_model.dart';
import '../models/timeline_entry.dart';
import '../models/user_model.dart';
import 'timeline_date_format.dart';
import 'timeline_events.dart';

class TimelineBuilderInput {
  final List<ClientTaskModel> tasks;
  final List<ClientCallModel> calls;
  final List<ClientVisitModel> visits;
  final List<ClientFieldVisitModel> fieldVisits;
  final List<ClientEventModel> events;
  final List<LeadSmsMessageModel> smsMessages;
  final List<LeadWhatsAppMessageModel> whatsappMessages;
  final List<UserModel> users;
  final List<StatusModel> statuses;
  final List<ChannelModel> channels;
  final List<StageModel> stages;
  final List<CallMethodModel> callMethods;
  final List<VisitTypeModel> visitTypes;
  final TimelineTranslate t;
  final Locale locale;
  final String leadContactName;
  final String leadContactPhone;
  final int? reAssignHours;
  final bool fieldVisitsAllowed;

  const TimelineBuilderInput({
    required this.tasks,
    required this.calls,
    required this.visits,
    required this.fieldVisits,
    required this.events,
    required this.smsMessages,
    required this.whatsappMessages,
    required this.users,
    required this.statuses,
    required this.channels,
    required this.stages,
    required this.callMethods,
    required this.visitTypes,
    required this.t,
    required this.locale,
    required this.leadContactName,
    required this.leadContactPhone,
    this.reAssignHours,
    this.fieldVisitsAllowed = true,
  });
}

String _tr(TimelineTranslate t, String key) {
  final v = t(key);
  return v.isEmpty ? key : v;
}

String? _userName(List<UserModel> users, int createdBy, String? username) {
  if (createdBy > 0) {
    try {
      final user = users.firstWhere((u) => u.id == createdBy);
      final name = user.name?.trim();
      if (name != null && name.isNotEmpty) return name;
      final un = user.username?.trim();
      if (un != null && un.isNotEmpty) return un;
    } catch (_) {}
  }
  final un = username?.trim();
  if (un != null && un.isNotEmpty) return un;
  return null;
}

String _formatPbxCallSummary(ClientCallModel cc, TimelineTranslate t) {
  final parts = <String>[];
  switch (cc.pbxDirection) {
    case 'inbound':
      parts.add(_tr(t, 'inbound'));
      break;
    case 'outbound':
      parts.add(_tr(t, 'outbound'));
      break;
    case 'internal':
      parts.add(_tr(t, 'internal'));
      break;
  }
  switch (cc.pbxDisposition) {
    case 'answered':
      parts.add(_tr(t, 'answered'));
      break;
    case 'no_answer':
      parts.add(_tr(t, 'missed'));
      break;
    case 'busy':
      parts.add(_tr(t, 'busy'));
      break;
    case 'failed':
      parts.add(_tr(t, 'callFailed'));
      break;
  }
  if (cc.pbxDurationSec != null && cc.pbxDurationSec! > 0) {
    parts.add('${cc.pbxDurationSec}s');
  }
  return parts.isNotEmpty ? parts.join(' · ') : cc.notes;
}

String? _stageColor(List<StageModel> stages, String? stageName) {
  if (stageName == null || stageName.isEmpty) return null;
  try {
    final s = stages.firstWhere(
      (st) =>
          st.name == stageName ||
          st.id.toString() == stageName,
    );
    return s.color;
  } catch (_) {
    return null;
  }
}

List<TimelineEntry> buildLeadTimeline(TimelineBuilderInput input) {
  final t = input.t;
  final locale = input.locale;
  final users = input.users;
  String formatDetail(DateTime? d) => formatTimelineDetailDateTime(d, locale);

  final actions = input.tasks.map((ct) {
    final stageName = ct.stageName ?? '';
    StageModel? stageConfig;
    try {
      stageConfig = input.stages.firstWhere(
        (s) => s.name == stageName || s.id == ct.stage,
      );
    } catch (_) {
      stageConfig = null;
    }
    return TimelineEntry(
      id: 'action-${ct.id}',
      type: TimelineEntryType.action,
      user: _userName(users, ct.createdBy, ct.createdByUsername) ??
          _tr(t, 'unknown'),
      action: _tr(t, 'stageUpdated'),
      details: ct.notes,
      date: formatTimelineDate(ct.createdAt, locale),
      timestamp: ct.createdAt.millisecondsSinceEpoch,
      stage: stageName.isNotEmpty ? stageName : null,
      color: stageConfig?.color ?? _stageColor(input.stages, stageName),
    );
  });

  final calls = input.calls.map((cc) {
    CallMethodModel? callMethod;
    try {
      callMethod = input.callMethods.firstWhere((cm) => cm.id == cc.callMethod);
    } catch (_) {
      callMethod = null;
    }
    final callMethodName =
        callMethod?.name ?? cc.callMethodName ?? _tr(t, 'call');
    final callDate = cc.callDatetime ?? cc.createdAt;
    final isPbx = cc.isPbx;

    return TimelineEntry(
      id: 'call-${cc.id}',
      type: TimelineEntryType.call,
      user: _userName(users, cc.createdBy, cc.createdByUsername) ??
          _tr(t, 'unknown'),
      action: isPbx ? _formatPbxCallSummary(cc, t) : _tr(t, 'callMade'),
      details: isPbx ? '' : cc.notes,
      date: formatTimelineDate(callDate, locale),
      timestamp: callDate.millisecondsSinceEpoch,
      stage: isPbx ? _tr(t, 'pbxCallSource') : callMethodName,
      color: isPbx ? '#4f46e5' : callMethod?.color,
      callDatetime: formatDetail(callDate),
      followUpDate: cc.followUpDate != null
          ? formatDetail(cc.followUpDate)
          : null,
      recordingUrl: cc.pbxRecordingUrl,
      recordingStatus: cc.pbxRecordingStatus,
    );
  });

  final visits = input.visits.map((cv) {
    VisitTypeModel? vt;
    try {
      vt = input.visitTypes.firstWhere((x) => x.id == cv.visitType);
    } catch (_) {
      vt = null;
    }
    final visitTypeName = vt?.name ?? cv.visitTypeName ?? _tr(t, 'visit');
    final visitDate = cv.visitDatetime ?? cv.createdAt;

    return TimelineEntry(
      id: 'visit-${cv.id}',
      type: TimelineEntryType.visit,
      user: _userName(users, cv.createdBy, cv.createdByUsername) ??
          _tr(t, 'unknown'),
      action: _tr(t, 'visitLogged'),
      details: cv.summary,
      date: formatTimelineDate(visitDate, locale),
      timestamp: visitDate.millisecondsSinceEpoch,
      stage: visitTypeName,
      color: vt?.color,
      callDatetime: formatDetail(visitDate),
      followUpDate: cv.upcomingVisitDate != null
          ? formatDetail(cv.upcomingVisitDate)
          : null,
    );
  });

  final fieldVisits = input.fieldVisitsAllowed
      ? input.fieldVisits.map((cv) {
          final visitDate = cv.visitDatetime ?? cv.createdAt;
          return TimelineEntry(
            id: 'field-visit-${cv.id}',
            type: TimelineEntryType.fieldVisit,
            user: _userName(users, cv.createdBy ?? 0, cv.createdByUsername) ??
                _tr(t, 'unknown'),
            action: _tr(t, 'fieldVisitLogged'),
            details: cv.summary,
            date: formatTimelineDate(visitDate, locale),
            timestamp: visitDate.millisecondsSinceEpoch,
            callDatetime: formatDetail(visitDate),
            followUpDate: cv.upcomingVisitDate != null
                ? formatDetail(cv.upcomingVisitDate)
                : null,
            locationPhotoUrl: cv.clientLocationPhotoUrl,
          );
        })
      : <TimelineEntry>[];

  final eventFormatCtx = TimelineEventFormatContext(
    t: t,
    users: users,
    statuses: input.statuses,
    channels: input.channels,
  );

  final events = input.events.map((ce) {
    final actor = resolveTimelineActor(
      createdById: ce.createdBy,
      createdByUsername: ce.createdByUsername,
      users: users,
      t: t,
      fallback: timelineEventActorFallback(
        eventType: ce.eventType,
        newValue: ce.newValue,
        createdBy: ce.createdBy,
      ),
      contactName: input.leadContactName,
      contactPhone: input.leadContactPhone,
    );

    final actionText = ce.eventType == 'location_update'
        ? _tr(t, clientLocationEventTranslationKey(ce.notes))
        : getTimelineEventAction(
            ce.eventType,
            t,
            notes: ce.notes,
            oldValue: ce.oldValue,
            newValue: ce.newValue,
          );

    final editFieldLabel = ce.eventType == 'edit'
        ? getEditFieldLabel(
            ce.notes,
            t,
            oldValue: ce.oldValue,
            newValue: ce.newValue,
          )
        : null;

    String? eventColor;
    if (ce.eventType == 'status_change') {
      try {
        final statusConfig = input.statuses.firstWhere(
          (s) =>
              s.name == ce.newValue || s.id.toString() == ce.newValue,
        );
        eventColor = statusConfig.color;
      } catch (_) {}
    }

    final pair = formatTimelineEventValuePair(
      ce.oldValue,
      ce.newValue,
      eventFormatCtx,
      ce.eventType,
      notes: ce.notes,
    );

    var translatedDetails = '';
    if (ce.eventType == 'location_update') {
      translatedDetails = '';
    } else if (ce.eventType == 're_assignment') {
      final hoursMatch = RegExp(r'(\d+)\s*ساعة').firstMatch(ce.notes ?? '');
      final hours = hoursMatch?.group(1) ??
          (input.reAssignHours?.toString() ?? '24');
      translatedDetails = _tr(t, 'autoReassignedFromTo')
          .replaceAll('{from}', pair.oldFormatted ?? _tr(t, 'unassigned'))
          .replaceAll('{to}', pair.newFormatted ?? _tr(t, 'unassigned'))
          .replaceAll('{hours}', hours);
    } else {
      translatedDetails =
          localizeTimelineEventNotes(ce.notes, ce.eventType, t);
    }

    final showValuePair = ce.eventType != 'location_update' &&
        (pair.oldFormatted != null || pair.newFormatted != null);
    final suppressDetailsWithPair = showValuePair &&
        ['edit', 'status_change', 'assignment', 'created']
            .contains(ce.eventType);
    final detailsOnly =
        translatedDetails.isNotEmpty && !suppressDetailsWithPair;

    return TimelineEntry(
      id: 'event-${ce.id}',
      type: ce.eventType == 'location_update'
          ? TimelineEntryType.locationUpdate
          : TimelineEntryType.event,
      user: actor.name,
      action: actionText,
      fieldLabel: editFieldLabel,
      details: detailsOnly ? translatedDetails : '',
      date: formatTimelineDate(ce.createdAt, locale),
      timestamp: ce.createdAt.millisecondsSinceEpoch,
      oldValue: ce.eventType == 'location_update'
          ? ce.oldValue
          : pair.oldFormatted,
      newValue: ce.eventType == 'location_update'
          ? ce.newValue
          : pair.newFormatted,
      color: eventColor,
    );
  });

  final smsEntries = input.smsMessages.map((sms) {
    final isAutoWelcome = sms.createdBy == null;
    return TimelineEntry(
      id: 'sms-${sms.id}',
      type: TimelineEntryType.sms,
      user: _userName(users, sms.createdBy ?? 0, sms.createdByUsername) ??
          _tr(t, 'unknown'),
      action: isAutoWelcome
          ? _tr(t, 'smsSentAutoWelcome')
          : _tr(t, 'smsSentLabel'),
      details: sms.body,
      date: formatTimelineDate(sms.createdAt, locale),
      timestamp: sms.createdAt.millisecondsSinceEpoch,
      stage: sms.phoneNumber.isNotEmpty ? sms.phoneNumber : null,
    );
  });

  final waEntries = input.whatsappMessages.map((wa) {
    final isInbound = wa.isInbound;
    final actor = resolveTimelineActor(
      createdById: wa.createdBy,
      createdByUsername: wa.createdByUsername,
      users: users,
      t: t,
      fallback: isInbound
          ? TimelineActorFallback.contact
          : TimelineActorFallback.whatsapp,
      contactName: input.leadContactName,
      contactPhone: wa.phoneNumber.isNotEmpty
          ? wa.phoneNumber
          : input.leadContactPhone,
    );
    return TimelineEntry(
      id: 'wa-${wa.id}',
      type: TimelineEntryType.whatsapp,
      user: actor.name,
      action: isInbound ? _tr(t, 'whatsappReceived') : _tr(t, 'whatsappSent'),
      details: wa.body,
      date: formatTimelineDate(wa.createdAt, locale),
      timestamp: wa.createdAt.millisecondsSinceEpoch,
      stage: wa.phoneNumber.isNotEmpty ? wa.phoneNumber : null,
    );
  });

  return [
    ...actions,
    ...calls,
    ...visits,
    ...fieldVisits,
    ...events,
    ...smsEntries,
    ...waEntries,
  ];
}
