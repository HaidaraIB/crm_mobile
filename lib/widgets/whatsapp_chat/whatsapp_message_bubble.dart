import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_localizations.dart';
import '../../models/lead_whatsapp_message_model.dart';
import '../../screens/team_chat/team_chat_media.dart';
import '../../services/api_service.dart';
import '../../utils/whatsapp_formatted_text.dart';
import '../../utils/whatsapp_message_body_localize.dart';
import 'whatsapp_chat_theme.dart';
import 'whatsapp_phone_text.dart';
import 'whatsapp_status_widgets.dart';

class WhatsAppMessageBubble extends StatelessWidget {
  const WhatsAppMessageBubble({
    super.key,
    required this.message,
    this.connectedPhoneNumberId,
    this.onResend,
    this.onDelete,
  });

  final LeadWhatsAppMessageModel message;
  final String? connectedPhoneNumberId;
  final VoidCallback? onResend;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    final colors = WhatsAppChatColors.of(context);
    final isInbound = message.isInbound;
    final failed = message.isFailed;
    final isOut = !isInbound;

    final Color bubbleColor;
    final Color fg;
    if (failed && isOut) {
      bubbleColor = colors.bubbleOutFailed;
      fg = colors.bubbleOutFailedFg;
    } else if (isInbound) {
      bubbleColor = colors.bubbleIn;
      fg = colors.bubbleInFg;
    } else {
      bubbleColor = colors.bubbleOut;
      fg = colors.bubbleOutFg;
    }

    final align = isInbound ? Alignment.centerLeft : Alignment.centerRight;
    final viaPrevious = colorsConnectedViaPrevious(colors);
    final time = withLatinDigits(
      DateFormat('h:mm a', 'en_US').format(message.createdAt.toLocal()),
    );
    final sender = (isOut && (message.createdByUsername?.isNotEmpty ?? false))
        ? message.createdByUsername!
        : null;
    final metaColor = isOut ? colors.metaOut : colors.metaIn;
    final metaStyle = TextStyle(
      fontSize: 10,
      height: 1.1,
      color: metaColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Align(
      alignment: align,
      child: Opacity(
        opacity: message.isSending ? 0.75 : 1,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: isInbound
                ? Border.all(color: colors.bubbleInBorder)
                : (failed ? Border.all(color: Colors.red.shade300) : null),
            boxShadow: isInbound
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: colors.isDark ? 0.25 : 0.06),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg, fontSize: 14, height: 1.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (viaPrevious)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOut
                              ? Colors.white.withValues(alpha: 0.15)
                              : colors.viaPreviousBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          t('whatsappViaPreviousNumber'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isOut ? Colors.white.withValues(alpha: 0.85) : colors.viaPreviousFg,
                          ),
                        ),
                      ),
                    ),
                  ),
                _buildContent(context, t, fg),
                if (failed && (message.deliveryError?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      message.deliveryError!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isOut ? Colors.white.withValues(alpha: 0.9) : Colors.red.shade300,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: resolveBubbleTextDirection('A'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (sender != null) ...[
                        Flexible(
                          child: Text(
                            sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(time, style: metaStyle),
                      if (isOut) ...[
                        const SizedBox(width: 4),
                        WhatsAppDeliveryTicks(
                          status: message.deliveryStatus,
                          failed: failed,
                          readColor: colors.tickRead,
                          mutedColor: colors.tickMuted,
                          onOutbound: true,
                        ),
                      ],
                    ],
                  ),
                ),
                if (failed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: onResend,
                        style: TextButton.styleFrom(
                          foregroundColor: isOut ? Colors.white : null,
                        ),
                        child: Text(t('resend')),
                      ),
                      TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: isOut ? Colors.white : null,
                        ),
                        child: Text(t('delete')),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool colorsConnectedViaPrevious(WhatsAppChatColors colors) {
    return connectedPhoneNumberId != null &&
        (message.phoneNumberId?.isNotEmpty ?? false) &&
        message.phoneNumberId != connectedPhoneNumberId;
  }

  Widget _buildContent(BuildContext context, String Function(String) t, Color fg) {
    if (message.isLocation) {
      final lat = message.locationLatitude;
      final lng = message.locationLongitude;
      final label = message.locationName?.isNotEmpty == true
          ? message.locationName!
          : (message.locationAddress?.isNotEmpty == true
              ? message.locationAddress!
              : '${lat ?? ''}, ${lng ?? ''}');
      final dir = resolveBubbleTextDirection(label);
      return InkWell(
        onTap: lat != null && lng != null
            ? () {
                final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                );
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 18, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Directionality(
                textDirection: dir,
                child: Text(label, style: TextStyle(color: fg)),
              ),
            ),
          ],
        ),
      );
    }

    if (message.hasAttachment && message.id > 0) {
      final url = (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty)
          ? message.attachmentUrl!
          : ApiService().whatsappMessageAttachmentUrl(message.id);
      final kind = message.attachmentKind;
      if (kind == 'image') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TenantChatMemoryImage(
              url: url,
              attachmentWidth: message.attachmentWidth,
              attachmentHeight: message.attachmentHeight,
              suggestedFilename: message.originalFilename,
            ),
            if (message.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              WhatsAppFormattedText(
                localizeWhatsAppMessageBody(message.body, t),
                style: TextStyle(color: fg, fontSize: 14),
              ),
            ],
          ],
        );
      }
      if (kind == 'video') {
        return TenantChatMemoryVideo(
          url: url,
          attachmentWidth: message.attachmentWidth,
          attachmentHeight: message.attachmentHeight,
        );
      }
      if (kind == 'audio') {
        return TenantChatInlineAudio(
          url: url,
          originalFilename: message.originalFilename,
          mine: !message.isInbound,
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 18, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              message.originalFilename?.isNotEmpty == true
                  ? message.originalFilename!
                  : localizeWhatsAppMessageBody(message.body, t),
              style: TextStyle(color: fg),
            ),
          ),
        ],
      );
    }

    if (message.hasAttachment) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(message.attachmentKind), size: 18, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              message.originalFilename ?? localizeWhatsAppMessageBody(message.body, t),
              style: TextStyle(color: fg),
            ),
          ),
        ],
      );
    }

    final body = localizeWhatsAppMessageBody(message.body, t);
    if (body.isEmpty) return const SizedBox.shrink();
    return WhatsAppFormattedText(
      body,
      style: TextStyle(color: fg, fontSize: 14, height: 1.35),
    );
  }

  IconData _iconFor(String? kind) {
    switch (kind) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'audio':
        return Icons.mic_outlined;
      case 'document':
        return Icons.description_outlined;
      default:
        return Icons.attach_file;
    }
  }
}
