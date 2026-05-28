import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/team_chat/cubit/team_chat_list_cubit.dart';
import '../../../features/team_chat/cubit/team_chat_list_state.dart';
import '../../../features/team_chat/cubit/team_chat_peer_presence_cubit.dart';
import '../../../features/team_chat/cubit/team_chat_peer_presence_state.dart';
import '../../../models/tenant_chat_models.dart';
import '../team_chat_common.dart';

String? teamChatThreadPresenceSubtitle({
  required TenantChatConversation? selected,
  required TenantChatPeerPresenceResponse? presenceResponse,
  required String Function(String key) tr,
}) {
  if (selected == null) return null;
  final r = presenceResponse;
  if (selected.isCompanyGroup) {
    if (r != null && r.isGroupMode && r.groupPeers.isNotEmpty) {
      final line = tenantChatGroupPresenceLine(r.groupPeers, tr);
      if (line != null && line.isNotEmpty) return line;
    }
    final mc = selected.memberCount ?? 0;
    final oc = selected.onlineCount ?? 0;
    return tr('teamChatGroupMembersOnline')
        .replaceAll('{memberCount}', '$mc')
        .replaceAll('{onlineCount}', '$oc');
  }
  if (r == null || r.isGroupMode) return null;
  final act = r.activity;
  if (act == null || act == kTenantChatPresenceIdle) return null;
  final ou = selected.otherUser;
  if (ou == null) return null;
  final name = tenantChatPeerName(ou);
  var key = 'teamChatPeerTyping';
  if (act == kTenantChatPresenceUploading) key = 'teamChatPeerUploading';
  if (act == kTenantChatPresenceRecording) key = 'teamChatPeerRecording';
  if (act == kTenantChatPresenceSending) key = 'teamChatPeerSending';
  return tr(key).replaceAll('{name}', name);
}

/// App bar / thread header subtitle driven only by list selection + presence poll.
class TeamChatPresenceSubtitle extends StatelessWidget {
  const TeamChatPresenceSubtitle({
    super.key,
    required this.companyRoomLabel,
    required this.tr,
  });

  final String companyRoomLabel;
  final String Function(String key) tr;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TeamChatListCubit, TeamChatListState,
        TenantChatConversation?>(
      selector: (s) => s.selectedConversation,
      builder: (context, selected) {
        return BlocSelector<TeamChatPeerPresenceCubit, TeamChatPeerPresenceState,
            TenantChatPeerPresenceResponse?>(
          selector: (s) => s.response,
          builder: (context, presence) {
            return Text(
              teamChatThreadPresenceSubtitle(
                    selected: selected,
                    presenceResponse: presence,
                    tr: tr,
                  ) ??
                  '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            );
          },
        );
      },
    );
  }
}
