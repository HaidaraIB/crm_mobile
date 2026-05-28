import 'package:equatable/equatable.dart';

import '../../../models/tenant_chat_models.dart';

class TeamChatPeerPresenceState extends Equatable {
  const TeamChatPeerPresenceState({
    required this.boundConversationId,
    required this.response,
  });

  const TeamChatPeerPresenceState.initial()
      : boundConversationId = null,
        response = null;

  final int? boundConversationId;
  final TenantChatPeerPresenceResponse? response;

  TeamChatPeerPresenceState copyWith({
    int? boundConversationId,
    bool clearBoundConversationId = false,
    TenantChatPeerPresenceResponse? response,
    bool clearResponse = false,
  }) {
    return TeamChatPeerPresenceState(
      boundConversationId: clearBoundConversationId
          ? null
          : (boundConversationId ?? this.boundConversationId),
      response: clearResponse ? null : (response ?? this.response),
    );
  }

  @override
  List<Object?> get props => [boundConversationId, response];
}
