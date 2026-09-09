import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../chat_engine/cubit/chat_thread_cubit.dart';
import '../../chat_engine/cubit/chat_thread_state.dart';
import '../../chat_engine/models/chat_list_row.dart';
import '../../chat_engine/ui/chat_message_list_view.dart';
import '../../chat_engine/ui/chat_scroll_fab.dart';
import '../../features/whatsapp_chat/cubit/whatsapp_chat_thread_cubit.dart';
import '../../features/whatsapp_chat/cubit/whatsapp_chat_thread_state.dart';
import '../../features/whatsapp_chat/whatsapp_chat_repository.dart';
import '../../features/whatsapp_chat/whatsapp_coordinator_factory.dart';
import '../../features/whatsapp_chat/whatsapp_message_adapter.dart';
import '../../features/whatsapp_chat/whatsapp_thread_repository.dart';
import '../../models/lead_whatsapp_message_model.dart';
import '../../models/whatsapp_template_model.dart';
import '../../services/api_service.dart';
import '../../utils/compress_image_for_chat.dart';
import '../../utils/whatsapp_access.dart';
import '../../utils/whatsapp_chat_media_album.dart';
import '../../utils/whatsapp_template_placeholders.dart';
import '../../utils/whatsapp_thread_items.dart';
import '../../widgets/chat/chat_attach_sheet.dart';
import '../../widgets/chat/chat_composer_shell.dart';
import '../../widgets/chat/chat_conversation_status_menu.dart';
import '../../widgets/chat/chat_palette.dart';
import '../../widgets/chat/chat_pending_attachment_chip.dart';
import '../../widgets/chat/chat_separators.dart';
import '../../widgets/chat/chat_voice_recording_bar.dart';
import '../../widgets/chat_thread_empty.dart';
import '../../widgets/whatsapp_chat/company_library_picker_sheet.dart';
import '../../widgets/whatsapp_chat/whatsapp_chat_theme.dart';
import '../../widgets/whatsapp_chat/whatsapp_media_album_screen.dart';
import '../../widgets/whatsapp_chat/whatsapp_message_bubble.dart';
import '../../widgets/whatsapp_chat/whatsapp_phone_text.dart';
import '../../widgets/whatsapp_chat/whatsapp_status_widgets.dart';

class WhatsAppChatThreadScreen extends StatelessWidget {
  const WhatsAppChatThreadScreen({
    super.key,
    this.clientId,
    required this.clientName,
    required this.phoneNumber,
    this.isManual = false,
    this.initialStatus = 'open',
    this.initialStarred = false,
    this.initialUnsubscribed = false,
  });

  final int? clientId;
  final String clientName;
  final String phoneNumber;
  final bool isManual;
  final String initialStatus;
  final bool initialStarred;
  final bool initialUnsubscribed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WhatsAppChatThreadCubit(
        repository: ApiWhatsAppChatRepository(),
        clientId: clientId,
        phoneNumber: phoneNumber,
      )..bootstrap(),
      child: _WhatsAppChatThreadView(
        clientName: clientName,
        phoneNumber: phoneNumber,
        clientId: clientId,
        initialStatus: initialStatus,
        initialStarred: initialStarred,
        initialUnsubscribed: initialUnsubscribed,
      ),
    );
  }
}

class _WhatsAppChatThreadView extends StatefulWidget {
  const _WhatsAppChatThreadView({
    required this.clientName,
    required this.phoneNumber,
    this.clientId,
    this.initialStatus = 'open',
    this.initialStarred = false,
    this.initialUnsubscribed = false,
  });

  final String clientName;
  final String phoneNumber;
  final int? clientId;
  final String initialStatus;
  final bool initialStarred;
  final bool initialUnsubscribed;

  @override
  State<_WhatsAppChatThreadView> createState() => _WhatsAppChatThreadViewState();
}

class _WhatsAppChatThreadViewState extends State<_WhatsAppChatThreadView>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _soundPlayer = AudioPlayer();

  WhatsAppEngineBundle? _engine;
  int? _syncedMessagesIdentity;

  String? _pendingPath;
  String? _pendingKind;
  bool _pendingVoice = false;
  bool _recording = false;
  bool _recordingPaused = false;
  Duration _recordElapsed = Duration.zero;
  /// Excludes paused spans, so the elapsed label and the 4-minute cap both
  /// measure actual recorded audio.
  final Stopwatch _recordWatch = Stopwatch();
  bool _compressing = false;
  bool _sendingAttachment = false;
  Timer? _voiceCapTimer;
  bool _scrolledOnce = false;
  bool _foreground = true;
  String _employeeName = '';
  bool _canDeleteServer = false;
  late String _status;
  late bool _isStarred;
  late bool _isUnsubscribed;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _isStarred = widget.initialStarred;
    _isUnsubscribed = widget.initialUnsubscribed;
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(() => setState(() {}));
    _engine = WhatsAppCoordinatorFactory.create(
      repository: ApiWhatsAppChatRepository(),
      clientId: widget.clientId,
      phoneNumber: widget.phoneNumber,
      isForeground: () => _foreground,
    );
    _loadEmployeeName();
    // Preloaded so the quick-template chips can appear without opening the sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<WhatsAppChatThreadCubit>().ensureTemplatesLoaded());
    });
  }

  /// Fills the `{ اسم الموظف }` template placeholder with the signed-in sender.
  Future<void> _loadEmployeeName() async {
    try {
      final user = await ApiService().getCurrentUser();
      if (!mounted) return;
      setState(() {
        _employeeName = user.displayName;
        _canDeleteServer = canDeleteWhatsAppHistory(user);
      });
    } catch (_) {}
  }

  Future<void> _setStatus(String status, {String? snoozedUntil}) async {
    final id = widget.clientId;
    if (id == null || id <= 0) return;
    try {
      await ApiWhatsAppChatRepository().updateConversationState(
        clientId: id,
        status: status,
        snoozedUntil: snoozedUntil,
      );
      if (!mounted) return;
      setState(() => _status = status);
    } catch (_) {}
  }

  Future<void> _toggleStar() async {
    final id = widget.clientId;
    if (id == null || id <= 0) return;
    try {
      await ApiWhatsAppChatRepository().updateConversationState(
        clientId: id,
        isStarred: !_isStarred,
      );
      if (!mounted) return;
      setState(() => _isStarred = !_isStarred);
    } catch (_) {}
  }

  Future<void> _toggleUnsubscribed() async {
    final id = widget.clientId;
    if (id == null || id <= 0) return;
    try {
      await ApiWhatsAppChatRepository().updateConversationState(
        clientId: id,
        isUnsubscribed: !_isUnsubscribed,
      );
      if (!mounted) return;
      setState(() => _isUnsubscribed = !_isUnsubscribed);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _voiceCapTimer?.cancel();
    _recorder.dispose();
    _soundPlayer.dispose();
    _engine?.dispose();
    super.dispose();
  }

  void _syncEngine(List<LeadWhatsAppMessageModel> messages) {
    final eng = _engine;
    if (eng == null) return;
    final identity = Object.hashAll(messages.map((m) => Object.hash(m.id, m.deliveryStatus, m.localStatus, m.body)));
    if (identity == _syncedMessagesIdentity) return;
    _syncedMessagesIdentity = identity;
    eng.registry.clear();
    eng.threadCubit.upsertMessages(adaptWhatsAppMessages(messages));
  }

  void _scrollToEndOrUnread(WhatsAppChatThreadState state) {
    final eng = _engine;
    if (_scrolledOnce || eng == null) return;
    final rows = eng.threadCubit.state.rows;
    if (rows.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final unreadIdx = rows.indexWhere((r) => r is ChatUnreadSeparatorRow);
      eng.scrollService.updateItemCount(rows.length);
      eng.scrollService.stickToTail = true;
      if (unreadIdx >= 0) {
        await eng.scrollService.scrollToRowIndex(unreadIdx);
      } else {
        await eng.coordinator.scrollToBottom(animated: false);
      }
      _scrolledOnce = true;
      if (mounted) context.read<WhatsAppChatThreadCubit>().markInitialScrollDone();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) {
      context.read<WhatsAppChatThreadCubit>().setForeground(_foreground);
    }
  }

  Future<void> _playInboundSound() async {
    try {
      await _soundPlayer.play(AssetSource('sounds/notif_whatsapp.wav'));
    } catch (_) {}
  }

  Future<void> _sendText() async {
    final text = _controller.text;
    if (_pendingPath != null) {
      await _sendPendingAttachment(caption: text.trim().isEmpty ? null : text.trim());
      _controller.clear();
      return;
    }
    if (text.trim().isEmpty) return;
    _controller.clear();
    await context.read<WhatsAppChatThreadCubit>().sendText(text);
  }

  Future<void> _sendPendingAttachment({String? caption}) async {
    final path = _pendingPath;
    if (path == null) return;
    setState(() => _sendingAttachment = true);
    final cubit = context.read<WhatsAppChatThreadCubit>();
    await cubit.sendMedia(
      path,
      caption: caption,
      isVoiceNote: _pendingVoice,
      kind: _pendingKind,
    );
    setState(() {
      _pendingPath = null;
      _pendingKind = null;
      _pendingVoice = false;
      _sendingAttachment = false;
    });
  }

  Future<void> _showAttachSheet() async {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    final action = await showChatAttachSheet(
      context,
      capabilities: const ChatAttachCapabilities(
        photo: true,
        camera: true,
        video: true,
        file: true,
        library: true,
        location: true,
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
        await _pickDocument();
      case ChatAttachAction.library:
        unawaited(_pickFromCompanyLibrary());
      case ChatAttachAction.location:
        await _showLocationOptions();
    }
  }

  Future<void> _showLocationOptions() async {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(t('whatsappCurrentLocation')),
              onTap: () => Navigator.pop(ctx, 'current'),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(t('whatsappPickOnMap')),
              onTap: () => Navigator.pop(ctx, 'map'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'current') {
      unawaited(_useCurrentLocationQuick());
    } else {
      unawaited(_shareLocation());
    }
  }

  Future<void> _openTemplatesSheet({required bool blockFreeText}) async {
    final cubit = context.read<WhatsAppChatThreadCubit>();
    final colors = WhatsAppChatColors.of(context);
    final localizations = AppLocalizations.of(context);
    String t(String k) => localizations?.translate(k) ?? k;

    unawaited(cubit.ensureTemplatesLoaded());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.composerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return BlocProvider.value(
          value: cubit,
          child: BlocBuilder<WhatsAppChatThreadCubit, WhatsAppChatThreadState>(
            builder: (context, state) {
              final templates = state.templates;
              final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.inputBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t('whatsappTemplatesTitle'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colors.bubbleInFg,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: t('retry'),
                              onPressed: state.templatesLoading
                                  ? null
                                  : () => cubit.ensureTemplatesLoaded(force: true),
                              icon: Icon(Icons.refresh, color: colors.metaIn),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              icon: Icon(Icons.close, color: colors.metaIn),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: colors.composerBorder),
                      if (state.templatesLoading && templates.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (templates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 40,
                                color: colors.metaIn,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                t('whatsappNoApprovedTemplates'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.bubbleInFg,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t('whatsappTemplatesEmptyHint'),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, height: 1.4, color: colors.metaIn),
                              ),
                            ],
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                            itemCount: templates.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: colors.composerBorder),
                            itemBuilder: (context, index) {
                              final tpl = templates[index];
                              final preview = tpl.content.trim();
                              return ListTile(
                                title: Text(
                                  tpl.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colors.bubbleInFg,
                                  ),
                                ),
                                subtitle: preview.isEmpty
                                    ? null
                                    : Text(
                                        preview,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: colors.metaIn),
                                      ),
                                trailing: blockFreeText
                                    ? Icon(Icons.send, size: 18, color: AppTheme.primaryColor)
                                    : Tooltip(
                                        message: t('whatsappInsertTemplate'),
                                        child: Icon(Icons.keyboard_arrow_down, color: colors.metaIn),
                                      ),
                                onTap: state.sending
                                    ? null
                                    : () async {
                                        Navigator.pop(sheetCtx);
                                        if (blockFreeText) {
                                          await cubit.sendTemplate(tpl.id);
                                          return;
                                        }
                                        _insertTemplate(tpl);
                                      },
                                onLongPress: state.sending || blockFreeText
                                    ? null
                                    : () async {
                                        Navigator.pop(sheetCtx);
                                        await cubit.sendTemplate(tpl.id);
                                      },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(source: source);
      if (file == null) return;
      setState(() => _compressing = true);
      final path = await compressImageForChatIfNeeded(file.path);
      setState(() {
        _compressing = false;
        _pendingPath = path;
        _pendingKind = 'image';
        _pendingVoice = false;
      });
    } catch (_) {
      setState(() => _compressing = false);
    }
  }

  Future<void> _pickVideo() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _pendingPath = file.path;
      _pendingKind = 'video';
      _pendingVoice = false;
    });
  }

  /// Audio extensions are accepted alongside documents so an existing recording
  /// can be attached, matching the web file input's `audio/*`.
  static const List<String> _audioExtensions = [
    'mp3',
    'm4a',
    'ogg',
    'opus',
    'wav',
    'aac',
  ];

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'txt',
        ..._audioExtensions,
      ],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final ext = path.split('.').last.toLowerCase();
    setState(() {
      _pendingPath = path;
      _pendingKind = _audioExtensions.contains(ext) ? 'audio' : 'document';
      _pendingVoice = false;
    });
  }

  /// One-tap chips for the first few approved templates, inserting the resolved
  /// content into the composer. Web parity: `ChatComposer` quick-template row.
  Widget _buildQuickTemplates(
    WhatsAppChatThreadState state,
    WhatsAppChatColors colors,
  ) {
    final templates = state.templates.take(6).toList();
    if (templates.isEmpty) return const SizedBox.shrink();
    return Container(
      color: colors.composerBg,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: SizedBox(
        height: 32,
        child: Semantics(
          label: AppLocalizations.of(context)?.translate('whatsappQuickTemplates'),
          container: true,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final tpl = templates[index];
              return ActionChip(
                label: Text(
                  tpl.name,
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () => _insertTemplate(tpl),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Fills placeholders and drops the text into the composer, leaving the user
  /// free to edit before sending.
  void _insertTemplate(WhatsAppTemplateModel tpl) {
    final resolved = replaceWhatsAppTemplatePlaceholders(
      tpl.content,
      customerName: widget.clientName,
      phone: widget.phoneNumber,
      employeeName: _employeeName,
      bodyVariables: tpl.bodyVariables,
    );
    _controller.text = resolved;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  /// Opens every image/video in the thread as a swipeable album, positioned on
  /// the tapped message (web parity: `ChatMediaViewer`).
  void _openMediaAlbum(WhatsAppChatThreadState state, int messageId) {
    final items = buildWhatsAppMediaAlbum(state.messages);
    WhatsAppMediaAlbumScreen.open(
      context,
      items: items,
      initialIndex: findWhatsAppMediaAlbumIndex(items, messageId),
    );
  }

  Future<void> _pickFromCompanyLibrary() async {
    final picked = await CompanyLibraryPickerSheet.show(context);
    if (picked == null || !mounted) return;
    setState(() {
      _pendingPath = picked.path;
      _pendingKind = picked.kind;
      _pendingVoice = false;
    });
  }

  /// Max recorded (unpaused) length, matching the web recorder.
  static const Duration _voiceCap = Duration(minutes: 4);

  Future<void> _startVoiceRecording() async {
    final loc = AppLocalizations.of(context);
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc?.translate('teamChatMicDenied') ?? 'Mic denied')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    // Match team chat: AAC-LC .m4a (server converts to OGG/Opus for Meta).
    final path = '${dir.path}/wa_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
    if (!mounted) return;
    // The stopwatch excludes paused spans, so the cap counts recorded audio.
    _recordWatch
      ..reset()
      ..start();
    setState(() {
      _recording = true;
      _recordingPaused = false;
      _recordElapsed = Duration.zero;
    });
    _voiceCapTimer?.cancel();
    _voiceCapTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recording) return;
      setState(() => _recordElapsed = _recordWatch.elapsed);
      if (_recordWatch.elapsed >= _voiceCap) unawaited(_stopVoiceRecording());
    });
  }

  Future<void> _pauseVoiceRecording() async {
    if (!_recording || _recordingPaused) return;
    await _recorder.pause();
    _recordWatch.stop();
    if (!mounted) return;
    setState(() => _recordingPaused = true);
  }

  Future<void> _resumeVoiceRecording() async {
    if (!_recording || !_recordingPaused) return;
    await _recorder.resume();
    _recordWatch.start();
    if (!mounted) return;
    setState(() => _recordingPaused = false);
  }

  /// Stops and keeps the recording as a pending voice-note attachment.
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
    });
    if (path != null && File(path).existsSync()) {
      setState(() {
        _pendingPath = path;
        _pendingKind = 'audio';
        _pendingVoice = true;
      });
    }
  }

  /// Discards the recording without attaching it.
  Future<void> _cancelVoiceRecording() async {
    if (!_recording) return;
    _voiceCapTimer?.cancel();
    _recordWatch.stop();
    try {
      await _recorder.cancel();
    } catch (_) {
      // Some platforms only support stop(); drop the file either way.
      final path = await _recorder.stop();
      if (path != null) {
        final f = File(path);
        if (f.existsSync()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordingPaused = false;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _shareLocation() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _ShareLocationSheet(),
    );
    if (picked == null || !mounted) return;
    await context.read<WhatsAppChatThreadCubit>().sendLocation(
          latitude: picked['lat'] as double,
          longitude: picked['lng'] as double,
          name: picked['name'] as String?,
          address: picked['address'] as String?,
        );
  }

  Future<void> _useCurrentLocationQuick() async {
    final loc = AppLocalizations.of(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc?.translate('locationServiceDisabled') ?? 'Location disabled')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc?.translate('locationPermissionDenied') ?? 'Permission denied'),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      await context.read<WhatsAppChatThreadCubit>().sendLocation(
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.translate('whatsappChatCouldNotSend') ?? 'Could not send'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    String t(String k) => localizations?.translate(k) ?? k;

    final titleIsPhone = WhatsAppPhoneText.isPhoneLike(widget.clientName);
    final colors = WhatsAppChatColors.of(context);

    return Scaffold(
      backgroundColor: colors.threadBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBg,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleIsPhone
                ? WhatsAppPhoneText(
                    widget.clientName,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  )
                : Text(
                    widget.clientName,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
            if (widget.phoneNumber.isNotEmpty &&
                widget.phoneNumber != widget.clientName)
              WhatsAppPhoneText(
                widget.phoneNumber,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        actions: [
          if (widget.clientId != null && widget.clientId! > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Center(
                child: ChatConversationStatusMenu(
                  t: t,
                  status: _status,
                  isStarred: _isStarred,
                  isUnsubscribed: _isUnsubscribed,
                  onChange: (payload) async {
                    if (payload.isStarred != null) {
                      await _toggleStar();
                      return;
                    }
                    if (payload.isUnsubscribed != null) {
                      await _toggleUnsubscribed();
                      return;
                    }
                    if (payload.status != null) {
                      await _setStatus(
                        payload.status!,
                        snoozedUntil: payload.snoozedUntil,
                      );
                    }
                  },
                ),
              ),
            ),
          if (widget.clientId != null && widget.clientId! > 0)
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.white),
              tooltip: t('whatsappOpenLead'),
              onPressed: () {
                Navigator.pushNamed(context, '/leads/details', arguments: widget.clientId);
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => context.read<WhatsAppChatThreadCubit>().refresh(),
          ),
        ],
      ),
      body: BlocConsumer<WhatsAppChatThreadCubit, WhatsAppChatThreadState>(
        listenWhen: (p, c) =>
            p.sendError != c.sendError ||
            p.playOpenThreadSound != c.playOpenThreadSound ||
            p.messages != c.messages,
        listener: (context, state) {
          if (state.sendError != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.sendError!)));
          }
          if (state.playOpenThreadSound) {
            unawaited(_playInboundSound());
          }
          _syncEngine(state.messages);
          if (!state.loading && state.messages.isNotEmpty) {
            _scrollToEndOrUnread(state);
            if (_scrolledOnce && (_engine?.scrollService.stickToTail ?? false)) {
              unawaited(_engine!.coordinator.scrollToBottom(animated: true));
            }
          }
        },
        builder: (context, state) {
          _syncEngine(state.messages);

          if (!state.composerReady) {
            return Column(
              children: [
                Expanded(child: _WhatsAppThreadOpening(label: t('loading'))),
              ],
            );
          }

          final session = state.sessionWindow;
          final blockFreeText = session != null && session.inSession == false;
          final sendBlocked = state.sendBlocked;
          final hasDraft = _controller.text.trim().isNotEmpty || _pendingPath != null;
          final palette = WhatsAppStyleChatPalette.of(context);

          return Column(
            children: [
              if (session != null && !state.sendBlocked)
                WhatsAppSessionBanner(inSession: session.inSession),
              if (state.sendBlocked)
                _AlertBar(
                  message: t('whatsappReconnectRequired'),
                  colors: colors,
                )
              else if (state.displayNameBlocked)
                _AlertBar(
                  message: t('whatsapp_display_name_not_approved'),
                  colors: colors,
                )
              else if (state.composerAlert != null)
                _AlertBar(
                  message: t(state.composerAlert!),
                  colors: colors,
                  onDismiss: () =>
                      context.read<WhatsAppChatThreadCubit>().clearComposerAlert(),
                ),
              Expanded(child: _buildThreadBody(state, t, language, palette)),
              if (!_recording &&
                  !blockFreeText &&
                  !sendBlocked &&
                  session?.inSession == true)
                WhatsAppSessionOpenHint(hoursRemaining: session?.hoursRemaining),
              if (!_recording && !sendBlocked && !blockFreeText)
                _buildQuickTemplates(state, colors),
              if (blockFreeText && !sendBlocked)
                ColoredBox(
                  color: colors.composerBg,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: (state.sending || sendBlocked)
                              ? null
                              : () => _openTemplatesSheet(blockFreeText: true),
                          icon: state.sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.description_outlined),
                          label: Text(t('whatsappChooseTemplate')),
                          style: FilledButton.styleFrom(
                            foregroundColor: colors.bubbleInFg,
                            backgroundColor: colors.bubbleIn,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                ChatComposerShell(
                  draft: _controller,
                  hintText: t('typeMessageWhatsApp'),
                  sending: state.sending || _sendingAttachment,
                  enabled: !sendBlocked,
                  onSend: () => unawaited(_sendText()),
                  paletteSendBg: AppTheme.primaryColor,
                  paletteSendFg: Colors.white,
                  composerBg: colors.composerBg,
                  inputFill: colors.inputFill,
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
                          onClear: () => setState(() {
                            _pendingPath = null;
                            _pendingKind = null;
                            _pendingVoice = false;
                          }),
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
                            metaColor: colors.metaIn,
                          ),
                        )
                      : null,
                  onAttach: (_sendingAttachment || sendBlocked)
                      ? null
                      : () => unawaited(_showAttachSheet()),
                  showMic: !hasDraft,
                  onMic: () => unawaited(_startVoiceRecording()),
                  banner: sendBlocked
                      ? null
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: Icon(
                              Icons.description_outlined,
                              color: colors.metaIn,
                            ),
                            onPressed: () =>
                                _openTemplatesSheet(blockFreeText: false),
                            tooltip: t('template'),
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThreadBody(
    WhatsAppChatThreadState state,
    String Function(String) t,
    String language,
    ChatPalette palette,
  ) {
    final eng = _engine;
    if (state.loading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadError != null && state.messages.isEmpty) {
      final colors = WhatsAppChatColors.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.metaIn),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.read<WhatsAppChatThreadCubit>().refresh(),
                child: Text(t('retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (eng == null || state.messages.isEmpty) {
      return ChatThreadEmpty(
        icon: Icons.chat_bubble_outline_rounded,
        title: t('whatsappThreadEmpty'),
        subtitle: t('whatsappThreadEmptyHint'),
      );
    }

    // Conversation-started chip stays as a list header (not a ChatListRow).
    Widget? startedHeader;
    if (state.messages.isNotEmpty) {
      final first = state.messages.first;
      final startedLabel = t('whatsappConversationStartedOn').replaceAll(
        '{date}',
        chatDayChipLabel(first.createdAt.toLocal(), language: language, t: t),
      );
      startedHeader = WhatsAppStatusSeparator(
        item: WhatsAppThreadStatusItem(
          id: 'status-started',
          variant: WhatsAppThreadStatusVariant.started,
          label: startedLabel,
        ),
      );
    }

    return BlocProvider<ChatThreadCubit<WhatsAppEngineMessage>>.value(
      value: eng.threadCubit,
      child: BlocBuilder<ChatThreadCubit<WhatsAppEngineMessage>, ChatThreadState>(
        builder: (context, threadState) {
          eng.scrollService.updateItemCount(threadState.rows.length);
          return Directionality(
            textDirection: resolveBubbleTextDirection('A'),
            child: Stack(
              children: [
                Column(
                  children: [
                    if (startedHeader != null) startedHeader,
                    Expanded(
                      child: ChatMessageListView(
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
                          final engMsg = row.message as WhatsAppEngineMessage;
                          final msg = engMsg.raw;
                          return WhatsAppMessageBubble(
                            message: msg,
                            connectedPhoneNumberId: state.connectedPhoneNumberId,
                            onResend: () => context
                                .read<WhatsAppChatThreadCubit>()
                                .resendFailed(msg),
                            onDelete: () => context
                                .read<WhatsAppChatThreadCubit>()
                                .deleteFailedOrServerMessage(
                                  msg,
                                  canDeleteServer: _canDeleteServer,
                                ),
                            showDelete: msg.id <= 0 ||
                                msg.isOptimistic ||
                                _canDeleteServer,
                            onOpenAlbum: () => _openMediaAlbum(state, msg.id),
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
                    ),
                  ],
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
}

/// Full-body placeholder while session + account status are still resolving.
/// A tiny spinner above a live composer reads as three different screens.
class _WhatsAppThreadOpening extends StatelessWidget {
  const _WhatsAppThreadOpening({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryAccent(theme.brightness),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky composer warning bar. Dismissible only when [onDismiss] is given —
/// account-level blocks stay until the underlying problem is fixed.
class _AlertBar extends StatelessWidget {
  const _AlertBar({
    required this.message,
    required this.colors,
    this.onDismiss,
  });

  final String message;
  final WhatsAppChatColors colors;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.alertErrorBg,
      child: ListTile(
        dense: true,
        title: Text(
          message,
          style: TextStyle(fontSize: 12, color: colors.alertErrorFg),
        ),
        trailing: onDismiss == null
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.alertErrorFg),
                onPressed: onDismiss,
              ),
      ),
    );
  }
}

class _ShareLocationSheet extends StatefulWidget {
  const _ShareLocationSheet();

  @override
  State<_ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends State<_ShareLocationSheet> {
  LatLng _point = const LatLng(33.3152, 44.3661);
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initPos();
  }

  Future<void> _initPos() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _point = LatLng(pos.latitude, pos.longitude);
          _ready = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final height = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              loc?.translate('whatsappShareLocation') ?? 'Share location',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: _point,
                      initialZoom: 14,
                      onTap: (_, p) => setState(() => _point = p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.loopcrm.mobile',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _point,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: loc?.translate('whatsappLocationName') ?? 'Name (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: loc?.translate('whatsappLocationAddress') ?? 'Address (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'lat': _point.latitude,
                      'lng': _point.longitude,
                      'name': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
                      'address':
                          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
                    });
                  },
                  child: Text(loc?.translate('whatsappSendLocation') ?? 'Send location'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
