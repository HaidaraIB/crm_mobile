import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/app_locales.dart';
import '../../../features/team_chat/cubit/team_chat_list_cubit.dart';
import '../../../features/team_chat/cubit/team_chat_list_state.dart';
import '../../../models/tenant_chat_models.dart';
import '../team_chat_common.dart';
import '../team_chat_conversation_tile.dart';

DateTime _startOfLocalDay(DateTime d) =>
    DateTime(d.year, d.month, d.day);

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _conversationRowTime(TenantChatConversation c, String lang) {
  final raw = c.lastMessage?.createdAt ?? c.updatedAt;
  if (raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw);
    final now = DateTime.now();
    final intlLoc = AppLocales.intlDateFormat(AppLocales.fromLanguageCode(lang));
    if (_dayKey(_startOfLocalDay(dt)) == _dayKey(_startOfLocalDay(now))) {
      return DateFormat.Hm(intlLoc).format(dt);
    }
    if (dt.year == now.year) {
      return DateFormat.MMMd(intlLoc).format(dt);
    }
    return DateFormat.yMMMd(intlLoc).format(dt);
  } catch (_) {
    return '';
  }
}

class TeamChatConversationList extends StatelessWidget {
  const TeamChatConversationList({
    super.key,
    required this.wide,
    required this.lang,
    required this.onSelect,
    required this.onNewChat,
  });

  final bool wide;
  final String lang;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;

    return BlocBuilder<TeamChatListCubit, TeamChatListState>(
      buildWhen: (prev, next) =>
          prev.conversations != next.conversations ||
          prev.selectedId != next.selectedId ||
          prev.loadingConv != next.loadingConv,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: onNewChat,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: Text(t('teamChatNewConversation')),
                  ),
                ),
              ),
            Expanded(
              child: state.loadingConv
                  ? const Center(child: CircularProgressIndicator())
                  : state.conversations.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              t('teamChatSelectThread'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: state.conversations.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 88,
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.2),
                          ),
                          itemBuilder: (ctx, i) {
                            final c = state.conversations[i];
                            final active = c.id == state.selectedId;
                            final preview = c.lastMessage?.body ?? '';
                            final companyRoom = t('teamChatCompanyRoom');
                            return TeamChatConversationRow(
                              conversation: c,
                              selected: active,
                              previewText: preview.isEmpty
                                  ? t('teamChatNoMessagesYet')
                                  : preview,
                              timeLabel: _conversationRowTime(c, lang),
                              titleText: tenantChatConversationTitle(
                                c,
                                companyRoom,
                              ),
                              avatarLetters: tenantChatConversationAvatarLetters(
                                c,
                                companyRoom,
                              ),
                              showOnlineDot: !c.isCompanyGroup &&
                                  (c.otherUser?.isOnline == true),
                              onTap: () => onSelect(c.id),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
