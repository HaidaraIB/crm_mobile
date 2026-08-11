import '../models/lead_whatsapp_message_model.dart';
import '../services/api_service.dart';

/// One image/video attachment in a thread's media album.
class WhatsAppMediaAlbumItem {
  const WhatsAppMediaAlbumItem({
    required this.id,
    required this.kind,
    required this.url,
    this.filename,
  });

  final int id;

  /// `image` or `video`.
  final String kind;
  final String url;
  final String? filename;

  bool get isImage => kind == 'image';
}

/// Chronological album of every image/video attachment in the loaded thread.
///
/// Port of `CRM-project/components/chat/chatMediaAlbum.ts` — tapping one photo
/// should open a swipeable album of all of them, not just that one.
List<WhatsAppMediaAlbumItem> buildWhatsAppMediaAlbum(
  List<LeadWhatsAppMessageModel> messages,
) {
  final out = <WhatsAppMediaAlbumItem>[];
  for (final m in messages) {
    if (!m.hasAttachment || m.id <= 0) continue;
    final kind = m.attachmentKind;
    if (kind != 'image' && kind != 'video') continue;
    final url = (m.attachmentUrl?.isNotEmpty ?? false)
        ? m.attachmentUrl!
        : ApiService().whatsappMessageAttachmentUrl(m.id);
    if (url.isEmpty) continue;
    out.add(
      WhatsAppMediaAlbumItem(
        id: m.id,
        kind: kind!,
        url: url,
        filename: m.originalFilename,
      ),
    );
  }
  return out;
}

/// Index of [messageId] in [items], or 0 when it is not part of the album.
int findWhatsAppMediaAlbumIndex(
  List<WhatsAppMediaAlbumItem> items,
  int messageId,
) {
  final idx = items.indexWhere((it) => it.id == messageId);
  return idx >= 0 ? idx : 0;
}
