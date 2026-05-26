import 'package:flutter/material.dart';

class MessageHighlightWrapper extends StatelessWidget {
  const MessageHighlightWrapper({
    super.key,
    required this.highlighted,
    required this.child,
  });

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      color: highlighted ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
      child: child,
    );
  }
}

