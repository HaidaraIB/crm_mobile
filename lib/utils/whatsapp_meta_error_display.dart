/// Map Meta Graph / `delivery_error` strings to CRM i18n keys when possible.
///
/// Port of `CRM-project/utils/whatsappMetaErrorDisplay.ts` — keep the code table
/// in sync with the web version.
library;

const Map<String, String> _codeToKey = {
  '131037': 'whatsapp_display_name_not_approved',
  '131026': 'whatsapp_recipient_not_deliverable',
  '131047': 'whatsappOutsideSessionUseTemplate',
  '131049': 'whatsapp_ecosystem_engagement_limit',
  '132000': 'whatsapp_template_parameter_count',
  '132001': 'whatsapp_template_not_found_or_language',
};

final RegExp _leadingCode = RegExp(r'^(\d{5,7})\b');

/// If [raw] looks like "131047: Re-engagement…" or contains a known Meta code,
/// return the matching translation key; otherwise null.
String? metaDeliveryErrorTranslationKey(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  final leading = _leadingCode.firstMatch(text);
  if (leading != null) {
    final key = _codeToKey[leading.group(1)];
    if (key != null) return key;
  }
  for (final entry in _codeToKey.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Localized text for a Meta delivery error, falling back to the raw string
/// when the code is unknown or the key has no translation.
String localizeMetaDeliveryError(String? raw, String Function(String key) t) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return '';
  final key = metaDeliveryErrorTranslationKey(text);
  if (key != null) {
    final translated = t(key);
    if (translated.isNotEmpty && translated != key) return translated;
  }
  return text;
}
