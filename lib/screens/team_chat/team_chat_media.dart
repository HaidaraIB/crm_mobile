import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/localization/app_localizations.dart';
import '../../services/api_service.dart';
import 'team_chat_common.dart';
import 'team_chat_media_viewer_screen.dart';

String _extFromPath(String path) {
  final seg = path.split('/').last.split('\\').last;
  final d = seg.lastIndexOf('.');
  return d >= 0 ? seg.substring(d).toLowerCase() : '';
}

/// Same file may be served with different query strings (tokens) on each API poll.
/// Use this for cache keys and [didUpdateWidget] identity so images do not reload in a loop.
String tenantChatBinaryUrlIdentity(String absoluteUrl) {
  try {
    final u = Uri.parse(absoluteUrl);
    return '${u.scheme}://${u.host}${u.path}';
  } catch (_) {
    return absoluteUrl;
  }
}

const double kTenantChatInlineMediaMaxHeight = 260;
const double kTenantChatMediaFallbackAspect = 16 / 9;

/// Height for inline chat image/video shell from max width and optional intrinsic dimensions.
double tenantChatMediaBoxHeight(
  double maxWidth,
  int? attachmentWidth,
  int? attachmentHeight,
) {
  final ar = (attachmentWidth != null &&
          attachmentHeight != null &&
          attachmentWidth > 0 &&
          attachmentHeight > 0)
      ? attachmentWidth / attachmentHeight
      : kTenantChatMediaFallbackAspect;
  final h = maxWidth / ar;
  return h > kTenantChatInlineMediaMaxHeight
      ? kTenantChatInlineMediaMaxHeight
      : h;
}

class TenantChatMemoryImage extends StatefulWidget {
  const TenantChatMemoryImage({
    super.key,
    required this.url,
    this.maxHeight = kTenantChatInlineMediaMaxHeight,
    this.borderRadius = 12,
    this.attachmentWidth,
    this.attachmentHeight,
    this.suggestedFilename,
    this.onIntrinsicLayout,
  });

  final String url;
  final double maxHeight;
  final double borderRadius;
  final int? attachmentWidth;
  final int? attachmentHeight;
  final String? suggestedFilename;
  final VoidCallback? onIntrinsicLayout;

  @override
  State<TenantChatMemoryImage> createState() => _TenantChatMemoryImageState();
}

class _TenantChatMemoryImageState extends State<TenantChatMemoryImage> {
  Uint8List? _bytes;
  bool _failed = false;
  bool _userRequestedLoad = false;
  int _loadGeneration = 0;

  static final LinkedHashMap<String, Uint8List> _bytesCache = LinkedHashMap();
  static const int _maxBytesCache = 40;

  static Uint8List? _takeFromCache(String identity) {
    final b = _bytesCache.remove(identity);
    if (b != null) {
      _bytesCache[identity] = b;
    }
    return b;
  }

  static void _putInCache(String identity, Uint8List bytes) {
    while (_bytesCache.length >= _maxBytesCache) {
      _bytesCache.remove(_bytesCache.keys.first);
    }
    _bytesCache[identity] = bytes;
  }

  @override
  void initState() {
    super.initState();
    final id = tenantChatBinaryUrlIdentity(widget.url);
    final cached = _takeFromCache(id);
    if (cached != null) {
      _bytes = cached;
    }
  }

  @override
  void didUpdateWidget(covariant TenantChatMemoryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = tenantChatBinaryUrlIdentity(oldWidget.url);
    final newId = tenantChatBinaryUrlIdentity(widget.url);
    if (oldId != newId) {
      _loadGeneration++;
      _failed = false;
      _userRequestedLoad = false;
      final cached = _takeFromCache(newId);
      if (cached != null) {
        setState(() => _bytes = cached);
      } else {
        setState(() => _bytes = null);
      }
    }
  }

  Future<void> _load() async {
    final identity = tenantChatBinaryUrlIdentity(widget.url);
    final gen = ++_loadGeneration;
    try {
      final b = await ApiService().fetchAuthenticatedBinaryGet(widget.url);
      if (!mounted || gen != _loadGeneration) return;
      _putInCache(identity, b);
      setState(() {
        _bytes = b;
        _failed = false;
      });
      widget.onIntrinsicLayout?.call();
    } catch (_) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _failed = true;
        _userRequestedLoad = false;
      });
    }
  }

  void _onTapLoad() {
    if (_bytes != null || _failed) return;
    setState(() => _userRequestedLoad = true);
    _load();
  }

  void _openViewer() {
    final b = _bytes;
    if (b == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => TeamChatMediaViewerScreen.image(
          imageBytes: b,
          suggestedFilename: widget.suggestedFilename,
        ),
      ),
    );
  }

  Widget _placeholderShell(BuildContext context, double maxWidth, Widget child) {
    final h = tenantChatMediaBoxHeight(
      maxWidth,
      widget.attachmentWidth,
      widget.attachmentHeight,
    );
    return SizedBox(
      width: maxWidth,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_failed) {
      return Text(
        loc?.translate('teamChatCouldNotLoad') ?? 'Could not load',
        style: const TextStyle(fontSize: 12),
      );
    }
    return LayoutBuilder(
      builder: (context, cons) {
        final maxW = cons.maxWidth;
        if (_bytes == null) {
          if (!_userRequestedLoad) {
            return _placeholderShell(
              context,
              maxW,
              Semantics(
                button: true,
                label: loc?.translate('teamChatTapToLoadAria') ?? 'Load media',
                child: Material(
                  color: Colors.black.withValues(alpha: 0.06),
                  child: InkWell(
                    onTap: _onTapLoad,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey.shade700.withValues(alpha: 0.35),
                            Colors.grey.shade900.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                loc?.translate('teamChatTapToLoad') ?? 'Tap to load',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          return _placeholderShell(
            context,
            maxW,
            const ColoredBox(
              color: Color(0x14000000),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        final hasDims = widget.attachmentWidth != null &&
            widget.attachmentHeight != null &&
            widget.attachmentWidth! > 0 &&
            widget.attachmentHeight! > 0;
        if (hasDims) {
          final h = tenantChatMediaBoxHeight(
            maxW,
            widget.attachmentWidth,
            widget.attachmentHeight,
          );
          return SizedBox(
            width: maxW,
            height: h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openViewer,
                  child: Image.memory(
                    _bytes!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    width: maxW,
                    height: h,
                  ),
                ),
              ),
            ),
          );
        }
        return SizedBox(
          width: maxW,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openViewer,
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: widget.maxHeight),
                    child: Image.memory(
                      _bytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TenantChatMemoryVideo extends StatefulWidget {
  const TenantChatMemoryVideo({
    super.key,
    required this.url,
    this.maxHeight = kTenantChatInlineMediaMaxHeight,
    this.attachmentWidth,
    this.attachmentHeight,
    this.suggestedFilename,
    this.onIntrinsicLayout,
  });

  final String url;
  final double maxHeight;
  final int? attachmentWidth;
  final int? attachmentHeight;
  final String? suggestedFilename;
  final VoidCallback? onIntrinsicLayout;

  @override
  State<TenantChatMemoryVideo> createState() => _TenantChatMemoryVideoState();
}

class _TenantChatMemoryVideoState extends State<TenantChatMemoryVideo>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _video;
  bool _failed = false;
  bool _userRequestedLoad = false;
  int _initGeneration = 0;

  @override
  bool get wantKeepAlive => _video != null;

  @override
  void didUpdateWidget(covariant TenantChatMemoryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (tenantChatBinaryUrlIdentity(oldWidget.url) !=
        tenantChatBinaryUrlIdentity(widget.url)) {
      _disposeVideo();
      _failed = false;
      _userRequestedLoad = false;
      if (mounted) setState(() {});
    }
  }

  void _disposeVideo() {
    _video?.dispose();
    _video = null;
    if (mounted) updateKeepAlive();
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _onTapLoad() {
    if (_video != null || _failed) return;
    setState(() => _userRequestedLoad = true);
    _init();
  }

  Future<void> _init() async {
    final gen = ++_initGeneration;
    try {
      final bytes = await ApiService().fetchAuthenticatedBinaryGet(widget.url);
      if (!mounted || gen != _initGeneration) return;
      final dir = await getTemporaryDirectory();
      var ext = _extFromPath(Uri.parse(widget.url).path);
      if (ext.isEmpty || ext == '.') ext = '.mp4';
      final f = File('${dir.path}/chat_vid_${DateTime.now().millisecondsSinceEpoch}$ext');
      await f.writeAsBytes(bytes, flush: true);
      final vc = VideoPlayerController.file(f);
      await vc.initialize();
      if (!mounted || gen != _initGeneration) {
        await vc.dispose();
        return;
      }
      await vc.setLooping(false);
      await vc.pause();
      setState(() {
        _video = vc;
      });
      updateKeepAlive();
      widget.onIntrinsicLayout?.call();
    } catch (_) {
      if (mounted && gen == _initGeneration) {
        setState(() {
          _failed = true;
          _userRequestedLoad = false;
        });
      }
    }
  }

  Future<void> _openViewer() async {
    final ds = _video?.dataSource;
    if (ds == null || ds.isEmpty || !mounted) return;
    final path = tenantChatNativeFilePath(ds);
    await _video?.pause();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => TeamChatMediaViewerScreen.video(
          videoFilePath: path,
          suggestedFilename: widget.suggestedFilename,
        ),
      ),
    );
  }

  Widget _sizedShell(double maxWidth, Widget child) {
    final h = tenantChatMediaBoxHeight(
      maxWidth,
      widget.attachmentWidth,
      widget.attachmentHeight,
    );
    return SizedBox(width: maxWidth, height: h, child: child);
  }

  Widget _inlinePreview(double maxW) {
    final vc = _video!;
    var w = vc.value.size.width;
    var h = vc.value.size.height;
    if (w <= 0 || h <= 0) {
      final aw = widget.attachmentWidth;
      final ah = widget.attachmentHeight;
      if (aw != null && ah != null && aw > 0 && ah > 0) {
        w = aw.toDouble();
        h = ah.toDouble();
      } else {
        w = 16;
        h = 9;
      }
    }
    final loc = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: loc?.translate('teamChatOpenMediaViewer') ?? 'Open video',
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: _openViewer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: VideoPlayer(vc),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = AppLocalizations.of(context);
    if (_failed) {
      return Text(
        loc?.translate('teamChatCouldNotLoad') ?? 'Could not load',
        style: const TextStyle(fontSize: 12),
      );
    }
    return LayoutBuilder(
      builder: (context, cons) {
        final maxW = cons.maxWidth;
        if (_video != null) {
          final h = tenantChatMediaBoxHeight(
            maxW,
            widget.attachmentWidth,
            widget.attachmentHeight,
          );
          return SizedBox(
            width: maxW,
            height: h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _inlinePreview(maxW),
            ),
          );
        }
        if (!_userRequestedLoad) {
          return _sizedShell(
            maxW,
            Semantics(
              button: true,
              label: loc?.translate('teamChatTapToLoadAria') ?? 'Load media',
              child: Material(
                color: Colors.black.withValues(alpha: 0.06),
                child: InkWell(
                  onTap: _onTapLoad,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade700.withValues(alpha: 0.35),
                          Colors.grey.shade900.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              loc?.translate('teamChatTapToLoad') ?? 'Tap to load',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return _sizedShell(
          maxW,
          const ColoredBox(
            color: Color(0x14000000),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TenantChatInlineAudio extends StatefulWidget {
  const TenantChatInlineAudio({
    super.key,
    required this.url,
    this.originalFilename,
    this.mine = false,
  });

  final String url;
  final String? originalFilename;
  final bool mine;

  @override
  State<TenantChatInlineAudio> createState() => _TenantChatInlineAudioState();
}

String _formatVoiceDuration(Duration d) {
  final totalSec = d.inSeconds.clamp(0, 24 * 3600);
  final m = totalSec ~/ 60;
  final s = totalSec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _TenantChatInlineAudioState extends State<TenantChatInlineAudio> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  bool _failed = false;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackRate = 1.0;
  bool _scrubbing = false;
  double? _scrubValue;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;

  static const List<double> _playbackRates = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  void _attachStreams() {
    _stateSub?.cancel();
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _durSub?.cancel();
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _posSub?.cancel();
    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted || _scrubbing) return;
      setState(() => _position = p);
    });
    _completeSub?.cancel();
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        if (_duration > Duration.zero) {
          _position = _duration;
        }
      });
    });
  }

  Future<void> _prepare() async {
    try {
      final bytes = await ApiService().fetchAuthenticatedBinaryGet(widget.url);
      final dir = await getTemporaryDirectory();
      var ext = _extFromPath(widget.originalFilename ?? '');
      if (ext.isEmpty || ext == '.') ext = '.m4a';
      final f = File(
        '${dir.path}/chat_aud_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await f.writeAsBytes(bytes, flush: true);
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(DeviceFileSource(f.path));
      final d = await _player.getDuration();
      if (mounted && d != null && d > Duration.zero) {
        setState(() => _duration = d);
      }
      _attachStreams();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _applyPlaybackRate() async {
    try {
      await _player.setPlaybackRate(_playbackRate);
    } catch (_) {}
  }

  Future<void> _togglePlay() async {
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
        return;
      }
      if (_state == PlayerState.completed) {
        await _player.seek(Duration.zero);
        setState(() => _position = Duration.zero);
      }
      await _player.resume();
      await _applyPlaybackRate();
    } catch (_) {}
  }

  Future<void> _setRate(double rate) async {
    setState(() => _playbackRate = rate);
    await _applyPlaybackRate();
  }

  double _sliderValue() {
    final totalMs = _duration.inMilliseconds;
    if (totalMs <= 0) return 0;
    if (_scrubbing && _scrubValue != null) {
      return _scrubValue!.clamp(0.0, 1.0);
    }
    return (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  String _speedMenuLabel(double r) {
    if ((r - 0.5).abs() < 0.01) return '0.5×';
    if ((r - 1.0).abs() < 0.01) return '1×';
    if ((r - 1.5).abs() < 0.01) return '1.5×';
    return '2×';
  }

  String _rateLabel() => _speedMenuLabel(_playbackRate);

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_failed) {
      return Text(
        AppLocalizations.of(context)?.translate('teamChatCouldNotLoad') ??
            'Could not load',
        style: const TextStyle(fontSize: 12),
      );
    }
    if (_loading) {
      return SizedBox(
        height: 40,
        width: 40,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.mine ? Colors.white : scheme.primary,
          ),
        ),
      );
    }

    // Outgoing bubbles use AppTheme.primaryColor + Colors.white (see TeamChatMessageBubble),
    // not ColorScheme.primary/onPrimary — avoid low-contrast controls on custom fills.
    final onBubble = widget.mine ? Colors.white : scheme.onSurface;
    final muted = widget.mine
        ? Colors.white.withValues(alpha: 0.88)
        : scheme.onSurfaceVariant;
    final accent = widget.mine ? Colors.white : scheme.primary;
    final trackInactive = widget.mine
        ? Colors.white.withValues(alpha: 0.38)
        : scheme.onSurface.withValues(alpha: 0.28);
    final voiceLabel =
        AppLocalizations.of(context)?.translate('teamChatMediaAudio') ?? 'Voice message';
    final totalMs = _duration.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(
                _state == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: onBubble,
                size: 28,
              ),
              onPressed: _togglePlay,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: accent,
                  inactiveTrackColor: trackInactive,
                  thumbColor: accent,
                  overlayColor: accent.withValues(alpha: widget.mine ? 0.22 : 0.18),
                ),
                child: Slider(
                  value: _sliderValue(),
                  onChangeStart: totalMs > 0
                      ? (_) {
                          setState(() {
                            _scrubbing = true;
                            _scrubValue = _sliderValue();
                          });
                        }
                      : null,
                  onChanged: totalMs > 0 ? (v) => setState(() => _scrubValue = v) : null,
                  onChangeEnd: totalMs > 0
                      ? (v) async {
                          if (totalMs > 0) {
                            final target = Duration(
                              milliseconds: (v * totalMs).round().clamp(0, totalMs),
                            );
                            try {
                              await _player.seek(target);
                              if (mounted) {
                                setState(() => _position = target);
                              }
                            } catch (_) {}
                          }
                          if (mounted) {
                            setState(() {
                              _scrubbing = false;
                              _scrubValue = null;
                            });
                          }
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 2),
            PopupMenuButton<double>(
              tooltip: 'Playback speed',
              padding: EdgeInsets.zero,
              color: scheme.surface,
              onSelected: _setRate,
              itemBuilder: (ctx) => [
                for (final r in _playbackRates)
                  PopupMenuItem<double>(
                    value: r,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_speedMenuLabel(r)),
                        if ((r - _playbackRate).abs() < 0.01)
                          Icon(Icons.check, size: 18, color: scheme.primary),
                      ],
                    ),
                  ),
              ],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.mine
                      ? Colors.white.withValues(alpha: 0.18)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.mine
                        ? Colors.white.withValues(alpha: 0.45)
                        : scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    _rateLabel(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: widget.mine ? Colors.white : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 44, end: 8, bottom: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  voiceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              Text(
                '${_formatVoiceDuration(_position)} / ${_formatVoiceDuration(_duration)}',
                style: TextStyle(fontSize: 11, color: muted, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
