import '../constants/app_constants.dart';

/// Resolves API-relative media paths to absolute URLs (screenshots, field visit photos, etc.).
String? resolveMediaUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  var base = AppConstants.baseUrl.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  final origin =
      base.contains('/api') ? base.substring(0, base.indexOf('/api')) : base;
  final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return '$origin$path';
}

String? mediaFilenameFromUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final seg = url.split(RegExp(r'[/\\]')).last;
  return seg.isEmpty ? null : seg;
}
