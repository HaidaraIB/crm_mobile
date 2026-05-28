import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

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
  bool _pollTickInFlight = false;

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

  void startPolling({Duration interval = const Duration(milliseconds: 2800)}) {
    stopPolling();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_pollTick());
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTick() async {
    if (_pollTickInFlight || isClosed) return;
    _pollTickInFlight = true;
    try {
      await pollNewer();
    } finally {
      _pollTickInFlight = false;
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
    return super.close();
  }
}
