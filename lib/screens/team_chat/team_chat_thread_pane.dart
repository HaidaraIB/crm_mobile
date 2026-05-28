import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../chat_engine/cubit/chat_thread_cubit.dart';
import '../../chat_engine/cubit/chat_thread_state.dart';
import '../../chat_engine/highlight/message_highlight_controller.dart';
import '../../chat_engine/models/chat_list_row.dart';
import '../../chat_engine/navigation/chat_navigation_source.dart';
import '../../chat_engine/scroll/chat_scroll_service.dart';
import '../../chat_engine/ui/chat_message_list_view.dart';
import '../../chat_engine/ui/chat_scroll_fab.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/team_chat/team_chat_coordinator_factory.dart';
import '../../features/team_chat/tenant_chat_message_adapter.dart';
import '../../models/tenant_chat_models.dart';
import '../../services/api_service.dart';
import 'team_chat_message_bubble.dart';

/// Message list + scroll/pagination for one conversation. Uses [ChatThreadCubit] + indexed list.
class TeamChatThreadPane extends StatefulWidget {
  const TeamChatThreadPane({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.isCompanyGroup,
    required this.readCursor,
    required this.serverUnreadCount,
    required this.onReadCursorAdvanced,
    required this.onReply,
    required this.onForward,
    required this.onPin,
    required this.onJumpToPinned,
    this.lang = 'en',
  });

  final int conversationId;
  final int currentUserId;
  final bool isCompanyGroup;
  final int readCursor;
  final int serverUnreadCount;
  final ValueChanged<int> onReadCursorAdvanced;
  final void Function(TenantChatMessage message) onReply;
  final void Function(TenantChatMessage message) onForward;
  final void Function(TenantChatMessage message) onPin;
  final void Function(int messageId) onJumpToPinned;
  final String lang;

  @override
  TeamChatThreadPaneState createState() => TeamChatThreadPaneState();
}

class TeamChatThreadPaneState extends State<TeamChatThreadPane> {
  TeamChatEngineBundle? _engine;
  Timer? _markReadDebounce;
  Timer? _positionsDebounce;
  int _pendingMarkReadId = 0;
  int _localReadCursor = 0;
  bool _loadingOlderInFlight = false;
  final ValueNotifier<bool> _tailScrollSettled = ValueNotifier(false);
  final ValueNotifier<bool> _olderSpinner = ValueNotifier(false);
  /// Hides the list while prepending older rows so SPL's index shift isn't visible.
  final ValueNotifier<bool> _prependMask = ValueNotifier(false);

  ChatThreadCubit<TenantEngineMessage> get _cubit => _engine!.threadCubit;
  ChatScrollService get _scroll => _engine!.scrollService;
  MessageHighlightController get _highlight => _engine!.highlightController;

  String _t(String key) =>
      AppLocalizations.of(context)?.translate(key) ?? key;

  @override
  void initState() {
    super.initState();
    _localReadCursor = widget.readCursor;
    _initEngine();
  }

  @override
  void didUpdateWidget(TeamChatThreadPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _disposeEngine();
      _localReadCursor = widget.readCursor;
      _initEngine();
    } else if (oldWidget.readCursor != widget.readCursor &&
        widget.readCursor > _localReadCursor) {
      _localReadCursor = widget.readCursor;
    }
  }

  void _initEngine() {
    _tailScrollSettled.value = false;
    _engine = TeamChatCoordinatorFactory.create(
      api: ApiService(),
      conversationId: widget.conversationId,
      currentUserId: widget.currentUserId,
      readCursor: _localReadCursor,
    );
    _engine!.itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);
    unawaited(_cubit.loadInitial().then((_) async {
      if (!mounted) return;
      _scroll.stickToTail = true;
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      await _scroll.scrollToBottom(animated: false);
      if (!mounted) return;
      _markTailScrollSettled();
    }));
    _cubit.startPolling();
  }

  void _markTailScrollSettled() {
    if (_tailScrollSettled.value) return;
    void trySettle() {
      if (!mounted) return;
      final count = _cubit.state.rows.length;
      if (_scroll.metricsFor(count).atBottom || _scroll.stickToTail) {
        _tailScrollSettled.value = true;
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tailScrollSettled.value) return;
        _tailScrollSettled.value = true;
      });
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => trySettle());
  }

  void _disposeEngine() {
    _engine?.threadCubit.stopPolling();
    _markReadDebounce?.cancel();
    _positionsDebounce?.cancel();
    _tailScrollSettled.dispose();
    _olderSpinner.dispose();
    _prependMask.dispose();
    _engine?.itemPositionsListener.itemPositions.removeListener(_onItemPositionsChanged);
    _engine?.dispose();
    _engine = null;
  }

  @override
  void dispose() {
    _disposeEngine();
    super.dispose();
  }

  Future<void> onMessageSent() async {
    await _cubit.pollNewer();
    if (!mounted) return;
    await _scrollToTailAfterNewRows();
  }

  /// Same tail alignment as [onMessageSent] — used when poll appends messages at the bottom.
  Future<void> _scrollToTailAfterNewRows() async {
    _scroll.stickToTail = true;
    if (!mounted || _engine == null) return;
    final count = _cubit.state.rows.length;
    _scroll.updateItemCount(count);
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted || _engine == null) return;
    await _scroll.scrollToBottom(animated: false);
  }

  bool _shouldFollowIncomingTail(int itemCount) {
    if (_scroll.stickToTail) return true;
    final metrics = _scroll.metricsFor(itemCount);
    return metrics.atBottom || metrics.nearBottom;
  }

  Future<void> scrollToBottom({bool animated = true}) {
    return _scroll.scrollToBottom(animated: animated);
  }

  Future<void> jumpToMessage(int messageId) {
    return _engine!.coordinator.navigateToMessage(
      messageId,
      source: NavigationSource.reply,
    );
  }

  Future<void> _onScrollFabTap() async {
    if (_engine == null) return;
    await _scroll.scrollToBottom(animated: true);
    if (!mounted || _engine == null) return;
    final lastId = _lastMessageId(_cubit.state);
    if (lastId != null && lastId > _localReadCursor) {
      _pendingMarkReadId = lastId;
      _markReadDebounce?.cancel();
      _markReadDebounce = Timer(const Duration(milliseconds: 80), () async {
        final pid = _pendingMarkReadId;
        _pendingMarkReadId = 0;
        if (pid <= _localReadCursor) return;
        final newCursor =
            await ApiService().markTenantChatRead(widget.conversationId, pid);
        if (!mounted) return;
        if (newCursor != null && newCursor > _localReadCursor) {
          _localReadCursor = newCursor;
        } else if (pid > _localReadCursor) {
          _localReadCursor = pid;
        }
        widget.onReadCursorAdvanced(_localReadCursor);
      });
    }
  }

  int _fabUnreadBadge(ChatThreadState state) {
    final below = _peerBelowCount(state);
    if (below > 0) return below;
    return widget.serverUnreadCount;
  }

  void _onPollNewerRows() {
    if (!mounted || _engine == null || _loadingOlderInFlight) return;
    final count = _cubit.state.rows.length;
    _scroll.updateItemCount(count);
    if (!_shouldFollowIncomingTail(count)) return;
    unawaited(_scrollToTailAfterNewRows());
  }

  void _onItemPositionsChanged() {
    _positionsDebounce?.cancel();
    _positionsDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || _engine == null) return;
      final state = _cubit.state;
      final count = state.rows.length;
      _scroll.updateItemCount(count);

      if (!_loadingOlderInFlight && state.hasOlder && count > 0) {
        final positions = _engine!.itemPositionsListener.itemPositions.value;
        if (positions.isNotEmpty) {
          final minIndex =
              positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
          if (minIndex <= 2) {
            unawaited(_loadOlderWithAnchor());
          }
        }
      }
      _scheduleMarkRead(state);
    });
  }

  Future<void> _loadOlderWithAnchor() async {
    if (_loadingOlderInFlight || _engine == null) return;
    _loadingOlderInFlight = true;
    _olderSpinner.value = true;
    _prependMask.value = true;
    await SchedulerBinding.instance.endOfFrame;

    final rowsBefore = _cubit.state.rows;
    final anchor = _scroll.snapshotTopAnchor(rowsBefore);
    try {
      final loaded = await _cubit.loadOlder();
      if (!mounted || _engine == null) return;

      final rowsAfter = _cubit.state.rows;
      _scroll.updateItemCount(rowsAfter.length);
      if (loaded && anchor != null && rowsAfter.length > rowsBefore.length) {
        final delta = rowsAfter.length - rowsBefore.length;
        await _scroll.restoreTopAnchorAfterPrepend(
          anchor,
          rowsAfter,
          rowCountDelta: delta,
        );
      }
    } finally {
      if (mounted) {
        _prependMask.value = false;
        _loadingOlderInFlight = false;
        _olderSpinner.value = false;
      }
    }
  }

  bool _sameSenderAsPrevious(List<ChatListRow> rows, int index) {
    if (index <= 0) return false;
    final row = rows[index];
    final prev = rows[index - 1];
    if (row is! ChatMessageRow || prev is! ChatMessageRow) return false;
    return prev.message.senderId == row.message.senderId;
  }

  void _scheduleMarkRead(ChatThreadState state) {
    final metrics = _scroll.metricsFor(state.rows.length);
    int markTarget = 0;
    if (metrics.atBottom) {
      final lastMsg = _lastMessageId(state);
      if (lastMsg != null) markTarget = lastMsg;
    } else {
      markTarget = _maxVisibleMessageId(state);
    }
    if (markTarget <= _localReadCursor) return;
    _pendingMarkReadId =
        _pendingMarkReadId > markTarget ? _pendingMarkReadId : markTarget;
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 160), () async {
      final pid = _pendingMarkReadId;
      _pendingMarkReadId = 0;
      if (pid <= _localReadCursor) return;
      final api = ApiService();
      final newCursor =
          await api.markTenantChatRead(widget.conversationId, pid);
      if (!mounted) return;
      if (newCursor != null && newCursor > _localReadCursor) {
        _localReadCursor = newCursor;
      } else if (pid > _localReadCursor) {
        _localReadCursor = pid;
      }
      widget.onReadCursorAdvanced(_localReadCursor);
    });
  }

  int? _tailMessageId(List<ChatListRow> rows) {
    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      if (row is ChatMessageRow) return row.message.id;
    }
    return null;
  }

  int? _lastMessageId(ChatThreadState state) => _tailMessageId(state.rows);

  int _maxVisibleMessageId(ChatThreadState state) {
    final positions = _engine!.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return _localReadCursor;
    var maxId = _localReadCursor;
    for (final p in positions) {
      if (p.index < 0 || p.index >= state.rows.length) continue;
      final row = state.rows[p.index];
      if (row is ChatMessageRow && row.message.id > maxId) {
        maxId = row.message.id;
      }
    }
    return maxId;
  }

  int _peerBelowCount(ChatThreadState state) {
    final positions = _engine!.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return 0;
    final maxVisible = positions
        .where((p) => p.itemLeadingEdge < 1.0)
        .map((p) => p.index)
        .fold<int>(0, (a, b) => a > b ? a : b);
    var n = 0;
    for (var i = maxVisible + 1; i < state.rows.length; i++) {
      final row = state.rows[i];
      if (row is! ChatMessageRow) continue;
      final m = row.message;
      if (m.senderId == widget.currentUserId) continue;
      if (m.id <= _localReadCursor) continue;
      n++;
    }
    return n;
  }

  String _daySep(DateTime dayStart, String lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dayStart == today) return _t('teamChatDayToday');
    final yesterday = today.subtract(const Duration(days: 1));
    if (dayStart == yesterday) return _t('teamChatDayYesterday');
    return DateFormat.yMMMd(lang).format(dayStart);
  }

  @override
  Widget build(BuildContext context) {
    if (_engine == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    return BlocProvider<ChatThreadCubit<TenantEngineMessage>>.value(
      value: _cubit,
      child: BlocListener<ChatThreadCubit<TenantEngineMessage>, ChatThreadState>(
        listenWhen: (prev, next) =>
            !next.loading &&
            prev.rows.isNotEmpty &&
            _tailMessageId(prev.rows) != _tailMessageId(next.rows),
        listener: (_, __) => _onPollNewerRows(),
        child: BlocBuilder<ChatThreadCubit<TenantEngineMessage>, ChatThreadState>(
        buildWhen: (prev, next) =>
            prev.loading != next.loading ||
            prev.rows != next.rows ||
            prev.error != next.error ||
            prev.version != next.version,
        builder: (context, state) {
          _scroll.updateItemCount(state.rows.length);
          if (state.loading && state.rows.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.rows.isEmpty) {
            return Center(child: Text(state.error!));
          }

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomRight,
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: scheme.surfaceContainerLowest,
                  child: ValueListenableBuilder<int?>(
                    valueListenable: _highlight.highlightedMessageId,
                    builder: (context, highlightedId, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _prependMask,
                        builder: (context, maskList, _) {
                          return Opacity(
                            opacity: maskList ? 0 : 1,
                            child: ChatMessageListView(
                        rows: state.rows,
                        itemScrollController: _engine!.itemScrollController,
                        itemPositionsListener: _engine!.itemPositionsListener,
                        highlightedMessageId: highlightedId,
                        onScrollNotification: (n) => _scroll.handleScrollNotification(
                          n,
                          state.rows.length,
                        ),
                        messageBuilder: (ctx, row, index) {
                          final eng = row.message as TenantEngineMessage;
                          final m = eng.raw;
                          return TeamChatMessageBubble(
                            message: m,
                            mine: m.sender.id == widget.currentUserId,
                            lang: widget.lang,
                            sameSenderAsPrevious:
                                _sameSenderAsPrevious(state.rows, index),
                            isCompanyGroup: widget.isCompanyGroup,
                            tr: _t,
                            onReply: () => widget.onReply(m),
                            onForward: () => widget.onForward(m),
                            onPin: () => widget.onPin(m),
                            onJump: (id) =>
                                _engine!.coordinator.navigateToMessage(
                              id,
                              source: NavigationSource.reply,
                            ),
                            labelCouldNotLoad: _t('teamChatCouldNotLoad'),
                            labelReply: _t('teamChatReply'),
                            labelForward: _t('teamChatForward'),
                            labelPin: _t('teamChatPin'),
                            labelForwarded: _t('teamChatForwarded'),
                            labelJumpFwd: _t('teamChatJumpToForwardedMessage'),
                            labelJumpQ: _t('teamChatJumpToQuotedMessage'),
                            labelRead: _t('teamChatRead'),
                            labelDelivered: _t('teamChatDelivered'),
                          );
                        },
                        daySeparatorBuilder: (ctx, row) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _daySep(row.dayStart, widget.lang),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                        unreadBuilder: (ctx) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Text(
                              _t('unread'),
                              style:
                                  Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                          ),
                        ),
                      ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _olderSpinner,
                builder: (context, showOlderSpinner, _) {
                  if (!showOlderSpinner) return const SizedBox.shrink();
                  return Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Material(
                          color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
                          elevation: 1,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _t('loading'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _tailScrollSettled,
                builder: (context, settled, _) {
                  return ValueListenableBuilder<Iterable<ItemPosition>>(
                    valueListenable: _engine!.itemPositionsListener.itemPositions,
                    builder: (context, __, ___) {
                      final metrics = _scroll.metricsFor(state.rows.length);
                      if (!settled && _scroll.stickToTail) {
                        return const SizedBox.shrink();
                      }
                      if (metrics.atBottom) return const SizedBox.shrink();
                      return Positioned(
                        right: 12,
                        bottom: 12,
                        child: ChatScrollFab(
                          unreadCount: _fabUnreadBadge(state),
                          onTap: () => unawaited(_onScrollFabTap()),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}
