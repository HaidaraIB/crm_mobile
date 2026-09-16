import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_locales.dart';
import '../../features/whatsapp_chat/cubit/whatsapp_conversation_list_cubit.dart';
import '../../features/whatsapp_chat/cubit/whatsapp_conversation_list_state.dart';
import '../../features/whatsapp_chat/whatsapp_chat_repository.dart';
import '../../models/user_model.dart';
import '../../models/whatsapp_conversation_model.dart';
import '../../services/api_service.dart';
import '../../utils/whatsapp_access.dart';
import '../../utils/whatsapp_message_body_localize.dart';
import '../../widgets/chat/chat_conversation_status_menu.dart';
import '../../widgets/whatsapp_chat/whatsapp_access_guard.dart';
import '../../widgets/whatsapp_chat/whatsapp_chat_theme.dart';
import '../../widgets/whatsapp_chat/whatsapp_phone_text.dart';
import 'whatsapp_chat_thread_screen.dart';
import 'whatsapp_start_conversation_screen.dart';

class WhatsAppConversationListScreen extends StatefulWidget {
  const WhatsAppConversationListScreen({super.key});

  @override
  State<WhatsAppConversationListScreen> createState() =>
      _WhatsAppConversationListScreenState();
}

class _WhatsAppConversationListScreenState
    extends State<WhatsAppConversationListScreen> with WidgetsBindingObserver {
  UserModel? _user;
  bool _foreground = true;
  int? _openedClientId;
  WhatsAppConversationListCubit? _cubit;
  bool _userLoadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit?.close();
    _cubit = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  Future<void> _bootstrap() async {
    try {
      final u = await ApiService().getCurrentUser();
      if (!mounted) return;
      final includeManual = canOpenManualWhatsAppChats(u);
      final cubit = WhatsAppConversationListCubit(
        repository: ApiWhatsAppChatRepository(),
        isForeground: () => _foreground,
        includeManualChats: includeManual,
      )..bootstrap();
      setState(() {
        _user = u;
        _cubit = cubit;
        _userLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Still open chats; manuals only for confirmed admins.
      final cubit = WhatsAppConversationListCubit(
        repository: ApiWhatsAppChatRepository(),
        isForeground: () => _foreground,
        includeManualChats: false,
      )..bootstrap();
      setState(() {
        _cubit = cubit;
        _userLoadFailed = true;
      });
    }
  }

  bool get _includeManual => canOpenManualWhatsAppChats(_user);

  String _timeLabel(DateTime? dt) {
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

  Future<void> _openThread(
    BuildContext providerContext, {
    required int? clientId,
    required String name,
    required String phone,
    bool isManual = false,
    String status = 'open',
    bool isStarred = false,
    bool isUnsubscribed = false,
  }) async {
    setState(() => _openedClientId = (clientId != null && clientId > 0) ? clientId : null);
    await Navigator.push<void>(
      providerContext,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'WhatsAppChatThreadScreen'),
        builder: (_) => WhatsAppChatThreadScreen(
          clientId: isManual ? null : clientId,
          clientName: name,
          phoneNumber: phone,
          isManual: isManual,
          initialStatus: status,
          initialStarred: isStarred,
          initialUnsubscribed: isUnsubscribed,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _openedClientId = null);
    unawaited(_cubit?.refresh(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    String t(String k) =>
        (localizations ?? AppLocalizations(const Locale('en'))).translate(k);
    final cubit = _cubit;

    if (cubit == null) {
      final colors = WhatsAppChatColors.of(context);
      return Scaffold(
        backgroundColor: colors.listBg,
        appBar: AppBar(
          backgroundColor: colors.headerBg,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text(t('whatsappChats')),
        ),
        body: Center(
          child: _userLoadFailed
              ? Text(t('whatsappChatCouldNotLoad'))
              : const CircularProgressIndicator(),
        ),
      );
    }

    final colors = WhatsAppChatColors.of(context);
    return BlocProvider.value(
      value: cubit,
      child: Builder(
        builder: (providerContext) {
          return BlocBuilder<WhatsAppConversationListCubit,
              WhatsAppConversationListState>(
            builder: (context, state) {
              if (state.unavailableCode != null) {
                return WhatsAppAccessDeniedScreen(
                  messageKey: whatsappChatsUnavailableMessageKey(
                    state.unavailableCode,
                  ),
                );
              }
              return Scaffold(
                backgroundColor: colors.listBg,
                appBar: AppBar(
                  backgroundColor: colors.headerBg,
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  title: Text(t('whatsappChats')),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
                      tooltip: t('startNewConversation'),
                      onPressed: () async {
                        final result =
                            await Navigator.push<WhatsAppStartConversationResult>(
                          providerContext,
                          MaterialPageRoute(
                            builder: (_) => WhatsAppStartConversationScreen(
                              allowManual: _includeManual,
                            ),
                          ),
                        );
                        if (result == null || !providerContext.mounted) return;
                        await _openThread(
                          providerContext,
                          clientId: result.clientId,
                          name: result.name,
                          phone: result.phone,
                          isManual: result.isManual,
                        );
                      },
                    ),
                  ],
                ),
                body: _ConversationListBody(
                  timeLabel: _timeLabel,
                  t: t,
                  openedClientId: _openedClientId,
                  canDelete: canDeleteWhatsAppHistory(_user),
                  showAssignmentFilters: !(_user?.isAssignedClinicalStaff ?? false),
                  onOpen: (c) async {
                    final isManual = c.id <= 0;
                    await _openThread(
                      providerContext,
                      clientId: isManual ? null : c.id,
                      name: c.name,
                      phone: c.phoneNumber,
                      isManual: isManual,
                      status: c.status,
                      isStarred: c.isStarred,
                      isUnsubscribed: c.isUnsubscribed,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationListBody extends StatefulWidget {
  const _ConversationListBody({
    required this.timeLabel,
    required this.t,
    required this.onOpen,
    required this.canDelete,
    this.showAssignmentFilters = true,
    this.openedClientId,
  });

  final String Function(DateTime?) timeLabel;
  final String Function(String) t;
  final Future<void> Function(WhatsAppConversationModel) onOpen;
  final bool canDelete;
  final bool showAssignmentFilters;
  final int? openedClientId;

  @override
  State<_ConversationListBody> createState() => _ConversationListBodyState();
}

class _ConversationListBodyState extends State<_ConversationListBody> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  static const _statusKeys = [
    'all',
    'open',
    'pending',
    'spam',
    'invalid',
    'done',
    'snoozed',
    'unread',
    'unsubscribed',
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      context.read<WhatsAppConversationListCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    final cubit = context.read<WhatsAppConversationListCubit>();
    final f = cubit.state.filters;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.t('filter'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (widget.showAssignmentFilters)
                      for (final a in ['all', 'mine', 'unassigned'])
                        FilterChip(
                          label: Text(widget.t(
                            a == 'all'
                                ? 'chatFilterAll'
                                : a == 'mine'
                                    ? 'chatFilterAssignedToMe'
                                    : 'chatFilterUnassigned',
                          )),
                          selected: f.assignment == a && !f.starred,
                          onSelected: (_) {
                            cubit.setAssignment(a);
                            Navigator.pop(ctx);
                          },
                        ),
                    FilterChip(
                      label: Text(widget.t('chatFilterStarred')),
                      selected: f.starred,
                      onSelected: (_) {
                        cubit.toggleStarred();
                        Navigator.pop(ctx);
                      },
                    ),
                    FilterChip(
                      label: Text(widget.t('chatFilterUnreplied')),
                      selected: f.unreplied,
                      onSelected: (_) {
                        cubit.toggleUnreplied();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WhatsAppConversationModel c,
  ) async {
    if (c.id <= 0) return;
    final cubit = context.read<WhatsAppConversationListCubit>();
    final change = await showChatConversationStatusSheet(
      context: context,
      t: widget.t,
      isStarred: c.isStarred,
      isUnsubscribed: c.isUnsubscribed,
    );
    if (change == null || !context.mounted) return;
    await cubit.updateConversationState(
      clientId: c.id,
      status: change.status,
      snoozedUntil: change.snoozedUntil,
      isStarred: change.isStarred,
      isUnsubscribed: change.isUnsubscribed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WhatsAppConversationListCubit, WhatsAppConversationListState>(
      builder: (context, state) {
        if (state.loading && state.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.loadError != null && state.conversations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.t('whatsappChatCouldNotLoad'), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<WhatsAppConversationListCubit>().refresh(),
                    child: Text(widget.t('retry')),
                  ),
                ],
              ),
            ),
          );
        }

        final filtered = state.conversations;
        final f = state.filters;

        return Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                children: [
                  for (final key in _statusKeys)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(
                          '${widget.t('chatStatus_$key')} ${state.statusCounts[key] ?? ''}',
                        ),
                        selected: !f.starred && f.status == key,
                        onSelected: (_) => context
                            .read<WhatsAppConversationListCubit>()
                            .setStatusFilter(key),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => context
                          .read<WhatsAppConversationListCubit>()
                          .setSearch(v),
                      decoration: InputDecoration(
                        hintText: widget.t('searchConversations'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: widget.t('filter'),
                    onPressed: () => _showFilterSheet(context),
                  ),
                  FilterChip(
                    label: Text(widget.t('chatFilterUnreplied')),
                    selected: f.unreplied,
                    onSelected: (_) => context
                        .read<WhatsAppConversationListCubit>()
                        .toggleUnreplied(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(widget.t('noConversations')))
                  : RefreshIndicator(
                      onRefresh: () =>
                          context.read<WhatsAppConversationListCubit>().refresh(),
                      child: ListView.separated(
                        controller: _scrollCtrl,
                        itemCount: filtered.length +
                            ((state.hasMore ||
                                    (state.totalCount > 0 &&
                                        filtered.length < state.totalCount))
                                ? 1
                                : 0),
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.2),
                        ),
                        itemBuilder: (context, index) {
                          if (index >= filtered.length) {
                            final shown = filtered.length;
                            final total = state.totalCount > 0
                                ? state.totalCount
                                : shown;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    widget
                                        .t('chatListShowingCount')
                                        .replaceAll('{shown}', '$shown')
                                        .replaceAll('{total}', '$total'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (state.hasMore) ...[
                                    const SizedBox(height: 8),
                                    if (state.loadingMore)
                                      const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    else
                                      TextButton(
                                        onPressed: () => context
                                            .read<WhatsAppConversationListCubit>()
                                            .loadMore(),
                                        child: Text(widget.t('chatListLoadMore')),
                                      ),
                                  ],
                                ],
                              ),
                            );
                          }
                          final c = filtered[index];
                          final selected = widget.openedClientId != null &&
                              widget.openedClientId == c.id;
                          final unread = c.unreadCount > 0 && !selected;
                          final title = c.name.isNotEmpty ? c.name : c.phoneNumber;
                          final preview = localizeWhatsAppMessageBody(
                            c.lastMessagePreview,
                            widget.t,
                          );

                          final tile = ListTile(
                            onTap: () => widget.onOpen(c),
                            onLongPress: c.id > 0
                                ? () => _showActions(context, c)
                                : null,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: Text(
                                title.isNotEmpty ? title[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppTheme.primaryColor),
                              ),
                            ),
                            title: Row(
                              children: [
                                if (c.isStarred)
                                  const Padding(
                                    padding: EdgeInsetsDirectional.only(end: 4),
                                    child: Icon(Icons.star, size: 14, color: Colors.amber),
                                  ),
                                Expanded(
                                  child: WhatsAppPhoneText.isPhoneLike(title)
                                      ? WhatsAppPhoneText(
                                          title,
                                          style: TextStyle(
                                            fontWeight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        )
                                      : Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                ),
                                if (c.status == 'snoozed')
                                  const Icon(Icons.snooze, size: 14, color: Colors.amber),
                                Text(
                                  widget.timeLabel(c.lastMessageAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: unread
                                        ? AppTheme.primaryColor
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (c.status != 'open')
                                  Container(
                                    margin: const EdgeInsetsDirectional.only(start: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.t('chatStatus_${c.status}'),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                if (unread)
                                  Container(
                                    margin: const EdgeInsetsDirectional.only(start: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      c.unreadCount > 99
                                          ? '99+'
                                          : '${c.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );

                          if (!widget.canDelete) return tile;

                          return Dismissible(
                            key: ValueKey('wa-conv-${c.id}-${c.phoneNumber}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      content: Text(widget.t('deleteConversationConfirm')),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: Text(widget.t('cancel')),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: Text(widget.t('delete')),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                            },
                            onDismissed: (_) {
                              context
                                  .read<WhatsAppConversationListCubit>()
                                  .deleteConversation(c);
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
    );
  }
}
