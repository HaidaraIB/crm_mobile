import 'package:flutter/material.dart';

/// Capability flags for the shared attach bottom sheet.
class ChatAttachCapabilities {
  const ChatAttachCapabilities({
    this.photo = true,
    this.camera = false,
    this.video = false,
    this.file = true,
    this.library = false,
    this.location = false,
  });

  final bool photo;
  final bool camera;
  final bool video;
  final bool file;
  final bool library;
  final bool location;
}

enum ChatAttachAction { photo, camera, video, file, library, location }

/// Bottom sheet with optional attach actions (channel screens filter via flags).
Future<ChatAttachAction?> showChatAttachSheet(
  BuildContext context, {
  required ChatAttachCapabilities capabilities,
  required String Function(String key) t,
}) {
  final items = <(ChatAttachAction, IconData, String)>[];
  if (capabilities.photo) {
    items.add((ChatAttachAction.photo, Icons.photo_outlined, t('teamChatMediaPhoto')));
  }
  if (capabilities.camera) {
    items.add((
      ChatAttachAction.camera,
      Icons.photo_camera_outlined,
      t('whatsappAttachCamera'),
    ));
  }
  if (capabilities.video) {
    items.add((
      ChatAttachAction.video,
      Icons.videocam_outlined,
      t('teamChatMediaVideo'),
    ));
  }
  if (capabilities.file) {
    items.add((
      ChatAttachAction.file,
      Icons.insert_drive_file_outlined,
      t('teamChatMediaDocument'),
    ));
  }
  if (capabilities.library) {
    items.add((
      ChatAttachAction.library,
      Icons.folder_outlined,
      t('libraryPickerTitle'),
    ));
  }
  if (capabilities.location) {
    items.add((
      ChatAttachAction.location,
      Icons.location_on_outlined,
      t('whatsappShareLocation'),
    ));
  }

  if (items.isEmpty) return Future.value(null);

  return showModalBottomSheet<ChatAttachAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (action, icon, label) in items)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(ctx, action),
              ),
          ],
        ),
      );
    },
  );
}
