import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../features/team_chat/cubit/team_chat_list_cubit.dart';
import '../../../features/team_chat/cubit/team_chat_list_state.dart';
import '../../../models/tenant_chat_models.dart';
import '../team_chat_thread_pane.dart';
import 'team_chat_composer_section.dart';
import 'team_chat_pinned_bar.dart';
import 'team_chat_wide_thread_header.dart';

class TeamChatThreadColumn extends StatelessWidget {
  const TeamChatThreadColumn({
    super.key,
    required this.threadPaneKey,
    required this.draft,
    required this.lang,
    required this.wide,
    required this.onReply,
    required this.onForward,
    required this.onPin,
    required this.onJumpToPinned,
    required this.onUnpin,
    required this.onToggleVoice,
  });

  final GlobalKey<TeamChatThreadPaneState> threadPaneKey;
  final TextEditingController draft;
  final String lang;
  final bool wide;
  final void Function(TenantChatMessage message) onReply;
  final void Function(TenantChatMessage message) onForward;
  final void Function(TenantChatMessage message) onPin;
  final void Function(int messageId) onJumpToPinned;
  final void Function(int messageId) onUnpin;
  final Future<void> Function() onToggleVoice;

  String _t(BuildContext context, String key) {
    final loc = AppLocalizations.of(context);
    return loc?.translate(key) ?? key;
  }

  @override
  Widget build(BuildContext context) {
    String tr(String k) => _t(context, k);

    return BlocBuilder<TeamChatListCubit, TeamChatListState>(
      buildWhen: (prev, next) =>
          prev.selectedId != next.selectedId ||
          prev.currentUserId != next.currentUserId ||
          prev.readCursor != next.readCursor ||
          prev.selectedConversation != next.selectedConversation,
      builder: (context, listState) {
        if (listState.selectedId == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tr('teamChatSelectThread'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final selected = listState.selectedConversation;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide && selected != null)
              TeamChatWideThreadHeader(
                conversation: selected,
                companyRoomLabel: tr('teamChatCompanyRoom'),
                tr: tr,
              ),
            TeamChatPinnedBar(
              onJumpToPinned: onJumpToPinned,
              onUnpin: onUnpin,
            ),
            Expanded(
              child: listState.currentUserId == null
                  ? const Center(child: CircularProgressIndicator())
                  : TeamChatThreadPane(
                      key: threadPaneKey,
                      conversationId: listState.selectedId!,
                      currentUserId: listState.currentUserId!,
                      isCompanyGroup: selected?.isCompanyGroup ?? false,
                      readCursor: listState.readCursor,
                      serverUnreadCount: selected?.unreadCount ?? 0,
                      lang: lang,
                      onReadCursorAdvanced: (id) {
                        context.read<TeamChatListCubit>().advanceReadCursor(id);
                      },
                      onReply: onReply,
                      onForward: onForward,
                      onPin: onPin,
                      onJumpToPinned: onJumpToPinned,
                    ),
            ),
            TeamChatComposerSection(
              draft: draft,
              onScrollToBottom: ({bool animated = true}) =>
                  threadPaneKey.currentState?.scrollToBottom(
                        animated: animated,
                      ) ??
                  Future.value(),
              onToggleVoice: onToggleVoice,
            ),
          ],
        );
      },
    );
  }
}
