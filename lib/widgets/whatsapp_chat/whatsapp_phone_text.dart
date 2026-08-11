import 'package:flutter/material.dart';

import '../../core/utils/lead_phone_utils.dart';

/// LTR-isolated phone / E.164 display (mobile equivalent of web PhoneText).
class WhatsAppPhoneText extends StatelessWidget {
  const WhatsAppPhoneText(
    this.phone, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String phone;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  static bool isPhoneLike(String? value) {
    if (value == null) return false;
    final t = value.trim();
    if (t.isEmpty) return false;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7 && RegExp(r'^[\d\s+\-().]+$').hasMatch(t);
  }

  @override
  Widget build(BuildContext context) {
    final display = formatPhoneForDisplay(phone);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        display.isNotEmpty ? display : phone,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: TextAlign.start,
      ),
    );
  }
}

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

/// Force Latin digits in time strings under Arabic locale.
String withLatinDigits(String input) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(eastern[i], '$i');
  }
  return out;
}
