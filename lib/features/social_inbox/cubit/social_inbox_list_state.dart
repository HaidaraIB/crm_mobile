import 'package:equatable/equatable.dart';

import '../../../models/social_conversation_model.dart';

enum SocialInboxListStatus { initial, loading, loaded, error, denied }

class SocialInboxListState extends Equatable {
  final SocialInboxListStatus status;
  final List<SocialConversationModel> conversations;
  final Map<String, int> statusCounts;
  final String channelFilter;
  final String statusFilter;
  final String search;
  final String? errorMessage;

  /// Localization key when the API answered 403 — not a retryable load failure.
  final String? deniedMessageKey;

  const SocialInboxListState({
    this.status = SocialInboxListStatus.initial,
    this.conversations = const [],
    this.statusCounts = const {},
    this.channelFilter = 'all',
    this.statusFilter = 'all',
    this.search = '',
    this.errorMessage,
    this.deniedMessageKey,
  });

  const SocialInboxListState.initial() : this();

  int get totalUnread =>
      conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  SocialInboxListState copyWith({
    SocialInboxListStatus? status,
    List<SocialConversationModel>? conversations,
    Map<String, int>? statusCounts,
    String? channelFilter,
    String? statusFilter,
    String? search,
    String? errorMessage,
    String? deniedMessageKey,
    bool clearError = false,
  }) {
    return SocialInboxListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      statusCounts: statusCounts ?? this.statusCounts,
      channelFilter: channelFilter ?? this.channelFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      search: search ?? this.search,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      deniedMessageKey: clearError ? null : (deniedMessageKey ?? this.deniedMessageKey),
    );
  }

  @override
  List<Object?> get props => [
        status,
        conversations,
        statusCounts,
        channelFilter,
        statusFilter,
        search,
        errorMessage,
        deniedMessageKey,
      ];
}
