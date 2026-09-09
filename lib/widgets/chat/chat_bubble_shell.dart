import 'package:flutter/material.dart';

import 'chat_palette.dart';

/// Shared outbound/inbound bubble chrome. Channel content goes in [child].
///
/// Visual defaults match Team Chat (asymmetric 18/4 radii, CRM purple out,
/// surface inbound) so WhatsApp and Inbox read as the same product.
class ChatBubbleShell extends StatelessWidget {
  const ChatBubbleShell({
    super.key,
    required this.isInbound,
    required this.palette,
    required this.child,
    this.failed = false,
    this.sending = false,
    this.maxWidthFactor = 0.82,
    this.margin = const EdgeInsets.symmetric(vertical: 3),
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 6),
    this.borderRadius,
    this.onLongPress,
    this.onLongPressStart,
  });

  final bool isInbound;
  final ChatPalette palette;
  final Widget child;
  final bool failed;
  final bool sending;
  final double maxWidthFactor;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onLongPress;
  final void Function(LongPressStartDetails details)? onLongPressStart;

  /// Team-chat corner radii: soft “tail” on the outer bottom corner.
  static BorderRadius radiusFor({required bool isInbound}) {
    if (isInbound) {
      return const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomRight: Radius.circular(18),
        bottomLeft: Radius.circular(4),
      );
    }
    return const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
      bottomRight: Radius.circular(4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOut = !isInbound;
    final Color bg;
    final Color fg;
    if (failed && isOut) {
      bg = palette.bubbleOutFailed;
      fg = palette.bubbleOutFailedFg;
    } else if (isInbound) {
      bg = palette.bubbleIn;
      fg = palette.bubbleInFg;
    } else {
      bg = palette.bubbleOut;
      fg = palette.bubbleOutFg;
    }

    final radius = borderRadius ?? radiusFor(isInbound: isInbound);
    final border = isInbound && palette.bubbleInBorder.a > 0
        ? Border.all(color: palette.bubbleInBorder)
        : null;

    // Align + maxWidth only (no IntrinsicWidth): media uses LayoutBuilder/SizedBox
    // at max width, and Team headers use Flexible — both break under IntrinsicWidth
    // ("RenderBox was not laid out" up through MessageHighlightWrapper).
    return Align(
      alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Opacity(
        opacity: sending ? 0.75 : 1,
        child: Container(
          margin: margin,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * maxWidthFactor,
          ),
          child: Material(
            color: bg,
            elevation: isInbound ? 0.5 : 0,
            shadowColor: Colors.black26,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              onLongPress: onLongPress,
              onLongPressStart: onLongPressStart,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: border,
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: fg, height: 1.35),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Telegram-style body + trailing meta (time / ticks) that hug content width.
///
/// Do not wrap this in [SizedBox] width-infinity or [IntrinsicWidth]. Under the
/// shell's loose max-width, [Wrap] sizes to its runs; [WrapAlignment.end] only
/// right-packs meta when a run is shorter than the widest run (e.g. time alone
/// on the last line).
class ChatBubbleTextAndMeta extends StatelessWidget {
  const ChatBubbleTextAndMeta({
    super.key,
    required this.meta,
    this.body,
  });

  final Widget? body;
  final Widget meta;

  @override
  Widget build(BuildContext context) {
    if (body == null) return meta;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      runSpacing: 2,
      children: [body!, meta],
    );
  }
}
