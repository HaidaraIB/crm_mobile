import 'package:equatable/equatable.dart';

import '../../../models/tenant_chat_models.dart';

class TeamChatComposerState extends Equatable {
  const TeamChatComposerState({
    required this.boundConversationId,
    required this.replyTo,
    required this.forwardSourceId,
    required this.pendingAttachmentPath,
    required this.compressing,
    required this.sending,
    required this.voiceRecording,
    required this.draftTypingSignal,
    required this.sendErrorKey,
    required this.pinErrorKey,
  });

  const TeamChatComposerState.initial()
      : boundConversationId = null,
        replyTo = null,
        forwardSourceId = null,
        pendingAttachmentPath = null,
        compressing = false,
        sending = false,
        voiceRecording = false,
        draftTypingSignal = false,
        sendErrorKey = null,
        pinErrorKey = null;

  final int? boundConversationId;
  final TenantChatMessage? replyTo;
  final int? forwardSourceId;
  final String? pendingAttachmentPath;
  final bool compressing;
  final bool sending;
  final bool voiceRecording;
  final bool draftTypingSignal;
  final String? sendErrorKey;
  final String? pinErrorKey;

  bool get hasAttach => pendingAttachmentPath != null;

  TeamChatComposerState copyWith({
    int? boundConversationId,
    bool clearBoundConversationId = false,
    TenantChatMessage? replyTo,
    bool clearReplyTo = false,
    int? forwardSourceId,
    bool clearForwardSourceId = false,
    String? pendingAttachmentPath,
    bool clearPendingAttachment = false,
    bool? compressing,
    bool? sending,
    bool? voiceRecording,
    bool? draftTypingSignal,
    String? sendErrorKey,
    bool clearSendError = false,
    String? pinErrorKey,
    bool clearPinError = false,
  }) {
    return TeamChatComposerState(
      boundConversationId: clearBoundConversationId
          ? null
          : (boundConversationId ?? this.boundConversationId),
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      forwardSourceId: clearForwardSourceId
          ? null
          : (forwardSourceId ?? this.forwardSourceId),
      pendingAttachmentPath: clearPendingAttachment
          ? null
          : (pendingAttachmentPath ?? this.pendingAttachmentPath),
      compressing: compressing ?? this.compressing,
      sending: sending ?? this.sending,
      voiceRecording: voiceRecording ?? this.voiceRecording,
      draftTypingSignal: draftTypingSignal ?? this.draftTypingSignal,
      sendErrorKey: clearSendError ? null : (sendErrorKey ?? this.sendErrorKey),
      pinErrorKey: clearPinError ? null : (pinErrorKey ?? this.pinErrorKey),
    );
  }

  @override
  List<Object?> get props => [
        boundConversationId,
        replyTo,
        forwardSourceId,
        pendingAttachmentPath,
        compressing,
        sending,
        voiceRecording,
        draftTypingSignal,
        sendErrorKey,
        pinErrorKey,
      ];
}
