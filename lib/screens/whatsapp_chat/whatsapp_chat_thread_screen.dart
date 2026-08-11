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
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/localization/app_localizations.dart';
import '../../features/whatsapp_chat/cubit/whatsapp_chat_thread_cubit.dart';
import '../../features/whatsapp_chat/cubit/whatsapp_chat_thread_state.dart';
import '../../features/whatsapp_chat/whatsapp_chat_repository.dart';
import '../../utils/compress_image_for_chat.dart';
import '../../utils/whatsapp_template_placeholders.dart';
import '../../utils/whatsapp_thread_items.dart';
import '../../widgets/whatsapp_chat/whatsapp_chat_theme.dart';
import '../../widgets/whatsapp_chat/whatsapp_message_bubble.dart';
import '../../widgets/whatsapp_chat/whatsapp_phone_text.dart';
import '../../widgets/whatsapp_chat/whatsapp_status_widgets.dart';
import '../../core/theme/app_theme.dart';

class WhatsAppChatThreadScreen extends StatelessWidget {
  const WhatsAppChatThreadScreen({
    super.key,
    this.clientId,
    required this.clientName,
    required this.phoneNumber,
    this.isManual = false,
  });

  final int? clientId;
  final String clientName;
  final String phoneNumber;
  final bool isManual;

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
      ),
    );
  }
}

class _WhatsAppChatThreadView extends StatefulWidget {
  const _WhatsAppChatThreadView({
    required this.clientName,
    required this.phoneNumber,
    this.clientId,
  });

  final String clientName;
  final String phoneNumber;
  final int? clientId;

  @override
  State<_WhatsAppChatThreadView> createState() => _WhatsAppChatThreadViewState();
}

class _WhatsAppChatThreadViewState extends State<_WhatsAppChatThreadView>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _soundPlayer = AudioPlayer();

  String? _pendingPath;
  String? _pendingKind;
  bool _pendingVoice = false;
  bool _recording = false;
  bool _compressing = false;
  bool _sendingAttachment = false;
  Timer? _voiceCapTimer;
  bool _scrolledOnce = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _voiceCapTimer?.cancel();
    _recorder.dispose();
    _soundPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    context.read<WhatsAppChatThreadCubit>().setForeground(_foreground);
  }

  void _scrollToEndOrUnread(WhatsAppChatThreadState state, List<WhatsAppThreadItem> items) {
    if (_scrolledOnce || items.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached) return;
      final unreadIdx = items.indexWhere(
        (e) => e is WhatsAppThreadStatusItem &&
            e.variant == WhatsAppThreadStatusVariant.newMessages,
      );
      final target = unreadIdx >= 0 ? unreadIdx : items.length - 1;
      try {
        // Instant jump on open — avoid the multi-step animate "snap".
        _itemScrollController.jumpTo(index: target.clamp(0, items.length - 1));
      } catch (_) {}
      _scrolledOnce = true;
      if (mounted) context.read<WhatsAppChatThreadCubit>().markInitialScrollDone();
    });
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t('teamChatMediaPhoto')),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t('whatsappAttachCamera')),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(t('teamChatMediaVideo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(t('teamChatMediaDocument')),
              onTap: () {
                Navigator.pop(ctx);
                _pickDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(t('whatsappCurrentLocation')),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_useCurrentLocationQuick());
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(t('whatsappPickOnMap')),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_shareLocation());
              },
            ),
          ],
        ),
      ),
    );
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
                                        final text = replaceWhatsAppTemplatePlaceholders(
                                          tpl.content,
                                          customerName: widget.clientName,
                                          phone: widget.phoneNumber,
                                        );
                                        _controller.text = text;
                                        _controller.selection =
                                            TextSelection.collapsed(offset: text.length);
                                        setState(() {});
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

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _pendingPath = path;
      _pendingKind = 'document';
      _pendingVoice = false;
    });
  }

  Future<void> _toggleVoice() async {
    final loc = AppLocalizations.of(context);
    if (_recording) {
      _voiceCapTimer?.cancel();
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null && File(path).existsSync()) {
        setState(() {
          _pendingPath = path;
          _pendingKind = 'audio';
          _pendingVoice = true;
        });
      }
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc?.translate('teamChatMicDenied') ?? 'Mic denied')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    // Match team chat: AAC-LC .m4a (Meta accepts; OGG preferred on web when available).
    final path = '${dir.path}/wa_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
    setState(() => _recording = true);
    _voiceCapTimer?.cancel();
    _voiceCapTimer = Timer(const Duration(minutes: 4), () {
      if (_recording) unawaited(_toggleVoice());
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
    final arabicUi = language == 'ar';
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
            p.messages.length != c.messages.length,
        listener: (context, state) {
          if (state.sendError != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.sendError!)));
          }
          if (state.playOpenThreadSound) {
            unawaited(_playInboundSound());
          }
        },
        builder: (context, state) {
          final session = state.sessionWindow;
          final blockFreeText = session != null && session.inSession == false;
          final items = buildWhatsAppThreadItems(
            state.messages,
            language: language,
            t: t,
            newMessagesBeforeApiId: state.newMessagesBeforeApiId,
          );
          if (!state.loading && items.isNotEmpty) {
            _scrollToEndOrUnread(state, items);
          }

          final composerDir = composerTextDirection(_controller.text, arabicUi: arabicUi);
          final hasDraft = _controller.text.trim().isNotEmpty || _pendingPath != null;

          return Column(
            children: [
              if (session != null)
                WhatsAppSessionBanner(
                  inSession: session.inSession,
                  hoursRemaining: session.hoursRemaining,
                ),
              if (state.composerAlert != null)
                Material(
                  color: colors.alertErrorBg,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      t(state.composerAlert!),
                      style: TextStyle(fontSize: 12, color: colors.alertErrorFg),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.close, size: 18, color: colors.alertErrorFg),
                      onPressed: () =>
                          context.read<WhatsAppChatThreadCubit>().clearComposerAlert(),
                    ),
                  ),
                ),
              Expanded(child: _buildThreadBody(state, items, t)),
              if (_pendingPath != null || _compressing)
                Container(
                  color: colors.composerBg,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(_pendingVoice ? Icons.mic : Icons.attach_file, size: 18, color: colors.metaIn),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _compressing
                              ? t('teamChatCompressing')
                              : (_pendingPath?.split('/').last.split('\\').last ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.metaIn),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: colors.metaIn),
                        tooltip: t('teamChatClearAttachment'),
                        onPressed: () => setState(() {
                          _pendingPath = null;
                          _pendingKind = null;
                          _pendingVoice = false;
                        }),
                      ),
                    ],
                  ),
                ),
              ColoredBox(
                color: colors.composerBg,
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.composerBorder)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: blockFreeText
                        ? SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: state.sending
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
                          )
                        : Directionality(
                            textDirection: resolveBubbleTextDirection('A'),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline, color: colors.metaIn),
                                  onPressed: _sendingAttachment ? null : _showAttachSheet,
                                  tooltip: t('teamChatAttach'),
                                ),
                                IconButton(
                                  icon: Icon(Icons.description_outlined, color: colors.metaIn),
                                  onPressed: () =>
                                      _openTemplatesSheet(blockFreeText: false),
                                  tooltip: t('template'),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    minLines: 1,
                                    maxLines: 4,
                                    textDirection: composerDir,
                                    textInputAction: TextInputAction.newline,
                                    style: TextStyle(color: colors.bubbleInFg),
                                    decoration: InputDecoration(
                                      hintText: t('typeMessageWhatsApp'),
                                      hintStyle: TextStyle(color: colors.metaIn),
                                      filled: true,
                                      fillColor: colors.inputFill,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide(color: colors.inputBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide(color: colors.inputBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(
                                          color: AppTheme.primaryColor,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (!hasDraft)
                                  IconButton.filled(
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: Icon(_recording ? Icons.stop : Icons.mic),
                                    onPressed: _sendingAttachment ? null : _toggleVoice,
                                    tooltip: t('teamChatRecordVoice'),
                                  )
                                else
                                  IconButton.filled(
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          AppTheme.primaryColor.withValues(alpha: 0.4),
                                    ),
                                    icon: state.sending || _sendingAttachment
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                    onPressed: (state.sending || _sendingAttachment)
                                        ? null
                                        : _sendText,
                                  ),
                              ],
                            ),
                          ),
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
    List<WhatsAppThreadItem> items,
    String Function(String) t,
  ) {
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
    if (items.isEmpty) {
      final colors = WhatsAppChatColors.of(context);
      return Center(
        child: Text(
          t('whatsappThreadEmpty'),
          style: TextStyle(color: colors.metaIn),
        ),
      );
    }
    return Directionality(
      // Keep bubble start/end sides stable (outgoing right) under app RTL.
      textDirection: resolveBubbleTextDirection('A'),
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is WhatsAppThreadStatusItem) {
            return WhatsAppStatusSeparator(item: item);
          }
          if (item is WhatsAppThreadMessageItem) {
            return WhatsAppMessageBubble(
              message: item.message,
              connectedPhoneNumberId: state.connectedPhoneNumberId,
              onResend: () =>
                  context.read<WhatsAppChatThreadCubit>().resendFailed(item.message),
              onDelete: () => context
                  .read<WhatsAppChatThreadCubit>()
                  .deleteFailedOrServerMessage(item.message),
            );
          }
          return const SizedBox.shrink();
        },
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
