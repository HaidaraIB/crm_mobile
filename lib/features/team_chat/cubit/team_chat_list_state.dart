import 'package:equatable/equatable.dart';

import '../../../models/tenant_chat_models.dart';

class TeamChatListState extends Equatable {
  const TeamChatListState({
    required this.conversations,
    required this.selectedId,
    required this.loadingConv,
    required this.loadError,
    required this.readCursor,
    required this.currentUserId,
  });

  const TeamChatListState.initial()
      : conversations = const [],
        selectedId = null,
        loadingConv = true,
        loadError = null,
        readCursor = 0,
        currentUserId = null;

  final List<TenantChatConversation> conversations;
  final int? selectedId;
  final bool loadingConv;
  final String? loadError;
  final int readCursor;
  final int? currentUserId;

  TenantChatConversation? get selectedConversation {
    final id = selectedId;
    if (id == null) return null;
    for (final c in conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  TeamChatListState copyWith({
    List<TenantChatConversation>? conversations,
    int? selectedId,
    bool clearSelectedId = false,
    bool? loadingConv,
    String? loadError,
    bool clearLoadError = false,
    int? readCursor,
    int? currentUserId,
  }) {
    return TeamChatListState(
      conversations: conversations ?? this.conversations,
      selectedId: clearSelectedId ? null : (selectedId ?? this.selectedId),
      loadingConv: loadingConv ?? this.loadingConv,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      readCursor: readCursor ?? this.readCursor,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  @override
  List<Object?> get props => [
        conversations,
        selectedId,
        loadingConv,
        loadError,
        readCursor,
        currentUserId,
      ];
}
