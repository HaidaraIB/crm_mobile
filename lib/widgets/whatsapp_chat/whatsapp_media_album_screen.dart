import 'package:flutter/material.dart';

import '../../screens/team_chat/team_chat_media_viewer_screen.dart';
import '../../utils/whatsapp_chat_media_album.dart';

/// Swipeable full-screen album of every image/video in a WhatsApp thread.
///
/// Matches the web `ChatMediaViewer`, which opens the whole thread album at the
/// tapped item rather than showing that one attachment in isolation.
class WhatsAppMediaAlbumScreen extends StatefulWidget {
  const WhatsAppMediaAlbumScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<WhatsAppMediaAlbumItem> items;
  final int initialIndex;

  /// Opens the album, or does nothing when there is nothing to show.
  static void open(
    BuildContext context, {
    required List<WhatsAppMediaAlbumItem> items,
    required int initialIndex,
  }) {
    if (items.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WhatsAppMediaAlbumScreen(
          items: items,
          initialIndex: initialIndex.clamp(0, items.length - 1),
        ),
      ),
    );
  }

  @override
  State<WhatsAppMediaAlbumScreen> createState() =>
      _WhatsAppMediaAlbumScreenState();
}

class _WhatsAppMediaAlbumScreenState extends State<WhatsAppMediaAlbumScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    return PageView.builder(
      controller: _controller,
      itemCount: total,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        // Each page is a full viewer, so it keeps its own load state and
        // save-to-gallery action.
        final suffix = total > 1 ? '${index + 1} / $total' : null;
        return item.isImage
            ? TeamChatMediaViewerScreen.networkImage(
                key: ValueKey('wa-album-${item.id}'),
                imageUrl: item.url,
                suggestedFilename: item.filename,
                titleSuffix: suffix,
              )
            : TeamChatMediaViewerScreen.networkVideo(
                key: ValueKey('wa-album-${item.id}'),
                videoUrl: item.url,
                suggestedFilename: item.filename,
                titleSuffix: suffix,
              );
      },
    );
  }
}
