import 'package:flutter/material.dart';

import '../../core/utils/input_text_direction.dart' show bidiIsolate;
import '../../widgets/whatsapp_chat/whatsapp_phone_text.dart';

export '../../core/utils/input_text_direction.dart' show bidiIsolate;
export '../../widgets/whatsapp_chat/whatsapp_phone_text.dart'
    show composerTextDirection, resolveBubbleTextDirection, withLatinDigits;

/// Row label (conversation names, previews, headers): alignment stays with the
/// **UI** direction so the text hugs the avatar edge — same as the web list,
/// which pins `text-right` in Arabic — while the content itself is isolated so
/// an English name inside an Arabic row still reads correctly.
class TeamChatIsolatedText extends StatelessWidget {
  const TeamChatIsolatedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      bidiIsolate(text),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: TextAlign.start,
    );
  }
}

/// Message text: direction — and therefore alignment inside the bubble — comes
/// from the first strong character of the string, not the app UI language.
/// Mobile equivalent of the web `ChatText` (`dir="auto"` + `unicode-bidi:
/// plaintext`).
class TeamChatAutoDirText extends StatelessWidget {
  const TeamChatAutoDirText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: resolveBubbleTextDirection(text),
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: TextAlign.start,
      ),
    );
  }
}
