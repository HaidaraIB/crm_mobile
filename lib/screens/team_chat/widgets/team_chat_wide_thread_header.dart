import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/team_chat/cubit/team_chat_peer_presence_cubit.dart';
import '../../../features/team_chat/cubit/team_chat_peer_presence_state.dart';
import '../../../models/tenant_chat_models.dart';
import '../team_chat_common.dart';
import '../team_chat_conversation_tile.dart';
import 'team_chat_presence_subtitle.dart';

class TeamChatWideThreadHeader extends StatelessWidget {
  const TeamChatWideThreadHeader({
    super.key,
    required this.conversation,
    required this.companyRoomLabel,
    required this.tr,
  });

  final TenantChatConversation conversation;
  final String companyRoomLabel;
  final String Function(String key) tr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: BlocSelector<TeamChatPeerPresenceCubit, TeamChatPeerPresenceState,
            TenantChatPeerPresenceResponse?>(
          selector: (s) => s.response,
          builder: (context, presence) {
            final subtitle = teamChatThreadPresenceSubtitle(
              selected: conversation,
              presenceResponse: presence,
              tr: tr,
            );
            if (conversation.isCompanyGroup) {
              return TeamChatGroupThreadAppBarTitle(
                title: tenantChatConversationTitle(conversation, companyRoomLabel),
                avatarLetters:
                    tenantChatConversationAvatarLetters(conversation, companyRoomLabel),
                subtitle: subtitle,
                onPrimaryBackground: false,
              );
            }
            final ou = conversation.otherUser;
            if (ou == null) return const SizedBox.shrink();
            return TeamChatThreadAppBarTitle(
              peer: ou,
              subtitle: subtitle,
              onPrimaryBackground: false,
            );
          },
        ),
      ),
    );
  }
}
