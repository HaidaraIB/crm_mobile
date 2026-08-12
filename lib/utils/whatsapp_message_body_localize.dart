/// Localize stub / system WhatsApp body previews (parity with web `localizeWhatsAppMessageBody`).
String localizeWhatsAppMessageBody(String? body, String Function(String key) t) {
  final raw = (body ?? '').trim();
  if (raw.isEmpty) return '';

  final lower = raw.toLowerCase();

  const exact = <String, String>{
    '[media message]': 'whatsappMediaUnavailable',
    '[image message]': 'whatsappMediaImage',
    '[video message]': 'whatsappMediaVideo',
    '[audio message]': 'whatsappMediaAudio',
    '[document message]': 'whatsappMediaDocument',
    '[sticker message]': 'whatsappMediaSticker',
    '[location message]': 'whatsappMediaLocation',
    '[contacts message]': 'whatsappMediaContacts',
    '[interactive message]': 'whatsappMediaInteractive',
    '[call permission request]': 'whatsappCallPermissionRequestLabel',
    '[call permission accepted]': 'whatsappCallPermissionAcceptedLabel',
    '[call permission rejected]': 'whatsappCallPermissionRejectedLabel',
    '[call permission reply]': 'whatsappCallPermissionReplyLabel',
    '[button message]': 'whatsappMediaButton',
    '[button reply]': 'whatsappMediaButton',
    '[list reply]': 'whatsappMediaInteractive',
    '[reaction]': 'whatsappMediaReaction',
  };
  final exactKey = exact[lower];
  if (exactKey != null) return t(exactKey);

  if (lower == '[image]' || lower.startsWith('[image')) {
    return t('whatsappMediaImage');
  }
  if (lower == '[video]' || lower.startsWith('[video')) {
    return t('whatsappMediaVideo');
  }
  if (lower == '[audio]' ||
      lower == '[voice message]' ||
      lower.startsWith('[audio') ||
      lower.startsWith('[voice')) {
    return t('whatsappMediaAudio');
  }
  if (lower == '[document]' ||
      lower.startsWith('[document') ||
      lower.startsWith('[file')) {
    return t('whatsappMediaDocument');
  }
  if (lower == '[sticker]' || lower.startsWith('[sticker')) {
    return t('whatsappMediaSticker');
  }
  if (lower == '[location]' || lower.startsWith('[location')) {
    return t('whatsappMediaLocation');
  }
  if (lower.contains('[contact') || lower == '[contacts]') {
    return t('whatsappMediaContacts');
  }
  if (lower.contains('[interactive') || lower.contains('[button')) {
    return t('whatsappMediaInteractive');
  }
  final reactionMatch =
      RegExp(r'^\[reaction(?:\s+(.+))?\]$', caseSensitive: false).firstMatch(raw);
  if (reactionMatch != null) {
    final emoji = (reactionMatch.group(1) ?? '').trim();
    final label = t('whatsappMediaReaction');
    return emoji.isEmpty ? label : '$label $emoji';
  }
  if (lower.contains('call permission accepted')) {
    return t('whatsappCallPermissionAcceptedLabel');
  }
  if (lower.contains('call permission rejected') ||
      lower.contains('call permission declined')) {
    return t('whatsappCallPermissionRejectedLabel');
  }
  if (lower.contains('call permission reply')) {
    return t('whatsappCallPermissionReplyLabel');
  }
  if (lower.contains('call permission')) {
    return t('whatsappCallPermissionRequestLabel');
  }
  return raw;
}
