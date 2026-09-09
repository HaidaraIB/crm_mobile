import 'package:flutter/material.dart';

/// Pending attachment strip above the composer input.
class ChatPendingAttachmentChip extends StatelessWidget {
  const ChatPendingAttachmentChip({
    super.key,
    required this.label,
    required this.onClear,
    this.compressing = false,
    this.compressLabel,
  });

  final String label;
  final VoidCallback onClear;
  final bool compressing;
  final String? compressLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = compressing ? (compressLabel ?? label) : label;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              compressing
                  ? Icons.hourglass_top_rounded
                  : Icons.attach_file_rounded,
              size: 22,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
              ),
            ),
            if (!compressing)
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
