import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/snackbar_helper.dart';
import 'team_chat_common.dart';

/// Full-screen viewer for team chat images (pinch zoom) and videos (Chewie controls + save).
/// Video fullscreen uses [DeviceOrientation.values] so the OS can honor rotation lock / auto-rotate.
class TeamChatMediaViewerScreen extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  TeamChatMediaViewerScreen._({
    super.key,
    this.imageBytes,
    this.videoFilePath,
    this.suggestedFilename,
  }) : assert(
          (imageBytes != null && videoFilePath == null) ||
              (imageBytes == null && videoFilePath != null),
        );

  factory TeamChatMediaViewerScreen.image({
    Key? key,
    required Uint8List imageBytes,
    String? suggestedFilename,
  }) {
    return TeamChatMediaViewerScreen._(
      key: key,
      imageBytes: imageBytes,
      suggestedFilename: suggestedFilename,
    );
  }

  factory TeamChatMediaViewerScreen.video({
    Key? key,
    required String videoFilePath,
    String? suggestedFilename,
  }) {
    return TeamChatMediaViewerScreen._(
      key: key,
      videoFilePath: videoFilePath,
      suggestedFilename: suggestedFilename,
    );
  }

  final Uint8List? imageBytes;
  final String? videoFilePath;
  final String? suggestedFilename;

  bool get isImage => imageBytes != null;

  @override
  State<TeamChatMediaViewerScreen> createState() => _TeamChatMediaViewerScreenState();
}

class _TeamChatMediaViewerScreenState extends State<TeamChatMediaViewerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _videoFailed = false;

  static final List<DeviceOrientation> _allOrientations =
      List<DeviceOrientation>.unmodifiable(DeviceOrientation.values);

  @override
  void initState() {
    super.initState();
    if (!widget.isImage) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final raw = widget.videoFilePath;
    if (raw == null) return;
    final path = tenantChatNativeFilePath(raw);
    final vc = VideoPlayerController.file(File(path));
    try {
      await vc.initialize();
      if (!mounted) {
        await vc.dispose();
        return;
      }
      final cw = ChewieController(
        videoPlayerController: vc,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        deviceOrientationsOnEnterFullScreen: _allOrientations,
        deviceOrientationsAfterFullScreen: _allOrientations,
      );
      setState(() {
        _video = vc;
        _chewie = cw;
      });
    } catch (_) {
      await vc.dispose();
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  String _galleryImageName() {
    final raw = widget.suggestedFilename;
    if (raw == null || raw.trim().isEmpty) return 'chat_image';
    final base = raw.split(RegExp(r'[/\\]')).last;
    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    final cleaned = stem.replaceAll(RegExp(r'[^\w\-]+'), '_').trim();
    return cleaned.isEmpty ? 'chat_image' : cleaned;
  }

  Future<void> _ensureGalleryAccess() async {
    if (await Gal.hasAccess(toAlbum: false)) return;
    await Gal.requestAccess(toAlbum: false);
  }

  String _saveExtFromFilename(String? filename) {
    if (filename == null) return '.png';
    final seg = filename.split(RegExp(r'[/\\]')).last.toLowerCase();
    final d = seg.lastIndexOf('.');
    final e = d >= 0 ? seg.substring(d) : '';
    if (e == '.jpg' || e == '.jpeg' || e == '.png' || e == '.webp' || e == '.gif') {
      return e;
    }
    return '.png';
  }

  /// Prefer [Gal.putImageBytes]; fall back to temp file + [Gal.putImage] if format detection fails.
  Future<void> _putImageToGallery(Uint8List bytes) async {
    try {
      await Gal.putImageBytes(bytes, name: _galleryImageName());
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) rethrow;
      final dir = await getTemporaryDirectory();
      final ext = _saveExtFromFilename(widget.suggestedFilename);
      final f = File('${dir.path}/chat_gal_${DateTime.now().millisecondsSinceEpoch}$ext');
      await f.writeAsBytes(bytes, flush: true);
      await Gal.putImage(f.path);
    }
  }

  Future<void> _saveImage() async {
    final bytes = widget.imageBytes;
    if (bytes == null) return;
    final loc = AppLocalizations.of(context);
    try {
      await _ensureGalleryAccess();
      if (!await Gal.hasAccess(toAlbum: false)) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            loc?.translate('teamChatSavePermissionDenied') ??
                'Photo library access was denied.',
          );
        }
        return;
      }
      await _putImageToGallery(bytes);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          loc?.translate('teamChatSavedToGallery') ?? 'Saved to gallery.',
        );
      }
    } on GalException catch (e) {
      if (!mounted) return;
      final msg = e.type == GalExceptionType.accessDenied
          ? (loc?.translate('teamChatSavePermissionDenied') ??
              'Photo library access was denied.')
          : (loc?.translate('teamChatSaveFailed') ?? 'Could not save.');
      SnackbarHelper.showError(context, msg);
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        loc?.translate('teamChatSaveFailed') ?? 'Could not save.',
      );
    }
  }

  Future<void> _saveVideo() async {
    final raw = widget.videoFilePath;
    if (raw == null) return;
    final path = tenantChatNativeFilePath(raw);
    final loc = AppLocalizations.of(context);
    try {
      await _ensureGalleryAccess();
      if (!await Gal.hasAccess(toAlbum: false)) {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            loc?.translate('teamChatSavePermissionDenied') ??
                'Photo library access was denied.',
          );
        }
        return;
      }
      await Gal.putVideo(path);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          loc?.translate('teamChatSavedToGallery') ?? 'Saved to gallery.',
        );
      }
    } on GalException catch (e) {
      if (!mounted) return;
      final msg = e.type == GalExceptionType.accessDenied
          ? (loc?.translate('teamChatSavePermissionDenied') ??
              'Photo library access was denied.')
          : (loc?.translate('teamChatSaveFailed') ?? 'Could not save.');
      SnackbarHelper.showError(context, msg);
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        loc?.translate('teamChatSaveFailed') ?? 'Could not save.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = widget.isImage
        ? (loc?.translate('teamChatMediaPhoto') ?? 'Photo')
        : (loc?.translate('teamChatMediaVideo') ?? 'Video');
    final saveLabel = loc?.translate('teamChatSaveToGallery') ?? 'Save to gallery';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: saveLabel,
            onPressed: widget.isImage ? _saveImage : _saveVideo,
          ),
        ],
      ),
      body: widget.isImage ? _buildImageBody() : _buildVideoBody(loc),
    );
  }

  Widget _buildImageBody() {
    final bytes = widget.imageBytes!;
    return LayoutBuilder(
      builder: (context, cons) {
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(24),
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoBody(AppLocalizations? loc) {
    if (_videoFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            loc?.translate('teamChatMediaCouldNotLoad') ?? 'Could not load this media.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final cw = _chewie;
    if (cw == null) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Center(
          child: AspectRatio(
            aspectRatio: _video!.value.aspectRatio == 0 ? 16 / 9 : _video!.value.aspectRatio,
            child: Chewie(controller: cw),
          ),
        ),
      ),
    );
  }
}
