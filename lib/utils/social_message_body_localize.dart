/// Media-only Instagram/Messenger messages carry an empty body, so a timeline
/// row for one would render blank. Substitute a localized placeholder.
///
/// The generic kinds borrow the `whatsappMedia*` keys on purpose: their values
/// are channel-neutral single words ("Image", "صورة"), and a second set of keys
/// holding identical strings is a translation file that drifts. Instagram-only
/// kinds have no WhatsApp equivalent and get their own keys.
///
/// Parity with web `utils/socialMessageBodyDisplay.ts`.
const _kindKeys = <String, String>{
  'image': 'whatsappMediaImage',
  'video': 'whatsappMediaVideo',
  'audio': 'whatsappMediaAudio',
  'document': 'whatsappMediaDocument',
  'location': 'whatsappMediaLocation',
  'share': 'socialMediaSharePlaceholder',
  'story_mention': 'socialMediaStoryMentionPlaceholder',
  'reel': 'socialMediaReelPlaceholder',
};

String localizeSocialMessageBody(
  String? body,
  String? attachmentKind,
  bool isVoiceNote,
  String Function(String key) t,
) {
  final raw = (body ?? '').trim();
  if (raw.isNotEmpty) return raw;
  if (isVoiceNote) return t('socialMediaVoicePlaceholder');
  if (attachmentKind == null || attachmentKind.isEmpty) return '';
  final key = _kindKeys[attachmentKind];
  return key != null ? t(key) : t('socialMediaGenericPlaceholder');
}
