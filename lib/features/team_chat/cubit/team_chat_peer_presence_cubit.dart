import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../screens/team_chat/team_chat_common.dart';
import '../team_chat_repository.dart';
import 'team_chat_peer_presence_state.dart';

class TeamChatPeerPresenceCubit extends Cubit<TeamChatPeerPresenceState> {
  TeamChatPeerPresenceCubit({
    required TeamChatRepository repository,
    bool Function()? isForeground,
  })  : _repository = repository,
        _isForeground = isForeground ?? (() => true),
        super(const TeamChatPeerPresenceState.initial());

  final TeamChatRepository _repository;
  final bool Function() _isForeground;
  Timer? _pollTimer;

  void bindConversation(int? conversationId) {
    _pollTimer?.cancel();
    if (conversationId == null) {
      emit(const TeamChatPeerPresenceState.initial());
      return;
    }
    emit(
      TeamChatPeerPresenceState(
        boundConversationId: conversationId,
        response: null,
      ),
    );
    _startPolling();
  }

  void setForeground(bool foreground) {
    if (!foreground) {
      _pollTimer?.cancel();
      _pollTimer = null;
    } else if (state.boundConversationId != null && _pollTimer == null) {
      _startPolling();
    }
  }

  void _startPolling() {
    if (!_isForeground() || state.boundConversationId == null) return;
    _pollTimer?.cancel();
    unawaited(_pollOnce());
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      unawaited(_pollOnce());
    });
  }

  Future<void> _pollOnce() async {
    final id = state.boundConversationId;
    if (id == null || !_isForeground()) return;
    final r = await _repository.getPeerPresence(id);
    if (state.boundConversationId != id) return;
    if (tenantChatPresenceResponsesEqual(state.response, r)) return;
    emit(state.copyWith(response: r));
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
