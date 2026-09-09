import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../chat_engine/cubit/chat_thread_cubit.dart';
import '../../chat_engine/cubit/chat_thread_state.dart';
import '../../chat_engine/ui/chat_message_list_view.dart';
import '../../chat_engine/ui/chat_scroll_fab.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../features/social_inbox/cubit/social_inbox_thread_cubit.dart';
import '../../features/social_inbox/cubit/social_inbox_thread_state.dart';
import '../../features/social_inbox/social_inbox_coordinator_factory.dart';
import '../../features/social_inbox/social_inbox_repository.dart';
import '../../features/social_inbox/social_message_adapter.dart';
import '../../models/social_conversation_model.dart';
import '../../models/social_message_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/compress_image_for_chat.dart';
import '../../utils/social_inbox_access.dart';
import '../../utils/social_message_body_localize.dart';
import '../../widgets/chat/chat_attach_sheet.dart';
import '../../widgets/chat/chat_bubble_shell.dart';
import '../../widgets/chat/chat_composer_shell.dart';
import '../../widgets/chat/chat_conversation_status_menu.dart';
import '../../widgets/chat/chat_media.dart';
import '../../widgets/chat/chat_palette.dart';
import '../../widgets/chat/chat_pending_attachment_chip.dart';
import '../../widgets/chat/chat_separators.dart';
import '../../widgets/chat/chat_text_direction.dart';
import '../../widgets/chat/chat_voice_recording_bar.dart';
import '../../widgets/chat_thread_empty.dart';
import 'convert_conversation_sheet.dart';

/// One Instagram/Messenger thread.
///
/// The reply window is stricter than WhatsApp's: there is no template to reopen a
/// closed thread, so the composer disables outright when the window closes.
class SocialInboxThreadScreen extends StatelessWidget {
  const SocialInboxThreadScreen({super.key, required this.conversation});

  final SocialConversationModel conversation;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SocialInboxThreadCubit(
        repository: ApiSocialInboxRepository(),
        conversation: conversation,
      )..bootstrap(),
      child: _SocialInboxThreadView(conversationId: conversation.id),
    );
  }
}

class _SocialInboxThreadView extends StatefulWidget {
  const _SocialInboxThreadView({required this.conversationId});

  final int conversationId;

  @override
  State<_SocialInboxThreadView> createState() => _SocialInboxThreadViewState();
}

class _SocialInboxThreadViewState extends State<_SocialInboxThreadView>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  SocialInboxEngineBundle? _engine;
  int? _syncedIdentity;
  UserModel? _currentUser;
  bool _foreground = true;
  bool _scrolledOnce = false;

  String? _pendingPath;
  bool _compressing = false;
  bool _sendingAttachment = false;
  bool _recording = false;
  bool _recordingPaused = false;
  Duration _recordElapsed = Duration.zero;
  final Stopwatch _recordWatch = Stopwatch();
  Timer? _voiceCapTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(() => setState(() {}));
    _engine = SocialInboxCoordinatorFactory.create(
      repository: ApiSocialInboxRepository(),
      conversationId: widget.conversationId,
      isForeground: () => _foreground,
    );
    ApiService().getCurrentUser().then((user) {
      if (mounted) setState(() => _currentUser = user);
    }).catchError((_) => null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _voiceCapTimer?.cancel();
    _recorder.dispose();
    _engine?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  void _syncEngine(List<SocialMessageModel> messages) {
    final eng = _engine;
    if (eng == null) return;
    final identity = Object.hashAll(
      messages.map((m) => Object.hash(m.id, m.deliveryStatus, m.body, m.tempId)),
    );
    if (identity == _syncedIdentity) return;
    _syncedIdentity = identity;
    eng.registry.clear();
    eng.threadCubit.upsertMessages(adaptSocialMessages(messages));
  }

  void _scrollToBottomOnce() {
    final eng = _engine;
    if (_scrolledOnce || eng == null) return;
    if (eng.threadCubit.state.rows.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      eng.scrollService.stickToTail = true;
      await eng.coordinator.scrollToBottom(animated: false);
      _scrolledOnce = true;
    });
  }

  Future<void> _openAttach() async {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    final action = await showChatAttachSheet(
      context,
      capabilities: const ChatAttachCapabilities(
        photo: true,
        camera: true,
        video: true,
        file: true,
      ),
      t: t,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ChatAttachAction.photo:
        await _pickImage(ImageSource.gallery);
      case ChatAttachAction.camera:
        await _pickImage(ImageSource.camera);
      case ChatAttachAction.video:
        await _pickVideo();
      case ChatAttachAction.file:
        await _pickFile();
      case ChatAttachAction.library:
      case ChatAttachAction.location:
        break;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await _imagePicker.pickImage(source: source);
    if (x == null || !mounted) return;
    setState(() => _compressing = true);
    final path = await compressImageForChatIfNeeded(x.path);
    if (!mounted) return;
    setState(() {
      _compressing = false;
      _pendingPath = path;
    });
  }

  Future<void> _pickVideo() async {
    final x = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() => _pendingPath = x.path);
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(withData: false);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _pendingPath = path);
  }

  Future<void> _startVoiceRecording() async {
    if (_recording) return;
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}social_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
    _recordWatch
      ..reset()
      ..start();
    _voiceCapTimer?.cancel();
    _voiceCapTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recording) return;
      setState(() => _recordElapsed = _recordWatch.elapsed);
      if (_recordWatch.elapsed.inMinutes >= 4) {
        unawaited(_stopVoiceRecording());
      }
    });
    if (!mounted) return;
    setState(() {
      _recording = true;
      _recordingPaused = false;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _pauseVoiceRecording() async {
    if (!_recording || _recordingPaused) return;
    await _recorder.pause();
    _recordWatch.stop();
    if (mounted) setState(() => _recordingPaused = true);
  }

  Future<void> _resumeVoiceRecording() async {
    if (!_recording || !_recordingPaused) return;
    await _recorder.resume();
    _recordWatch.start();
    if (mounted) setState(() => _recordingPaused = false);
  }

  Future<void> _stopVoiceRecording() async {
    if (!_recording) return;
    _voiceCapTimer?.cancel();
    _recordWatch.stop();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordingPaused = false;
      _recordElapsed = Duration.zero;
      if (path != null && File(path).existsSync()) {
        _pendingPath = path;
      }
    });
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_recording) return;
    _voiceCapTimer?.cancel();
    _recordWatch.stop();
    try {
      await _recorder.cancel();
    } catch (_) {
      final path = await _recorder.stop();
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordingPaused = false;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _send(SocialInboxThreadCubit cubit) async {
    final text = _controller.text.trim();
    final path = _pendingPath;
    if (path != null) {
      setState(() => _sendingAttachment = true);
      await cubit.sendMedia(path, caption: text.isEmpty ? null : text);
      if (!mounted) return;
      setState(() {
        _pendingPath = null;
        _sendingAttachment = false;
      });
      _controller.clear();
      return;
    }
    if (text.isEmpty) return;
    _controller.clear();
    await cubit.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    String t(String key) =>
        (localizations ?? AppLocalizations(const Locale('en'))).translate(key);
    final palette = WhatsAppStyleChatPalette.of(context);

    return BlocConsumer<SocialInboxThreadCubit, SocialInboxThreadState>(
      listenWhen: (previous, current) =>
          previous.sendErrorKey != current.sendErrorKey ||
          previous.messages != current.messages,
      listener: (context, state) {
        final key = state.sendErrorKey;
        if (key != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(t(key))));
          context.read<SocialInboxThreadCubit>().clearErrors();
        }
        _syncEngine(state.messages);
        if (state.messages.isNotEmpty) {
          _scrollToBottomOnce();
          if (_scrolledOnce && (_engine?.scrollService.stickToTail ?? false)) {
            unawaited(_engine!.coordinator.scrollToBottom(animated: true));
          }
        }
      },
      builder: (context, state) {
        final cubit = context.read<SocialInboxThreadCubit>();
        final conversation = state.conversation;
        if (conversation == null) return const SizedBox.shrink();
        _syncEngine(state.messages);

        final hasDraft =
            _controller.text.trim().isNotEmpty || _pendingPath != null;
        final blocked = state.composerBlocked;

        return Scaffold(
          backgroundColor: palette.threadBackground,
          appBar: AppBar(
            titleSpacing: 8,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.contact.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  conversation.isInstagram
                      ? t('instagramDirect')
                      : t('facebookMessenger'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            actions: [
              // Status first (closer to title); convert/open-lead icon at the end.
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Center(
                  child: ChatConversationStatusMenu(
                    t: t,
                    status: conversation.status,
                    isStarred: conversation.isStarred,
                    isUnsubscribed: conversation.isUnsubscribed,
                    onChange: (payload) {
                      unawaited(
                        cubit.updateConversationState(
                          status: payload.status,
                          snoozedUntil: payload.snoozedUntil,
                          isStarred: payload.isStarred,
                          isUnsubscribed: payload.isUnsubscribed,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (conversation.isConverted && conversation.clientId != null)
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  tooltip: t('whatsappOpenLead'),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/leads/details',
                      arguments: conversation.clientId,
                    );
                  },
                )
              else if (canConvertSocialConversation(_currentUser))
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  tooltip: t('convertToLead'),
                  onPressed: () => _openConvertSheet(context, cubit),
                ),
            ],
          ),
          body: Column(
            children: [
              if (blocked)
                Material(
                  color: Colors.amber.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('replyWindowClosed'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          t('replyWindowClosedHint'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              else if (state.window.mode == 'human_agent')
                Material(
                  color: Colors.amber.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      t('replyWindowHumanAgentShort'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              Expanded(
                child: _buildThreadBody(state, cubit, t, language, palette),
              ),
              ChatComposerShell(
                draft: _controller,
                hintText: blocked ? t('replyWindowClosed') : t('typeAMessage'),
                sending: state.isSending || _sendingAttachment,
                enabled: !blocked,
                onSend: () => unawaited(_send(cubit)),
                paletteSendBg: AppTheme.primaryColor,
                paletteSendFg: Colors.white,
                composerBg: palette.composerBg,
                inputFill: palette.inputFill,
                maxLines: 4,
                pendingAttachment: (_pendingPath != null || _compressing)
                    ? ChatPendingAttachmentChip(
                        label: _pendingPath
                                ?.split('/')
                                .last
                                .split('\\')
                                .last ??
                            '',
                        compressing: _compressing,
                        compressLabel: t('teamChatCompressing'),
                        onClear: () => setState(() => _pendingPath = null),
                      )
                    : null,
                recordingBar: _recording
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChatVoiceRecordingBar(
                          elapsed: _recordElapsed,
                          paused: _recordingPaused,
                          onPause: () => unawaited(_pauseVoiceRecording()),
                          onResume: () => unawaited(_resumeVoiceRecording()),
                          onStop: () => unawaited(_stopVoiceRecording()),
                          onCancel: () => unawaited(_cancelVoiceRecording()),
                          metaColor: palette.metaIn,
                        ),
                      )
                    : null,
                onAttach: blocked || _sendingAttachment
                    ? null
                    : () => unawaited(_openAttach()),
                showMic: !hasDraft && !blocked,
                onMic: () => unawaited(_startVoiceRecording()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThreadBody(
    SocialInboxThreadState state,
    SocialInboxThreadCubit cubit,
    String Function(String) t,
    String language,
    ChatPalette palette,
  ) {
    final eng = _engine;
    if (state.status == SocialThreadStatus.loading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == SocialThreadStatus.error && state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage ?? t('somethingWentWrong'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => cubit.load(),
                child: Text(t('retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (eng == null || state.messages.isEmpty) {
      return ChatThreadEmpty(
        icon: Icons.forum_outlined,
        title: t('socialThreadEmpty'),
        subtitle: t('socialThreadEmptyHint'),
      );
    }

    return BlocProvider<ChatThreadCubit<SocialEngineMessage>>.value(
      value: eng.threadCubit,
      child: BlocBuilder<ChatThreadCubit<SocialEngineMessage>, ChatThreadState>(
        builder: (context, threadState) {
          eng.scrollService.updateItemCount(threadState.rows.length);
          return Directionality(
            textDirection: resolveBubbleTextDirection('A'),
            child: Stack(
              children: [
                ChatMessageListView(
                  rows: threadState.rows,
                  itemScrollController: eng.itemScrollController,
                  itemPositionsListener: eng.itemPositionsListener,
                  highlightedMessageId:
                      eng.highlightController.highlightedMessageId.value,
                  onScrollNotification: (n) =>
                      eng.scrollService.handleScrollNotification(
                    n,
                    threadState.rows.length,
                  ),
                  messageBuilder: (ctx, row, index) {
                    final msg = (row.message as SocialEngineMessage).raw;
                    return _SocialMessageBubble(
                      message: msg,
                      attachmentUrl: cubit.attachmentUrl,
                      t: t,
                    );
                  },
                  daySeparatorBuilder: (ctx, row) => ChatDaySeparatorChip(
                    label: chatDayChipLabel(
                      row.dayStart,
                      language: language,
                      t: t,
                    ),
                    palette: palette,
                  ),
                  unreadBuilder: (ctx) => ChatUnreadSeparatorChip(
                    label: t('unread'),
                    palette: palette,
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: eng.itemPositionsListener.itemPositions,
                  builder: (context, positions, _) {
                    final metrics =
                        eng.scrollService.metricsFor(threadState.rows.length);
                    if (metrics.atBottom) return const SizedBox.shrink();
                    return Positioned(
                      right: 12,
                      bottom: 12,
                      child: ChatScrollFab(
                        unreadCount: 0,
                        onTap: () {
                          eng.scrollService.stickToTail = true;
                          unawaited(
                            eng.coordinator.scrollToBottom(animated: true),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openConvertSheet(
    BuildContext context,
    SocialInboxThreadCubit cubit,
  ) async {
    final conversation = cubit.state.conversation;
    if (conversation == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConvertConversationSheet(
        conversation: conversation,
        onConvert: cubit.convertToLead,
      ),
    );
  }
}

class _SocialMessageBubble extends StatelessWidget {
  const _SocialMessageBubble({
    required this.message,
    required this.attachmentUrl,
    required this.t,
  });

  final SocialMessageModel message;
  final String Function(int) attachmentUrl;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    // Force Team bubble chrome even if a WA-style palette is passed in.
    final teamPalette = TeamChatPalette.of(context);
    final outbound = message.isOutbound;
    final fg = outbound
        ? (message.isFailed
            ? teamPalette.bubbleOutFailedFg
            : teamPalette.bubbleOutFg)
        : teamPalette.bubbleInFg;
    final bodyText = localizeSocialMessageBody(
      message.body,
      message.attachmentKind,
      message.isVoiceNote,
      t,
    );
    final hasMedia = message.attachmentKind != null;
    final time = withLatinDigits(
      DateFormat.Hm().format(message.timestamp.toLocal()),
    );

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (message.reaction.isNotEmpty) ...[
          Text(message.reaction, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
        ],
        if (message.isPending)
          Icon(Icons.schedule, size: 14, color: fg.withValues(alpha: 0.72)),
        if (message.isFailed)
          Icon(Icons.error_outline, size: 14, color: fg.withValues(alpha: 0.9)),
        if (message.isPending || message.isFailed) const SizedBox(width: 4),
        Text(
          time,
          style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.72)),
        ),
      ],
    );

    return ChatBubbleShell(
      isInbound: !outbound,
      palette: teamPalette,
      failed: message.isFailed,
      sending: message.isPending && !message.isFailed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasMedia) ...[
            _Attachment(
              message: message,
              attachmentUrl: attachmentUrl,
              t: t,
            ),
            const SizedBox(height: 4),
          ],
          ChatBubbleTextAndMeta(
            body: bodyText.isNotEmpty
                ? Directionality(
                    textDirection: resolveBubbleTextDirection(bodyText),
                    child: Text(
                      bodyText,
                      style: TextStyle(color: fg, height: 1.35),
                    ),
                  )
                : null,
            meta: meta,
          ),
        ],
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment({
    required this.message,
    required this.attachmentUrl,
    required this.t,
  });

  final SocialMessageModel message;
  final String Function(int) attachmentUrl;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    if (!message.hasAttachment) {
      final label = switch (message.attachmentKind) {
        'story_mention' => t('storyMention'),
        'share' => t('sharedPost'),
        'reel' => t('sharedReel'),
        'location' => message.locationName.isNotEmpty
            ? message.locationName
            : t('locationLabel'),
        _ => null,
      };
      if (label == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
        ),
      );
    }

    final url = attachmentUrl(message.id);
    final kind = message.attachmentKind;
    if (kind == 'image') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TenantChatMemoryImage(
          url: url,
          suggestedFilename: message.originalFilename,
        ),
      );
    }
    if (kind == 'video') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TenantChatMemoryVideo(
          url: url,
          suggestedFilename: message.originalFilename,
        ),
      );
    }
    if (kind == 'audio' || message.isVoiceNote) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TenantChatInlineAudio(
          url: url,
          originalFilename: message.originalFilename,
          mine: message.isOutbound,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              message.originalFilename.isNotEmpty
                  ? message.originalFilename
                  : t('file'),
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
