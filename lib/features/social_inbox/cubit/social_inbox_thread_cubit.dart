import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/social_conversation_model.dart';
import '../../../models/social_message_model.dart';
import '../../../services/api_service.dart';
import '../../../services/sync_invalidation.dart';
import '../../../utils/social_inbox_access.dart';
import '../social_inbox_repository.dart';
import 'social_inbox_thread_state.dart';

class SocialInboxThreadCubit extends Cubit<SocialInboxThreadState> {
  SocialInboxThreadCubit({
    required SocialInboxRepository repository,
    required SocialConversationModel conversation,
    bool Function()? isForeground,
  })  : _repository = repository,
        _isForeground = isForeground ?? (() => true),
        super(SocialInboxThreadState(conversation: conversation));

  final SocialInboxRepository _repository;
  final bool Function() _isForeground;

  Timer? _timer;
  StreamSubscription<Map<String, String>>? _invalidateSub;
  int _tempCounter = 0;

  int get _conversationId => state.conversation!.id;

  Future<void> bootstrap() async {
    await load();
    if (isClosed) return;

    // Opening the thread clears its unread badge.
    unawaited(_markRead());

    _timer?.cancel();
    _timer = Timer.periodic(kSyncFallbackPollInterval, (_) {
      if (!isClosed && _isForeground()) {
        unawaited(load(silent: true));
      }
    });

    _invalidateSub?.cancel();
    _invalidateSub = SyncInvalidation.instance.stream.listen((event) {
      if (event['invalidate'] == 'social:conversations') {
        unawaited(load(silent: true));
      }
    });
  }

  Future<void> load({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) {
      emit(state.copyWith(status: SocialThreadStatus.loading, clearError: true));
    }
    try {
      final results = await Future.wait([
        _repository.getMessages(_conversationId),
        _repository.getSendWindow(_conversationId),
      ]);
      if (isClosed) return;
      final messages = results[0] as List<SocialMessageModel>;
      final window = results[1] as SocialSendWindow;

      // Keep optimistic bubbles that the server has not echoed back yet.
      final serverIds = messages.map((m) => m.id).toSet();
      final pending = state.messages
          .where((m) => m.tempId != null && !serverIds.contains(m.id))
          .toList();

      emit(state.copyWith(
        status: SocialThreadStatus.loaded,
        messages: [...messages, ...pending],
        window: window,
        clearError: true,
      ));
    } catch (e) {
      if (isClosed) return;
      if (silent) return;
      emit(state.copyWith(
        status: SocialThreadStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _markRead() async {
    try {
      await _repository.markRead(_conversationId);
    } catch (_) {
      // Read receipts are best-effort; never block the thread on them.
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isClosed) return;

    _tempCounter += 1;
    final tempId = 'temp-$_tempCounter';
    final optimistic = SocialMessageModel(
      id: -_tempCounter,
      direction: 'outbound',
      body: trimmed,
      deliveryStatus: 'pending',
      createdAt: DateTime.now(),
      tempId: tempId,
    );

    emit(state.copyWith(
      messages: [...state.messages, optimistic],
      isSending: true,
      clearError: true,
    ));

    try {
      final sent = await _repository.sendMessage(
        conversationId: _conversationId,
        text: trimmed,
      );
      if (isClosed) return;
      emit(state.copyWith(
        isSending: false,
        messages: state.messages
            .map((m) => m.tempId == tempId
                ? (sent ?? m.copyWith(deliveryStatus: 'sent', tempId: ''))
                : m)
            .toList(),
      ));
      unawaited(load(silent: true));
    } on SocialSendException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isSending: false,
        sendErrorKey: socialSendErrorMessageKey(e.code),
        // Drop the optimistic bubble: the message was never delivered, and a
        // ghost in the thread is worse than none.
        messages: state.messages.where((m) => m.tempId != tempId).toList(),
      ));
      // A closed window is a state change — refresh so the composer disables.
      if (e.code == 'social_outside_window') unawaited(load(silent: true));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isSending: false,
        errorMessage: e.toString(),
        messages: state.messages.where((m) => m.tempId != tempId).toList(),
      ));
    }
  }

  Future<void> sendMedia(String filePath, {String? caption}) async {
    if (isClosed) return;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      await _repository.sendMedia(
        conversationId: _conversationId,
        filePath: filePath,
        text: caption,
      );
      if (isClosed) return;
      emit(state.copyWith(isSending: false));
      unawaited(load(silent: true));
    } on SocialSendException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isSending: false,
        sendErrorKey: socialSendErrorMessageKey(e.code),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isSending: false, errorMessage: e.toString()));
    }
  }

  Future<void> updateConversationState({
    String? status,
    String? snoozedUntil,
    bool? isStarred,
    bool? isUnsubscribed,
  }) async {
    if (isClosed) return;
    final previous = state.conversation;
    if (previous == null) return;
    final next = previous.copyWith(
      status: status,
      snoozedUntil: snoozedUntil != null ? DateTime.tryParse(snoozedUntil) : null,
      clearSnoozedUntil: status != null && status != 'snoozed',
      isStarred: isStarred,
      isUnsubscribed: isUnsubscribed,
    );
    emit(state.copyWith(conversation: next));
    try {
      await _repository.updateState(
        conversationId: _conversationId,
        status: status,
        snoozedUntil: snoozedUntil,
        isStarred: isStarred,
        isUnsubscribed: isUnsubscribed,
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(conversation: previous, errorMessage: e.toString()));
    }
  }

  Future<void> setStatus(String status) =>
      updateConversationState(status: status);

  /// Returns the new lead id, or null when the conversion failed.
  Future<int?> convertToLead({
    String? name,
    String? phone,
    int? assignedTo,
    bool autoAssign = true,
    String? notes,
  }) async {
    if (isClosed) return null;
    try {
      final result = await _repository.convertToLead(
        conversationId: _conversationId,
        name: name,
        phone: phone,
        assignedTo: assignedTo,
        autoAssign: autoAssign,
        notes: notes,
      );
      if (isClosed) return null;
      final clientId = (result['client_id'] as num?)?.toInt();
      final clientName = result['client_name'] as String? ?? '';
      if (clientId != null && state.conversation != null) {
        emit(state.copyWith(
          conversation: state.conversation!
              .copyWith(clientId: clientId, clientName: clientName),
          clearError: true,
        ));
      }
      return clientId;
    } on SocialSendException catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(sendErrorKey: socialSendErrorMessageKey(e.code)));
      return null;
    } catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(errorMessage: e.toString()));
      return null;
    }
  }

  void clearErrors() {
    if (!isClosed) emit(state.copyWith(clearError: true));
  }

  String attachmentUrl(int messageId) => _repository.attachmentUrl(messageId);

  @override
  Future<void> close() {
    _timer?.cancel();
    _invalidateSub?.cancel();
    return super.close();
  }
}
