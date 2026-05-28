import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/chat_list_row.dart';
import 'chat_anchor_preservation.dart';
import 'chat_scroll_metrics.dart';

/// Scroll control for [ScrollablePositionedList] — index-based, not [ScrollController].
class ChatScrollService {
  ChatScrollService({
    required this.itemScrollController,
    required this.itemPositionsListener,
    this.nearBottomRowThreshold = 2,
    this.atBottomTrailingEdge = 0.992,
  });

  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final int nearBottomRowThreshold;
  final double atBottomTrailingEdge;

  /// Viewport fraction kept below the last bubble when snapped to tail (~10–12px).
  static const double tailComposerGapFraction = 0.014;

  bool stickToTail = true;
  bool userDragging = false;
  bool scrollActive = false;
  Completer<void>? _activeAnimation;
  int _tailSnapGeneration = 0;

  int _itemCount = 0;
  void updateItemCount(int count) => _itemCount = count;

  int _maxVisibleIndex(Iterable<ItemPosition> positions) {
    return positions
        .where((p) => p.itemLeadingEdge < 1.0)
        .map((p) => p.index)
        .fold<int>(0, (a, b) => a > b ? a : b);
  }

  ChatScrollMetrics metricsFor(int itemCount) {
    if (itemCount == 0) {
      return const ChatScrollMetrics(
        atBottom: true,
        nearBottom: true,
        pixelsFromBottom: 0,
      );
    }
    final positions = itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) {
      return ChatScrollMetrics(
        atBottom: stickToTail,
        nearBottom: stickToTail,
        pixelsFromBottom: stickToTail ? 0 : 999,
      );
    }

    final lastIndex = itemCount - 1;
    final maxVisible = _maxVisibleIndex(positions);
    ItemPosition? lastRow;
    for (final p in positions) {
      if (p.index == lastIndex) {
        lastRow = p;
        break;
      }
    }

    if (lastRow != null) {
      final trailingAtBottom =
          lastRow.itemTrailingEdge >= atBottomTrailingEdge;
      final nearBottomByEdge =
          trailingAtBottom ||
          lastRow.itemTrailingEdge >= atBottomTrailingEdge - 0.12;
      final nearBottom = nearBottomByEdge || maxVisible >= lastIndex;
      final atBottom = trailingAtBottom ||
          maxVisible >= lastIndex ||
          (stickToTail && nearBottom);
      final gap = (1.0 - lastRow.itemTrailingEdge).clamp(0.0, 1.0);
      return ChatScrollMetrics(
        atBottom: atBottom,
        nearBottom: nearBottom,
        pixelsFromBottom: gap * 400,
      );
    }

    final remaining = itemCount - 1 - maxVisible;
    final nearBottom = remaining <= nearBottomRowThreshold;
    final atBottom = stickToTail || nearBottom;
    return ChatScrollMetrics(
      atBottom: atBottom,
      nearBottom: nearBottom,
      pixelsFromBottom: remaining.toDouble() * 48,
    );
  }

  void cancelActiveAnimations() {
    _activeAnimation?.complete();
    _activeAnimation = null;
  }

  Future<void> scrollToBottom({bool animated = true}) async {
    if (!itemScrollController.isAttached || _itemCount == 0) return;
    stickToTail = true;
    if (userDragging || scrollActive) {
      scheduleSnapTailAfterScrollEnd(_itemCount);
      return;
    }
    cancelActiveAnimations();
    final last = _itemCount - 1;
    itemScrollController.jumpTo(index: last, alignment: 0);
    await _alignLastRowBottomToViewport(animated: animated);
  }

  Future<void> _alignLastRowBottomToViewport({required bool animated}) async {
    if (!itemScrollController.isAttached || _itemCount == 0) return;
    final last = _itemCount - 1;

    Future<void> alignOnce() async {
      if (!itemScrollController.isAttached) return;
      final alignment = _tailBottomAlignmentWithGap(last);
      if (alignment == null) return;
      if (!animated) {
        itemScrollController.jumpTo(index: last, alignment: alignment);
        return;
      }
      final c = Completer<void>();
      _activeAnimation = c;
      await itemScrollController.scrollTo(
        index: last,
        alignment: alignment,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      if (_activeAnimation == c) _activeAnimation = null;
    }

    await alignOnce();
    if (!animated) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(alignOnce());
    });
  }

  double? _tailBottomAlignment(int lastIndex) {
    for (final p in itemPositionsListener.itemPositions.value) {
      if (p.index != lastIndex) continue;
      final height = p.itemTrailingEdge - p.itemLeadingEdge;
      if (height <= 0) return 0;
      return (1.0 - height).clamp(0.0, 1.0);
    }
    return null;
  }

  double? _tailBottomAlignmentWithGap(int lastIndex) {
    final base = _tailBottomAlignment(lastIndex);
    if (base == null) return null;
    return (base - tailComposerGapFraction).clamp(0.0, 1.0);
  }

  Future<void> scrollToRowIndex(int index, {double alignment = 0.18}) async {
    if (!itemScrollController.isAttached || index < 0 || index >= _itemCount) {
      return;
    }
    stickToTail = false;
    await itemScrollController.scrollTo(
      index: index,
      alignment: alignment,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeInOutCubic,
    );
  }

  static const double _anchorEdgeEpsilon = 0.02;
  static const int _maxAnchorRestorePasses = 3;

  ChatAnchorSnapshot? snapshotTopAnchor(List<ChatListRow> rows) {
    final positions = itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || rows.isEmpty) return null;
    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return null;

    for (final pos in visible) {
      if (pos.index < 0 || pos.index >= rows.length) continue;
      final row = rows[pos.index];
      if (row is! ChatMessageRow) continue;
      return ChatAnchorSnapshot(
        rowIndex: pos.index,
        messageId: row.message.id,
        itemLeadingEdge: pos.itemLeadingEdge.clamp(0.0, 1.0),
      );
    }

    for (final pos in visible) {
      if (pos.index < 0 || pos.index >= rows.length) continue;
      final row = rows[pos.index];
      final messageId = row is ChatMessageRow ? row.message.id : 0;
      return ChatAnchorSnapshot(
        rowIndex: pos.index,
        messageId: messageId,
        itemLeadingEdge: pos.itemLeadingEdge.clamp(0.0, 1.0),
      );
    }
    return null;
  }

  int? _messageRowIndex(List<ChatListRow> rows, int messageId) {
    if (messageId <= 0) return null;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is ChatMessageRow && row.message.id == messageId) {
        return i;
      }
    }
    return null;
  }

  int _resolveRestoreIndex(
    ChatAnchorSnapshot snapshot,
    List<ChatListRow> rows, {
    required int rowCountDelta,
  }) {
    final byDelta = snapshot.rowIndex + rowCountDelta;
    if (byDelta >= 0 && byDelta < rows.length) return byDelta;
    return _messageRowIndex(rows, snapshot.messageId) ?? byDelta;
  }

  void _applyTopAnchor(
    ChatAnchorSnapshot snapshot,
    List<ChatListRow> rows, {
    required int rowCountDelta,
  }) {
    if (!itemScrollController.isAttached || rows.isEmpty) return;
    final targetIndex = _resolveRestoreIndex(
      snapshot,
      rows,
      rowCountDelta: rowCountDelta,
    );
    if (targetIndex < 0 || targetIndex >= rows.length) return;
    itemScrollController.jumpTo(
      index: targetIndex,
      alignment: snapshot.itemLeadingEdge,
    );
  }

  bool _isAnchorVerified(
    ChatAnchorSnapshot snapshot,
    List<ChatListRow> rows, {
    required int rowCountDelta,
  }) {
    final targetIndex = _resolveRestoreIndex(
      snapshot,
      rows,
      rowCountDelta: rowCountDelta,
    );
    if (targetIndex < 0 || targetIndex >= rows.length) return false;

    for (final p in itemPositionsListener.itemPositions.value) {
      if (p.index != targetIndex) continue;
      final edge = p.itemLeadingEdge.clamp(0.0, 1.0);
      return (edge - snapshot.itemLeadingEdge).abs() <= _anchorEdgeEpsilon;
    }
    return false;
  }

  /// Restores viewport after older rows are prepended.
  ///
  /// Waits for layout with the new [itemCount], then applies at most two
  /// [jumpTo] calls. Does not listen to [itemPositions] — that caused a
  /// feedback loop (each jumpTo re-fired the listener = visible double jump).
  Future<void> restoreTopAnchorAfterPrepend(
    ChatAnchorSnapshot? snapshot,
    List<ChatListRow> rows, {
    required int rowCountDelta,
  }) async {
    if (snapshot == null || rows.isEmpty) return;

    for (var pass = 0; pass < _maxAnchorRestorePasses; pass++) {
      await SchedulerBinding.instance.endOfFrame;
      if (!itemScrollController.isAttached) return;

      _applyTopAnchor(snapshot, rows, rowCountDelta: rowCountDelta);

      if (_isAnchorVerified(snapshot, rows, rowCountDelta: rowCountDelta)) {
        return;
      }
    }
  }

  Future<void> restoreTopAnchorDeferred(
    ChatAnchorSnapshot? snapshot,
    List<ChatListRow> rows, {
    required int rowCountDelta,
  }) =>
      restoreTopAnchorAfterPrepend(
        snapshot,
        rows,
        rowCountDelta: rowCountDelta,
      );

  bool handleScrollNotification(ScrollNotification n, int itemCount) {
    if (n.metrics.axis != Axis.vertical) return false;
    final atBottom = metricsFor(itemCount).atBottom;

    if (n is ScrollStartNotification) {
      scrollActive = true;
      if (n.dragDetails != null) {
        userDragging = true;
        stickToTail = false;
        cancelActiveAnimations();
        _tailSnapGeneration++;
      }
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      if (!atBottom) stickToTail = false;
    } else if (n is ScrollEndNotification) {
      scrollActive = false;
      userDragging = false;
      final metrics = metricsFor(itemCount);
      stickToTail = metrics.atBottom || metrics.nearBottom;
      if (stickToTail) {
        scheduleSnapTailAfterScrollEnd(itemCount);
      }
    }
    return false;
  }

  /// Schedules tail re-align after the drag gesture fully ends.
  ///
  /// Must not call [ItemScrollController.jumpTo] from [ScrollNotification]
  /// handlers — that races the scrollable's `_drag` lifecycle and triggers
  /// `'_drag == null': is not true`.
  void scheduleSnapTailAfterScrollEnd(int itemCount) {
    final generation = ++_tailSnapGeneration;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (generation != _tailSnapGeneration) return;
      if (userDragging || scrollActive) return;
      _applySnapTail(itemCount);
    });
  }

  void _applySnapTail(int itemCount) {
    if (!itemScrollController.isAttached || itemCount == 0) return;
    final last = itemCount - 1;
    final alignment = _tailBottomAlignmentWithGap(last);
    if (alignment != null) {
      itemScrollController.jumpTo(index: last, alignment: alignment);
      return;
    }
    itemScrollController.jumpTo(index: last, alignment: 0);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (userDragging || scrollActive) return;
      if (!itemScrollController.isAttached) return;
      final a = _tailBottomAlignmentWithGap(last);
      if (a != null) {
        itemScrollController.jumpTo(index: last, alignment: a);
      }
    });
  }

  void snapTailIfNeeded(int itemCount) {
    if (!stickToTail || userDragging || scrollActive) return;
    if (!itemScrollController.isAttached || itemCount == 0) return;
    final metrics = metricsFor(itemCount);
    if (metrics.atBottom) return;
    final last = itemCount - 1;
    final alignment = _tailBottomAlignmentWithGap(last);
    if (alignment == null) {
      itemScrollController.jumpTo(index: last, alignment: 0);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!stickToTail || userDragging || scrollActive) return;
        final a = _tailBottomAlignmentWithGap(last);
        if (a != null) {
          itemScrollController.jumpTo(index: last, alignment: a);
        }
      });
      return;
    }
    itemScrollController.jumpTo(index: last, alignment: alignment);
  }
}
