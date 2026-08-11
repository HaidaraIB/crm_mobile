import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/whatsapp_thread_items.dart';
import 'whatsapp_chat_theme.dart';

class WhatsAppStatusSeparator extends StatelessWidget {
  const WhatsAppStatusSeparator({super.key, required this.item});

  final WhatsAppThreadStatusItem item;

  @override
  Widget build(BuildContext context) {
    final colors = WhatsAppChatColors.of(context);
    final isNew = item.variant == WhatsAppThreadStatusVariant.newMessages;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: colors.composerBorder, thickness: 1),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            decoration: BoxDecoration(
              color: isNew
                  ? AppTheme.primaryColor.withValues(alpha: colors.isDark ? 0.22 : 0.12)
                  : colors.statusChipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isNew ? FontWeight.w600 : FontWeight.w500,
                color: isNew
                    ? (colors.isDark ? const Color(0xFFDDD6FE) : AppTheme.primaryColor)
                    : colors.statusChipFg,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: colors.composerBorder, thickness: 1),
          ),
        ],
      ),
    );
  }
}

class WhatsAppSessionBanner extends StatelessWidget {
  const WhatsAppSessionBanner({
    super.key,
    required this.inSession,
    this.hoursRemaining,
  });

  final bool inSession;
  final double? hoursRemaining;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = WhatsAppChatColors.of(context);
    if (!inSession) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.sessionWarnBg,
          border: Border(
            bottom: BorderSide(color: colors.sessionWarnBorder),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          loc?.translate('whatsappSessionClosedHint') ??
              'No customer message in the last 24 hours. Only approved templates can be sent.',
          style: TextStyle(fontSize: 12, color: colors.sessionWarnFg, height: 1.35),
        ),
      );
    }
    final h = hoursRemaining;
    if (h == null) return const SizedBox.shrink();
    final hoursLabel = h >= 10 ? h.round().toString() : h.toStringAsFixed(1);
    final text = (loc?.translate('whatsappSessionOpenHint') ??
            'Free-form messages are allowed for about {h} more hour(s).')
        .replaceAll('{h}', hoursLabel);
    return Container(
      width: double.infinity,
      color: colors.sessionInfoBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: colors.sessionInfoFg),
      ),
    );
  }
}

class WhatsAppDeliveryTicks extends StatelessWidget {
  const WhatsAppDeliveryTicks({
    super.key,
    required this.status,
    this.failed = false,
    this.readColor,
    this.mutedColor,
    this.onOutbound = false,
  });

  final String? status;
  final bool failed;
  final Color? readColor;
  final Color? mutedColor;
  final bool onOutbound;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Icon(
        Icons.error_outline,
        size: 14,
        color: onOutbound ? Colors.white : Colors.red.shade400,
      );
    }
    final s = (status ?? '').toLowerCase();
    final muted = mutedColor ??
        (onOutbound ? Colors.white.withValues(alpha: 0.65) : Colors.grey.shade600);
    final read = readColor ?? const Color(0xFF7DD3FC);
    if (s == 'sending' || s == 'pending') {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: muted,
        ),
      );
    }
    if (s == 'read') {
      return Icon(Icons.done_all, size: 14, color: read);
    }
    if (s == 'delivered') {
      return Icon(Icons.done_all, size: 14, color: muted);
    }
    return Icon(Icons.done, size: 14, color: muted);
  }
}
