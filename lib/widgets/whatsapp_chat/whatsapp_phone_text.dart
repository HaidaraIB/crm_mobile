import 'package:flutter/material.dart';

import '../../core/utils/lead_phone_utils.dart';

export '../../core/utils/app_locales.dart' show withLatinDigits;
export '../chat/chat_text_direction.dart'
    show composerTextDirection, resolveBubbleTextDirection;

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

