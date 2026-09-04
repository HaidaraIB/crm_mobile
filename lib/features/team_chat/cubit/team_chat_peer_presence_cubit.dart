import 'dart:async';

import '../../../services/realtime_channel.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/tenant_chat_models.dart';
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
  Timer? _expiryTimer;
  StreamSubscription<RealtimePresence>? _presenceSub;
  StreamSubscription<bool>? _statusSub;
  int? _subscribedId;
  int? _currentUserId;

  /// Needed only to recognise this connection's own echoed frames.
  ///
  /// The server sends a presence frame to everyone in the conversation group
  /// including its author, deliberately — a second tab of the same user has to
  /// see it. Here it would just mean an HTTP round trip per keystroke of this
  /// user's own typing, for a response that never mentions them.
  void setCurrentUserId(int? userId) {
    _currentUserId = userId;
  }

  void bindConversation(int? conversationId) {
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    _unsubscribeSocket();
    if (conversationId == null) {
      emit(const TeamChatPeerPresenceState.initial());
      return;
    }
    _subscribeSocket(conversationId);
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

  /// Typing indicators: 2.6s normally, 30s while the socket is up.
  ///
  /// Presence is ephemeral and changes at keystroke rate, so polling it is the
  /// worst-value request in the app — most answers are "still nothing". With a
  /// connection every change arrives as a frame instead, whichever transport the
  /// peer used to report it, so this becomes a backstop against a socket that is
  /// open yet silently not delivering.
  ///
  /// Not removed: with no socket this is the only source of the indicator, and
  /// it reverts to its original cadence automatically.
  Duration get _pollInterval => RealtimeChannel.instance.isConnected
      ? const Duration(seconds: 30)
      : const Duration(milliseconds: 2600);

  void _startPolling() {
    if (!_isForeground() || state.boundConversationId == null) return;
    _pollTimer?.cancel();
    unawaited(_pollOnce());
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollOnce());
    });
  }

  /// Receive typing/recording over the socket instead of asking for it.
  ///
  /// Presence is ephemeral and changes at keystroke rate, so polling it is the
  /// worst-value request in the app — nearly every answer is "still nothing".
  /// A frame arrives the instant the peer starts typing.
  ///
  /// The poll below is not removed, only slowed: a socket that is open but
  /// silently not delivering is a failure this client cannot detect on its own,
  /// and with no socket the poll is the only source of the indicator at all.
  void _subscribeSocket(int conversationId) {
    _subscribedId = conversationId;
    RealtimeChannel.instance.subscribeConversation(conversationId);

    _presenceSub = RealtimeChannel.instance.presence.listen((event) {
      if (event.conversationId != state.boundConversationId) return;
      if (_currentUserId != null && event.userId == _currentUserId) return;
      // Re-read through the endpoint rather than reconstructing the payload
      // here: the response carries peer names and role for the group case, and
      // a frame carries only an id. One request per real change still beats one
      // every 2.6 seconds regardless of whether anything happened.
      unawaited(_pollOnce());
      _scheduleExpiryRecheck(event.state);
    });

    // Tighten the fallback the moment delivery stops, rather than waiting out
    // the backed-off interval.
    _statusSub = RealtimeChannel.instance.connectionChanges.listen((_) {
      if (state.boundConversationId != null) _startPolling();
    });
  }

  /// Clear an indicator whose owner stopped without saying so.
  ///
  /// Presence has no "stopped" event when an app is killed or backgrounded
  /// mid-sentence, and the server simply lets the key expire after 12s. While the
  /// socket is up the fallback poll is 30s, so without this a peer could appear
  /// to be typing for half a minute after they had gone. One read just past the
  /// TTL settles it.
  void _scheduleExpiryRecheck(String state) {
    _expiryTimer?.cancel();
    if (state == kTenantChatPresenceIdle) return;
    _expiryTimer = Timer(const Duration(seconds: 13), () {
      unawaited(_pollOnce());
    });
  }

  void _unsubscribeSocket() {
    final id = _subscribedId;
    if (id != null) RealtimeChannel.instance.unsubscribeConversation(id);
    _subscribedId = null;
    _presenceSub?.cancel();
    _presenceSub = null;
    _statusSub?.cancel();
    _statusSub = null;
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
    _expiryTimer?.cancel();
    _unsubscribeSocket();
    return super.close();
  }
}
