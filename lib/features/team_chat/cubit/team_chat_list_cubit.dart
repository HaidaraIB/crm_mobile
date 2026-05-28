import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/tenant_chat_models.dart';
import '../../../services/notification_service.dart';
import '../../../services/team_chat_away_service.dart';
import '../../../services/team_chat_unread_holder.dart';
import '../team_chat_equality.dart';
import '../team_chat_repository.dart';
import 'team_chat_list_state.dart';

class TeamChatListCubit extends Cubit<TeamChatListState> {
  TeamChatListCubit({
    required TeamChatRepository repository,
    bool Function()? isForeground,
  })  : _repository = repository,
        _isForeground = isForeground ?? (() => true),
        super(const TeamChatListState.initial());

  final TeamChatRepository _repository;
  final bool Function() _isForeground;
  Timer? _convTimer;

  Future<void> bootstrap({int? initialConversationId}) async {
    try {
      final me = await _repository.getCurrentUser();
      emit(state.copyWith(currentUserId: me.id));
    } catch (_) {}

    await refreshConversations();
    if (initialConversationId != null) {
      for (final c in state.conversations) {
        if (c.id == initialConversationId) {
          await selectConversation(initialConversationId);
          break;
        }
      }
    }
    _convTimer?.cancel();
    _convTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isForeground()) {
        unawaited(refreshConversations(silent: true));
      }
    });
  }

  Future<void> refreshConversations({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(loadingConv: true));
    }
    try {
      final page = await _repository.getConversations();
      final total = page.results.fold<int>(0, (s, c) => s + c.unreadCount);
      TeamChatUnreadHolder.setTotal(total);
      final sorted = sortTenantConversations(page.results);
      if (silent &&
          !state.loadingConv &&
          tenantConversationsPayloadEqual(state.conversations, sorted)) {
        _syncReadCursorFromServer();
        return;
      }
      emit(
        state.copyWith(
          conversations: sorted,
          loadingConv: false,
          clearLoadError: true,
        ),
      );
      _syncReadCursorFromServer();
    } catch (e) {
      emit(
        state.copyWith(
          loadingConv: false,
          loadError: silent ? state.loadError : e.toString(),
        ),
      );
    }
  }

  void _syncReadCursorFromServer() {
    final id = state.selectedId;
    if (id == null) return;
    TenantChatConversation? row;
    for (final c in state.conversations) {
      if (c.id == id) {
        row = c;
        break;
      }
    }
    if (row != null && row.lastReadMessageId != null) {
      final server = row.lastReadMessageId!;
      final next = state.readCursor > server ? state.readCursor : server;
      if (next != state.readCursor) {
        emit(state.copyWith(readCursor: next));
      }
    }
  }

  Future<void> selectConversation(int id) async {
    unawaited(NotificationService().clearTenantChatPushMergeBuffer(id));
    TenantChatConversation? row;
    for (final c in state.conversations) {
      if (c.id == id) {
        row = c;
        break;
      }
    }
    final readCursor = row?.lastReadMessageId ?? 0;
    emit(
      state.copyWith(
        selectedId: id,
        readCursor: readCursor,
        clearLoadError: true,
      ),
    );
    TeamChatAwayService.instance.setActiveConversationId(id);
    _syncReadCursorFromServer();
  }

  void clearSelection() {
    emit(state.copyWith(clearSelectedId: true));
    TeamChatAwayService.instance.setActiveConversationId(null);
  }

  void advanceReadCursor(int id) {
    if (id > state.readCursor) {
      emit(state.copyWith(readCursor: id));
    }
  }

  @override
  Future<void> close() {
    _convTimer?.cancel();
    TeamChatAwayService.instance.setActiveConversationId(null);
    return super.close();
  }
}
