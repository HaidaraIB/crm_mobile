import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_service.dart';
import '../../../services/sync_invalidation.dart';
import '../../../utils/social_inbox_access.dart';
import '../social_inbox_repository.dart';
import 'social_inbox_list_state.dart';

class SocialInboxListCubit extends Cubit<SocialInboxListState> {
  SocialInboxListCubit({
    required SocialInboxRepository repository,
    bool Function()? isForeground,
  })  : _repository = repository,
        _isForeground = isForeground ?? (() => true),
        super(const SocialInboxListState.initial());

  final SocialInboxRepository _repository;
  final bool Function() _isForeground;

  Timer? _timer;
  Timer? _searchDebounce;
  StreamSubscription<Map<String, String>>? _invalidateSub;

  Future<void> bootstrap() async {
    await refresh();
    if (isClosed) return;

    _timer?.cancel();
    // Fallback only — the digest's `inbox` slice and FCM both arrive sooner.
    _timer = Timer.periodic(kSyncFallbackPollInterval, (_) {
      if (!isClosed && _isForeground()) {
        unawaited(refresh(silent: true));
      }
    });

    _invalidateSub?.cancel();
    _invalidateSub = SyncInvalidation.instance.stream.listen((event) {
      if (event['invalidate'] == 'social:conversations') {
        unawaited(refresh(silent: true));
      }
    });
  }

  Future<void> refresh({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) {
      emit(state.copyWith(status: SocialInboxListStatus.loading, clearError: true));
    }
    try {
      final page = await _repository.getConversations(
        channel: state.channelFilter,
        status: state.statusFilter,
        search: state.search.isEmpty ? null : state.search,
        limit: 100,
      );
      if (isClosed) return;
      emit(state.copyWith(
        status: SocialInboxListStatus.loaded,
        conversations: page.results,
        statusCounts: page.statusCounts,
        clearError: true,
      ));
    } on SocialInboxAccessDeniedException catch (e) {
      if (isClosed) return;
      // A 403 is a permanent answer for this user — show an explanation, not Retry.
      emit(state.copyWith(
        status: SocialInboxListStatus.denied,
        deniedMessageKey: socialInboxUnavailableMessageKey(e.code),
      ));
    } catch (e) {
      if (isClosed) return;
      if (silent) return; // Never surface a background poll failure.
      emit(state.copyWith(
        status: SocialInboxListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void setChannel(String channel) {
    if (state.channelFilter == channel) return;
    emit(state.copyWith(channelFilter: channel));
    unawaited(refresh());
  }

  void setStatus(String status) {
    if (state.statusFilter == status) return;
    emit(state.copyWith(statusFilter: status));
    unawaited(refresh());
  }

  void setSearch(String value) {
    emit(state.copyWith(search: value));
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!isClosed) unawaited(refresh(silent: true));
    });
  }

  /// Optimistic local clear so the badge disappears the moment a thread opens.
  void markReadLocally(int conversationId) {
    if (isClosed) return;
    emit(state.copyWith(
      conversations: state.conversations
          .map((c) => c.id == conversationId ? c.copyWith(unreadCount: 0) : c)
          .toList(),
    ));
  }

  Future<void> updateConversationState({
    required int conversationId,
    String? status,
    String? snoozedUntil,
    bool? isStarred,
    bool? isUnsubscribed,
  }) async {
    if (isClosed) return;
    final previous = state.conversations;
    emit(state.copyWith(
      conversations: previous
          .map(
            (c) => c.id != conversationId
                ? c
                : c.copyWith(
                    status: status,
                    snoozedUntil: snoozedUntil != null
                        ? DateTime.tryParse(snoozedUntil)
                        : null,
                    clearSnoozedUntil: status != null && status != 'snoozed',
                    isStarred: isStarred,
                    isUnsubscribed: isUnsubscribed,
                  ),
          )
          .toList(),
    ));
    try {
      await _repository.updateState(
        conversationId: conversationId,
        status: status,
        snoozedUntil: snoozedUntil,
        isStarred: isStarred,
        isUnsubscribed: isUnsubscribed,
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(conversations: previous));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _searchDebounce?.cancel();
    _invalidateSub?.cancel();
    return super.close();
  }
}
