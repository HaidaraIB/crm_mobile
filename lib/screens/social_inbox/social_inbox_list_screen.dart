import 'dart:async';

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
import '../../services/social_inbox_availability.dart';
import '../../utils/social_inbox_access.dart';
import '../../utils/whatsapp_message_body_localize.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/bidi_text.dart';
import '../../widgets/brand_icons.dart';
import '../../widgets/chat/chat_conversation_status_menu.dart';
import 'social_inbox_thread_screen.dart';
import 'package:crm_mobile/widgets/auto_dir_text_field.dart';

/// Hides the Inbox entry when plan or admin policy has the integration off.
/// Role checks stay at the call site; this only covers the digest gate.
class SocialInboxEntryGate extends StatelessWidget {
  const SocialInboxEntryGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: SocialInboxAvailability.available,
      builder: (context, available, _) {
        if (available == false) return const SizedBox.shrink();
        return child;
      },
    );
  }
}

/// Omni-Channel Inbox — Instagram DM + Messenger conversation list.
///
/// Sibling of the WhatsApp conversation list, but a row here is a conversation
/// rather than a lead: most are unconverted, and converting is the agent's job.
class SocialInboxListScreen extends StatelessWidget {
  const SocialInboxListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: SocialInboxAvailability.available,
      builder: (context, available, _) {
        if (available == false) return const _SocialInboxUnavailable();
        return BlocProvider(
          create: (_) =>
              SocialInboxListCubit(repository: ApiSocialInboxRepository())..bootstrap(),
          child: const _SocialInboxListView(),
        );
      },
    );
  }
}

class _SocialInboxUnavailable extends StatelessWidget {
  const _SocialInboxUnavailable();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    String t(String key) =>
        (localizations ?? AppLocalizations(const Locale('en'))).translate(key);
    return Scaffold(
      appBar: AppBar(title: Text(t('omniChannelInbox'))),
      body: _CenteredMessage(
        icon: Icons.lock_outline,
        title: t('socialInboxUnavailable'),
      ),
    );
  }
}

class _SocialInboxListView extends StatefulWidget {
  const _SocialInboxListView();

  @override
  State<_SocialInboxListView> createState() => _SocialInboxListViewState();
}

class _SocialInboxListViewState extends State<_SocialInboxListView> {
  static const _statusFilters = [
    'all',
    'open',
    'pending',
    'done',
    'snoozed',
    'spam',
    'invalid',
  ];

  UserModel? _user;

  @override
  void initState() {
    super.initState();
    ApiService().getCurrentUser().then((user) {
      if (mounted) setState(() => _user = user);
    }).catchError((_) => null);
  }

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
    final canDelete = canDeleteSocialHistory(_user);

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

          // Do not paint filter chips / empty counts until the first list
          // response is verified — same rule as WhatsApp chats.
          final awaitingFirstList = state.conversations.isEmpty &&
              (state.status == SocialInboxListStatus.initial ||
                  state.status == SocialInboxListStatus.loading);
          if (awaitingFirstList) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == SocialInboxListStatus.error &&
              state.conversations.isEmpty) {
            return _CenteredMessage(
              icon: Icons.error_outline,
              title: t('socialInboxCouldNotLoad'),
              action: TextButton(
                onPressed: () => cubit.refresh(),
                child: Text(t('retry')),
              ),
            );
          }

          return Column(
            children: [
              _Filters(
                t: t,
                channel: state.channelFilter,
                status: state.statusFilter,
                assignment: state.assignmentFilter,
                statusCounts: state.statusCounts,
                statusFilters: _statusFilters,
                onChannel: cubit.setChannel,
                onStatus: cubit.setStatus,
                onAssignment: cubit.setAssignment,
                onSearch: cubit.setSearch,
              ),
              if (state.conversations.isEmpty)
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
                        final tile = _ConversationTile(
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
                        if (!canDelete) return tile;
                        return Dismissible(
                          key: ValueKey('social-conv-${conversation.id}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    content: Text(t('deleteConversationConfirm')),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text(t('cancel')),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: Text(t('delete')),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          onDismissed: (_) {
                            unawaited(cubit.deleteConversation(conversation.id));
                          },
                          background: Container(
                            color: Colors.red,
                            alignment: AlignmentDirectional.centerEnd,
                            padding: const EdgeInsetsDirectional.only(end: 16),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: tile,
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
    required this.assignment,
    required this.statusCounts,
    required this.statusFilters,
    required this.onChannel,
    required this.onStatus,
    required this.onAssignment,
    required this.onSearch,
  });

  final String Function(String) t;
  final String channel;
  final String status;
  final String assignment;
  final Map<String, int> statusCounts;
  final List<String> statusFilters;
  final void Function(String) onChannel;
  final void Function(String) onStatus;
  final void Function(String) onAssignment;
  final void Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AutoDirTextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: t('search'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          _AssignmentChips(
            t: t,
            assignment: assignment,
            onAssignment: onAssignment,
          ),
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
                      showCheckmark: false,
                      avatar: entry[0] == 'all'
                          ? null
                          : socialChannelBrandIcon(entry[0], size: 16),
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
        ? localizeWhatsAppListPreview(rawPreview, t)
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
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.outlineVariant,
                          width: 1.25,
                        ),
                      ),
                      child: socialChannelBrandIcon(
                        conversation.channel,
                        size: 12,
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
                          child: IsolatedText(
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
                        if (conversation.assignedToName.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            conversation.assignedToName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryAccent(scheme.brightness),
                            ),
                          ),
                        ],
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: unread > 0
                                  ? AppTheme.primaryAccent(scheme.brightness)
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
                          child: IsolatedText(
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

class _AssignmentChips extends StatefulWidget {
  const _AssignmentChips({
    required this.t,
    required this.assignment,
    required this.onAssignment,
  });

  final String Function(String) t;
  final String assignment;
  final void Function(String) onAssignment;

  @override
  State<_AssignmentChips> createState() => _AssignmentChipsState();
}

class _AssignmentChipsState extends State<_AssignmentChips> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    ApiService().getCurrentUser().then((user) {
      if (mounted) setState(() => _user = user);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (!userSeesAllSocialConversations(_user)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in const [
              ['all', 'all'],
              ['mine', 'chatFilterAssignedToMe'],
              ['unassigned', 'chatFilterUnassigned'],
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ChoiceChip(
                  label: Text(widget.t(entry[1])),
                  selected: widget.assignment == entry[0],
                  onSelected: (_) => widget.onAssignment(entry[0]),
                ),
              ),
          ],
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

class _SocialContactAvatar extends StatelessWidget {
  const _SocialContactAvatar({
    required this.displayName,
    required this.profilePicUrl,
  });

  final String displayName;
  final String profilePicUrl;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      radius: 26,
      imageUrl: profilePicUrl,
      initials: appAvatarInitials(displayName),
    );
  }
}
