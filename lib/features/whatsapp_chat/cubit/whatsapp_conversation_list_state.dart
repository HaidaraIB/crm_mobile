import 'package:equatable/equatable.dart';

import '../../../models/whatsapp_conversation_model.dart';

class WhatsAppChatListFilters extends Equatable {
  const WhatsAppChatListFilters({
    this.status = 'open',
    this.assignment = 'all',
    this.agentId,
    this.starred = false,
    this.unreplied = false,
    this.search = '',
  });

  final String status;
  final String assignment;
  final int? agentId;
  final bool starred;
  final bool unreplied;
  final String search;

  bool get isDefault =>
      status == 'open' &&
      assignment == 'all' &&
      agentId == null &&
      !starred &&
      !unreplied &&
      search.trim().isEmpty;

  WhatsAppChatListFilters copyWith({
    String? status,
    String? assignment,
    int? agentId,
    bool? starred,
    bool? unreplied,
    String? search,
    bool clearAgent = false,
  }) {
    return WhatsAppChatListFilters(
      status: status ?? this.status,
      assignment: assignment ?? this.assignment,
      agentId: clearAgent ? null : (agentId ?? this.agentId),
      starred: starred ?? this.starred,
      unreplied: unreplied ?? this.unreplied,
      search: search ?? this.search,
    );
  }

  @override
  List<Object?> get props =>
      [status, assignment, agentId, starred, unreplied, search];
}

class WhatsAppConversationListState extends Equatable {
  const WhatsAppConversationListState({
    required this.conversations,
    required this.loading,
    required this.loadError,
    required this.unavailableCode,
    required this.filters,
    required this.statusCounts,
    required this.assignmentCounts,
  });

  const WhatsAppConversationListState.initial()
      : conversations = const [],
        loading = true,
        loadError = null,
        unavailableCode = null,
        filters = const WhatsAppChatListFilters(),
        statusCounts = const {},
        assignmentCounts = const {};

  final List<WhatsAppConversationModel> conversations;
  final bool loading;
  final String? loadError;
  /// Non-null when chats are gated (403). Not a retryable load failure.
  final String? unavailableCode;
  final WhatsAppChatListFilters filters;
  final Map<String, int> statusCounts;
  final Map<String, int> assignmentCounts;

  WhatsAppConversationListState copyWith({
    List<WhatsAppConversationModel>? conversations,
    bool? loading,
    String? loadError,
    String? unavailableCode,
    WhatsAppChatListFilters? filters,
    Map<String, int>? statusCounts,
    Map<String, int>? assignmentCounts,
    bool clearLoadError = false,
    bool clearUnavailable = false,
  }) {
    return WhatsAppConversationListState(
      conversations: conversations ?? this.conversations,
      loading: loading ?? this.loading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      unavailableCode:
          clearUnavailable ? null : (unavailableCode ?? this.unavailableCode),
      filters: filters ?? this.filters,
      statusCounts: statusCounts ?? this.statusCounts,
      assignmentCounts: assignmentCounts ?? this.assignmentCounts,
    );
  }

  @override
  List<Object?> get props => [
        conversations,
        loading,
        loadError,
        unavailableCode,
        filters,
        statusCounts,
        assignmentCounts,
      ];
}
