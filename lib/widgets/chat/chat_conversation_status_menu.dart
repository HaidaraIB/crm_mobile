import 'package:flutter/material.dart';

/// Status colors shared with web `utils/whatsappConversationStatus.ts`.
abstract final class ChatConversationStatusColors {
  static const Map<String, Color> values = {
    'open': Color(0xFF22C55E),
    'pending': Color(0xFFF59E0B),
    'spam': Color(0xFFEF4444),
    'invalid': Color(0xFFA855F7),
    'done': Color(0xFF64748B),
    'snoozed': Color(0xFF0EA5E9),
    'unread': Color(0xFF3B82F6),
    'unsubscribed': Color(0xFF94A3B8),
    'all': Color(0xFF6366F1),
  };

  static Color of(String status) =>
      values[status] ?? const Color(0xFF94A3B8);
}

class ChatConversationStatusChange {
  const ChatConversationStatusChange({
    this.status,
    this.snoozedUntil,
    this.isStarred,
    this.isUnsubscribed,
  });

  final String? status;
  final String? snoozedUntil;
  final bool? isStarred;
  final bool? isUnsubscribed;
}

/// Header status control shared by WhatsApp and Inbox — matches web
/// `ChatConversationStatusMenu` (colored dots, snooze presets, star, unsubscribe).
class ChatConversationStatusMenu extends StatefulWidget {
  const ChatConversationStatusMenu({
    super.key,
    required this.t,
    required this.status,
    required this.onChange,
    this.isStarred = false,
    this.isUnsubscribed = false,
    this.onPrimaryBackground = true,
  });

  final String Function(String key) t;
  final String status;
  final bool isStarred;
  final bool isUnsubscribed;
  final ValueChanged<ChatConversationStatusChange> onChange;

  /// When true (default), the trigger chip is styled for a purple/colored AppBar.
  final bool onPrimaryBackground;

  static const statusOptions = ['open', 'pending', 'spam', 'invalid', 'done'];

  @override
  State<ChatConversationStatusMenu> createState() =>
      _ChatConversationStatusMenuState();
}

class _ChatConversationStatusMenuState extends State<ChatConversationStatusMenu> {
  final MenuController _controller = MenuController();

  String get _statusKey {
    final s = widget.status.trim().isEmpty ? 'open' : widget.status.trim();
    return s.toLowerCase();
  }

  void _close() {
    if (_controller.isOpen) _controller.close();
  }

  Future<void> _pickCustomSnooze() async {
    _close();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    widget.onChange(
      ChatConversationStatusChange(
        status: 'snoozed',
        snoozedUntil: dt.toUtc().toIso8601String(),
      ),
    );
  }

  void _snoozeHours(int hours) {
    _close();
    widget.onChange(
      ChatConversationStatusChange(
        status: 'snoozed',
        snoozedUntil:
            DateTime.now().add(Duration(hours: hours)).toUtc().toIso8601String(),
      ),
    );
  }

  void _snoozeTomorrowNine() {
    _close();
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day + 1, 9);
    widget.onChange(
      ChatConversationStatusChange(
        status: 'snoozed',
        snoozedUntil: d.toUtc().toIso8601String(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = ChatConversationStatusColors.of(_statusKey);
    final chipFg = widget.onPrimaryBackground ? Colors.white : scheme.onSurface;
    final chipBg = widget.onPrimaryBackground
        ? Colors.white.withValues(alpha: 0.15)
        : scheme.surfaceContainerHighest;

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
      ),
      builder: (context, controller, child) {
        return Tooltip(
          message: widget.t('chatSetStatus'),
          child: Material(
            color: chipBg,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 8, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: chipFg.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        widget.t('chatStatus_$_statusKey'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: chipFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more,
                      size: 16,
                      color: chipFg.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      menuChildren: [
        for (final st in ChatConversationStatusMenu.statusOptions)
          MenuItemButton(
            leadingIcon: _StatusDot(color: ChatConversationStatusColors.of(st)),
            onPressed: () {
              _close();
              widget.onChange(ChatConversationStatusChange(status: st));
            },
            child: Text(widget.t('chatStatus_$st')),
          ),
        SubmenuButton(
          leadingIcon: Icon(
            Icons.schedule,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          menuChildren: [
            MenuItemButton(
              onPressed: () => _snoozeHours(1),
              child: Text(widget.t('chatSnooze1h')),
            ),
            MenuItemButton(
              onPressed: () => _snoozeHours(3),
              child: Text(widget.t('chatSnooze3h')),
            ),
            MenuItemButton(
              onPressed: _snoozeTomorrowNine,
              child: Text(widget.t('chatSnoozeTomorrow')),
            ),
            MenuItemButton(
              onPressed: _pickCustomSnooze,
              child: Text(widget.t('chatSnoozeCustom')),
            ),
          ],
          child: Text(widget.t('chatSnoozeUntil')),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            widget.isStarred ? Icons.star : Icons.star_outline,
            size: 16,
            color: widget.isStarred ? Colors.amber : scheme.onSurfaceVariant,
          ),
          onPressed: () {
            _close();
            widget.onChange(
              ChatConversationStatusChange(isStarred: !widget.isStarred),
            );
          },
          child: Text(
            widget.isStarred ? widget.t('chatUnstar') : widget.t('chatStar'),
          ),
        ),
        MenuItemButton(
          onPressed: () {
            _close();
            widget.onChange(
              ChatConversationStatusChange(
                isUnsubscribed: !widget.isUnsubscribed,
              ),
            );
          },
          child: Text(
            widget.isUnsubscribed
                ? widget.t('chatResubscribe')
                : widget.t('chatMarkUnsubscribed'),
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsetsDirectional.only(start: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Long-press / overflow sheet for conversation status — shared by WhatsApp and
/// Inbox list rows so both channels expose the same actions.
Future<ChatConversationStatusChange?> showChatConversationStatusSheet({
  required BuildContext context,
  required String Function(String key) t,
  required bool isStarred,
  required bool isUnsubscribed,
}) {
  return showModalBottomSheet<ChatConversationStatusChange>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final st in ChatConversationStatusMenu.statusOptions)
              ListTile(
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ChatConversationStatusColors.of(st),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(t('chatStatus_$st')),
                onTap: () => Navigator.pop(
                  ctx,
                  ChatConversationStatusChange(status: st),
                ),
              ),
            ListTile(
              leading: Icon(Icons.schedule, color: scheme.onSurfaceVariant),
              title: Text(t('chatSnooze1h')),
              onTap: () => Navigator.pop(
                ctx,
                ChatConversationStatusChange(
                  status: 'snoozed',
                  snoozedUntil: DateTime.now()
                      .add(const Duration(hours: 1))
                      .toUtc()
                      .toIso8601String(),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                isStarred ? Icons.star : Icons.star_outline,
                color: isStarred ? Colors.amber : scheme.onSurfaceVariant,
              ),
              title: Text(isStarred ? t('chatUnstar') : t('chatStar')),
              onTap: () => Navigator.pop(
                ctx,
                ChatConversationStatusChange(isStarred: !isStarred),
              ),
            ),
            ListTile(
              title: Text(
                isUnsubscribed
                    ? t('chatResubscribe')
                    : t('chatMarkUnsubscribed'),
              ),
              onTap: () => Navigator.pop(
                ctx,
                ChatConversationStatusChange(isUnsubscribed: !isUnsubscribed),
              ),
            ),
          ],
        ),
      );
    },
  );
}

