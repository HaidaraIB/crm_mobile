import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/chat/chat_attach_sheet.dart';
import '../../widgets/chat/chat_composer_shell.dart';
import '../../widgets/chat/chat_pending_attachment_chip.dart';

/// Team Chat composer — thin wrapper over [ChatComposerShell].
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
  final Widget? replyBanner;

  Future<void> _openAttach(BuildContext context) async {
    String t(String key) {
      if (key == 'teamChatMediaPhoto') return attachPhotoLabel;
      if (key == 'teamChatMediaDocument' || key == 'teamChatAttach') {
        return attachFileLabel;
      }
      return key;
    }

    final action = await showChatAttachSheet(
      context,
      capabilities: const ChatAttachCapabilities(photo: true, file: true),
      t: t,
    );
    if (action == ChatAttachAction.photo) onPickImage();
    if (action == ChatAttachAction.file) onPickFile();
  }

  @override
  Widget build(BuildContext context) {
    return ChatComposerShell(
      draft: draft,
      hintText: hintText,
      sending: sending,
      onSend: onSend,
      paletteSendBg: AppTheme.primaryColor,
      paletteSendFg: Colors.white,
      banner: replyBanner,
      pendingAttachment: (compressing || hasAttach)
          ? ChatPendingAttachmentChip(
              label: attachFileName,
              compressing: compressing,
              compressLabel: compressLabel,
              onClear: onClearAttach,
            )
          : null,
      onAttach: () => _openAttach(context),
      standaloneMic: true,
      onMic: onVoice,
      voiceRecording: voiceRecording,
    );
  }
}
