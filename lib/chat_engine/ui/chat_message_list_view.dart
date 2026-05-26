import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/chat_list_row.dart';
import 'message_highlight_wrapper.dart';

typedef ChatRowBuilder = Widget Function(
  BuildContext context,
  ChatMessageRow row,
  int index,
);

typedef ChatSeparatorBuilder = Widget Function(
  BuildContext context,
  ChatDaySeparatorRow row,
);

class ChatMessageListView extends StatelessWidget {
  const ChatMessageListView({
    super.key,
    required this.rows,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.highlightedMessageId,
    required this.messageBuilder,
    required this.daySeparatorBuilder,
    required this.unreadBuilder,
    this.onScrollNotification,
  });

  final List<ChatListRow> rows;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final int? highlightedMessageId;
  final ChatRowBuilder messageBuilder;
  final ChatSeparatorBuilder daySeparatorBuilder;
  final WidgetBuilder unreadBuilder;
  final NotificationListenerCallback<ScrollNotification>? onScrollNotification;

  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(8, 6, 8, 12);

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: onScrollNotification ?? (_) => false,
      child: ScrollablePositionedList.builder(
        key: const PageStorageKey<String>('chat_message_list'),
        itemCount: rows.length,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        padding: listPadding,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        minCacheExtent: 480,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is ChatDaySeparatorRow) {
            return daySeparatorBuilder(context, row);
          }
          if (row is ChatUnreadSeparatorRow) return unreadBuilder(context);
          final messageRow = row as ChatMessageRow;
          final message = messageRow.message;
          final highlighted = message.id == highlightedMessageId;
          return RepaintBoundary(
            child: MessageHighlightWrapper(
              highlighted: highlighted,
              child: KeyedSubtree(
                key: ValueKey('msg_${message.id}'),
                child: messageBuilder(context, messageRow, index),
              ),
            ),
          );
        },
      ),
    );
  }
}
