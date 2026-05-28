import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/tenant_chat_models.dart';
import '../../../screens/team_chat/team_chat_common.dart';

class TeamChatNewPeerState {
  const TeamChatNewPeerState({
    required this.peers,
    required this.query,
    required this.filtered,
  });

  final List<TenantChatPeer> peers;
  final String query;
  final List<TenantChatPeer> filtered;
}

class TeamChatNewPeerCubit extends Cubit<TeamChatNewPeerState> {
  TeamChatNewPeerCubit({
    required List<TenantChatPeer> peers,
    required this.tr,
  })  : _peers = peers,
        super(
          TeamChatNewPeerState(
            peers: peers,
            query: '',
            filtered: peers,
          ),
        );

  final List<TenantChatPeer> _peers;
  final String Function(String key) tr;
  Timer? _debounce;

  void setQuery(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final q = raw.trim().toLowerCase();
      if (q.isEmpty) {
        emit(TeamChatNewPeerState(peers: _peers, query: '', filtered: _peers));
        return;
      }
      final filtered = _peers.where((p) {
        final name = tenantChatPeerName(p).toLowerCase();
        final un = p.username.toLowerCase();
        final role = tenantChatPeerRoleLabel(p.role, tr).toLowerCase();
        return name.contains(q) || un.contains(q) || role.contains(q);
      }).toList();
      emit(TeamChatNewPeerState(peers: _peers, query: q, filtered: filtered));
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
