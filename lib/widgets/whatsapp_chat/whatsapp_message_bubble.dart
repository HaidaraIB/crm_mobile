import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_localizations.dart';
import '../../models/lead_whatsapp_message_model.dart';
import '../../screens/team_chat/team_chat_media.dart';
import '../../services/api_service.dart';
import '../../utils/whatsapp_formatted_text.dart';
import '../../utils/whatsapp_message_body_localize.dart';
import '../../utils/whatsapp_meta_error_display.dart';
import '../chat/chat_bubble_shell.dart';
import '../chat/chat_palette.dart';
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
    this.onOpenAlbum,
    this.showDelete = true,
  });

  final LeadWhatsAppMessageModel message;
  final String? connectedPhoneNumberId;
  final VoidCallback? onResend;
  final VoidCallback? onDelete;
  final bool showDelete;

  /// Opens the thread's media album at this message. When null, the media
  /// widgets fall back to their single-item viewer.
  final VoidCallback? onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    // Same bubble chrome as Team Chat (shape + colors).
    final palette = TeamChatPalette.of(context);
    final colors = WhatsAppChatColors.of(context);
    final isInbound = message.isInbound;
    final failed = message.isFailed;
    final isOut = !isInbound;

    final fg = failed && isOut
        ? palette.bubbleOutFailedFg
        : isInbound
            ? palette.bubbleInFg
            : palette.bubbleOutFg;

    final viaPrevious = _viaPreviousNumber;
    final time = withLatinDigits(
      DateFormat.Hm().format(message.createdAt.toLocal()),
    );
    final sender = (isOut && (message.createdByUsername?.isNotEmpty ?? false))
        ? message.createdByUsername!
        : null;

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (sender != null) ...[
          Text(
            sender,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.72)),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          time,
          style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.72)),
        ),
        if (isOut) ...[
          const SizedBox(width: 4),
          WhatsAppDeliveryTicks(
            status: message.deliveryStatus,
            failed: failed,
            readColor: Colors.lightBlueAccent,
            mutedColor: fg.withValues(alpha: 0.78),
            onOutbound: true,
          ),
        ],
      ],
    );

    final bodyWidget = _buildBodyText(context, t, fg);
    final mediaOrSpecial = _buildMediaOrSpecial(context, t, fg);

    return ChatBubbleShell(
      isInbound: isInbound,
      palette: palette,
      failed: failed,
      sending: message.isSending,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viaPrevious)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
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
                    color: isOut
                        ? Colors.white.withValues(alpha: 0.85)
                        : colors.viaPreviousFg,
                  ),
                ),
              ),
            ),
          if (mediaOrSpecial != null) ...[
            mediaOrSpecial,
            const SizedBox(height: 4),
          ],
          ChatBubbleTextAndMeta(
            body: bodyWidget,
            meta: meta,
          ),
          if (failed && (message.deliveryError?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                localizeMetaDeliveryError(message.deliveryError, t),
                style: TextStyle(
                  fontSize: 11,
                  color: isOut
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.red.shade300,
                ),
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
                if (showDelete && onDelete != null)
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
    );
  }

  bool get _viaPreviousNumber {
    return connectedPhoneNumberId != null &&
        (message.phoneNumberId?.isNotEmpty ?? false) &&
        message.phoneNumberId != connectedPhoneNumberId;
  }

  /// Caption / plain text that sits in the Telegram-style wrap with meta.
  Widget? _buildBodyText(
    BuildContext context,
    String Function(String) t,
    Color fg,
  ) {
    // Location / media-only with no caption: meta rides alone.
    if (message.isLocation) return null;
    if (message.hasAttachment && message.id > 0) {
      final kind = message.attachmentKind;
      if (kind == 'image' && message.body.isNotEmpty) {
        return WhatsAppFormattedText(
          localizeWhatsAppMessageBody(message.body, t),
          style: TextStyle(color: fg, height: 1.35),
        );
      }
      if (kind == 'image' || kind == 'video' || kind == 'audio') return null;
    }
    final body = localizeWhatsAppMessageBody(message.body, t);
    if (body.isEmpty) return null;
    return WhatsAppFormattedText(
      body,
      style: TextStyle(color: fg, height: 1.35),
    );
  }

  Widget? _buildMediaOrSpecial(
    BuildContext context,
    String Function(String) t,
    Color fg,
  ) {
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
        return TenantChatMemoryImage(
          url: url,
          borderRadius: 10,
          attachmentWidth: message.attachmentWidth,
          attachmentHeight: message.attachmentHeight,
          suggestedFilename: message.originalFilename,
          onOpenOverride: onOpenAlbum,
        );
      }
      if (kind == 'video') {
        return TenantChatMemoryVideo(
          url: url,
          attachmentWidth: message.attachmentWidth,
          attachmentHeight: message.attachmentHeight,
          suggestedFilename: message.originalFilename,
          onOpenOverride: onOpenAlbum,
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
              message.originalFilename ??
                  localizeWhatsAppMessageBody(message.body, t),
              style: TextStyle(color: fg),
            ),
          ),
        ],
      );
    }

    return null;
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
