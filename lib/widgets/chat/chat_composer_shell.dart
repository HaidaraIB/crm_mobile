import 'package:flutter/material.dart';

import 'chat_text_direction.dart';

/// Shared composer chrome: banner / pending / attach / field / mic|send.
///
/// Channel screens own send rules (24h window, templates, reply dock). Pass
/// [recordingBar] to replace the input row while recording.
class ChatComposerShell extends StatelessWidget {
  const ChatComposerShell({
    super.key,
    required this.draft,
    required this.hintText,
    required this.sending,
    required this.onSend,
    required this.paletteSendBg,
    required this.paletteSendFg,
    this.enabled = true,
    this.banner,
    this.pendingAttachment,
    this.recordingBar,
    this.onAttach,
    this.showMic = false,
    this.onMic,
    this.voiceRecording = false,
    this.standaloneMic = false,
    this.inputFill,
    this.composerBg,
    this.maxLines = 5,
    this.minLines = 1,
  });

  final TextEditingController draft;
  final String hintText;
  final bool sending;
  final VoidCallback onSend;
  final Color paletteSendBg;
  final Color paletteSendFg;
  final bool enabled;
  final Widget? banner;
  final Widget? pendingAttachment;
  final Widget? recordingBar;
  final VoidCallback? onAttach;
  final bool showMic;
  final VoidCallback? onMic;
  final bool voiceRecording;

  /// When true, mic sits beside the field and send stays (Team Chat).
  /// When false and [showMic], mic replaces send (WhatsApp / Inbox empty draft).
  final bool standaloneMic;
  final Color? inputFill;
  final Color? composerBg;
  final int maxLines;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = inputFill ??
        scheme.surfaceContainerHighest.withValues(alpha: 0.88);
    final bg = composerBg ?? scheme.surface;
    final docked = banner != null || pendingAttachment != null;

    return Material(
      color: bg,
      elevation: docked ? 4 : 0,
      shadowColor: Colors.black38,
      surfaceTintColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (banner != null) banner!,
          if (banner != null)
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          if (pendingAttachment != null) pendingAttachment!,
          if (pendingAttachment != null)
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                4,
                pendingAttachment != null ? 6 : 8,
                8,
                8,
              ),
              child: recordingBar != null
                  ? recordingBar!
                  : Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (onAttach != null)
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: scheme.primary,
                                  size: 26,
                                ),
                                onPressed:
                                    enabled && !sending ? onAttach : null,
                              ),
                            ),
                          if (standaloneMic && onMic != null)
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                alignment: Alignment.center,
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                icon: Icon(
                                  voiceRecording
                                      ? Icons.stop_circle_rounded
                                      : Icons.mic_none_rounded,
                                  color: voiceRecording
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                onPressed: enabled ? onMic : null,
                              ),
                            ),
                          Expanded(
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: draft,
                              builder: (context, value, _) => TextField(
                                controller: draft,
                                enabled: enabled && !sending,
                                minLines: minLines,
                                maxLines: maxLines,
                                textDirection: composerTextDirection(
                                  value.text,
                                  arabicUi: Directionality.of(context) ==
                                      TextDirection.rtl,
                                ),
                                textAlign: TextAlign.start,
                                textAlignVertical: TextAlignVertical.center,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                  hintText: hintText,
                                  filled: true,
                                  fillColor: fill,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
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
                                    borderSide: BorderSide(
                                      color: scheme.primary
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: !standaloneMic && showMic && onMic != null
                                ? IconButton.filled(
                                    style: IconButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: paletteSendBg,
                                      foregroundColor: paletteSendFg,
                                      disabledBackgroundColor:
                                          scheme.surfaceContainerHigh,
                                    ),
                                    onPressed:
                                        enabled && !sending ? onMic : null,
                                    icon: Icon(
                                      voiceRecording
                                          ? Icons.stop_circle_rounded
                                          : Icons.mic_none_rounded,
                                      size: 22,
                                    ),
                                  )
                                : IconButton.filled(
                                    style: IconButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: paletteSendBg,
                                      foregroundColor: paletteSendFg,
                                      disabledBackgroundColor:
                                          scheme.surfaceContainerHigh,
                                    ),
                                    onPressed:
                                        enabled && !sending ? onSend : null,
                                    icon: sending
                                        ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: paletteSendFg,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_rounded,
                                            size: 20,
                                          ),
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
