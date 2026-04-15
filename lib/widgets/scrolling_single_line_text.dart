import 'package:flutter/material.dart';

/// Gap between repeated copies (seamless loop).
const double _kMarqueeGap = 28.0;

/// Single-line label. If the text is wider than the space, it scrolls horizontally
/// in a continuous loop (one direction, seamless) so the full name is readable.
class ScrollingSingleLineText extends StatelessWidget {
  const ScrollingSingleLineText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDir = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          textDirection: textDir,
          maxLines: 1,
          textScaler: textScaler,
        )..layout();
        final textWidth = tp.width;
        final fits = textWidth <= constraints.maxWidth || text.isEmpty;

        if (fits) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: effectiveStyle,
          );
        }

        return _HorizontalMarquee(
          key: ValueKey<String>('${text}_${constraints.maxWidth.floor()}'),
          text: text,
          style: effectiveStyle,
          textWidth: textWidth,
          viewportWidth: constraints.maxWidth,
          textHeight: tp.height,
        );
      },
    );
  }
}

class _HorizontalMarquee extends StatefulWidget {
  const _HorizontalMarquee({
    super.key,
    required this.text,
    required this.style,
    required this.textWidth,
    required this.viewportWidth,
    required this.textHeight,
  });

  final String text;
  final TextStyle style;
  final double textWidth;
  final double viewportWidth;
  final double textHeight;

  @override
  State<_HorizontalMarquee> createState() => _HorizontalMarqueeState();
}

class _HorizontalMarqueeState extends State<_HorizontalMarquee> {
  final ScrollController _controller = ScrollController();
  int _runId = 0;

  /// One full cycle scroll distance: first copy + gap (then we jump to 0; second copy lines up).
  double get _loopDistance => widget.textWidth + _kMarqueeGap;

  @override
  void dispose() {
    _runId++;
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoop());
  }

  Future<void> _startLoop() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (!_controller.hasClients) return;
    if (_controller.position.maxScrollExtent <= 0) {
      await Future<void>.delayed(const Duration(milliseconds: 48));
      if (!mounted) return;
      if (!_controller.hasClients) return;
      if (_controller.position.maxScrollExtent <= 0) return;
    }

    final myRun = _runId;

    while (mounted && _controller.hasClients && myRun == _runId) {
      final maxScroll = _controller.position.maxScrollExtent;
      final target = _loopDistance.clamp(0.0, maxScroll);
      if (target <= 0) break;

      final durationMs = (target * 28).round().clamp(2200, 16000);
      final duration = Duration(milliseconds: durationMs);

      try {
        await _controller.animateTo(
          target,
          duration: duration,
          curve: Curves.linear,
        );
        if (!mounted || myRun != _runId) return;
        _controller.jumpTo(0);
      } catch (_) {
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDir = Directionality.of(context);

    return SizedBox(
      height: widget.textHeight,
      width: widget.viewportWidth,
      child: ClipRect(
        child: Semantics(
          label: widget.text,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    style: widget.style,
                    textDirection: textDir,
                  ),
                ),
                SizedBox(width: _kMarqueeGap),
                ExcludeSemantics(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    style: widget.style,
                    textDirection: textDir,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
