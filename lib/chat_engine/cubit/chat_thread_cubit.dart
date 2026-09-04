import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/sync_invalidation.dart';
import '../models/chat_list_row.dart';
import '../models/chat_message.dart';
import '../registry/message_registry.dart';
import 'chat_thread_state.dart';

class ChatFetchPageResult<T extends ChatMessage> {
  const ChatFetchPageResult({
    required this.messages,
    this.hasOlder = false,
    this.hasNewer = false,
  });

  final List<T> messages;
  final bool hasOlder;
  final bool hasNewer;
}

abstract class ChatThreadRepository<T extends ChatMessage> {
  Future<ChatFetchPageResult<T>> fetchTailWindow();
  Future<ChatFetchPageResult<T>> fetchOlder({required int beforeMessageId});
  Future<ChatFetchPageResult<T>> fetchNewer({required int afterMessageId});
  Future<ChatFetchPageResult<T>> fetchAround({required int messageId});

  /// Re-read the window ending at [throughMessageId] — messages that are already
  /// on screen, not new ones.
  ///
  /// Exists because a read receipt changes a message without adding one, and
  /// [fetchNewer] by definition cannot carry that: it asks for ids above the last
  /// one held, and a peer marking things read produces none.
  Future<ChatFetchPageResult<T>> fetchTailRefresh({required int throughMessageId});
}

/// Thread message list + pagination. No UI/scroll logic here.
class ChatThreadCubit<T extends ChatMessage> extends Cubit<ChatThreadState> {
  ChatThreadCubit({
    required this.repository,
    required this.registry,
    required this.sameSender,
    required this.isFirstUnreadPeerMessage,
  }) : super(const ChatThreadState.initial());

  final ChatThreadRepository<T> repository;
  final MessageRegistry<T> registry;
  final bool Function(T current, T? previous) sameSender;
  final bool Function(T message) isFirstUnreadPeerMessage;

  Timer? _pollTimer;
  Timer? _coalesceTimer;
  StreamSubscription<Map<String, String>>? _invalidateSub;
  bool _pollTickInFlight = false;
  DateTime _lastPollAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Floor between reads driven by the invalidation bus.
  ///
  /// Marking messages read now moves the thread's own counter, so this client's
  /// scrolling comes back to it as a change signal. Without a floor, dragging
  /// through a long thread would fire a read per debounce and a pair of fetches
  /// per read. Three sources feed this bus — a frame, a push, the digest — and
  /// they routinely report the same event, so coalescing them was worth doing
  /// regardless.
  static const Duration _minPollGap = Duration(seconds: 1);

  List<ChatListRow> _buildRows() => registry.buildRows(
        sameSender: sameSender,
        isFirstUnreadPeerMessage: isFirstUnreadPeerMessage,
      );

  Future<void> loadInitial() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      registry.clear();
      final page = await repository.fetchTailWindow();
      registry.upsertNewer(page.messages);
      emit(
        state.copyWith(
          loading: false,
          rows: _buildRows(),
          hasOlder: page.hasOlder,
          hasNewer: page.hasNewer,
          version: registry.version,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  bool _loadOlderInProgress = false;

  /// Loads older page. Returns whether new rows were merged (caller restores scroll anchor).
  Future<bool> loadOlder() async {
    if (_loadOlderInProgress || !state.hasOlder || registry.length == 0) {
      return false;
    }
    _loadOlderInProgress = true;
    try {
      final firstId = registry.orderedIds.first;
      final page = await repository.fetchOlder(beforeMessageId: firstId);
      if (page.messages.isEmpty) {
        emit(state.copyWith(hasOlder: false));
        return false;
      }
      final existing = registry.orderedIds.toSet();
      final incoming =
          page.messages.where((m) => !existing.contains(m.id)).toList(growable: false);
      if (incoming.isEmpty) {
        emit(state.copyWith(hasOlder: page.hasOlder));
        return false;
      }
      registry.upsertOlder(incoming);
      emit(
        state.copyWith(
          rows: _buildRows(),
          hasOlder: page.hasOlder,
          version: registry.version,
        ),
      );
      return true;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return false;
    } finally {
      _loadOlderInProgress = false;
    }
  }

  /// Fallback only — a realtime frame, the digest's `tenant_chat` slice and FCM
  /// all arrive sooner. Resolved at call time rather than as a default value,
  /// because the interval now depends on whether a socket is connected.
  void startPolling({Duration? interval}) {
    interval ??= kSyncFallbackPollInterval;
    return _startPolling(interval);
  }

  void _startPolling(Duration interval) {
    stopPolling();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_pollTick());
    });
    _invalidateSub?.cancel();
    _invalidateSub = SyncInvalidation.instance.stream.listen((event) {
      if (event['invalidate'] == 'tenant_chat:messages') {
        _requestPollTick();
      }
    });
  }

  /// Read now if the last read was long enough ago, otherwise once at the floor.
  ///
  /// Trailing rather than leading-only, so the last signal in a burst is still
  /// acted on — dropping it would leave the thread showing whatever the first one
  /// happened to catch.
  void _requestPollTick() {
    if (isClosed) return;
    final since = DateTime.now().difference(_lastPollAt);
    if (since >= _minPollGap) {
      unawaited(_pollTick());
      return;
    }
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_minPollGap - since, () => unawaited(_pollTick()));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
  }

  Future<void> _pollTick() async {
    if (_pollTickInFlight || isClosed) return;
    _pollTickInFlight = true;
    _lastPollAt = DateTime.now();
    try {
      await pollNewer();
      if (isClosed) return;
      await refreshLoadedTail();
    } finally {
      _pollTickInFlight = false;
    }
  }

  /// Pick up changes to messages already held — today, read receipts.
  ///
  /// `read_by_peer` is computed server-side per message, so a tick turning blue
  /// is a change to rows this client already has and will never ask for again:
  /// [pollNewer] anchors above the last known id, so the peer marking a thread
  /// read moved nothing it could see. The ticks therefore only refreshed when the
  /// thread was reopened, or when a later message happened to arrive.
  ///
  /// Restricted to ids already in the registry, so a window that reaches further
  /// back than what is loaded cannot append older rows to the end of the list.
  Future<void> refreshLoadedTail() async {
    if (registry.length == 0 || state.loading) return;
    final lastId = registry.orderedIds.last;
    try {
      final page = await repository.fetchTailRefresh(throughMessageId: lastId);
      if (isClosed || page.messages.isEmpty) return;
      final known = registry.orderedIds.toSet();
      final updates =
          page.messages.where((m) => known.contains(m.id)).toList(growable: false);
      if (updates.isEmpty) return;
      registry.upsertNewer(updates);
      emit(state.copyWith(rows: _buildRows(), version: registry.version));
    } catch (_) {
      // A backstop refresh failing is not worth surfacing: the next signal — a
      // frame, a push, or the timer — tries again, and the thread on screen is
      // still correct apart from a tick.
    }
  }

  Future<void> pollNewer() async {
    if (registry.length == 0 || state.loading) return;
    final lastId = registry.orderedIds.last;
    final page = await repository.fetchNewer(afterMessageId: lastId);
    if (page.messages.isEmpty) return;
    final beforeVersion = registry.version;
    registry.mergePoll(page.messages);
    if (registry.version == beforeVersion) return;
    emit(
      state.copyWith(
        rows: _buildRows(),
        hasNewer: page.hasNewer,
        version: registry.version,
      ),
    );
  }

  Future<bool> ensureMessageLoaded(int messageId) async {
    if (registry.contains(messageId)) return true;
    try {
      final around = await repository.fetchAround(messageId: messageId);
      registry.upsertOlder(around.messages);
      emit(
        state.copyWith(
          rows: _buildRows(),
          hasOlder: around.hasOlder,
          hasNewer: around.hasNewer,
          version: registry.version,
        ),
      );
      return registry.contains(messageId);
    } catch (_) {
      return false;
    }
  }

  T? messageById(int id) => registry.byId(id);

  @override
  Future<void> close() {
    stopPolling();
    _invalidateSub?.cancel();
    return super.close();
  }
}
