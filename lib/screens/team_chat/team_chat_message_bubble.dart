import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_locales.dart';
import '../../models/tenant_chat_models.dart';
import 'team_chat_common.dart';
import 'team_chat_media.dart';

/// Horizontal swipe toward chat center triggers [onSwipeReply].
class TeamChatSwipeReplyShell extends StatefulWidget {
  const TeamChatSwipeReplyShell({
    super.key,
    required this.mine,
    required this.child,
    required this.onSwipeReply,
  });

  final bool mine;
  final Widget child;
  final VoidCallback onSwipeReply;

  @override
  State<TeamChatSwipeReplyShell> createState() => _TeamChatSwipeReplyShellState();
}

class _TeamChatSwipeReplyShellState extends State<TeamChatSwipeReplyShell> {
  double _drag = 0;

  static const double _trigger = 52;
  static const double _maxPull = 72;

  void _onDragUpdate(DragUpdateDetails d) {
    final isRtl = switch (Directionality.of(context)) {
      TextDirection.rtl => true,
      TextDirection.ltr => false,
    };
    final dx = d.delta.dx;
    final towardCenter = widget.mine ? (isRtl ? dx : -dx) : (isRtl ? -dx : dx);
    setState(() {
      _drag = (_drag + towardCenter).clamp(0.0, _maxPull);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_drag >= _trigger) {
      HapticFeedback.lightImpact();
      widget.onSwipeReply();
    }
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRtl = switch (Directionality.of(context)) {
      TextDirection.rtl => true,
      TextDirection.ltr => false,
    };
    final childDx = widget.mine ? (isRtl ? _drag : -_drag) : (isRtl ? -_drag : _drag);

    return Stack(
      clipBehavior: Clip.none,
      alignment: widget.mine ? Alignment.centerRight : Alignment.centerLeft,
      children: [
        Positioned(
          right: widget.mine ? 0 : null,
          left: widget.mine ? null : 0,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: widget.mine ? 0 : 8,
              end: widget.mine ? 8 : 0,
            ),
            child: Icon(
              Icons.reply_rounded,
              size: 22,
              color: scheme.primary.withValues(alpha: 0.35 + (_drag / _maxPull) * 0.45),
            ),
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          behavior: HitTestBehavior.translucent,
          child: Transform.translate(
            offset: Offset(childDx, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class TeamChatMessageBubble extends StatelessWidget {
  const TeamChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.lang,
    required this.sameSenderAsPrevious,
    required this.isCompanyGroup,
    required this.tr,
    required this.onReply,
    required this.onForward,
    required this.onPin,
    required this.onJump,
    required this.labelCouldNotLoad,
    required this.labelReply,
    required this.labelForward,
    required this.labelPin,
    required this.labelForwarded,
    required this.labelJumpFwd,
    required this.labelJumpQ,
    required this.labelRead,
    required this.labelDelivered,
  });

  final TenantChatMessage message;
  final bool mine;
  final String lang;
  final bool sameSenderAsPrevious;
  final bool isCompanyGroup;
  final String Function(String key) tr;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onPin;
  final void Function(int id) onJump;
  final String labelCouldNotLoad;
  final String labelReply;
  final String labelForward;
  final String labelPin;
  final String labelForwarded;
  final String labelJumpFwd;
  final String labelJumpQ;
  final String labelRead;
  final String labelDelivered;

  void _showActionMenu(BuildContext context, LongPressStartDetails details) {
    HapticFeedback.lightImpact();
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final size = overlay.size;
    final p = details.globalPosition;
    final anchor = Rect.fromCircle(center: p, radius: 1);
    final container = Offset.zero & size;
    showMenu<void>(
      context: context,
      position: RelativeRect.fromRect(anchor, container),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<void>(
          onTap: () => Future.microtask(onReply),
          child: Row(
            children: [
              Icon(Icons.reply_rounded, size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(labelReply),
            ],
          ),
        ),
        PopupMenuItem<void>(
          onTap: () => Future.microtask(onForward),
          child: Row(
            children: [
              const Icon(Icons.forward_rounded, size: 22),
              const SizedBox(width: 12),
              Text(labelForward),
            ],
          ),
        ),
        PopupMenuItem<void>(
          onTap: () => Future.microtask(onPin),
          child: Row(
            children: [
              const Icon(Icons.push_pin_outlined, size: 22),
              const SizedBox(width: 12),
              Text(labelPin),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = mine
        ? AppTheme.primaryColor.withValues(alpha: 0.92)
        : scheme.surfaceContainerHigh;
    final fg = mine ? Colors.white : scheme.onSurface;
    final timeStr = DateFormat.Hm(
      AppLocales.intlDateFormat(AppLocales.fromLanguageCode(lang)),
    ).format(DateTime.parse(message.createdAt));
    final groupHeaderRole =
        !mine && isCompanyGroup ? tenantChatPeerRoleLabel(message.sender.role, tr) : '';

    final topPad = sameSenderAsPrevious ? 2.0 : 8.0;
    final brMine = const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
      bottomRight: Radius.circular(4),
    );
    final brTheirs = const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomRight: Radius.circular(18),
      bottomLeft: Radius.circular(4),
    );

    final bubble = Material(
      color: bubbleColor,
      elevation: mine ? 0 : 0.5,
      shadowColor: Colors.black26,
      borderRadius: mine ? brMine : brTheirs,
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onLongPressStart: (d) => _showActionMenu(context, d),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && isCompanyGroup) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        tenantChatPeerName(message.sender),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    if (groupHeaderRole.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          groupHeaderRole.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.35,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (message.forwardedFrom != null) ...[
                Text(
                  labelForwarded,
                  style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.85)),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => onJump(message.forwardedFrom!.id),
                  child: Text(labelJumpFwd, style: const TextStyle(fontSize: 12)),
                ),
              ],
              if (message.replyTo != null) ...[
                Material(
                  color: Colors.black.withValues(alpha: mine ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onJump(message.replyTo!.id),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tenantChatPeerName(message.replyTo!.sender),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: fg,
                                  ),
                                ),
                              ),
                              if (isCompanyGroup) ...[
                                Builder(
                                  builder: (ctx) {
                                    final rlab = tenantChatPeerRoleLabel(
                                      message.replyTo!.sender.role,
                                      tr,
                                    );
                                    if (rlab.isEmpty) return const SizedBox.shrink();
                                    final sch = Theme.of(ctx).colorScheme;
                                    return Padding(
                                      padding: const EdgeInsetsDirectional.only(start: 6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: sch.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          rlab.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                            color: sch.primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          Text(
                            message.replyTo!.body.isNotEmpty
                                ? message.replyTo!.body
                                : (message.replyTo!.attachmentKind ?? ''),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.95)),
                          ),
                          Text(
                            labelJumpQ,
                            style: TextStyle(
                              fontSize: 10,
                              color: fg.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (message.attachmentUrl != null && message.attachmentKind != null)
                TeamChatAttachmentPreview(
                  url: message.attachmentUrl!,
                  kind: message.attachmentKind!,
                  mine: mine,
                  originalFilename: message.originalFilename,
                  attachmentWidth: message.attachmentWidth,
                  attachmentHeight: message.attachmentHeight,
                  labelCouldNotLoad: labelCouldNotLoad,
                ),
              if (message.body.trim().isNotEmpty)
                Text(
                  message.body,
                  style: TextStyle(color: fg, height: 1.35),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: fg.withValues(alpha: 0.72),
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: message.readByPeer ? labelRead : labelDelivered,
                      child: Icon(
                        message.readByPeer ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 15,
                        color: message.readByPeer
                            ? Colors.lightBlueAccent
                            : fg.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: TeamChatSwipeReplyShell(
          mine: mine,
          onSwipeReply: onReply,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
            child: bubble,
          ),
        ),
      ),
    );
  }
}

/// Renamed from private _AttachmentPreview; same behavior.
class TeamChatAttachmentPreview extends StatelessWidget {
  const TeamChatAttachmentPreview({
    super.key,
    required this.url,
    required this.kind,
    required this.mine,
    this.originalFilename,
    this.attachmentWidth,
    this.attachmentHeight,
    required this.labelCouldNotLoad,
  });

  final String url;
  final String kind;
  final bool mine;
  final String? originalFilename;
  final int? attachmentWidth;
  final int? attachmentHeight;
  final String labelCouldNotLoad;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case 'image':
        return TenantChatMemoryImage(
          url: url,
          borderRadius: 10,
          attachmentWidth: attachmentWidth,
          attachmentHeight: attachmentHeight,
          suggestedFilename: originalFilename,
        );
      case 'video':
        return TenantChatMemoryVideo(
          url: url,
          attachmentWidth: attachmentWidth,
          attachmentHeight: attachmentHeight,
          suggestedFilename: originalFilename,
        );
      case 'audio':
        return TenantChatInlineAudio(
          url: url,
          originalFilename: originalFilename,
          mine: mine,
        );
      default:
        return Text(
          originalFilename ?? 'file',
          style: const TextStyle(decoration: TextDecoration.underline),
        );
    }
  }
}
