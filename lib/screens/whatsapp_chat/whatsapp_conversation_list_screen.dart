import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../features/whatsapp_chat/cubit/whatsapp_conversation_list_cubit.dart';
import '../../features/whatsapp_chat/cubit/whatsapp_conversation_list_state.dart';
import '../../features/whatsapp_chat/whatsapp_chat_repository.dart';
import '../../models/user_model.dart';
import '../../models/whatsapp_conversation_model.dart';
import '../../services/api_service.dart';
import '../../utils/whatsapp_access.dart';
import '../../utils/whatsapp_message_body_localize.dart';
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
    final raw =
        sameDay ? DateFormat.Hm().format(local) : DateFormat.MMMd().format(local);
    return withLatinDigits(raw);
  }

  Future<void> _openThread(
    BuildContext providerContext, {
    required int? clientId,
    required String name,
    required String phone,
    bool isManual = false,
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
        ),
      ),
    );
    if (!mounted || !providerContext.mounted) return;
    setState(() => _openedClientId = null);
    providerContext.read<WhatsAppConversationListCubit>().refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    String t(String k) => localizations?.translate(k) ?? k;
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
              onOpen: (c) async {
                final isManual = c.id <= 0;
                await _openThread(
                  providerContext,
                  clientId: isManual ? null : c.id,
                  name: c.name,
                  phone: c.phoneNumber,
                  isManual: isManual,
                );
              },
            ),
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
    this.openedClientId,
  });

  final String Function(DateTime?) timeLabel;
  final String Function(String) t;
  final Future<void> Function(WhatsAppConversationModel) onOpen;
  final int? openedClientId;

  @override
  State<_ConversationListBody> createState() => _ConversationListBodyState();
}

class _ConversationListBodyState extends State<_ConversationListBody> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

        final q = _searchCtrl.text.trim().toLowerCase();
        final filtered = q.isEmpty
            ? state.conversations
            : state.conversations.where((c) {
                return c.name.toLowerCase().contains(q) ||
                    c.phoneNumber.toLowerCase().contains(q) ||
                    c.leadCompanyName.toLowerCase().contains(q) ||
                    c.lastMessagePreview.toLowerCase().contains(q);
              }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: widget.t('searchConversations'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(widget.t('noConversations')))
                  : RefreshIndicator(
                      onRefresh: () =>
                          context.read<WhatsAppConversationListCubit>().refresh(),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          final selected = widget.openedClientId != null &&
                              widget.openedClientId == c.id;
                          final unread = c.unreadCount > 0 && !selected;
                          final title = c.name.isNotEmpty ? c.name : c.phoneNumber;
                          final preview = localizeWhatsAppMessageBody(
                            c.lastMessagePreview,
                            widget.t,
                          );

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
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: ListTile(
                              selected: selected,
                              selectedTileColor: WhatsAppChatColors.of(context).listActiveBg,
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withValues(
                                  alpha: Theme.of(context).brightness == Brightness.dark
                                      ? 0.30
                                      : 0.15,
                                ),
                                foregroundColor: AppTheme.primaryAccent(
                                  Theme.of(context).brightness,
                                ),
                                child: Text(
                                  title.isNotEmpty
                                      ? title.characters.first.toUpperCase()
                                      : '#',
                                ),
                              ),
                              title: WhatsAppPhoneText.isPhoneLike(title)
                                  ? WhatsAppPhoneText(
                                      title,
                                      style: TextStyle(
                                        fontWeight:
                                            unread ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    )
                                  : Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight:
                                            unread ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                              subtitle: Text(
                                preview.isNotEmpty ? preview : c.phoneNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight:
                                      unread ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    widget.timeLabel(c.lastMessageAt),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight:
                                              unread ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                  ),
                                  if (unread) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () => widget.onOpen(c),
                            ),
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
