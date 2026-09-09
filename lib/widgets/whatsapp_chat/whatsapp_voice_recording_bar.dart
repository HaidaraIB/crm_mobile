import 'package:flutter/material.dart';

import '../chat/chat_voice_recording_bar.dart';
import 'whatsapp_chat_theme.dart';

/// WhatsApp-themed wrapper around [ChatVoiceRecordingBar].
class WhatsAppVoiceRecordingBar extends StatelessWidget {
  const WhatsAppVoiceRecordingBar({
    super.key,
    required this.elapsed,
    required this.paused,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onCancel,
  });

  final Duration elapsed;
  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  static String formatElapsed(Duration d) =>
      ChatVoiceRecordingBar.formatElapsed(d);

  @override
  Widget build(BuildContext context) {
    final colors = WhatsAppChatColors.of(context);
    return ChatVoiceRecordingBar(
      elapsed: elapsed,
      paused: paused,
      onPause: onPause,
      onResume: onResume,
      onStop: onStop,
      onCancel: onCancel,
      metaColor: colors.metaIn,
    );
  }
}
