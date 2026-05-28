import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../models/tenant_chat_models.dart';
import '../../../utils/compress_image_for_chat.dart';
import '../team_chat_repository.dart';
import 'team_chat_composer_state.dart';

typedef TeamChatComposerRefresh = Future<void> Function();
typedef TeamChatComposerMessageSent = Future<void> Function();

class TeamChatComposerCubit extends Cubit<TeamChatComposerState> {
  TeamChatComposerCubit({
    required TeamChatRepository repository,
    TeamChatComposerRefresh? onRefreshConversations,
    TeamChatComposerMessageSent? onMessageSent,
  })  : _repository = repository,
        _onRefreshConversations = onRefreshConversations,
        _onMessageSent = onMessageSent,
        super(const TeamChatComposerState.initial());

  final TeamChatRepository _repository;
  final TeamChatComposerRefresh? _onRefreshConversations;
  final TeamChatComposerMessageSent? _onMessageSent;

  String _localPresence = kTenantChatPresenceIdle;
  Timer? _typingDebounceTimer;
  Timer? _presenceHeartbeatTimer;
  Timer? _voiceCapTimer;
  AudioRecorder? _recorder;
  String? _voiceTempPath;

  void bindConversation(int? conversationId) {
    final previousId = state.boundConversationId;
    _typingDebounceTimer?.cancel();
    _presenceHeartbeatTimer?.cancel();
    unawaited(_stopVoiceInternal(finalize: false));
    if (previousId != null && previousId != conversationId) {
      unawaited(
        _repository.postPeerPresence(previousId, kTenantChatPresenceIdle),
      );
    }
    _localPresence = kTenantChatPresenceIdle;
    emit(
      TeamChatComposerState(
        boundConversationId: conversationId,
        replyTo: null,
        forwardSourceId: null,
        pendingAttachmentPath: null,
        compressing: false,
        sending: false,
        voiceRecording: false,
        draftTypingSignal: false,
        sendErrorKey: null,
        pinErrorKey: null,
      ),
    );
  }

  void onDraftChanged({required bool hasText}) {
    if (state.boundConversationId == null) return;
    _typingDebounceTimer?.cancel();
    if (!hasText) {
      if (state.draftTypingSignal) {
        emit(state.copyWith(draftTypingSignal: false));
      }
      _updateDerivedPresence();
      return;
    }
    _typingDebounceTimer = Timer(const Duration(milliseconds: 550), () {
      if (!state.draftTypingSignal) {
        emit(state.copyWith(draftTypingSignal: true));
      }
      _updateDerivedPresence(hasDraftText: true);
    });
  }

  void setReplyTo(TenantChatMessage? message) {
    emit(state.copyWith(replyTo: message, clearReplyTo: message == null));
  }

  void setForwardSource(int? messageId) {
    emit(
      state.copyWith(
        forwardSourceId: messageId,
        clearForwardSourceId: messageId == null,
      ),
    );
  }

  void setPendingAttachment(String? path) {
    emit(
      state.copyWith(
        pendingAttachmentPath: path,
        clearPendingAttachment: path == null,
      ),
    );
    _updateDerivedPresence();
  }

  void clearSendError() {
    if (state.sendErrorKey != null) {
      emit(state.copyWith(clearSendError: true));
    }
  }

  void clearPinError() {
    if (state.pinErrorKey != null) {
      emit(state.copyWith(clearPinError: true));
    }
  }

  void _updateDerivedPresence({bool hasDraftText = false}) {
    final id = state.boundConversationId;
    if (id == null) return;
    String next;
    if (state.voiceRecording) {
      next = kTenantChatPresenceRecording;
    } else if (state.compressing || state.pendingAttachmentPath != null) {
      next = kTenantChatPresenceUploading;
    } else if (state.sending && state.pendingAttachmentPath != null) {
      next = kTenantChatPresenceUploading;
    } else if (state.sending) {
      next = kTenantChatPresenceSending;
    } else if (state.draftTypingSignal && hasDraftText) {
      next = kTenantChatPresenceTyping;
    } else if (state.draftTypingSignal) {
      next = kTenantChatPresenceTyping;
    } else {
      next = kTenantChatPresenceIdle;
    }
    if (next == _localPresence) return;
    _localPresence = next;
    unawaited(_repository.postPeerPresence(id, next));
    _presenceHeartbeatTimer?.cancel();
    if (next != kTenantChatPresenceIdle) {
      _presenceHeartbeatTimer =
          Timer.periodic(const Duration(milliseconds: 3200), (_) {
        final cid = state.boundConversationId;
        if (cid != null) {
          unawaited(_repository.postPeerPresence(cid, _localPresence));
        }
      });
    }
  }

  Future<void> send({
    required String draftText,
  }) async {
    final id = state.boundConversationId;
    if (id == null || state.sending) return;
    final text = draftText.trim();
    final path = state.pendingAttachmentPath;
    if (text.isEmpty && path == null) return;

    emit(state.copyWith(sending: true, clearSendError: true));
    _updateDerivedPresence();
    try {
      if (path != null) {
        var uploadPath = path;
        final lower = path.toLowerCase();
        if (lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.webp') ||
            lower.endsWith('.heic')) {
          if (!lower.endsWith('.gif')) {
            emit(state.copyWith(compressing: true));
            _updateDerivedPresence();
            try {
              uploadPath = await compressImageForChatIfNeeded(path);
            } finally {
              emit(state.copyWith(compressing: false));
            }
            _updateDerivedPresence();
          }
        }
        await _repository.sendMessageWithFile(
          id,
          uploadPath,
          body: text.isEmpty ? null : text,
          replyToMessageId: state.replyTo?.id,
        );
      } else {
        await _repository.sendMessage(
          id,
          text,
          replyToMessageId: state.replyTo?.id,
        );
      }
      emit(
        state.copyWith(
          clearReplyTo: true,
          clearPendingAttachment: true,
          sending: false,
        ),
      );
      await _onRefreshConversations?.call();
      await _onMessageSent?.call();
    } catch (_) {
      emit(
        state.copyWith(
          sending: false,
          sendErrorKey: 'teamChatCouldNotSend',
        ),
      );
    } finally {
      _updateDerivedPresence();
    }
  }

  Future<bool> startVoiceRecording() async {
    if (state.boundConversationId == null || state.sending || state.voiceRecording) {
      return false;
    }
    final rec = AudioRecorder();
    _recorder = rec;
    if (!await rec.hasPermission()) {
      await rec.dispose();
      _recorder = null;
      return false;
    }
    final dir = await getTemporaryDirectory();
    _voiceTempPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await rec.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: _voiceTempPath!,
    );
    emit(state.copyWith(voiceRecording: true));
    _updateDerivedPresence();
    _voiceCapTimer?.cancel();
    _voiceCapTimer = Timer(const Duration(minutes: 4), () {
      unawaited(_stopVoiceInternal(finalize: true));
    });
    return true;
  }

  Future<void> stopVoiceRecording() => _stopVoiceInternal(finalize: true);

  Future<void> _stopVoiceInternal({required bool finalize}) async {
    _voiceCapTimer?.cancel();
    final rec = _recorder;
    _recorder = null;
    if (rec != null) {
      if (await rec.isRecording()) {
        await rec.stop();
      }
      await rec.dispose();
    }
    if (finalize && _voiceTempPath != null) {
      final f = File(_voiceTempPath!);
      if (await f.exists() && await f.length() > 0) {
        emit(state.copyWith(pendingAttachmentPath: _voiceTempPath));
        _updateDerivedPresence();
      }
    }
    _voiceTempPath = null;
    if (state.voiceRecording) {
      emit(state.copyWith(voiceRecording: false));
    }
    _updateDerivedPresence();
  }

  Future<void> pinMessage(TenantChatMessage message) async {
    final id = state.boundConversationId;
    if (id == null) return;
    try {
      await _repository.pinMessage(id, message.id);
      await _onRefreshConversations?.call();
    } catch (_) {
      emit(state.copyWith(pinErrorKey: 'teamChatCouldNotSend'));
    }
  }

  Future<void> unpinMessage(int messageId) async {
    final id = state.boundConversationId;
    if (id == null) return;
    try {
      await _repository.unpinMessage(id, messageId);
      await _onRefreshConversations?.call();
    } catch (_) {}
  }

  Future<bool> forwardMessage({
    required int targetConversationId,
    required String caption,
    required int forwardFromMessageId,
    required int? currentSelectedId,
  }) async {
    try {
      await _repository.sendMessage(
        targetConversationId,
        caption,
        forwardFromMessageId: forwardFromMessageId,
      );
      emit(state.copyWith(clearForwardSourceId: true));
      await _onRefreshConversations?.call();
      if (currentSelectedId == targetConversationId) {
        await _onMessageSent?.call();
      }
      return true;
    } catch (_) {
      emit(state.copyWith(sendErrorKey: 'teamChatCouldNotSend'));
      return false;
    }
  }

  @override
  Future<void> close() async {
    _typingDebounceTimer?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _voiceCapTimer?.cancel();
    final id = state.boundConversationId;
    await _stopVoiceInternal(finalize: false);
    if (id != null) {
      unawaited(_repository.postPeerPresence(id, kTenantChatPresenceIdle));
    }
    return super.close();
  }
}
