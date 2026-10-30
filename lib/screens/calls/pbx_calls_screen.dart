import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../models/pbx_call_model.dart';
import '../../services/api_service.dart';
import '../../services/app_route_observer.dart';
import '../../services/pbx_call_launcher.dart';
import '../../services/sync_invalidation.dart';
import '../../utils/timeline_date_format.dart';
import '../leads/lead_profile_screen.dart';

/// Loop Cloud PBX call history (Phase 6): the calls this user may see, newest
/// first, with a Missed filter, call-back through [PbxCallLauncher] and
/// recording playback. Same visibility rule as the web Calls page (server-side).
///
/// Re-reads the first page when the user comes back to it (from a lead, or the
/// app returning to the foreground), when the `telephony` sync slice or the
/// per-agent socket frame moves, and on the usual fallback poll.
class PbxCallsScreen extends StatefulWidget {
  /// Open with the Missed filter on (e.g. from a missed-call push).
  final bool missedOnly;

  /// Loads one page. Defaults to [ApiService.getPbxCalls]; replaced in tests.
  @visibleForTesting
  final Future<PbxCallsPage> Function({String? cursor, bool missedOnly})?
  loadPage;

  const PbxCallsScreen({super.key, this.missedOnly = false, this.loadPage});

  @override
  State<PbxCallsScreen> createState() => _PbxCallsScreenState();
}

class _PbxCallsScreenState extends State<PbxCallsScreen>
    with RouteAware, WidgetsBindingObserver {
  /// Several signals can arrive together (a socket frame, then the digest).
  static const Duration _refreshDebounce = Duration(milliseconds: 400);

  final _calls = <PbxCallRecord>[];
  final _scroll = ScrollController();
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  bool _failed = false;
  late bool _missedOnly = widget.missedOnly;

  /// Bumped on every reload, so a page requested for the previous filter is dropped.
  int _generation = 0;
  StreamSubscription<Map<String, String>>? _invalidations;
  late final SyncFallbackTimer _fallback = SyncFallbackTimer(_scheduleRefresh);
  Timer? _refreshTimer;
  bool _routeSubscribed = false;

  String _t(String key) => AppLocalizations.of(context)?.translate(key) ?? key;

  Future<PbxCallsPage> _fetch({String? cursor}) {
    final load = widget.loadPage;
    if (load != null) return load(cursor: cursor, missedOnly: _missedOnly);
    return ApiService().getPbxCalls(cursor: cursor, missedOnly: _missedOnly);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        unawaited(_loadMore());
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _invalidations = SyncInvalidation.instance.stream.listen((event) {
      if (event['invalidate'] == kTelephonyCallsInvalidation) {
        _scheduleRefresh();
      }
    });
    _fallback.start();
    unawaited(_reload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeSubscribed && route is PageRoute) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_invalidations?.cancel());
    _fallback.stop();
    _refreshTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Back from a screen pushed on top (a lead, a dialer hand-off).
  @override
  void didPopNext() => _scheduleRefresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (!mounted) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_refreshDebounce, () => unawaited(_refreshInPlace()));
  }

  /// Re-reads the newest page and swaps it in without blanking the list, so a
  /// background refresh never flashes "Loading". A failure keeps what is shown.
  Future<void> _refreshInPlace() async {
    if (!mounted) return;
    if (_calls.isEmpty) return _reload();
    final generation = ++_generation;
    try {
      final page = await _fetch();
      if (!mounted || generation != _generation) return;
      setState(() {
        _calls
          ..clear()
          ..addAll(page.results);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      // Keep the rows already on screen; the next signal or poll tries again.
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _generation++;
      _calls.clear();
      _cursor = null;
      _done = false;
      _failed = false;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = await _fetch(cursor: _cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _calls.addAll(page.results);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('phoneCalls'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(_t('pbxFilter_all')),
                  selected: !_missedOnly,
                  onSelected: (_) {
                    setState(() => _missedOnly = false);
                    unawaited(_reload());
                  },
                ),
                ChoiceChip(
                  label: Text(_t('pbxFilter_missed')),
                  selected: _missedOnly,
                  onSelected: (_) {
                    setState(() => _missedOnly = true);
                    unawaited(_reload());
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _reload, child: _buildList()),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_calls.isEmpty) {
      final message = _failed
          ? _t('pbxCallsLoadFailed')
          : (_loading ? '${_t('loading')}…' : _t('pbxCallsEmpty'));
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _calls.length + (_done ? 0 : 1),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i >= _calls.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _PbxCallTile(call: _calls[i], t: _t);
      },
    );
  }
}

class _PbxCallTile extends StatelessWidget {
  final PbxCallRecord call;
  final String Function(String) t;

  const _PbxCallTile({required this.call, required this.t});

  IconData get _icon {
    if (call.isMissed) return Icons.call_missed;
    switch (call.direction) {
      case 'inbound':
        return Icons.call_received;
      case 'outbound':
        return Icons.call_made;
      default:
        return Icons.phone_in_talk;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missedColor = theme.colorScheme.error;
    final remote = call.remoteParty;
    final hasName = (call.crmContactName ?? '').trim().isNotEmpty;
    final number = remote.isEmpty || remote == 'anonymous'
        ? t('pbxUnknownCaller')
        : remote;
    final parts = <String>[
      t('pbxStatus_${call.status}'),
      if (call.startedAt != null)
        formatTimelineDate(call.startedAt, Localizations.localeOf(context)),
      if ((call.billsecS ?? 0) > 0)
        t('callDurationSeconds').replaceAll('{n}', '${call.billsecS}'),
      if ((call.answeredByNumber ?? call.extensionNumber) != null)
        '${t('pbxExtensionShort')} ${call.answeredByNumber ?? call.extensionNumber}',
    ];
    // Phone numbers stay left-to-right inside RTL (PhoneText parity).
    final numberText = Directionality(
      textDirection: TextDirection.ltr,
      child: Text(number),
    );
    return ListTile(
      leading: Icon(
        _icon,
        color: call.isMissed ? missedColor : theme.colorScheme.primary,
      ),
      title: hasName ? Text(call.crmContactName!) : numberText,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasName)
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall,
              child: numberText,
            ),
          Text(parts.join(' · '), style: theme.textTheme.bodySmall),
          if (call.hasRecording) _RecordingButton(callId: call.id, t: t),
        ],
      ),
      trailing:
          remote.isEmpty ||
              remote == 'anonymous' ||
              call.direction == 'internal'
          ? null
          : IconButton(
              tooltip: t('call'),
              icon: const Icon(Icons.phone),
              onPressed: () => PbxCallLauncher.call(
                context,
                phone: remote,
                leadId: call.crmContactId,
              ),
            ),
      onTap: call.crmContactId == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LeadProfileScreen(leadId: call.crmContactId!),
              ),
            ),
    );
  }
}

/// Loads a recording only when tapped (a list must not download every call's audio).
class _RecordingButton extends StatefulWidget {
  final String callId;
  final String Function(String) t;

  const _RecordingButton({required this.callId, required this.t});

  @override
  State<_RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<_RecordingButton> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  File? _file;
  bool _loading = false;
  bool _failed = false;
  bool _playing = false;

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future.value());
    unawaited(_player.dispose());
    final f = _file;
    if (f != null) unawaited(f.delete().catchError((_) => f));
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_file == null) {
      setState(() {
        _loading = true;
        _failed = false;
      });
      try {
        final api = ApiService();
        final ids = await api.getPbxCallRecordingIds(widget.callId);
        if (ids.isEmpty) throw StateError('no recording');
        // A 5-minute, audit-logged presigned URL; fetched without the CRM's token.
        final url = await api.fetchPbxRecordingAccessUrl(ids.first);
        final bytes = await api.fetchPresignedBinaryGet(url);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/pbx_rec_${widget.callId}.wav');
        await file.writeAsBytes(bytes, flush: true);
        _file = file;
        await _player.setReleaseMode(ReleaseMode.stop);
        await _player.setSource(DeviceFileSource(file.path));
        _sub = _player.onPlayerStateChanged.listen((s) {
          if (mounted) setState(() => _playing = s == PlayerState.playing);
        });
      } catch (_) {
        if (mounted) setState(() => _failed = true);
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Text(
        widget.t('recordingUnavailable'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
        ),
        onPressed: _toggle,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
              ),
        label: Text(widget.t('playRecording')),
      ),
    );
  }
}
