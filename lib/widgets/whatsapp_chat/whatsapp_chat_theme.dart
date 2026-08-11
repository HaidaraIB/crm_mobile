import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// WhatsApp thread colors — parity with web `whatsappChatTheme.ts`
/// (CRM primary outbound, gray wallpaper/inbound; clear dark tokens, not muddy containers).
class WhatsAppChatColors {
  WhatsAppChatColors._(this.isDark);

  factory WhatsAppChatColors.of(BuildContext context) {
    return WhatsAppChatColors._(Theme.of(context).brightness == Brightness.dark);
  }

  final bool isDark;

  /// Web `primary-600` for #4215AA ≈ hsl(257 78% 31%).
  static const Color _primary600 = Color(0xFF37118E);

  /// Slightly brighter violet for outbound bubbles on gray-950 (readable, not muddy).
  static const Color _bubbleOutDark = Color(0xFF6D28D9);

  /// Header bar (`bg-primary` / `dark:bg-primary-600`).
  Color get headerBg => isDark ? _primary600 : AppTheme.primaryColor;

  /// Thread wallpaper (gray-100 / gray-950).
  Color get threadBackground =>
      isDark ? const Color(0xFF030712) : const Color(0xFFF3F4F6);

  /// Incoming bubble (white / gray-800).
  Color get bubbleIn => isDark ? const Color(0xFF1F2937) : Colors.white;

  Color get bubbleInBorder =>
      isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

  Color get bubbleInFg =>
      isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);

  /// Outgoing bubble — solid primary / violet-700 in dark.
  Color get bubbleOut => isDark ? _bubbleOutDark : AppTheme.primaryColor;

  Color get bubbleOutFg => Colors.white;

  Color get bubbleOutFailed => const Color(0xFFE11D48);

  Color get bubbleOutFailedFg => Colors.white;

  Color get metaIn =>
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  Color get metaOut => Colors.white.withValues(alpha: 0.78);

  Color get tickRead => const Color(0xFF7DD3FC); // sky-300

  Color get tickMuted =>
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  Color get composerBg =>
      isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);

  Color get composerBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

  Color get inputFill =>
      isDark ? const Color(0xFF1F2937) : Colors.white;

  Color get inputBorder =>
      isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

  Color get statusChipBg =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

  Color get statusChipFg =>
      isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);

  Color get sessionWarnBg =>
      isDark ? const Color(0xFF451A03).withValues(alpha: 0.55) : const Color(0xFFFFFBEB);

  Color get sessionWarnFg =>
      isDark ? const Color(0xFFFEF3C7) : const Color(0xFF78350F);

  Color get sessionWarnBorder =>
      isDark ? const Color(0xFF92400E).withValues(alpha: 0.6) : const Color(0xFFFDE68A);

  Color get sessionInfoBg =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  Color get sessionInfoFg =>
      isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);

  Color get alertErrorBg =>
      isDark ? const Color(0xFF450A0A).withValues(alpha: 0.55) : const Color(0xFFFEF2F2);

  Color get alertErrorFg =>
      isDark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);

  Color get alertErrorBorder =>
      isDark ? const Color(0xFF991B1B).withValues(alpha: 0.6) : const Color(0xFFFECACA);

  Color get viaPreviousBg =>
      isDark ? const Color(0xFF78350F).withValues(alpha: 0.45) : const Color(0xFFFEF3C7);

  Color get viaPreviousFg =>
      isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);

  Color get listBg =>
      isDark ? const Color(0xFF111827) : Colors.white;

  Color get listActiveBg =>
      AppTheme.primaryColor.withValues(alpha: isDark ? 0.20 : 0.10);
}
