import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/utils/media_url_utils.dart';
import '../../screens/team_chat/team_chat_media_viewer_screen.dart';

/// Opens the app-wide full-screen media viewer (same as team chat conversations).
Future<void> openAppImageViewer(
  BuildContext context, {
  Uint8List? imageBytes,
  String? imageUrl,
  String? imageFilePath,
  String? suggestedFilename,
}) {
  assert(
    imageBytes != null || imageUrl != null || imageFilePath != null,
    'Provide imageBytes, imageUrl, or imageFilePath',
  );

  if (imageBytes != null) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeamChatMediaViewerScreen.image(
          imageBytes: imageBytes,
          suggestedFilename: suggestedFilename,
        ),
      ),
    );
  }

  if (imageFilePath != null) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeamChatMediaViewerScreen.fileImage(
          imageFilePath: imageFilePath,
          suggestedFilename: suggestedFilename,
        ),
      ),
    );
  }

  final resolved = resolveMediaUrl(imageUrl)!;
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => TeamChatMediaViewerScreen.networkImage(
        imageUrl: resolved,
        suggestedFilename:
            suggestedFilename ?? mediaFilenameFromUrl(resolved),
      ),
    ),
  );
}
