/// A file stored in the tenant's shared Company Library.
///
/// Mirrors `CompanyLibraryFileSerializer` in the backend and the
/// `CompanyLibraryFile` type in `CRM-project/services/api.ts`.
class CompanyLibraryFileModel {
  const CompanyLibraryFileModel({
    required this.id,
    required this.originalFilename,
    required this.mimeType,
    required this.sizeBytes,
    required this.kind,
    this.uploadedByName,
  });

  final int id;
  final String originalFilename;
  final String mimeType;
  final int sizeBytes;

  /// `image` | `video` | `audio` | `document` (server may add more).
  final String kind;
  final String? uploadedByName;

  factory CompanyLibraryFileModel.fromJson(Map<String, dynamic> json) {
    return CompanyLibraryFileModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      originalFilename: json['original_filename']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      kind: json['kind']?.toString() ?? 'document',
      uploadedByName: json['uploaded_by_name']?.toString(),
    );
  }

  /// Localization key for the kind chip, matching the web `kindLabel` helper.
  String get kindLabelKey {
    switch (kind) {
      case 'image':
        return 'libraryKindImage';
      case 'video':
        return 'libraryKindVideo';
      case 'audio':
        return 'libraryKindAudio';
      case 'document':
        return 'libraryKindDocument';
      default:
        return 'libraryKindDocument';
    }
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
