import 'package:flutter/material.dart';

import '../pinned/pinned_messages_controller.dart';

class PinnedMessageBanner extends StatelessWidget {
  const PinnedMessageBanner({
    super.key,
    required this.controller,
    required this.onTap,
  });

  final PinnedMessagesController controller;
  final ValueChanged<PinnedMessageRef> onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.visible,
      builder: (context, visible, _) {
        return ValueListenableBuilder<List<PinnedMessageRef>>(
          valueListenable: controller.pinned,
          builder: (context, pins, __) {
            if (pins.isEmpty) return const SizedBox.shrink();
            final pin = pins.first;
            return AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: InkWell(
                  onTap: () => onTap(pin),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pin.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (pins.length > 1)
                          Text(
                            '+${pins.length - 1}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

