import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../features/team_chat/cubit/team_chat_composer_cubit.dart';
import '../../features/team_chat/cubit/team_chat_list_cubit.dart';
import '../../features/team_chat/cubit/team_chat_list_state.dart';
import '../../features/team_chat/cubit/team_chat_new_peer_cubit.dart';
import '../../features/team_chat/cubit/team_chat_peer_presence_cubit.dart';
import '../../features/team_chat/cubit/team_chat_peer_presence_state.dart';
import '../../features/team_chat/team_chat_repository.dart';
import '../../models/tenant_chat_models.dart';
import '../../services/team_chat_away_service.dart';
import '../../services/team_chat_route_observer.dart';
import 'team_chat_common.dart';
import 'team_chat_conversation_tile.dart';
import 'team_chat_thread_pane.dart';
import 'widgets/team_chat_conversation_list.dart';
import 'widgets/team_chat_forward_sheet.dart';
import 'widgets/team_chat_new_peer_sheet.dart';
import 'widgets/team_chat_presence_subtitle.dart';
import 'widgets/team_chat_thread_column.dart';

class TeamChatScreen extends StatelessWidget {
  const TeamChatScreen({super.key, this.initialConversationId});

  final int? initialConversationId;

  @override
  Widget build(BuildContext context) {
    return _TeamChatProviders(
      initialConversationId: initialConversationId,
      child: _TeamChatShell(initialConversationId: initialConversationId),
    );
  }
}

class _TeamChatProviders extends StatefulWidget {
  const _TeamChatProviders({
    required this.child,
    this.initialConversationId,
  });

  final Widget child;
  final int? initialConversationId;

  @override
  State<_TeamChatProviders> createState() => _TeamChatProvidersState();
}

class _TeamChatProvidersState extends State<_TeamChatProviders>
    with WidgetsBindingObserver {
  late final TeamChatRepository _repository = ApiTeamChatRepository();
  late final TeamChatListCubit _listCubit;
  late final TeamChatPeerPresenceCubit _presenceCubit;
  late final TeamChatComposerCubit _composerCubit;
  final GlobalKey<TeamChatThreadPaneState> _threadPaneKey =
      GlobalKey<TeamChatThreadPaneState>();

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TeamChatAwayService.instance.setTeamChatVisible(true);

    _listCubit = TeamChatListCubit(
      repository: _repository,
      isForeground: () => _foreground,
    );
    _presenceCubit = TeamChatPeerPresenceCubit(
      repository: _repository,
      isForeground: () => _foreground,
    );
    _composerCubit = TeamChatComposerCubit(
      repository: _repository,
      onRefreshConversations: () => _listCubit.refreshConversations(silent: true),
      onMessageSent: () async {
        await _threadPaneKey.currentState?.onMessageSent();
      },
    );

    unawaited(_listCubit.bootstrap(initialConversationId: widget.initialConversationId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listCubit.close();
    _presenceCubit.close();
    _composerCubit.close();
    TeamChatAwayService.instance.setTeamChatVisible(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    _presenceCubit.setForeground(fg);
    if (fg && _listCubit.state.selectedId != null) {
      _presenceCubit.bindConversation(_listCubit.state.selectedId);
    }
  }

  void _selectConversation(int id) {
    unawaited(_listCubit.selectConversation(id));
    _presenceCubit.bindConversation(id);
    _composerCubit.bindConversation(id);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_threadPaneKey.currentState?.scrollToBottom(animated: false));
    });
  }

  void _clearSelection() {
    _listCubit.clearSelection();
    _presenceCubit.bindConversation(null);
    _composerCubit.bindConversation(null);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TeamChatListCubit>.value(value: _listCubit),
        BlocProvider<TeamChatPeerPresenceCubit>.value(value: _presenceCubit),
        BlocProvider<TeamChatComposerCubit>.value(value: _composerCubit),
      ],
      child: _TeamChatScope(
        threadPaneKey: _threadPaneKey,
        onSelectConversation: _selectConversation,
        onClearSelection: _clearSelection,
        child: widget.child,
      ),
    );
  }
}

class _TeamChatScope extends InheritedWidget {
  const _TeamChatScope({
    required this.threadPaneKey,
    required this.onSelectConversation,
    required this.onClearSelection,
    required super.child,
  });

  final GlobalKey<TeamChatThreadPaneState> threadPaneKey;
  final void Function(int id) onSelectConversation;
  final VoidCallback onClearSelection;

  static _TeamChatScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_TeamChatScope>();
    assert(scope != null, 'TeamChatScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(_TeamChatScope oldWidget) => false;
}

class _TeamChatShell extends StatefulWidget {
  const _TeamChatShell({this.initialConversationId});

  final int? initialConversationId;

  @override
  State<_TeamChatShell> createState() => _TeamChatShellState();
}

class _TeamChatShellState extends State<_TeamChatShell> with RouteAware {
  final TextEditingController _draft = TextEditingController();
  final TextEditingController _forwardCaption = TextEditingController();

  @override
  void initState() {
    super.initState();
    TeamChatAwayService.instance.setTeamChatVisible(true);
    _syncAwayContext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      teamChatRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    teamChatRouteObserver.unsubscribe(this);
    _draft.dispose();
    _forwardCaption.dispose();
    super.dispose();
  }

  void _syncAwayContext() {
    TeamChatAwayService.instance.setActiveConversationId(
      context.read<TeamChatListCubit>().state.selectedId,
    );
  }

  _TeamChatScope get _scope => _TeamChatScope.of(context);

  String _t(String key) {
    final loc = AppLocalizations.of(context);
    return loc?.translate(key) ?? key;
  }

  @override
  void didPush() {
    TeamChatAwayService.instance.setTeamChatVisible(true);
    _syncAwayContext();
    _snapThreadToBottomOnOpen();
  }

  @override
  void didPopNext() {
    TeamChatAwayService.instance.setTeamChatVisible(true);
    _syncAwayContext();
  }

  @override
  void didPushNext() => TeamChatAwayService.instance.setTeamChatVisible(false);

  @override
  void didPop() => TeamChatAwayService.instance.setTeamChatVisible(false);

  void _snapThreadToBottomOnOpen() {
    if (context.read<TeamChatListCubit>().state.selectedId == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _scope.threadPaneKey.currentState?.scrollToBottom(animated: false),
      );
    });
  }

  Future<void> _openNewChat() async {
    final repo = ApiTeamChatRepository();
    List<TenantChatPeer> users = [];
    try {
      final page = await repo.getEligibleUsers();
      users = page.results;
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(context, _t('teamChatCouldNotLoad'));
      }
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        final listCubit = context.read<TeamChatListCubit>();
        String tr(String k) =>
            AppLocalizations.of(ctx)?.translate(k) ?? k;
        return BlocProvider(
          create: (_) => TeamChatNewPeerCubit(peers: users, tr: tr),
          child: SizedBox(
            height: h * 0.72,
            child: TeamChatNewPeerSheet(
              peers: users,
              onPick: (p) async {
                try {
                  final c = await repo.startConversation(p.id);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await listCubit.refreshConversations(silent: true);
                  if (!mounted) return;
                  _scope.onSelectConversation(c.id);
                } catch (_) {
                  if (!mounted) return;
                  SnackbarHelper.showError(context, _t('teamChatCouldNotLoad'));
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _openForward(TenantChatMessage m) {
    final composer = context.read<TeamChatComposerCubit>();
    composer.setForwardSource(m.id);
    final listState = context.read<TeamChatListCubit>().state;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => TeamChatForwardSheet(
        conversations: listState.conversations
            .where((c) => c.id != listState.selectedId)
            .toList(),
        captionController: _forwardCaption,
        onSend: (targetId) async {
          final src = composer.state.forwardSourceId;
          if (src == null) return;
          final ok = await composer.forwardMessage(
            targetConversationId: targetId,
            caption: _forwardCaption.text.trim(),
            forwardFromMessageId: src,
            currentSelectedId: listState.selectedId,
          );
          if (ctx.mounted && ok) {
            Navigator.pop(ctx);
            _forwardCaption.clear();
          }
        },
      ),
    );
  }

  Future<void> _toggleVoice() async {
    final composer = context.read<TeamChatComposerCubit>();
    if (composer.state.voiceRecording) {
      await composer.stopVoiceRecording();
      await _scope.threadPaneKey.currentState?.scrollToBottom(animated: true);
      return;
    }
    final ok = await composer.startVoiceRecording();
    if (!ok && mounted) {
      SnackbarHelper.showError(context, _t('teamChatMicDenied'));
    }
  }

  void _setReplyTo(TenantChatMessage? m) {
    context.read<TeamChatComposerCubit>().setReplyTo(m);
    if (m != null) {
      unawaited(_scope.threadPaneKey.currentState?.scrollToBottom(animated: true));
    }
  }

  void _jumpToMessageId(int id) {
    unawaited(_scope.threadPaneKey.currentState?.jumpToMessage(id));
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final scope = _scope;

    return BlocBuilder<TeamChatListCubit, TeamChatListState>(
      buildWhen: (prev, next) =>
          prev.loadError != next.loadError ||
          prev.conversations.isEmpty != next.conversations.isEmpty ||
          prev.selectedId != next.selectedId,
      builder: (context, listState) {
        final inThreadNarrow = !wide && listState.selectedId != null;

        return Scaffold(
          appBar: AppBar(
            leading: inThreadNarrow
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: _scope.onClearSelection,
                  )
                : null,
            automaticallyImplyLeading: !inThreadNarrow,
            title: inThreadNarrow
                ? _NarrowThreadAppBarTitle(tr: _t)
                : Text(_t('teamChat')),
            actions: [
              if (!inThreadNarrow)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: _t('teamChatNewConversation'),
                  onPressed: _openNewChat,
                ),
            ],
          ),
          body: listState.loadError != null && listState.conversations.isEmpty
              ? Center(child: Text(_t('teamChatCouldNotLoad')))
              : wide
                  ? Row(
                      children: [
                        SizedBox(
                          width: 300,
                          child: TeamChatConversationList(
                            wide: true,
                            lang: lang,
                            onSelect: scope.onSelectConversation,
                            onNewChat: _openNewChat,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: TeamChatThreadColumn(
                            threadPaneKey: scope.threadPaneKey,
                            draft: _draft,
                            lang: lang,
                            wide: true,
                            onReply: _setReplyTo,
                            onForward: _openForward,
                            onPin: (m) => context.read<TeamChatComposerCubit>().pinMessage(m),
                            onJumpToPinned: _jumpToMessageId,
                            onUnpin: (id) =>
                                context.read<TeamChatComposerCubit>().unpinMessage(id),
                            onToggleVoice: _toggleVoice,
                          ),
                        ),
                      ],
                    )
                  : listState.selectedId == null
                      ? TeamChatConversationList(
                          wide: false,
                          lang: lang,
                          onSelect: scope.onSelectConversation,
                          onNewChat: _openNewChat,
                        )
                      : TeamChatThreadColumn(
                          threadPaneKey: scope.threadPaneKey,
                          draft: _draft,
                          lang: lang,
                          wide: false,
                          onReply: _setReplyTo,
                          onForward: _openForward,
                          onPin: (m) =>
                              context.read<TeamChatComposerCubit>().pinMessage(m),
                          onJumpToPinned: _jumpToMessageId,
                          onUnpin: (id) =>
                              context.read<TeamChatComposerCubit>().unpinMessage(id),
                          onToggleVoice: _toggleVoice,
                        ),
        );
      },
    );
  }
}

class _NarrowThreadAppBarTitle extends StatelessWidget {
  const _NarrowThreadAppBarTitle({required this.tr});

  final String Function(String key) tr;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamChatListCubit, TeamChatListState>(
      buildWhen: (prev, next) =>
          prev.selectedConversation != next.selectedConversation,
      builder: (context, listState) {
        final selected = listState.selectedConversation;
        if (selected == null) return Text(tr('teamChat'));

        return BlocSelector<TeamChatPeerPresenceCubit, TeamChatPeerPresenceState,
            String?>(
          selector: (s) => teamChatThreadPresenceSubtitle(
            selected: selected,
            presenceResponse: s.response,
            tr: tr,
          ),
          builder: (context, subtitle) {
            if (selected.isCompanyGroup) {
              return TeamChatGroupThreadAppBarTitle(
                title: tenantChatConversationTitle(
                  selected,
                  tr('teamChatCompanyRoom'),
                ),
                avatarLetters: tenantChatConversationAvatarLetters(
                  selected,
                  tr('teamChatCompanyRoom'),
                ),
                subtitle: subtitle,
              );
            }
            final ou = selected.otherUser;
            if (ou == null) return Text(tr('teamChat'));
            return TeamChatThreadAppBarTitle(
              peer: ou,
              subtitle: subtitle,
            );
          },
        );
      },
    );
  }
}
