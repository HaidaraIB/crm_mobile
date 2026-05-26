import 'package:flutter/material.dart';

class ChatScrollFab extends StatelessWidget {
  const ChatScrollFab({
    super.key,
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton.small(
      onPressed: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Icon(Icons.keyboard_arrow_down_rounded),
          if (unreadCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: scheme.primary,
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

