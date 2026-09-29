import 'package:flutter/material.dart';

import '../core/utils/input_text_direction.dart';

/// List row: stays on the UI edge (next to the avatar) but punctuation in an
/// English snippet does not jump when the app is Arabic.
class IsolatedText extends StatelessWidget {
  const IsolatedText(
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

/// Block of user text: alignment follows the first strong letter.
class ContentDirText extends StatelessWidget {
  const ContentDirText(
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
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: TextAlign.start,
      textDirection: resolveBubbleTextDirection(text),
    );
  }
}
