import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class TeamChatComposer extends StatelessWidget {
  const TeamChatComposer({
    super.key,
    required this.draft,
    required this.compressing,
    required this.hasAttach,
    required this.sending,
    required this.voiceRecording,
    required this.compressLabel,
    required this.hintText,
    required this.attachFileName,
    required this.onPickImage,
    required this.onPickFile,
    required this.onVoice,
    required this.onClearAttach,
    required this.onSend,
    required this.attachPhotoLabel,
    required this.attachFileLabel,
    this.replyBanner,
  });

  final TextEditingController draft;
  final bool compressing;
  final bool hasAttach;
  final bool sending;
  final bool voiceRecording;
  final String compressLabel;
  final String hintText;
  final String attachFileName;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onVoice;
  final VoidCallback onClearAttach;
  final VoidCallback onSend;
  final String attachPhotoLabel;
  final String attachFileLabel;
  /// Reply preview docked above the input row (same bottom sheet as composer).
  final Widget? replyBanner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.surfaceContainerHighest.withValues(alpha: 0.88);
    final docked = replyBanner != null || compressing || hasAttach;

    return Material(
      color: scheme.surface,
      elevation: docked ? 4 : 0,
      shadowColor: Colors.black38,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyBanner != null) replyBanner!,
          if (replyBanner != null)
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
          if (compressing || hasAttach) _AttachmentStrip(
            scheme: scheme,
            compressing: compressing,
            compressLabel: compressLabel,
            attachFileName: attachFileName,
            hasAttach: hasAttach,
            onClearAttach: onClearAttach,
          ),
          if (compressing || hasAttach)
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.25)),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(4, (compressing || hasAttach) ? 6 : 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.add_circle_outline_rounded, color: scheme.primary, size: 26),
                      onSelected: (v) {
                        if (v == 'img') onPickImage();
                        if (v == 'file') onPickFile();
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: 'img', child: Text(attachPhotoLabel)),
                        PopupMenuItem(value: 'file', child: Text(attachFileLabel)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                      icon: Icon(
                        voiceRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                        color: voiceRecording ? scheme.error : scheme.onSurfaceVariant,
                        size: 24,
                      ),
                      onPressed: onVoice,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: draft,
                      minLines: 1,
                      maxLines: 5,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: hintText,
                        filled: true,
                        fillColor: fill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.center,
                        minimumSize: const Size(40, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: scheme.surfaceContainerHigh,
                      ),
                      onPressed: sending ? null : onSend,
                      icon: sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({
    required this.scheme,
    required this.compressing,
    required this.compressLabel,
    required this.attachFileName,
    required this.hasAttach,
    required this.onClearAttach,
  });

  final ColorScheme scheme;
  final bool compressing;
  final String compressLabel;
  final String attachFileName;
  final bool hasAttach;
  final VoidCallback onClearAttach;

  @override
  Widget build(BuildContext context) {
    final title = compressing ? compressLabel : attachFileName;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              compressing ? Icons.hourglass_top_rounded : Icons.attach_file_rounded,
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
            if (hasAttach && !compressing)
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                onPressed: onClearAttach,
              ),
          ],
        ),
      ),
    );
  }
}
