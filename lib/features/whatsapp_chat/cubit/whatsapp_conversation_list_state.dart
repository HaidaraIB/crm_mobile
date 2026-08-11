import 'package:equatable/equatable.dart';

import '../../../models/whatsapp_conversation_model.dart';

class WhatsAppConversationListState extends Equatable {
  const WhatsAppConversationListState({
    required this.conversations,
    required this.loading,
    required this.loadError,
  });

  const WhatsAppConversationListState.initial()
      : conversations = const [],
        loading = true,
        loadError = null;

  final List<WhatsAppConversationModel> conversations;
  final bool loading;
  final String? loadError;

  WhatsAppConversationListState copyWith({
    List<WhatsAppConversationModel>? conversations,
    bool? loading,
    String? loadError,
    bool clearLoadError = false,
  }) {
    return WhatsAppConversationListState(
      conversations: conversations ?? this.conversations,
      loading: loading ?? this.loading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }

  @override
  List<Object?> get props => [conversations, loading, loadError];
}
