import 'package:flutter/material.dart';

bool forceLtrInputKeyboard(TextInputType? keyboardType) {
  if (keyboardType == null) return false;
  final name = keyboardType.toString();
  if (name.contains('phone')) return true;
  if (name.contains('emailAddress')) return true;
  if (name.contains('url')) return true;
  if (name.contains('datetime')) return true;
  if (name.contains('number')) return true;
  return keyboardType == TextInputType.emailAddress ||
      keyboardType == TextInputType.phone ||
      keyboardType == TextInputType.url ||
      keyboardType == TextInputType.datetime ||
      keyboardType == TextInputType.number;
}

/// First strong letter sets direction; empty text follows UI locale.
TextDirection composerTextDirection(String text, {required bool arabicUi}) {
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(ch)) {
      return TextDirection.rtl;
    }
    if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
      return TextDirection.ltr;
    }
  }
  return arabicUi ? TextDirection.rtl : TextDirection.ltr;
}

TextDirection resolveInputTextDirection(
  BuildContext context, {
  required String text,
  TextDirection? textDirection,
  TextInputType? keyboardType,
}) {
  if (textDirection != null) return textDirection;
  if (forceLtrInputKeyboard(keyboardType)) return TextDirection.ltr;
  final arabicUi = Directionality.of(context) == TextDirection.rtl;
  return composerTextDirection(text, arabicUi: arabicUi);
}

/// First-strong-isolate / pop-directional-isolate. Stops a run's direction from
/// leaking into the paragraph (CSS `unicode-bidi: isolate`).
const String _fsi = '\u2068';
const String _pdi = '\u2069';

String bidiIsolate(String text) => '$_fsi$text$_pdi';

/// Pin an Arabic hint to the left edge of an LTR field (phone, email, URL).
String ltrAnchoredHint(String hint) =>
    hint.isEmpty || hint.startsWith('\u200E') ? hint : '\u200E$hint';

/// Bubble body direction from the first strong character (ignore punctuation/digits).
TextDirection resolveBubbleTextDirection(String text) {
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(ch)) {
      return TextDirection.rtl;
    }
    if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
      return TextDirection.ltr;
    }
  }
  return TextDirection.ltr;
}
