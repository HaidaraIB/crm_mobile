import 'package:equatable/equatable.dart';

import '../../../models/social_conversation_model.dart';
import '../../../models/social_message_model.dart';

enum SocialThreadStatus { initial, loading, loaded, error }

class SocialInboxThreadState extends Equatable {
  final SocialThreadStatus status;
  final List<SocialMessageModel> messages;
  final SocialSendWindow window;
  final bool isSending;
  final String? errorMessage;

  /// Localization key for a send failure, so the UI can explain *why*
  /// (closed window, opted-out contact, expired token) instead of a generic retry.
  final String? sendErrorKey;
  final SocialConversationModel? conversation;

  /// First bootstrap has resolved messages + send window together.
  ///
  /// Until true, the thread must not paint composer chrome — [SocialSendWindow]
  /// defaults to closed, which would flash the Meta reply-lock banner and a
  /// disabled composer before the API answers.
  final bool composerReady;

  const SocialInboxThreadState({
    this.status = SocialThreadStatus.initial,
    this.messages = const [],
    this.window = const SocialSendWindow(),
    this.isSending = false,
    this.errorMessage,
    this.sendErrorKey,
    this.conversation,
    this.composerReady = false,
  });

  const SocialInboxThreadState.initial() : this();

  bool get requiresTemplate => window.requiresTemplate;

  bool get composerBlocked => !window.open && !requiresTemplate;

  SocialInboxThreadState copyWith({
    SocialThreadStatus? status,
    List<SocialMessageModel>? messages,
    SocialSendWindow? window,
    bool? isSending,
    String? errorMessage,
    String? sendErrorKey,
    SocialConversationModel? conversation,
    bool? composerReady,
    bool clearError = false,
  }) {
    return SocialInboxThreadState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      window: window ?? this.window,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sendErrorKey: clearError ? null : (sendErrorKey ?? this.sendErrorKey),
      conversation: conversation ?? this.conversation,
      composerReady: composerReady ?? this.composerReady,
    );
  }

  @override
  List<Object?> get props => [
        status,
        messages,
        window.open,
        window.mode,
        window.expiresAt,
        window.requiresTemplate,
        isSending,
        errorMessage,
        sendErrorKey,
        composerReady,
        conversation?.id,
        conversation?.clientId,
        conversation?.status,
        conversation?.isStarred,
        conversation?.isUnsubscribed,
        conversation?.snoozedUntil,
      ];
}
