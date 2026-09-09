import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../whatsapp_chat/whatsapp_chat_theme.dart';

/// Channel-agnostic colors for bubble / composer chrome.
abstract class ChatPalette {
  Color get bubbleIn;
  Color get bubbleInFg;
  Color get bubbleInBorder;
  Color get bubbleOut;
  Color get bubbleOutFg;
  Color get bubbleOutFailed;
  Color get bubbleOutFailedFg;
  Color get metaIn;
  Color get metaOut;
  Color get composerBg;
  Color get composerBorder;
  Color get inputFill;
  Color get inputBorder;
  Color get sendButtonBg;
  Color get sendButtonFg;
  Color get statusChipBg;
  Color get statusChipFg;
  Color get threadBackground;
}

/// Team chat: Material ColorScheme + CRM primary outbound.
class TeamChatPalette implements ChatPalette {
  TeamChatPalette(this.scheme);

  factory TeamChatPalette.of(BuildContext context) =>
      TeamChatPalette(Theme.of(context).colorScheme);

  final ColorScheme scheme;

  @override
  Color get bubbleIn => scheme.surfaceContainerHigh;

  @override
  Color get bubbleInFg => scheme.onSurface;

  @override
  Color get bubbleInBorder => Colors.transparent;

  @override
  Color get bubbleOut => AppTheme.primaryColor.withValues(alpha: 0.92);

  @override
  Color get bubbleOutFg => Colors.white;

  @override
  Color get bubbleOutFailed => scheme.error;

  @override
  Color get bubbleOutFailedFg => scheme.onError;

  @override
  Color get metaIn => scheme.onSurface.withValues(alpha: 0.72);

  @override
  Color get metaOut => Colors.white.withValues(alpha: 0.78);

  @override
  Color get composerBg => scheme.surface;

  @override
  Color get composerBorder => scheme.outlineVariant.withValues(alpha: 0.35);

  @override
  Color get inputFill => scheme.surfaceContainerHighest.withValues(alpha: 0.88);

  @override
  Color get inputBorder => scheme.primary.withValues(alpha: 0.35);

  @override
  Color get sendButtonBg => AppTheme.primaryColor;

  @override
  Color get sendButtonFg => Colors.white;

  @override
  Color get statusChipBg => scheme.surfaceContainerHigh.withValues(alpha: 0.92);

  @override
  Color get statusChipFg => scheme.onSurfaceVariant;

  @override
  Color get threadBackground => scheme.surfaceContainerLowest;
}

/// WhatsApp + Inbox: same bubble chrome as Team Chat; keep WA tokens for
/// composer/header/session banners only.
class WhatsAppStyleChatPalette implements ChatPalette {
  WhatsAppStyleChatPalette(this.colors, this._team);

  factory WhatsAppStyleChatPalette.of(BuildContext context) =>
      WhatsAppStyleChatPalette(
        WhatsAppChatColors.of(context),
        TeamChatPalette.of(context),
      );

  final WhatsAppChatColors colors;
  final TeamChatPalette _team;

  @override
  Color get bubbleIn => _team.bubbleIn;

  @override
  Color get bubbleInFg => _team.bubbleInFg;

  @override
  Color get bubbleInBorder => _team.bubbleInBorder;

  @override
  Color get bubbleOut => _team.bubbleOut;

  @override
  Color get bubbleOutFg => _team.bubbleOutFg;

  @override
  Color get bubbleOutFailed => _team.bubbleOutFailed;

  @override
  Color get bubbleOutFailedFg => _team.bubbleOutFailedFg;

  @override
  Color get metaIn => _team.metaIn;

  @override
  Color get metaOut => _team.metaOut;

  @override
  Color get composerBg => colors.composerBg;

  @override
  Color get composerBorder => colors.composerBorder;

  @override
  Color get inputFill => colors.inputFill;

  @override
  Color get inputBorder => colors.inputBorder;

  @override
  Color get sendButtonBg => AppTheme.primaryColor;

  @override
  Color get sendButtonFg => Colors.white;

  @override
  Color get statusChipBg => _team.statusChipBg;

  @override
  Color get statusChipFg => _team.statusChipFg;

  @override
  Color get threadBackground => _team.threadBackground;
}
