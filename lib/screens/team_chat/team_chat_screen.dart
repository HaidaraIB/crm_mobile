import 'dart:async';
import 'dart:io';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:record/record.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/app_locales.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/tenant_chat_models.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/team_chat_away_service.dart';
import '../../services/team_chat_route_observer.dart';
import '../../services/team_chat_unread_holder.dart';
import '../../utils/compress_image_for_chat.dart';
import 'team_chat_common.dart';
import 'team_chat_composer.dart';
import 'team_chat_conversation_tile.dart';
import 'team_chat_message_bubble.dart';

DateTime _startOfLocalDay(DateTime d) =>
    DateTime(d.year, d.month, d.day);

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// ListView only lays out visible children (+ [cacheExtent]). Far-off rows have no
/// [GlobalKey.currentContext] until we scroll them near the viewport.
const double _teamChatJumpDaySepBlockPx = 56;
const double _teamChatJumpListTopPadPx = 6;

bool _tenantMessagesPayloadEqual(List<TenantChatMessage> a, List<TenantChatMessage> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.id != y.id) return false;
    if (x.readByPeer != y.readByPeer) return false;
    if (x.body != y.body) return false;
    if (x.createdAt != y.createdAt) return false;
    if (x.sender.id != y.sender.id) return false;
    if (x.attachmentKind != y.attachmentKind) return false;
    if (x.attachmentUrl != y.attachmentUrl) return false;
    if (x.attachmentWidth != y.attachmentWidth) return false;
    if (x.attachmentHeight != y.attachmentHeight) return false;
    if (x.originalFilename != y.originalFilename) return false;
    if (x.replyTo?.id != y.replyTo?.id) return false;
    if (x.forwardedFrom?.id != y.forwardedFrom?.id) return false;
  }
  return true;
}

bool _tenantPinnedSummariesEqual(
  List<TenantChatPinnedMessageSummary> a,
  List<TenantChatPinnedMessageSummary> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (x.pinId != y.pinId ||
        x.messageId != y.messageId ||
        x.body != y.body ||
        x.attachmentKind != y.attachmentKind) {
      return false;
    }
  }
  return true;
}

bool _tenantConversationTilePayloadEqual(TenantChatConversation a, TenantChatConversation b) {
  if (a.id != b.id) return false;
  if (a.kind != b.kind) return false;
  if (a.unreadCount != b.unreadCount) return false;
  if (a.updatedAt != b.updatedAt) return false;
  if (a.lastReadMessageId != b.lastReadMessageId) return false;
  if (a.groupTitle != b.groupTitle) return false;
  if (a.memberCount != b.memberCount) return false;
  if (a.onlineCount != b.onlineCount) return false;
  final ou = a.otherUser, ob = b.otherUser;
  if ((ou == null) != (ob == null)) return false;
  if (ou != null && ob != null) {
    if (ou.id != ob.id) return false;
    if (ou.firstName != ob.firstName || ou.lastName != ob.lastName) return false;
    if (ou.profilePhoto != ob.profilePhoto) return false;
    if (ou.isOnline != ob.isOnline) return false;
  }
  final lm = a.lastMessage, rm = b.lastMessage;
  if ((lm == null) != (rm == null)) return false;
  if (lm != null) {
    if (lm.id != rm!.id ||
        lm.body != rm.body ||
        lm.createdAt != rm.createdAt ||
        lm.senderId != rm.senderId ||
        lm.attachmentKind != rm.attachmentKind) {
      return false;
    }
  }
  return _tenantPinnedSummariesEqual(a.pinnedMessages, b.pinnedMessages);
}

bool _tenantConversationsPayloadEqual(List<TenantChatConversation> a, List<TenantChatConversation> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_tenantConversationTilePayloadEqual(a[i], b[i])) return false;
  }
  return true;
}

List<List<TenantChatMessage>> _groupTenantMessagesByDay(List<TenantChatMessage> messages) {
  final groups = <String, List<TenantChatMessage>>{};
  for (final m in messages) {
    final d = DateTime.parse(m.createdAt);
    groups.putIfAbsent(_dayKey(d), () => []).add(m);
  }
  final keys = groups.keys.toList()..sort();
  return [for (final k in keys) groups[k]!];
}

/// One visual row in the thread list: day chip or message bubble.
final class _ChatThreadRow {
  const _ChatThreadRow.daySeparator(this.dayStart) : message = null, sameSenderAsPrevious = false;
  const _ChatThreadRow.message(this.message, {required this.sameSenderAsPrevious}) : dayStart = null;

  final DateTime? dayStart;
  final TenantChatMessage? message;
  final bool sameSenderAsPrevious;

  bool get isDaySeparator => dayStart != null;
}

List<_ChatThreadRow> _computeChatThreadRows(List<TenantChatMessage> messages) {
  if (messages.isEmpty) return const [];
  final out = <_ChatThreadRow>[];
  for (final list in _groupTenantMessagesByDay(messages)) {
    out.add(_ChatThreadRow.daySeparator(_startOfLocalDay(DateTime.parse(list.first.createdAt))));
    for (var j = 0; j < list.length; j++) {
      final m = list[j];
      final prev = j > 0 ? list[j - 1] : null;
      final sameSender = prev != null && prev.sender.id == m.sender.id;
      out.add(_ChatThreadRow.message(m, sameSenderAsPrevious: sameSender));
    }
  }
  return out;
}

class TeamChatScreen extends StatefulWidget {
  const TeamChatScreen({super.key, this.initialConversationId});

  /// When set (e.g. from a push notification), open this thread after loading conversations.
  final int? initialConversationId;

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen>
    with RouteAware, WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final TextEditingController _draft = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _messageItemKeys = {};

  List<TenantChatConversation> _conversations = [];
  List<TenantChatMessage> _messages = [];
  int? _selectedId;
  bool _loadingConv = true;
  bool _loadingMsg = false;
  String? _loadError;

  TenantChatMessage? _replyTo;
  int? _forwardSourceId;
  final TextEditingController _forwardCaption = TextEditingController();

  String? _pendingAttachmentPath;
  bool _compressing = false;
  bool _sending = false;
  bool _voiceRecording = false;
  AudioRecorder? _recorder;
  Timer? _voiceCapTimer;
  String? _voiceTempPath;

  Timer? _convTimer;
  Timer? _msgTimer;
  Timer? _presencePollTimer;
  Timer? _presenceHeartbeatTimer;
  Timer? _typingDebounceTimer;
  Timer? _markReadDebounce;

  int _readCursor = 0;
  int _pendingMarkReadId = 0;
  /// User wants the transcript tail (new messages / late media layout). Not the same as "geometrically
  /// near bottom" — [maxScrollExtent] grows as images load, which would falsely clear a geometry-only flag.
  bool _stickToTail = true;
  bool _tailSnapPostFrameScheduled = false;
  bool _showScrollFab = false;
  int _peerBelowFab = 0;

  String _localPresence = kTenantChatPresenceIdle;
  bool _draftTypingSignal = false;

  int? _currentUserId;
  TenantChatPeerPresenceResponse? _presenceResponse;

  /// Recomputed only when [_messages] identity changes — avoids O(n) row allocations every rebuild.
  List<TenantChatMessage>? _threadRowsMessagesRef;
  List<_ChatThreadRow>? _threadRowsCache;

  static const double _nearBottomPx = 80;
  static const double _avgRowPx = 58;

  /// Same idea as web [threadFabUnreadCount]: geometric peer-below vs server [unreadCount] for this thread.
  int _fabUnreadDisplayCount() {
    final id = _selectedId;
    var server = 0;
    if (id != null) {
      for (final c in _conversations) {
        if (c.id == id) {
          server = c.unreadCount;
          break;
        }
      }
    }
    return _peerBelowFab > server ? _peerBelowFab : server;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _draft.addListener(_onDraftChanged);
    TeamChatAwayService.instance.setTeamChatVisible(true);
    _syncTeamChatAwayContext();
    unawaited(_bootstrap());
  }

  void _syncTeamChatAwayContext() {
    TeamChatAwayService.instance.setActiveConversationId(_selectedId);
  }

  Future<void> _bootstrap() async {
    try {
      final me = await _api.getCurrentUser();
      _currentUserId = me.id;
    } catch (_) {}
    await _refreshConversations();
    final openId = widget.initialConversationId;
    if (openId != null && mounted) {
      for (final c in _conversations) {
        if (c.id == openId) {
          await _selectConversation(openId);
          break;
        }
      }
    }
    _convTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_foreground) unawaited(_refreshConversations(silent: true));
    });
  }

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

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
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _draft.removeListener(_onDraftChanged);
    _convTimer?.cancel();
    _msgTimer?.cancel();
    _presencePollTimer?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _markReadDebounce?.cancel();
    _voiceCapTimer?.cancel();
    unawaited(_stopVoiceInternal(finalize: false, allowSetState: false));
    if (_selectedId != null) {
      unawaited(_api.postTenantChatPeerPresence(_selectedId!, kTenantChatPresenceIdle));
    }
    _draft.dispose();
    _forwardCaption.dispose();
    TeamChatAwayService.instance.setActiveConversationId(null);
    TeamChatAwayService.instance.setTeamChatVisible(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _msgTimer?.cancel();
      _presencePollTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startThreadTimers();
    }
  }

  @override
  void didPush() {
    TeamChatAwayService.instance.setTeamChatVisible(true);
    _syncTeamChatAwayContext();
    _snapThreadToBottomOnOpen();
  }

  @override
  void didPopNext() {
    TeamChatAwayService.instance.setTeamChatVisible(true);
    _syncTeamChatAwayContext();
    // Do not snap the thread here: [didPopNext] runs when any route pushed on top
    // (e.g. image/video viewer) is popped — user expects the prior scroll offset.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _processScrollFabAndRead();
    });
  }

  /// Snap to the latest messages when this route is first shown ([didPush]).
  /// Not used when returning from overlays (see [didPopNext]).
  void _snapThreadToBottomOnOpen() {
    if (_selectedId == null) return;
    _stickToTail = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: false);
      _processScrollFabAndRead();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleTailSnapIfSticking();
      });
    });
  }

  @override
  void didPushNext() => TeamChatAwayService.instance.setTeamChatVisible(false);

  @override
  void didPop() => TeamChatAwayService.instance.setTeamChatVisible(false);

  Future<void> _refreshConversations({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loadingConv = true);
    try {
      final page = await _api.getTenantChatConversations();
      if (!mounted) return;
      final total = page.results.fold<int>(0, (s, c) => s + c.unreadCount);
      TeamChatUnreadHolder.setTotal(total);
      final sorted = [...page.results]..sort((a, b) {
        final ag = a.isCompanyGroup ? 1 : 0;
        final bg = b.isCompanyGroup ? 1 : 0;
        if (ag != bg) return bg.compareTo(ag);
        return b.updatedAt.compareTo(a.updatedAt);
      });
      if (silent &&
          !_loadingConv &&
          _tenantConversationsPayloadEqual(_conversations, sorted)) {
        _syncReadCursorFromServer();
        return;
      }
      setState(() {
        _conversations = sorted;
        _loadingConv = false;
        _loadError = null;
      });
      _syncReadCursorFromServer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConv = false;
        if (!silent) _loadError = e.toString();
      });
    }
  }

  void _syncReadCursorFromServer() {
    if (_selectedId == null) return;
    TenantChatConversation? row;
    for (final c in _conversations) {
      if (c.id == _selectedId) {
        row = c;
        break;
      }
    }
    if (row != null && row.lastReadMessageId != null) {
      _readCursor = _readCursor > row.lastReadMessageId!
          ? _readCursor
          : row.lastReadMessageId!;
    }
  }

  Future<void> _selectConversation(int id) async {
    unawaited(NotificationService().clearTenantChatPushMergeBuffer(id));
    TenantChatConversation? row;
    for (final c in _conversations) {
      if (c.id == id) {
        row = c;
        break;
      }
    }
    _stickToTail = true;
    _readCursor = row?.lastReadMessageId ?? 0;
    _messageItemKeys.clear();
    _threadRowsCache = null;
    _threadRowsMessagesRef = null;
    setState(() {
      _selectedId = id;
      _messages = [];
      _replyTo = null;
      _forwardSourceId = null;
      _pendingAttachmentPath = null;
      _loadError = null;
      _presenceResponse = null;
    });
    _syncTeamChatAwayContext();
    _msgTimer?.cancel();
    _presencePollTimer?.cancel();
    _syncReadCursorFromServer();
    await _loadMessages();
    _startThreadTimers();
    if (mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
        _processScrollFabAndRead();
        // Second frame: first [jumpTo] may run before full child layout; metrics also cover async media.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scheduleTailSnapIfSticking();
        });
      });
    }
  }

  void _startThreadTimers() {
    if (!_foreground || _selectedId == null) return;
    _msgTimer?.cancel();
    _msgTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (_foreground) unawaited(_loadMessages(silent: true));
    });
    _presencePollTimer?.cancel();
    _presencePollTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) async {
      if (!_foreground || _selectedId == null) return;
      final r = await _api.getTenantChatPeerPresence(_selectedId!);
      if (!mounted || _selectedId == null) return;
      if (tenantChatPresenceResponsesEqual(_presenceResponse, r)) return;
      setState(() => _presenceResponse = r);
    });
    unawaited(_pollPresenceOnce());
  }

  Future<void> _pollPresenceOnce() async {
    if (_selectedId == null) return;
    final r = await _api.getTenantChatPeerPresence(_selectedId!);
    if (!mounted) return;
    if (tenantChatPresenceResponsesEqual(_presenceResponse, r)) return;
    setState(() => _presenceResponse = r);
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final id = _selectedId;
    if (id == null) return;
    if (!silent && mounted) setState(() => _loadingMsg = true);
    try {
      final page = await _api.getTenantChatMessages(id);
      if (!mounted || _selectedId != id) return;
      final sorted = [...page.results]..sort(
          (a, b) => DateTime.parse(a.createdAt).compareTo(DateTime.parse(b.createdAt)),
        );
      if (silent && _tenantMessagesPayloadEqual(_messages, sorted)) {
        return;
      }
      setState(() {
        _messages = sorted;
        _loadingMsg = false;
      });
      if (_stickToTail) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: false);
        });
      }
    } catch (e) {
      if (!mounted || _selectedId != id) return;
      setState(() {
        _loadingMsg = false;
        if (!silent) _loadError = e.toString();
      });
    }
  }

  void _onDraftChanged() {
    if (_selectedId == null) return;
    _typingDebounceTimer?.cancel();
    if (_draft.text.trim().isEmpty) {
      setState(() => _draftTypingSignal = false);
      _updateDerivedPresence();
      return;
    }
    _typingDebounceTimer = Timer(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() => _draftTypingSignal = true);
      _updateDerivedPresence();
    });
  }

  void _updateDerivedPresence() {
    if (_selectedId == null) return;
    String next;
    if (_voiceRecording) {
      next = kTenantChatPresenceRecording;
    } else if (_compressing || _pendingAttachmentPath != null) {
      next = kTenantChatPresenceUploading;
    } else if (_sending && _pendingAttachmentPath != null) {
      next = kTenantChatPresenceUploading;
    } else if (_sending) {
      next = kTenantChatPresenceSending;
    } else if (_draftTypingSignal && _draft.text.trim().isNotEmpty) {
      next = kTenantChatPresenceTyping;
    } else {
      next = kTenantChatPresenceIdle;
    }
    if (next == _localPresence) return;
    _localPresence = next;
    unawaited(_api.postTenantChatPeerPresence(_selectedId!, next));
    _presenceHeartbeatTimer?.cancel();
    if (next != kTenantChatPresenceIdle) {
      _presenceHeartbeatTimer =
          Timer.periodic(const Duration(milliseconds: 3200), (_) {
        unawaited(_api.postTenantChatPeerPresence(_selectedId!, _localPresence));
      });
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _processScrollFabAndRead();
  }

  /// When the scrollable's content size changes (e.g. decoded images), re-apply tail if we're following it.
  bool _onThreadScrollMetricsNotification(ScrollMetricsNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    _scheduleTailSnapIfSticking();
    return false;
  }

  void _scheduleTailSnapIfSticking() {
    if (!_stickToTail) return;
    if (_tailSnapPostFrameScheduled) return;
    _tailSnapPostFrameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _tailSnapPostFrameScheduled = false;
      if (!mounted || !_stickToTail || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (_scroll.position.pixels < max - 2) {
        _scroll.jumpTo(max);
      }
      _processScrollFabAndRead();
    });
  }

  /// Sync tail-follow intent from user-driven scroll only (not from content height changes).
  bool _onThreadScrollInteractionNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final m = n.metrics;
    final fromBottom = m.maxScrollExtent - m.pixels;
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      _stickToTail = fromBottom <= _nearBottomPx;
    } else if (n is ScrollEndNotification) {
      _stickToTail = fromBottom <= _nearBottomPx;
    }
    return false;
  }

  int _estimateMaxVisibleMessageId() {
    if (_messages.isEmpty || !_scroll.hasClients) return 0;
    final pos = _scroll.position;
    final nearBottom = pos.maxScrollExtent - pos.pixels < _nearBottomPx;
    if (nearBottom) return _messages.last.id;
    final lastIdx =
        ((pos.pixels + pos.viewportDimension) / _avgRowPx).floor().clamp(0, _messages.length - 1);
    var maxId = 0;
    for (var i = 0; i <= lastIdx; i++) {
      if (_messages[i].id > maxId) maxId = _messages[i].id;
    }
    return maxId;
  }

  int _countPeerBelowViewport() {
    final uid = _currentUserId;
    if (uid == null || !_scroll.hasClients || _messages.isEmpty) return 0;
    final pos = _scroll.position;
    final line = pos.pixels + pos.viewportDimension - 10;
    final firstIdx = (pos.pixels / _avgRowPx).floor().clamp(0, _messages.length - 1);
    double y = firstIdx * _avgRowPx;
    var n = 0;
    for (var i = firstIdx; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.sender.id == uid) continue;
      if (m.id <= _readCursor) continue;
      if (y > line) n++;
      y += _avgRowPx;
    }
    return n;
  }

  void _processScrollFabAndRead() {
    if (!mounted || _selectedId == null || _currentUserId == null) return;
    if (!_scroll.hasClients || _messages.isEmpty) {
      if (_showScrollFab || _peerBelowFab != 0) {
        setState(() {
          _showScrollFab = false;
          _peerBelowFab = 0;
        });
      }
      return;
    }
    final pos = _scroll.position;
    final near = pos.maxScrollExtent - pos.pixels < _nearBottomPx;
    final peerBelow = near ? 0 : _countPeerBelowViewport();
    final showFab = !near;
    if (_showScrollFab != showFab || _peerBelowFab != peerBelow) {
      setState(() {
        _showScrollFab = showFab;
        _peerBelowFab = peerBelow;
      });
    }

    final markTarget =
        near ? _messages.last.id : _estimateMaxVisibleMessageId();
    if (markTarget <= _readCursor) return;
    _pendingMarkReadId = _pendingMarkReadId > markTarget ? _pendingMarkReadId : markTarget;
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 160), () async {
      final pid = _pendingMarkReadId;
      _pendingMarkReadId = 0;
      final sid = _selectedId;
      if (sid == null || pid <= _readCursor) return;
      final newCursor = await _api.markTenantChatRead(sid, pid);
      if (!mounted) return;
      if (newCursor != null) {
        _readCursor = newCursor > _readCursor ? newCursor : _readCursor;
      } else {
        _readCursor = pid > _readCursor ? pid : _readCursor;
      }
      await _refreshConversations(silent: true);
      if (mounted) setState(() {});
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(max, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(max);
    }
    _stickToTail = true;
  }

  Future<void> _send() async {
    final id = _selectedId;
    if (id == null || _sending) return;
    final text = _draft.text.trim();
    final path = _pendingAttachmentPath;
    if (text.isEmpty && path == null) return;
    setState(() => _sending = true);
    _updateDerivedPresence();
    try {
      if (path != null) {
        var uploadPath = path;
        final lower = path.toLowerCase();
        if (lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.webp') ||
            lower.endsWith('.heic')) {
          if (!lower.endsWith('.gif')) {
            setState(() => _compressing = true);
            _updateDerivedPresence();
            try {
              uploadPath = await compressImageForChatIfNeeded(path);
            } finally {
              if (mounted) setState(() => _compressing = false);
            }
            _updateDerivedPresence();
          }
        }
        await _api.sendTenantChatMessageWithFile(
          id,
          uploadPath,
          body: text.isEmpty ? null : text,
          replyToMessageId: _replyTo?.id,
        );
      } else {
        await _api.sendTenantChatMessage(
          id,
          text,
          replyToMessageId: _replyTo?.id,
        );
      }
      if (!mounted) return;
      _draft.clear();
      setState(() {
        _replyTo = null;
        _pendingAttachmentPath = null;
      });
      await _refreshConversations(silent: true);
      await _loadMessages(silent: true);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
        _processScrollFabAndRead();
      });
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('teamChatCouldNotSend') ??
              'Could not send',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _updateDerivedPresence();
      }
    }
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() => _pendingAttachmentPath = x.path);
    _updateDerivedPresence();
    _bumpScrollIfNearBottom();
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(withData: false);
    if (r == null || r.files.single.path == null || !mounted) return;
    setState(() => _pendingAttachmentPath = r.files.single.path);
    _updateDerivedPresence();
    _bumpScrollIfNearBottom();
  }

  Future<void> _toggleVoice() async {
    if (_voiceRecording) {
      await _stopVoiceInternal(finalize: true, allowSetState: true);
      return;
    }
    if (_selectedId == null || _sending) return;
    final rec = AudioRecorder();
    _recorder = rec;
    if (!await rec.hasPermission()) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('teamChatMicDenied') ?? 'Mic denied',
        );
      }
      return;
    }
    if (!mounted) return;
    final dir = await getTemporaryDirectory();
    if (!mounted) return;
    _voiceTempPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await rec.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: _voiceTempPath!,
    );
    if (!mounted) return;
    setState(() => _voiceRecording = true);
    _updateDerivedPresence();
    _voiceCapTimer?.cancel();
    _voiceCapTimer = Timer(const Duration(minutes: 4), () {
      unawaited(_stopVoiceInternal(finalize: true, allowSetState: true));
    });
  }

  /// Stops microphone capture. When [allowSetState] is false (e.g. [dispose]), only
  /// updates fields — never [setState] after the element may be defunct.
  Future<void> _stopVoiceInternal({
    required bool finalize,
    bool allowSetState = true,
  }) async {
    _voiceCapTimer?.cancel();
    final rec = _recorder;
    _recorder = null;
    if (rec != null) {
      if (await rec.isRecording()) {
        await rec.stop();
      }
      await rec.dispose();
    }
    if (finalize && _voiceTempPath != null) {
      final f = File(_voiceTempPath!);
      if (await f.exists() && await f.length() > 0 && allowSetState && mounted) {
        setState(() => _pendingAttachmentPath = _voiceTempPath);
        _updateDerivedPresence();
        _bumpScrollIfNearBottom();
      }
    }
    _voiceTempPath = null;
    _voiceRecording = false;
    if (allowSetState && mounted) {
      setState(() {});
    }
    if (mounted) {
      _updateDerivedPresence();
    }
  }

  Future<void> _pin(TenantChatMessage m) async {
    final id = _selectedId;
    if (id == null) return;
    try {
      await _api.pinTenantChatMessage(id, m.id);
      await _refreshConversations(silent: true);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('teamChatCouldNotSend') ?? 'Error',
        );
      }
    }
  }

  Future<void> _unpin(int messageId) async {
    final id = _selectedId;
    if (id == null) return;
    try {
      await _api.unpinTenantChatMessage(id, messageId);
      await _refreshConversations(silent: true);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _openForward(TenantChatMessage m) {
    setState(() => _forwardSourceId = m.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ForwardSheet(
        conversations: _conversations.where((c) => c.id != _selectedId).toList(),
        captionController: _forwardCaption,
        onSend: (targetId) async {
          final src = _forwardSourceId;
          if (src == null) return;
          try {
            await _api.sendTenantChatMessage(
              targetId,
              _forwardCaption.text.trim(),
              forwardFromMessageId: src,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              setState(() {
                _forwardSourceId = null;
                _forwardCaption.clear();
              });
              await _refreshConversations(silent: true);
              if (_selectedId != null) await _loadMessages(silent: true);
            }
          } catch (_) {
            if (mounted) {
              SnackbarHelper.showError(
                context,
                AppLocalizations.of(context)?.translate('teamChatCouldNotSend') ?? 'Error',
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _openNewChat() async {
    List<TenantChatPeer> users = [];
    try {
      final page = await _api.getTenantChatEligibleUsers();
      users = page.results;
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          AppLocalizations.of(context)?.translate('teamChatCouldNotLoad') ?? 'Error',
        );
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
        return SizedBox(
          height: h * 0.72,
          child: _TeamChatNewPeerSheet(
            peers: users,
            onPick: (p) async {
              try {
                final c = await _api.startTenantChatConversation(p.id);
                if (ctx.mounted) Navigator.pop(ctx);
                await _refreshConversations(silent: true);
                if (mounted) await _selectConversation(c.id);
              } catch (_) {
                if (mounted) {
                  SnackbarHelper.showError(
                    context,
                    AppLocalizations.of(context)?.translate('teamChatCouldNotLoad') ?? '',
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  String _t(String key, [BuildContext? c]) {
    final loc = AppLocalizations.of(c ?? context);
    return loc?.translate(key) ?? key;
  }

  String _daySep(DateTime dayStart, String lang) {
    final now = DateTime.now();
    final today = _startOfLocalDay(now);
    final yest = today.subtract(const Duration(days: 1));
    if (dayStart == today) return _t('teamChatDayToday');
    if (dayStart == yest) return _t('teamChatDayYesterday');
    final intlLoc = AppLocales.intlDateFormat(AppLocales.fromLanguageCode(lang));
    final sameYear = dayStart.year == now.year;
    return sameYear
        ? DateFormat.MMMMd(intlLoc).format(dayStart)
        : DateFormat.yMMMd(intlLoc).format(dayStart);
  }

  String? _groupMembersLine(TenantChatConversation c) {
    final mc = c.memberCount ?? 0;
    final oc = c.onlineCount ?? 0;
    return _t('teamChatGroupMembersOnline')
        .replaceAll('{memberCount}', '$mc')
        .replaceAll('{onlineCount}', '$oc');
  }

  String? _threadPresenceSubtitle(TenantChatConversation? selected) {
    if (selected == null) return null;
    final r = _presenceResponse;
    if (selected.isCompanyGroup) {
      if (r != null && r.isGroupMode && r.groupPeers.isNotEmpty) {
        final line = tenantChatGroupPresenceLine(r.groupPeers, _t);
        if (line != null && line.isNotEmpty) return line;
      }
      return _groupMembersLine(selected);
    }
    if (r == null || r.isGroupMode) return null;
    final act = r.activity;
    if (act == null || act == kTenantChatPresenceIdle) return null;
    final ou = selected.otherUser;
    if (ou == null) return null;
    final name = tenantChatPeerName(ou);
    var key = 'teamChatPeerTyping';
    if (act == kTenantChatPresenceUploading) key = 'teamChatPeerUploading';
    if (act == kTenantChatPresenceRecording) key = 'teamChatPeerRecording';
    if (act == kTenantChatPresenceSending) key = 'teamChatPeerSending';
    return _t(key).replaceAll('{name}', name);
  }

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

  void _setReplyTo(TenantChatMessage? m) {
    final nearBottom = _scroll.hasClients &&
        (_scroll.position.maxScrollExtent - _scroll.position.pixels <
            _nearBottomPx + 120);
    setState(() => _replyTo = m);
    if (m != null && nearBottom) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          _scrollToBottom(animated: true);
        }
        SchedulerBinding.instance.addPostFrameCallback((_) => _processScrollFabAndRead());
      });
    } else if (m != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _processScrollFabAndRead());
    }
  }

  Widget _replyDockBanner() {
    final r = _replyTo!;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsetsDirectional.only(start: 6, end: 8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_t('teamChatReplyingTo')} ${tenantChatPeerName(r.sender)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.body.isNotEmpty ? r.body : (r.attachmentKind ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
              onPressed: () => _setReplyTo(null),
            ),
          ],
        ),
      ),
    );
  }

  void _jumpToMessageId(int id) {
    // Jumping up must opt out of tail-follow; otherwise scroll-metrics tail snap or the next
    // silent reload scroll-to-bottom immediately cancels the jump.
    _stickToTail = false;
    unawaited(_jumpToMessageIdImpl(id));
  }

  List<_ChatThreadRow> _threadRowsForCurrentMessages() {
    if (identical(_threadRowsMessagesRef, _messages) && _threadRowsCache != null) {
      return _threadRowsCache!;
    }
    _threadRowsMessagesRef = _messages;
    _threadRowsCache = _computeChatThreadRows(_messages);
    return _threadRowsCache!;
  }

  double _approxAttachmentBlockHeightForJump(TenantChatMessage m, double maxBubbleWidth) {
    final k = m.attachmentKind ?? '';
    if (k == 'image' || k == 'video') {
      final iw = (m.attachmentWidth ?? 280).toDouble().clamp(40, 2000);
      final ih = (m.attachmentHeight ?? 200).toDouble().clamp(40, 4000);
      final aspect = ih / iw;
      final w = maxBubbleWidth.clamp(120, 600);
      return (w * aspect).clamp(96, 320);
    }
    if (k == 'audio') return 92;
    return 48;
  }

  double _approxBubbleHeightForJump(
    TenantChatMessage m,
    TenantChatMessage? prev,
    double maxBubbleWidth,
  ) {
    var h = (prev != null && prev.sender.id == m.sender.id) ? 2.0 : 8.0;
    h += 16;
    if (m.forwardedFrom != null) h += 52;
    if (m.replyTo != null) h += 102;
    if (m.attachmentUrl != null && m.attachmentKind != null) {
      h += _approxAttachmentBlockHeightForJump(m, maxBubbleWidth);
    }
    final body = m.body.trim();
    if (body.isNotEmpty) {
      final approxCharsPerLine = (maxBubbleWidth / 8).floor().clamp(18, 44);
      final lines = (body.length / approxCharsPerLine).ceil().clamp(1, 12);
      h += lines * 19.0;
    }
    h += 24;
    return h;
  }

  /// Sum of heights of list children before the bubble with [messageId] (same order as [_buildMessageList]).
  double _estimatedScrollOffsetBeforeMessage(int messageId, double maxBubbleWidth) {
    var y = _teamChatJumpListTopPadPx;
    for (final dayList in _groupTenantMessagesByDay(_messages)) {
      y += _teamChatJumpDaySepBlockPx;
      TenantChatMessage? prev;
      for (final m in dayList) {
        if (m.id == messageId) return y;
        y += _approxBubbleHeightForJump(m, prev, maxBubbleWidth);
        prev = m;
      }
    }
    return y;
  }

  Future<void> _jumpToMessageIdImpl(int id) async {
    if (!_messages.any((m) => m.id == id)) return;
    if (!mounted) return;
    final maxW = MediaQuery.sizeOf(context).width * 0.82;

    Future<bool> tryEnsureVisible() async {
      final ctx = _messageItemKeys[id]?.currentContext;
      if (ctx == null) return false;
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeInOut,
        alignment: 0.12,
      );
      return true;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (await tryEnsureVisible()) return;

    if (!_scroll.hasClients) return;
    final maxExtent = _scroll.position.maxScrollExtent;
    final base = _estimatedScrollOffsetBeforeMessage(id, maxW).clamp(0.0, maxExtent);

    // Lazy ListView: bracket scroll positions until the target row is laid out and [tryEnsureVisible] succeeds.
    final deltas = <double>[
      0,
      -220,
      220,
      -440,
      440,
      -700,
      700,
      -1000,
      1000,
      -1400,
      1400,
      -1900,
      1900,
    ];
    for (final d in deltas) {
      if (!mounted || !_scroll.hasClients) return;
      final off = (base + d).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(off);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (await tryEnsureVisible()) return;
    }
  }

  void _bumpScrollIfNearBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final near =
          _scroll.position.maxScrollExtent - _scroll.position.pixels < _nearBottomPx + 120;
      if (near) {
        _scrollToBottom(animated: true);
        SchedulerBinding.instance.addPostFrameCallback((_) => _processScrollFabAndRead());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    TenantChatConversation? selected;
    for (final c in _conversations) {
      if (c.id == _selectedId) {
        selected = c;
        break;
      }
    }

    final inThreadNarrow = !wide && _selectedId != null;

    return Scaffold(
      appBar: AppBar(
        leading: inThreadNarrow
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  setState(() => _selectedId = null);
                  _syncTeamChatAwayContext();
                },
              )
            : null,
        automaticallyImplyLeading: !inThreadNarrow,
        title: inThreadNarrow && selected != null
            ? (selected.isCompanyGroup
                ? TeamChatGroupThreadAppBarTitle(
                    title: tenantChatConversationTitle(
                      selected,
                      _t('teamChatCompanyRoom'),
                    ),
                    avatarLetters: tenantChatConversationAvatarLetters(
                      selected,
                      _t('teamChatCompanyRoom'),
                    ),
                    subtitle: _threadPresenceSubtitle(selected),
                  )
                : selected.otherUser != null
                    ? TeamChatThreadAppBarTitle(
                        peer: selected.otherUser!,
                        subtitle: _threadPresenceSubtitle(selected),
                      )
                    : Text(_t('teamChat')))
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
      body: _loadError != null && _conversations.isEmpty
          ? Center(child: Text(_t('teamChatCouldNotLoad')))
          : wide
              ? Row(
                  children: [
                    SizedBox(width: 300, child: _buildConvList(wide, lang)),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildThreadPane(selected, lang, wide)),
                  ],
                )
              : _selectedId == null
                  ? _buildConvList(wide, lang)
                  : _buildThreadPane(selected, lang, wide),
    );
  }

  Widget _buildConvList(bool wide, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _openNewChat,
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: Text(_t('teamChatNewConversation')),
              ),
            ),
          ),
        Expanded(
          child: _loadingConv
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_t('teamChatSelectThread'), textAlign: TextAlign.center),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 88,
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                      ),
                      itemBuilder: (ctx, i) {
                        final c = _conversations[i];
                        final active = c.id == _selectedId;
                        final preview = c.lastMessage?.body ?? '';
                        final companyRoom = _t('teamChatCompanyRoom');
                        return TeamChatConversationRow(
                          conversation: c,
                          selected: active,
                          previewText:
                              preview.isEmpty ? _t('teamChatNoMessagesYet') : preview,
                          timeLabel: _conversationRowTime(c, lang),
                          titleText: tenantChatConversationTitle(c, companyRoom),
                          avatarLetters:
                              tenantChatConversationAvatarLetters(c, companyRoom),
                          showOnlineDot:
                              !c.isCompanyGroup && (c.otherUser?.isOnline == true),
                          onTap: () => _selectConversation(c.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildThreadPane(TenantChatConversation? selected, String lang, bool wide) {
    if (_selectedId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_t('teamChatSelectThread'), textAlign: TextAlign.center),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide && selected != null)
          Material(
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: selected.isCompanyGroup
                  ? TeamChatGroupThreadAppBarTitle(
                      title: tenantChatConversationTitle(
                        selected,
                        _t('teamChatCompanyRoom'),
                      ),
                      avatarLetters: tenantChatConversationAvatarLetters(
                        selected,
                        _t('teamChatCompanyRoom'),
                      ),
                      subtitle: _threadPresenceSubtitle(selected),
                      onPrimaryBackground: false,
                    )
                  : selected.otherUser != null
                      ? TeamChatThreadAppBarTitle(
                          peer: selected.otherUser!,
                          subtitle: _threadPresenceSubtitle(selected),
                          onPrimaryBackground: false,
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        if (selected != null && selected.pinnedMessages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Material(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.only(bottom: 4),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  _t('teamChatPinnedHeader'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                children: selected.pinnedMessages.map((p) {
                  return ListTile(
                    dense: true,
                    title: Text(p.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.push_pin_outlined),
                      onPressed: () => _unpin(p.messageId),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.bottomRight,
            children: [
              Positioned.fill(child: _buildMessageList(lang)),
              if (_showScrollFab)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Builder(
                    builder: (context) {
                      final fabUnread = _fabUnreadDisplayCount();
                      final scheme = Theme.of(context).colorScheme;
                      return FloatingActionButton.small(
                        heroTag: 'tc_scroll',
                        onPressed: () {
                          _scrollToBottom();
                          SchedulerBinding.instance.addPostFrameCallback((_) => _processScrollFabAndRead());
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.keyboard_arrow_down_rounded),
                            if (fabUnread > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: scheme.primary,
                                  child: Text(
                                    fabUnread > 99 ? '99+' : '$fabUnread',
                                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildMessageList(String lang) {
    if (_loadingMsg && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    TenantChatConversation? threadConv;
    for (final c in _conversations) {
      if (c.id == _selectedId) {
        threadConv = c;
        break;
      }
    }
    final threadIsCompanyGroup = threadConv?.isCompanyGroup ?? false;
    final scheme = Theme.of(context).colorScheme;
    final rows = _threadRowsForCurrentMessages();
    return Container(
      color: scheme.surfaceContainerLowest,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _onThreadScrollMetricsNotification,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onThreadScrollInteractionNotification,
          child: ListView.builder(
            controller: _scroll,
            itemCount: rows.length,
            // Widen layout cache so "jump to quoted" can resolve [GlobalKey] for rows a bit above the viewport.
            cacheExtent: 1800,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row.isDaySeparator) {
                final dayStart = row.dayStart!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _daySep(dayStart, lang),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }
              final m = row.message!;
              return RepaintBoundary(
                child: TeamChatMessageBubble(
                  key: _messageItemKeys.putIfAbsent(m.id, () => GlobalKey()),
                  message: m,
                  mine: m.sender.id == _currentUserId,
                  lang: lang,
                  sameSenderAsPrevious: row.sameSenderAsPrevious,
                  isCompanyGroup: threadIsCompanyGroup,
                  tr: _t,
                  onReply: () => _setReplyTo(m),
                  onForward: () => _openForward(m),
                  onPin: () => _pin(m),
                  onJump: _jumpToMessageId,
                  labelCouldNotLoad: _t('teamChatCouldNotLoad'),
                  labelReply: _t('teamChatReply'),
                  labelForward: _t('teamChatForward'),
                  labelPin: _t('teamChatPin'),
                  labelForwarded: _t('teamChatForwarded'),
                  labelJumpFwd: _t('teamChatJumpToForwardedMessage'),
                  labelJumpQ: _t('teamChatJumpToQuotedMessage'),
                  labelRead: _t('teamChatRead'),
                  labelDelivered: _t('teamChatDelivered'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final hasAttach = _pendingAttachmentPath != null;
    return TeamChatComposer(
      draft: _draft,
      compressing: _compressing,
      hasAttach: hasAttach,
      sending: _sending,
      voiceRecording: _voiceRecording,
      compressLabel: _t('teamChatCompressing'),
      hintText: _t('teamChatMessagePlaceholder'),
      attachFileName: hasAttach ? _pendingAttachmentPath!.split(Platform.pathSeparator).last : '',
      onPickImage: () => unawaited(_pickImage()),
      onPickFile: () => unawaited(_pickFile()),
      onVoice: _toggleVoice,
      onClearAttach: () {
        setState(() => _pendingAttachmentPath = null);
        _updateDerivedPresence();
      },
      onSend: _send,
      attachPhotoLabel: _t('teamChatMediaPhoto'),
      attachFileLabel: _t('teamChatAttach'),
      replyBanner: _replyTo != null ? _replyDockBanner() : null,
    );
  }
}

class _ForwardSheet extends StatelessWidget {
  const _ForwardSheet({
    required this.conversations,
    required this.captionController,
    required this.onSend,
  });

  final List<TenantChatConversation> conversations;
  final TextEditingController captionController;
  final Future<void> Function(int targetId) onSend;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String k) => loc?.translate(k) ?? k;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(t('teamChatForwardTo'), style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: captionController,
              decoration: InputDecoration(
                labelText: t('teamChatForwardCaption'),
                hintText: t('teamChatForwardCaptionPlaceholder'),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 280,
            child: conversations.isEmpty
                ? Center(child: Text(t('teamChatNoEligiblePeers')))
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (ctx, i) {
                      final c = conversations[i];
                      return ListTile(
                        title: Text(
                          c.isCompanyGroup
                              ? tenantChatConversationTitle(
                                  c,
                                  t('teamChatCompanyRoom'),
                                )
                              : (c.otherUser != null
                                  ? tenantChatPeerName(c.otherUser!)
                                  : ''),
                        ),
                        onTap: () => onSend(c.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TeamChatNewPeerSheet extends StatefulWidget {
  const _TeamChatNewPeerSheet({
    required this.peers,
    required this.onPick,
  });

  final List<TenantChatPeer> peers;
  final Future<void> Function(TenantChatPeer peer) onPick;

  @override
  State<_TeamChatNewPeerSheet> createState() => _TeamChatNewPeerSheetState();
}

class _TeamChatNewPeerSheetState extends State<_TeamChatNewPeerSheet> {
  late final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String tr(String k) => loc?.translate(k) ?? k;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = _search.text.trim().toLowerCase();

    final filtered = widget.peers.where((p) {
      if (q.isEmpty) return true;
      final name = tenantChatPeerName(p).toLowerCase();
      final un = p.username.toLowerCase();
      final role = tenantChatPeerRoleLabel(p.role, tr).toLowerCase();
      return name.contains(q) || un.contains(q) || role.contains(q);
    }).toList();

    final searchFill = Color.lerp(
      scheme.surfaceContainerHighest,
      scheme.surface,
      theme.brightness == Brightness.dark ? 0.45 : 0.2,
    )!;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr('teamChatNewConversation'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('cancel')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: tr('teamChatSearchPeople'),
                prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                filled: true,
                fillColor: searchFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: widget.peers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        tr('teamChatNoEligiblePeers'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            tr('teamChatNoMatchingPeers'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          indent: 76,
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                        itemBuilder: (ctx, i) {
                          final p = filtered[i];
                          final name = tenantChatPeerName(p);
                          final roleLine = tenantChatPeerRoleLabel(p.role, tr);
                          final photo = p.profilePhoto?.trim();
                          final ImageProvider<Object>? avatarImg =
                              photo != null &&
                                      photo.isNotEmpty &&
                                      (photo.startsWith('http://') ||
                                          photo.startsWith('https://'))
                                  ? NetworkImage(photo)
                                  : null;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => widget.onPick(p),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor:
                                              scheme.primary.withValues(alpha: 0.12),
                                          backgroundImage: avatarImg,
                                          child: avatarImg == null
                                              ? Text(
                                                  tenantChatPeerInitials(p),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: scheme.primary,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        if (p.isOnline == true)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.greenAccent.shade400,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: scheme.surface,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (roleLine.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              roleLine,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
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
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
