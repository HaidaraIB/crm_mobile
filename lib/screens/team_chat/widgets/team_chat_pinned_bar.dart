import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../features/team_chat/cubit/team_chat_list_cubit.dart';
import '../../../features/team_chat/cubit/team_chat_list_state.dart';
import '../../../models/tenant_chat_models.dart';

class TeamChatPinnedBar extends StatelessWidget {
  const TeamChatPinnedBar({
    super.key,
    required this.onJumpToPinned,
    required this.onUnpin,
  });

  final ValueChanged<int> onJumpToPinned;
  final ValueChanged<int> onUnpin;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;

    return BlocSelector<TeamChatListCubit, TeamChatListState,
        List<TenantChatPinnedMessageSummary>>(
      selector: (s) => s.selectedConversation?.pinnedMessages ?? const [],
      builder: (context, pinned) {
        if (pinned.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Material(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.only(bottom: 4),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                t('teamChatPinnedHeader'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              children: pinned.map((p) {
                return ListTile(
                  dense: true,
                  title: Text(p.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => onJumpToPinned(p.messageId),
                  trailing: IconButton(
                    icon: const Icon(Icons.push_pin_outlined),
                    onPressed: () => onUnpin(p.messageId),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
