import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/whatsapp_chat/whatsapp_phone_text.dart';

/// Renders WhatsApp-style markdown: *bold* _italic_ ~strike~ ```mono``` + URL linkify.
class WhatsAppFormattedText extends StatelessWidget {
  const WhatsAppFormattedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  static final _urlRe = RegExp(
    r'(https?:\/\/[^\s<>]+)|(www\.[^\s<>]+)',
    caseSensitive: false,
  );

  static final _tokenRe = RegExp(
    r'```([\s\S]+?)```|\*([^*\n]+)\*|_([^_\n]+)_|~([^~\n]+)~',
  );

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    var i = 0;
    final matches = _tokenRe.allMatches(text).toList();
    var mi = 0;

    while (i < text.length) {
      if (mi < matches.length && matches[mi].start == i) {
        final m = matches[mi];
        if (m.group(1) != null) {
          spans.add(TextSpan(
            text: m.group(1),
            style: base.copyWith(fontFamily: 'monospace', fontSize: (base.fontSize ?? 14) * 0.95),
          ));
        } else if (m.group(2) != null) {
          spans.add(TextSpan(text: m.group(2), style: base.copyWith(fontWeight: FontWeight.bold)));
        } else if (m.group(3) != null) {
          spans.add(TextSpan(text: m.group(3), style: base.copyWith(fontStyle: FontStyle.italic)));
        } else if (m.group(4) != null) {
          spans.add(TextSpan(
            text: m.group(4),
            style: base.copyWith(decoration: TextDecoration.lineThrough),
          ));
        }
        i = m.end;
        mi++;
        continue;
      }

      final nextToken = mi < matches.length ? matches[mi].start : text.length;
      final chunk = text.substring(i, nextToken);
      spans.addAll(_linkify(chunk, base));
      i = nextToken;
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: textAlign,
      textDirection: resolveBubbleTextDirection(text),
    );
  }

  List<InlineSpan> _linkify(String chunk, TextStyle base) {
    final out = <InlineSpan>[];
    var i = 0;
    for (final m in _urlRe.allMatches(chunk)) {
      if (m.start > i) {
        out.add(TextSpan(text: chunk.substring(i, m.start)));
      }
      final raw = m.group(0)!;
      final href = raw.toLowerCase().startsWith('http') ? raw : 'https://$raw';
      out.add(
        TextSpan(
          text: raw,
          style: base.copyWith(
            color: Colors.lightBlue.shade700,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final uri = Uri.tryParse(href);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      i = m.end;
    }
    if (i < chunk.length) {
      out.add(TextSpan(text: chunk.substring(i)));
    }
    return out;
  }
}
