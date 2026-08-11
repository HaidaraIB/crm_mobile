import 'package:intl/intl.dart';

import '../models/lead_whatsapp_message_model.dart';

enum WhatsAppThreadStatusVariant { started, day, newMessages }

sealed class WhatsAppThreadItem {
  const WhatsAppThreadItem();
}

class WhatsAppThreadStatusItem extends WhatsAppThreadItem {
  const WhatsAppThreadStatusItem({
    required this.id,
    required this.variant,
    required this.label,
  });

  final String id;
  final WhatsAppThreadStatusVariant variant;
  final String label;
}

class WhatsAppThreadMessageItem extends WhatsAppThreadItem {
  const WhatsAppThreadMessageItem(this.message);

  final LeadWhatsAppMessageModel message;
}

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _formatStatusDate(DateTime d, String language) {
  // Compact one-line chip (web uses short month + day + year).
  final locale = language == 'ar' ? 'ar' : 'en_GB';
  return DateFormat('d MMM y', locale).format(d);
}

String _formatDayChip(DateTime d, String language, String Function(String) t) {
  final now = DateTime.now();
  final startToday = DateTime(now.year, now.month, now.day);
  final startMsg = DateTime(d.year, d.month, d.day);
  final diffDays = startToday.difference(startMsg).inDays;
  if (diffDays == 0) return t('teamChatDayToday');
  if (diffDays == 1) return t('teamChatDayYesterday');
  return _formatStatusDate(d, language);
}

/// Insert WhatsApp-style status rows: conversation started, day chips, unread divider.
List<WhatsAppThreadItem> buildWhatsAppThreadItems(
  List<LeadWhatsAppMessageModel> messages, {
  required String language,
  required String Function(String key) t,
  int? newMessagesBeforeApiId,
}) {
  if (messages.isEmpty) return const [];

  final items = <WhatsAppThreadItem>[];
  final first = messages.first;
  final startedLabel = (t('whatsappConversationStartedOn'))
      .replaceAll('{date}', _formatStatusDate(first.createdAt.toLocal(), language));
  items.add(
    WhatsAppThreadStatusItem(
      id: 'status-started',
      variant: WhatsAppThreadStatusVariant.started,
      label: startedLabel,
    ),
  );

  String? prevDay;
  var newDividerInserted = false;

  for (final msg in messages) {
    final local = msg.createdAt.toLocal();
    final key = _dayKey(local);
    if (prevDay != null && key != prevDay) {
      items.add(
        WhatsAppThreadStatusItem(
          id: 'status-day-$key',
          variant: WhatsAppThreadStatusVariant.day,
          label: _formatDayChip(local, language, t),
        ),
      );
    }
    prevDay = key;

    if (!newDividerInserted &&
        newMessagesBeforeApiId != null &&
        msg.id == newMessagesBeforeApiId) {
      items.add(
        WhatsAppThreadStatusItem(
          id: 'status-new-messages',
          variant: WhatsAppThreadStatusVariant.newMessages,
          label: t('whatsappNewMessages'),
        ),
      );
      newDividerInserted = true;
    }

    items.add(WhatsAppThreadMessageItem(msg));
  }

  return items;
}

/// First unread inbound message id (before mark-read), or null.
int? firstUnreadInboundId(List<LeadWhatsAppMessageModel> oldestFirst) {
  for (final m in oldestFirst) {
    if (m.isInbound && !m.isRead && m.id > 0) return m.id;
  }
  return null;
}

/// Derive open 24h session from latest inbound (web dual approach).
bool deriveSessionOpenFromMessages(List<LeadWhatsAppMessageModel> messages) {
  DateTime? latestInbound;
  for (final m in messages) {
    if (!m.isInbound) continue;
    if (latestInbound == null || m.createdAt.isAfter(latestInbound)) {
      latestInbound = m.createdAt;
    }
  }
  if (latestInbound == null) return false;
  return DateTime.now().toUtc().difference(latestInbound.toUtc()) <
      const Duration(hours: 24);
}

double? deriveHoursRemainingFromMessages(List<LeadWhatsAppMessageModel> messages) {
  DateTime? latestInbound;
  for (final m in messages) {
    if (!m.isInbound) continue;
    if (latestInbound == null || m.createdAt.isAfter(latestInbound)) {
      latestInbound = m.createdAt;
    }
  }
  if (latestInbound == null) return null;
  final expires = latestInbound.toUtc().add(const Duration(hours: 24));
  final rem = expires.difference(DateTime.now().toUtc()).inMinutes / 60.0;
  return rem > 0 ? rem : 0;
}
