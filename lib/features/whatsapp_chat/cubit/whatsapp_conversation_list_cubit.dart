import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/whatsapp_conversation_model.dart';
import '../../../services/api_service.dart';
import '../../../services/whatsapp_chat_unread_holder.dart';
import '../../../services/sync_invalidation.dart';
import '../../../utils/whatsapp_manual_chats_storage.dart';
import '../whatsapp_chat_repository.dart';
import 'whatsapp_conversation_list_state.dart';

const int kWhatsAppConversationsPageSize = 100;

class WhatsAppConversationListCubit extends Cubit<WhatsAppConversationListState> {
  WhatsAppConversationListCubit({
    required WhatsAppChatRepository repository,
    bool Function()? isForeground,
    this.includeManualChats = false,
  })  : _repository = repository,
        _isForeground = isForeground ?? (() => true),
        super(const WhatsAppConversationListState.initial());

  final WhatsAppChatRepository _repository;
  final bool Function() _isForeground;
  /// Owners/admins may persist manual phone threads locally.
  final bool includeManualChats;
  Timer? _timer;
  Timer? _awaySoundTimer;
  Timer? _searchDebounce;
  StreamSubscription<Map<String, String>>? _invalidateSub;
  int _lastUnreadTotal = 0;
  final AudioPlayer _awayPlayer = AudioPlayer();

  Future<void> bootstrap() async {
    await refresh();
    if (isClosed) return;
    _timer?.cancel();
    // Fallback only — the digest's `chat` slice and FCM both arrive sooner.
    _timer = Timer.periodic(kSyncFallbackPollInterval, (_) {
      if (!isClosed && _isForeground()) {
        unawaited(refresh(silent: true));
      }
    });
    _awaySoundTimer?.cancel();
    _awaySoundTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isClosed && _isForeground()) unawaited(_checkAwaySound());
    });
    _invalidateSub?.cancel();
    _invalidateSub = SyncInvalidation.instance.stream.listen((event) {
      if (event['invalidate'] == 'whatsapp:conversations') {
        unawaited(refresh(silent: true));
      }
    });
  }

  Future<void> _checkAwaySound() async {
    try {
      final n = await _repository.getUnreadCount();
      if (isClosed) return;
      if (n > _lastUnreadTotal && _lastUnreadTotal >= 0) {
        try {
          await _awayPlayer.play(AssetSource('sounds/notif_tenant_chat.wav'));
        } catch (_) {}
      }
      if (isClosed) return;
      _lastUnreadTotal = n;
      WhatsAppChatUnreadHolder.setTotal(n);
    } catch (_) {}
  }

  void setStatusFilter(String status) {
    emit(state.copyWith(
      filters: state.filters.copyWith(status: status, starred: false),
    ));
    unawaited(refresh());
  }

  void setAssignment(String assignment) {
    emit(state.copyWith(
      filters: state.filters.copyWith(
        assignment: assignment,
        starred: false,
        clearAgent: true,
      ),
    ));
    unawaited(refresh());
  }

  void setAgent(int? agentId) {
    emit(state.copyWith(
      filters: state.filters.copyWith(
        agentId: agentId,
        assignment: 'all',
        starred: false,
        clearAgent: agentId == null,
      ),
    ));
    unawaited(refresh());
  }

  void toggleStarred() {
    final next = !state.filters.starred;
    emit(state.copyWith(
      filters: state.filters.copyWith(
        starred: next,
        status: next ? 'all' : state.filters.status,
        assignment: next ? 'all' : state.filters.assignment,
        clearAgent: next,
      ),
    ));
    unawaited(refresh());
  }

  void toggleUnreplied() {
    emit(state.copyWith(
      filters: state.filters.copyWith(unreplied: !state.filters.unreplied),
    ));
    unawaited(refresh());
  }

  void setSearch(String search) {
    emit(state.copyWith(filters: state.filters.copyWith(search: search)));
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(refresh(silent: true));
    });
  }

  Future<void> updateConversationState({
    required int clientId,
    String? status,
    String? snoozedUntil,
    bool? isStarred,
    bool? isUnsubscribed,
  }) async {
    try {
      await _repository.updateConversationState(
        clientId: clientId,
        status: status,
        snoozedUntil: snoozedUntil,
        isStarred: isStarred,
        isUnsubscribed: isUnsubscribed,
      );
      if (isClosed) return;
      final updated = state.conversations.map((c) {
        if (c.id != clientId) return c;
        return c.copyWith(
          status: status,
          snoozedUntil: snoozedUntil != null ? DateTime.tryParse(snoozedUntil) : null,
          clearSnoozedUntil: status != null && status != 'snoozed',
          isStarred: isStarred,
          isUnsubscribed: isUnsubscribed,
        );
      }).toList();
      emit(state.copyWith(conversations: updated));
      await refresh(silent: true);
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadError: e.toString()));
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) {
      emit(state.copyWith(loading: true, loadingMore: false));
    }
    try {
      final f = state.filters;
      final keepLoaded = silent
          ? state.conversations.where((c) => c.id > 0).length
          : 0;
      final merged = <WhatsAppConversationModel>[];
      var apiCount = 0;
      Map<String, int> statusCounts = const {};
      Map<String, int> assignmentCounts = const {};
      var offset = 0;
      // Silent poll re-fetches every already-loaded page so scroll position is kept.
      // Manual refresh always starts from the first page only.
      final stopAfter = silent && keepLoaded > 0
          ? keepLoaded
          : kWhatsAppConversationsPageSize;

      while (true) {
        final page = await _repository.getConversations(
          status: f.starred ? null : (f.status == 'all' ? null : f.status),
          assignment: f.assignment == 'all' ? null : f.assignment,
          agentId: f.agentId,
          starred: f.starred ? true : null,
          unreplied: f.unreplied ? true : null,
          search: f.search.trim().isEmpty ? null : f.search.trim(),
          limit: kWhatsAppConversationsPageSize,
          offset: offset,
        );
        if (isClosed) return;
        if (offset == 0) {
          apiCount = page.count;
          statusCounts = page.statusCounts;
          assignmentCounts = page.assignmentCounts;
        }
        for (final c in page.results) {
          if (!merged.any((e) => e.id == c.id)) merged.add(c);
        }
        offset = merged.length;
        final gotFullPage =
            page.results.length >= kWhatsAppConversationsPageSize;
        if (!gotFullPage || offset >= apiCount) break;
        if (!silent) break; // first page only on manual/filter refresh
        if (offset >= stopAfter) break;
      }

      if (includeManualChats && f.isDefault) {
        final manuals = await WhatsAppManualChatsStorage.load();
        if (isClosed) return;
        for (final m in manuals) {
          final digits = m.phoneNumber.replaceAll(RegExp(r'\D'), '');
          final exists = merged.any(
            (c) => c.phoneNumber.replaceAll(RegExp(r'\D'), '') == digits,
          );
          if (!exists) {
            merged.add(
              WhatsAppConversationModel(
                id: -digits.hashCode.abs(),
                name: m.name.isNotEmpty ? m.name : m.phoneNumber,
                phoneNumber: m.phoneNumber,
                lastMessageAt: m.lastMessageAt,
                lastMessagePreview: '',
                unreadCount: 0,
              ),
            );
          } else {
            // Upgrade: drop local manual when CRM lead exists.
            unawaited(WhatsAppManualChatsStorage.remove(m.phoneNumber));
          }
        }
      }

      final unreadTotal = merged.fold<int>(0, (s, c) => s + c.unreadCount);
      WhatsAppChatUnreadHolder.setAvailable(true);
      WhatsAppChatUnreadHolder.setTotal(unreadTotal);
      _lastUnreadTotal = unreadTotal;
      if (isClosed) return;
      final crmLoaded = merged.where((c) => c.id > 0).length;
      emit(
        state.copyWith(
          conversations: merged,
          loading: false,
          loadingMore: false,
          totalCount: apiCount,
          hasMore: crmLoaded < apiCount,
          statusCounts: statusCounts,
          assignmentCounts: assignmentCounts,
          clearLoadError: true,
          clearUnavailable: true,
        ),
      );
    } on WhatsAppAccessDeniedException catch (e) {
      if (isClosed) return;
      WhatsAppChatUnreadHolder.setAvailable(false);
      emit(
        state.copyWith(
          loading: false,
          loadingMore: false,
          unavailableCode: e.code,
          clearLoadError: true,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          loadingMore: false,
          loadError: silent ? state.loadError : e.toString(),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (isClosed) return;
    if (state.loading || state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final f = state.filters;
      // Offset is CRM rows only (exclude local manual placeholders with id <= 0).
      final offset = state.conversations.where((c) => c.id > 0).length;
      final page = await _repository.getConversations(
        status: f.starred ? null : (f.status == 'all' ? null : f.status),
        assignment: f.assignment == 'all' ? null : f.assignment,
        agentId: f.agentId,
        starred: f.starred ? true : null,
        unreplied: f.unreplied ? true : null,
        search: f.search.trim().isEmpty ? null : f.search.trim(),
        limit: kWhatsAppConversationsPageSize,
        offset: offset,
      );
      if (isClosed) return;
      final seen = {for (final c in state.conversations) c.id};
      final appended = <WhatsAppConversationModel>[
        ...state.conversations,
        for (final c in page.results)
          if (!seen.contains(c.id)) c,
      ];
      final apiCount = page.count;
      final crmLoaded = appended.where((c) => c.id > 0).length;
      emit(
        state.copyWith(
          conversations: appended,
          loadingMore: false,
          totalCount: apiCount,
          hasMore: page.results.length >= kWhatsAppConversationsPageSize &&
              crmLoaded < apiCount,
          statusCounts: page.statusCounts.isNotEmpty
              ? page.statusCounts
              : state.statusCounts,
          assignmentCounts: page.assignmentCounts.isNotEmpty
              ? page.assignmentCounts
              : state.assignmentCounts,
          clearLoadError: true,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadingMore: false, loadError: e.toString()));
    }
  }

  Future<void> deleteConversation(WhatsAppConversationModel c) async {
    try {
      if (c.id > 0) {
        await _repository.deleteConversation(clientId: c.id);
      } else {
        await _repository.deleteConversation(phone: c.phoneNumber);
        await WhatsAppManualChatsStorage.remove(c.phoneNumber);
      }
      if (isClosed) return;
      await refresh(silent: true);
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadError: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _awaySoundTimer?.cancel();
    _searchDebounce?.cancel();
    _invalidateSub?.cancel();
    _awayPlayer.dispose();
    return super.close();
  }
}
