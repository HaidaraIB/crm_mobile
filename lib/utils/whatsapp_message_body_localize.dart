/// Localize stub / system WhatsApp body previews (parity with web `localizeWhatsAppMessageBody`).
String localizeWhatsAppMessageBody(String? body, String Function(String key) t) {
  final raw = (body ?? '').trim();
  if (raw.isEmpty) return '';

  final lower = raw.toLowerCase();
  if (lower == '[image]' || lower == '[image message]' || lower.startsWith('[image')) {
    return t('whatsappMediaImage');
  }
  if (lower == '[video]' || lower == '[video message]' || lower.startsWith('[video')) {
    return t('whatsappMediaVideo');
  }
  if (lower == '[audio]' || lower == '[audio message]' || lower == '[voice message]' ||
      lower.startsWith('[audio') || lower.startsWith('[voice')) {
    return t('whatsappMediaAudio');
  }
  if (lower == '[document]' || lower == '[document message]' || lower.startsWith('[document') ||
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
  if (lower.contains('[reaction')) {
    return t('whatsappMediaReaction');
  }
  if (lower.contains('call permission')) {
    return t('whatsappMediaCallPermission');
  }
  return raw;
}
