import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import 'whatsapp_chat_theme.dart';
import 'whatsapp_phone_text.dart';

/// In-composer controls while a voice note is being recorded.
///
/// Mirrors the web `ChatVoiceRecordingBar`
/// (`CRM-project/components/chat/ChatVoiceRecordingBar.tsx`): elapsed timer,
/// pause/resume, discard, and stop-and-attach.
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

  static String formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    final colors = WhatsAppChatColors.of(context);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: paused ? 0.4 : 1),
          ),
        ),
        const SizedBox(width: 8),
        // Timer digits stay LTR so 1:05 does not flip under Arabic.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            withLatinDigits(formatElapsed(elapsed)),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.red,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            paused ? t('whatsappRecordingPaused') : t('whatsappRecording'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.metaIn),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.metaIn),
          tooltip: t('whatsappCancelRecording'),
          onPressed: onCancel,
        ),
        IconButton(
          icon: Icon(
            paused ? Icons.play_arrow : Icons.pause,
            color: colors.metaIn,
          ),
          tooltip: paused
              ? t('whatsappResumeRecording')
              : t('whatsappPauseRecording'),
          onPressed: paused ? onResume : onPause,
        ),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.stop),
          tooltip: t('whatsappStopRecording'),
          onPressed: onStop,
        ),
      ],
    );
  }
}
