import 'package:flutter/material.dart';

export '../../core/utils/app_locales.dart' show withLatinDigits;

/// Detect first strong BiDi letter for composer text direction.
TextDirection composerTextDirection(String text, {required bool arabicUi}) {
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(ch)) {
      return TextDirection.rtl;
    }
    if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
      return TextDirection.ltr;
    }
  }
  return arabicUi ? TextDirection.rtl : TextDirection.ltr;
}

/// Bubble body direction from the first strong character (ignore punctuation/digits).
TextDirection resolveBubbleTextDirection(String text) {
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(ch)) {
      return TextDirection.rtl;
    }
    if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
      return TextDirection.ltr;
    }
  }
  return TextDirection.ltr;
}
