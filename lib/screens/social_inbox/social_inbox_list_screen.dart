import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_locales.dart';
import '../../features/social_inbox/cubit/social_inbox_list_cubit.dart';
import '../../features/social_inbox/cubit/social_inbox_list_state.dart';
import '../../features/social_inbox/social_inbox_repository.dart';
import '../../models/social_conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/social_inbox_access.dart';
import '../../utils/social_message_body_localize.dart';
import '../../widgets/chat/chat_conversation_status_menu.dart';
import 'social_inbox_thread_screen.dart';

/// Omni-Channel Inbox — Instagram DM + Messenger conversation list.
///
/// Sibling of the WhatsApp conversation list, but a row here is a conversation
/// rather than a lead: most are unconverted, and converting is the agent's job.
class SocialInboxListScreen extends StatelessWidget {
  const SocialInboxListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          SocialInboxListCubit(repository: ApiSocialInboxRepository())..bootstrap(),
      child: const _SocialInboxListView(),
    );
  }
}

class _SocialInboxListView extends StatelessWidget {
  const _SocialInboxListView();

  static const _statusFilters = [
    'all',
    'open',
    'pending',
    'done',
    'snoozed',
    'spam',
    'invalid',
  ];

  String _timeLabel(BuildContext context, DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year && local.month == now.month && local.day == now.day;
    final tag = AppLocales.intlDateFormat(
      AppLocalizations.of(context)?.locale ?? AppLocales.english,
    );
    final raw =
        sameDay ? DateFormat.Hm(tag).format(local) : DateFormat.MMMd(tag).format(local);
    return withLatinDigits(raw);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    String t(String key) =>
        (localizations ?? AppLocalizations(const Locale('en'))).translate(key);

    return Scaffold(
      appBar: AppBar(title: Text(t('omniChannelInbox'))),
      body: BlocBuilder<SocialInboxListCubit, SocialInboxListState>(
        builder: (context, state) {
          final cubit = context.read<SocialInboxListCubit>();

          // A 403 is a permanent answer for this user — explain, do not offer Retry.
          if (state.status == SocialInboxListStatus.denied) {
            return _CenteredMessage(
              icon: Icons.lock_outline,
              title: t(state.deniedMessageKey ?? 'socialInboxUnavailable'),
            );
          }

          return Column(
            children: [
              _Filters(
                t: t,
                channel: state.channelFilter,
                status: state.statusFilter,
                statusCounts: state.statusCounts,
                statusFilters: _statusFilters,
                onChannel: cubit.setChannel,
                onStatus: cubit.setStatus,
                onSearch: cubit.setSearch,
              ),
              if (state.status == SocialInboxListStatus.loading &&
                  state.conversations.isEmpty)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (state.status == SocialInboxListStatus.error &&
                  state.conversations.isEmpty)
                Expanded(
                  child: _CenteredMessage(
                    icon: Icons.error_outline,
                    title: t('socialInboxCouldNotLoad'),
                    action: TextButton(
                      onPressed: () => cubit.refresh(),
                      child: Text(t('retry')),
                    ),
                  ),
                )
              else if (state.conversations.isEmpty)
                Expanded(
                  child: _EmptyInboxMessage(t: t),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => cubit.refresh(),
                    child: ListView.separated(
                      itemCount: state.conversations.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 88,
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.2),
                      ),
                      itemBuilder: (context, index) {
                        final conversation = state.conversations[index];
                        return _ConversationTile(
                          conversation: conversation,
                          t: t,
                          timeLabel: _timeLabel(context, conversation.lastMessageAt),
                          onTap: () async {
                            cubit.markReadLocally(conversation.id);
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SocialInboxThreadScreen(
                                  conversation: conversation,
                                ),
                              ),
                            );
                            if (context.mounted) cubit.refresh(silent: true);
                          },
                          onLongPress: () => _showStatusActions(
                            context,
                            cubit: cubit,
                            conversation: conversation,
                            t: t,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showStatusActions(
  BuildContext context, {
  required SocialInboxListCubit cubit,
  required SocialConversationModel conversation,
  required String Function(String) t,
}) async {
  final change = await showChatConversationStatusSheet(
    context: context,
    t: t,
    isStarred: conversation.isStarred,
    isUnsubscribed: conversation.isUnsubscribed,
  );
  if (change == null || !context.mounted) return;
  await cubit.updateConversationState(
    conversationId: conversation.id,
    status: change.status,
    snoozedUntil: change.snoozedUntil,
    isStarred: change.isStarred,
    isUnsubscribed: change.isUnsubscribed,
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.t,
    required this.channel,
    required this.status,
    required this.statusCounts,
    required this.statusFilters,
    required this.onChannel,
    required this.onStatus,
    required this.onSearch,
  });

  final String Function(String) t;
  final String channel;
  final String status;
  final Map<String, int> statusCounts;
  final List<String> statusFilters;
  final void Function(String) onChannel;
  final void Function(String) onStatus;
  final void Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: t('search'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const [
                  ['all', 'allChannels'],
                  ['instagram', 'instagramDirect'],
                  ['messenger', 'facebookMessenger'],
                  ['whatsapp', 'whatsapp'],
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(t(entry[1])),
                      selected: channel == entry[0],
                      onSelected: (_) => onChannel(entry[0]),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in statusFilters)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: FilterChip(
                      label: Text(
                        value == 'all'
                            ? t('all')
                            : '${t('socialStatus_$value')}'
                                '${(statusCounts[value] ?? 0) > 0 ? ' (${statusCounts[value]})' : ''}',
                      ),
                      selected: status == value,
                      onSelected: (_) => onStatus(value),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout mirrors [TeamChatConversationRow] / WhatsApp list tiles: avatar,
/// title + time, preview + unread — so the three chat lists read as one product.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.t,
    required this.timeLabel,
    required this.onTap,
    this.onLongPress,
  });

  final SocialConversationModel conversation;
  final String Function(String) t;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = conversation.contact.label;
    final unread = conversation.unreadCount;
    final rawPreview = conversation.lastMessagePreview.trim();
    final preview = rawPreview.isNotEmpty
        ? localizeSocialMessageBody(rawPreview, null, false, t)
        : t(
            conversation.isWhatsapp
                ? 'whatsapp'
                : conversation.isInstagram
                    ? 'instagramDirect'
                    : 'facebookMessenger',
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _SocialContactAvatar(
                    displayName: label,
                    profilePicUrl: conversation.contact.profilePicUrl,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 1),
                      ),
                      child: Icon(
                        conversation.isInstagram
                            ? Icons.camera_alt_outlined
                            : conversation.isWhatsapp
                                ? Icons.phone_android_outlined
                                : Icons.chat_bubble_outline,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: unread > 0
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              color: unread > 0
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              fontWeight:
                                  unread > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (conversation.isConverted) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t('convertedToLead'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyInboxMessage extends StatefulWidget {
  const _EmptyInboxMessage({required this.t});

  final String Function(String) t;

  @override
  State<_EmptyInboxMessage> createState() => _EmptyInboxMessageState();
}

class _EmptyInboxMessageState extends State<_EmptyInboxMessage> {
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ApiService().getCurrentUser();
      if (mounted) setState(() => _currentUser = user);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.forum_outlined,
      title: widget.t('noSocialConversations'),
      subtitle: widget.t(socialInboxEmptyHintKey(_currentUser)),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

class _SocialContactAvatar extends StatefulWidget {
  const _SocialContactAvatar({
    required this.displayName,
    required this.profilePicUrl,
  });

  final String displayName;
  final String profilePicUrl;

  @override
  State<_SocialContactAvatar> createState() => _SocialContactAvatarState();
}

class _SocialContactAvatarState extends State<_SocialContactAvatar> {
  bool _imageFailed = false;

  String _initials() {
    final parts = widget.displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = widget.profilePicUrl.trim();
    if (url.isNotEmpty && !_imageFailed) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {
          if (mounted) setState(() => _imageFailed = true);
        },
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
      child: Text(
        _initials(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
      ),
    );
  }
}
