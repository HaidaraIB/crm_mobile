import '../core/localization/app_localizations.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import 'whatsapp_message_body_localize.dart';

typedef TimelineTranslate = String Function(String key);

class TimelineEventFormatContext {
  final TimelineTranslate t;
  final List<UserModel> users;
  final List<StatusModel> statuses;
  final List<ChannelModel> channels;

  const TimelineEventFormatContext({
    required this.t,
    required this.users,
    required this.statuses,
    required this.channels,
  });
}

enum TimelineActorFallback { system, whatsapp, contact }

const _editNoteFieldKeys = <String, String>{
  'budget': 'timelineFieldBudgetUpdated',
  'budget max': 'timelineFieldBudgetMaxUpdated',
  'budget_max': 'timelineFieldBudgetMaxUpdated',
  'communication way': 'timelineFieldCommunicationWayUpdated',
  'communication_way': 'timelineFieldCommunicationWayUpdated',
  'name': 'timelineFieldNameUpdated',
  'priority': 'timelineFieldPriorityUpdated',
  'type': 'timelineFieldTypeUpdated',
  'notes': 'timelineFieldNotesUpdated',
  'profession': 'timelineFieldProfessionUpdated',
  'residence': 'timelineFieldResidenceUpdated',
  'lead company name': 'timelineFieldLeadCompanyNameUpdated',
  'lead_company_name': 'timelineFieldLeadCompanyNameUpdated',
  'interested developer': 'timelineFieldInterestedDeveloperUpdated',
  'interested_developer': 'timelineFieldInterestedDeveloperUpdated',
  'interested project': 'timelineFieldInterestedProjectUpdated',
  'interested_project': 'timelineFieldInterestedProjectUpdated',
  'interested unit': 'timelineFieldInterestedUnitUpdated',
  'interested_unit': 'timelineFieldInterestedUnitUpdated',
};

const _eventTypeActionKeys = <String, String>{
  'status_change': 'statusUpdated',
  'tags_change': 'timelineTagsUpdated',
  'assignment': 'leadAssigned',
  'location_update': 'timeline',
  'edit': 'leadEdited',
  're_assignment': 'leadReAssigned',
  'created': 'timelineEventCreated',
  'whatsapp_message': 'whatsappReceived',
};

const _waMessageTypeKeys = <String, String>{
  'text': 'whatsappMessageType_text',
  'image': 'whatsappMessageType_image',
  'video': 'whatsappMessageType_video',
  'audio': 'whatsappMessageType_audio',
  'document': 'whatsappMessageType_document',
  'sticker': 'whatsappMessageType_sticker',
  'location': 'whatsappMessageType_location',
  'contacts': 'whatsappMessageType_contacts',
  'interactive': 'whatsappMessageType_interactive',
  'button': 'whatsappMessageType_button',
  'reaction': 'whatsappMessageType_reaction',
  'unknown': 'whatsappMessageType_unknown',
};

const _sourceValueKeys = <String, String>{
  'custom lead api': 'leadApiSource',
  'custom api': 'leadApiSource',
  'mujeb': 'mujebSource',
  'whatsapp': 'whatsappSource',
  'tiktok': 'tiktokSource',
  'meta': 'metaLeadForm',
  'manual': 'manualSource',
};

String normalizeToken(String value) => value.trim().toLowerCase();

String _tr(TimelineTranslate t, String key) {
  final v = t(key);
  return v.isEmpty ? key : v;
}

class TimelineActor {
  final String name;
  final String? avatar;
  const TimelineActor({required this.name, this.avatar});
}

TimelineActor resolveTimelineActor({
  int? createdById,
  String? createdByUsername,
  required List<UserModel> users,
  required TimelineTranslate t,
  TimelineActorFallback? fallback,
  String? contactName,
  String? contactPhone,
}) {
  if (createdById != null && createdById > 0) {
    try {
      final user = users.firstWhere((u) => u.id == createdById);
      final name = user.name?.trim();
      if (name != null && name.isNotEmpty) {
        return TimelineActor(name: name, avatar: user.avatar);
      }
      final username = user.username?.trim();
      if (username != null && username.isNotEmpty) {
        return TimelineActor(name: username, avatar: user.avatar);
      }
    } catch (_) {}
  }
  final username = createdByUsername?.trim();
  if (username != null && username.isNotEmpty) {
    return TimelineActor(name: username);
  }
  if (fallback == TimelineActorFallback.contact) {
    final contact = (contactName ?? contactPhone ?? '').trim();
    if (contact.isNotEmpty) return TimelineActor(name: contact);
  }
  if (fallback == TimelineActorFallback.whatsapp) {
    return TimelineActor(name: _tr(t, 'whatsappSource'));
  }
  if (fallback == TimelineActorFallback.system) {
    return TimelineActor(name: _tr(t, 'timelineActorSystem'));
  }
  return TimelineActor(name: _tr(t, 'unknown'));
}

TimelineActorFallback? timelineEventActorFallback({
  required String eventType,
  String? newValue,
  int? createdBy,
}) {
  if (createdBy != null) return null;
  if (eventType == 'whatsapp_message') return TimelineActorFallback.contact;
  if (eventType == 'created' &&
      normalizeToken(newValue ?? '') == 'whatsapp') {
    return TimelineActorFallback.whatsapp;
  }
  if (['assignment', 're_assignment', 'created'].contains(eventType)) {
    return TimelineActorFallback.system;
  }
  return TimelineActorFallback.system;
}

/// Names split out of a tag-change event's machine key.
class ParsedTagsChange {
  final List<String> added;
  final List<String> removed;

  const ParsedTagsChange({required this.added, required this.removed});
}

/// Split the API's machine key for a tag change — `tags_updated:+VIP,Hot|-Cold`
/// (either side may be empty). Returns null when the notes are not that shape.
ParsedTagsChange? parseTagsChangeNotes(String? notes) {
  final match =
      RegExp(r'^tags_updated:\+(.*)\|-(.*)$').firstMatch((notes ?? '').trim());
  if (match == null) return null;
  List<String> split(String? raw) => (raw ?? '')
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();
  return ParsedTagsChange(
    added: split(match.group(1)),
    removed: split(match.group(2)),
  );
}

String? parseEditFieldKeyFromNotes(String? notes) {
  if (notes == null) return null;
  final trimmed = notes.trim();

  final keyMatch = RegExp(r'^field_updated:([a-z0-9_]+)$', caseSensitive: false)
      .firstMatch(trimmed);
  if (keyMatch != null) {
    final slug = normalizeToken(keyMatch.group(1)!);
    return _editNoteFieldKeys[slug] ??
        _editNoteFieldKeys[slug.replaceAll('_', ' ')];
  }

  final match =
      RegExp(r'^(.+?)\s+updated$', caseSensitive: false).firstMatch(trimmed);
  if (match == null) return null;
  final slug = normalizeToken(match.group(1)!.replaceAll('_', ' '));
  return _editNoteFieldKeys[slug];
}

String? _inferEditFieldKeyFromValues(String? oldValue, String? newValue) {
  bool looksLikeCoordinate(String? value) =>
      value != null && RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value.trim());

  if (looksLikeCoordinate(oldValue) || looksLikeCoordinate(newValue)) {
    return 'timelineFieldLocationUpdated';
  }
  return null;
}

String? getEditFieldLabel(
  String? notes,
  TimelineTranslate t, {
  String? oldValue,
  String? newValue,
}) {
  final fieldKey =
      parseEditFieldKeyFromNotes(notes) ??
      _inferEditFieldKeyFromValues(oldValue, newValue);
  if (fieldKey != null) return _tr(t, fieldKey);

  final match =
      RegExp(r'^(.+?)\s+updated$', caseSensitive: false).firstMatch(notes ?? '');
  if (match != null) {
    final human = match.group(1)!.replaceAll('_', ' ').trim();
    return _tr(t, 'timelineFieldGenericUpdated').replaceAll('{{field}}', human);
  }
  return null;
}

String getTimelineEventAction(
  String eventType,
  TimelineTranslate t, {
  String? notes,
  String? oldValue,
  String? newValue,
}) {
  if (eventType == 'edit') {
    return getEditFieldLabel(notes, t, oldValue: oldValue, newValue: newValue) ??
        _tr(t, 'leadEdited');
  }
  final key = _eventTypeActionKeys[eventType];
  if (key != null) return _tr(t, key);
  return _tr(t, 'timeline');
}

String formatTimelineEventValue(
  String? value,
  TimelineEventFormatContext ctx, {
  String hint = 'generic',
}) {
  final t = ctx.t;
  if (value == null || value == '' || value == 'None' || value == 'null') {
    return _tr(t, 'timelineValueEmpty');
  }

  final trimmed = value.trim();
  final normalized = normalizeToken(trimmed);

  if (normalized == 'unassigned' || normalized == 'none') {
    return _tr(t, 'unassigned');
  }

  final sourceKey = _sourceValueKeys[normalized];
  if (sourceKey != null) return _tr(t, sourceKey);

  if (hint == 'user' || RegExp(r'^\d+$').hasMatch(trimmed)) {
    final userId = int.tryParse(trimmed);
    if (userId != null) {
      try {
        final user = ctx.users.firstWhere((u) => u.id == userId);
        if (user.name != null && user.name!.trim().isNotEmpty) {
          return user.name!.trim();
        }
        if (user.username != null && user.username!.trim().isNotEmpty) {
          return user.username!.trim();
        }
      } catch (_) {}
    }
    try {
      final byUsername = ctx.users.firstWhere(
        (u) =>
            normalizeToken(u.username ?? '') == normalized ||
            normalizeToken(u.name ?? '') == normalized,
      );
      if (byUsername.name != null && byUsername.name!.trim().isNotEmpty) {
        return byUsername.name!.trim();
      }
      if (byUsername.username != null &&
          byUsername.username!.trim().isNotEmpty) {
        return byUsername.username!.trim();
      }
    } catch (_) {}
  }

  if (hint == 'status' || hint == 'generic') {
    try {
      final statusById =
          ctx.statuses.firstWhere((s) => s.id.toString() == trimmed);
      return statusById.name;
    } catch (_) {}
    try {
      final statusByName =
          ctx.statuses.firstWhere((s) => normalizeToken(s.name) == normalized);
      return statusByName.name;
    } catch (_) {}
  }

  if (hint == 'channel' || hint == 'generic') {
    try {
      final channelById =
          ctx.channels.firstWhere((c) => c.id.toString() == trimmed);
      return channelById.name;
    } catch (_) {}
    try {
      final channelByName =
          ctx.channels.firstWhere((c) => normalizeToken(c.name) == normalized);
      return channelByName.name;
    } catch (_) {}
    if (normalized == 'whatsapp') return _tr(t, 'whatsappSource');
  }

  if (RegExp(r'^0+(\.0+)?$').hasMatch(trimmed) || trimmed == '0.00') {
    return _tr(t, 'timelineValueEmpty');
  }

  return trimmed;
}

String inferValueHintFromEditNotes(String? notes) {
  final fieldKey = parseEditFieldKeyFromNotes(notes);
  if (fieldKey == 'timelineFieldCommunicationWayUpdated') return 'channel';
  return 'generic';
}

({String? oldFormatted, String? newFormatted}) formatTimelineEventValuePair(
  String? oldValue,
  String? newValue,
  TimelineEventFormatContext ctx,
  String eventType, {
  String? notes,
}) {
  var hint = 'generic';
  if (eventType == 'assignment' || eventType == 're_assignment') hint = 'user';
  if (eventType == 'status_change') hint = 'status';
  if (eventType == 'created') hint = 'generic';
  if (eventType == 'edit') hint = inferValueHintFromEditNotes(notes);

  String? formatOne(String? value) {
    if (value == null || value.isEmpty) return null;
    if (eventType == 'whatsapp_message') {
      return localizeWhatsAppMessageBody(value, ctx.t);
    }
    return formatTimelineEventValue(value, ctx, hint: hint);
  }

  return (
    oldFormatted: formatOne(oldValue),
    newFormatted: formatOne(newValue),
  );
}

String localizeTimelineEventNotes(
  String? notes,
  String eventType,
  TimelineTranslate t,
) {
  if (notes == null || notes.trim().isEmpty) return '';

  final trimmed = notes.trim();

  if (eventType == 'edit') {
    final fieldKey = parseEditFieldKeyFromNotes(trimmed);
    if (fieldKey != null) return _tr(t, fieldKey);
  }

  if (eventType == 'created' ||
      trimmed.toLowerCase().startsWith('lead from')) {
    final lower = trimmed.toLowerCase();
    if (lower.contains('custom lead api') || lower.contains('custom api')) {
      final emailMatch =
          RegExp(r'email:\s*(.+)', caseSensitive: false).firstMatch(trimmed);
      final base = _tr(t, 'timelineLeadFromCustomApi');
      return emailMatch != null ? '$base · ${emailMatch.group(1)!.trim()}' : base;
    }
    if (lower.contains('mujeb')) {
      final emailMatch =
          RegExp(r'email:\s*(.+)', caseSensitive: false).firstMatch(trimmed);
      final base = _tr(t, 'timelineLeadFromMujeb');
      return emailMatch != null ? '$base · ${emailMatch.group(1)!.trim()}' : base;
    }
    if (lower.contains('tiktok')) return _tr(t, 'timelineLeadFromTikTok');
    if (lower.contains('whatsapp')) return _tr(t, 'timelineLeadFromWhatsapp');
    if (lower.contains('meta')) return _tr(t, 'timelineLeadFromMeta');
  }

  if (eventType == 'status_change') {
    final statusMatch = RegExp(
      r'status changed from (.+) to (.+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (statusMatch != null) {
      final emptyCtx = TimelineEventFormatContext(
        t: t,
        users: const [],
        statuses: const [],
        channels: const [],
      );
      return '${_tr(t, 'statusChangedFrom')} ${formatTimelineEventValue(statusMatch.group(1), emptyCtx)} ${_tr(t, 'statusChangedTo')} ${formatTimelineEventValue(statusMatch.group(2), emptyCtx)}';
    }
  }

  if (eventType == 'tags_change') {
    final parsed = parseTagsChangeNotes(trimmed);
    if (parsed != null) {
      final added = parsed.added;
      final removed = parsed.removed;
      final parts = <String>[];
      if (added.isNotEmpty) {
        parts.add('${_tr(t, 'timelineTagsAdded')}: ${added.join(', ')}');
      }
      if (removed.isNotEmpty) {
        parts.add('${_tr(t, 'timelineTagsRemoved')}: ${removed.join(', ')}');
      }
      if (parts.isNotEmpty) return parts.join(' · ');
      return _tr(t, 'timelineTagsUpdated');
    }
  }

  if (eventType == 'assignment') {
    final emptyCtx = TimelineEventFormatContext(
      t: t,
      users: const [],
      statuses: const [],
      channels: const [],
    );
    final assignedMatch = RegExp(
      r'^assigned to (.+?)(?: \(was (.+)\))?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (assignedMatch != null) {
      final newVal = formatTimelineEventValue(
        assignedMatch.group(1),
        emptyCtx,
        hint: 'user',
      );
      final oldRaw = assignedMatch.group(2);
      if (oldRaw != null) {
        final oldVal =
            formatTimelineEventValue(oldRaw, emptyCtx, hint: 'user');
        if (oldVal != newVal) {
          return '${_tr(t, 'assignedToAction')} $newVal (${_tr(t, 'was')} $oldVal)';
        }
      }
      return '${_tr(t, 'assignedToAction')} $newVal';
    }
    final unassignedMatch = RegExp(
      r'^unassigned \(was (.+)\)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (unassignedMatch != null) {
      final oldVal = formatTimelineEventValue(
        unassignedMatch.group(1),
        emptyCtx,
        hint: 'user',
      );
      return '${_tr(t, 'unassigned')} (${_tr(t, 'was')} $oldVal)';
    }
  }

  if (trimmed.toLowerCase().contains('bulk assigned')) {
    final emptyCtx = TimelineEventFormatContext(
      t: t,
      users: const [],
      statuses: const [],
      channels: const [],
    );
    final bulkMatch = RegExp(
      r'bulk assigned to (.+?)(?: \(was (.+)\))?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (bulkMatch != null) {
      final newVal = formatTimelineEventValue(
        bulkMatch.group(1),
        emptyCtx,
        hint: 'user',
      );
      final oldRaw = bulkMatch.group(2);
      if (oldRaw != null) {
        final oldVal =
            formatTimelineEventValue(oldRaw, emptyCtx, hint: 'user');
        if (oldVal != newVal) {
          return '${_tr(t, 'bulkAssignedTo')} $newVal (${_tr(t, 'was')} $oldVal)';
        }
      }
      return '${_tr(t, 'bulkAssignedTo')} $newVal';
    }
  }

  final receivedMatch = RegExp(
    r'^WhatsApp message received:\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (receivedMatch != null || eventType == 'whatsapp_message') {
    if (RegExp(r'coexistence echo|WhatsApp Business app message',
            caseSensitive: false)
        .hasMatch(trimmed)) {
      return _tr(t, 'timelineWhatsAppCoexistenceEcho');
    }
    if (receivedMatch != null) {
      final typeRaw = receivedMatch.group(1)!.trim().toLowerCase();
      final typeKey = _waMessageTypeKeys[typeRaw];
      final typeLabel =
          typeKey != null ? _tr(t, typeKey) : receivedMatch.group(1)!.trim();
      return '${_tr(t, 'timelineWhatsAppMessageReceived')}: $typeLabel';
    }
  }

  if (RegExp(r'^Client created for WhatsApp conversation$', caseSensitive: false)
      .hasMatch(trimmed)) {
    return _tr(t, 'timelineLeadFromWhatsapp');
  }

  return trimmed;
}

/// Helper when AppLocalizations is available.
TimelineTranslate translateFromLocalizations(AppLocalizations? loc) {
  return (key) => loc?.translate(key) ?? key;
}
