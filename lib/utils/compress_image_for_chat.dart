import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Downscale and re-encode raster images for team chat upload (matches web compressImageForChat).
/// Skips GIF (animation) and non-images.
Future<String> compressImageForChatIfNeeded(String filePath) async {
  final lower = filePath.toLowerCase();
  if (lower.endsWith('.gif')) return filePath;

  final ext = _ext(filePath);
  const imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'};
  if (!imageExts.contains(ext) && !lower.contains('image')) {
    // Heuristic: image_picker paths may omit extension clarity; still try compress for common cases.
    if (!lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.png') &&
        !lower.endsWith('.webp')) {
      return filePath;
    }
  }

  try {
    final dir = await getTemporaryDirectory();
    final base = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    final outWebp = '${dir.path}${Platform.pathSeparator}$base.webp';
    final xfile = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outWebp,
      quality: 84,
      minWidth: 1920,
      minHeight: 1920,
      format: CompressFormat.webp,
    );
    if (xfile != null) {
      final f = File(xfile.path);
      if (await f.length() > 100) return xfile.path;
    }
    final outJpg = '${dir.path}${Platform.pathSeparator}$base.jpg';
    final xfileJpg = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outJpg,
      quality: 84,
      minWidth: 1920,
      minHeight: 1920,
      format: CompressFormat.jpeg,
    );
    if (xfileJpg != null) return xfileJpg.path;
  } catch (_) {
    //
  }
  return filePath;
}

String _ext(String filePath) {
  final n = filePath.replaceAll('\\', '/').split('/').last;
  final d = n.lastIndexOf('.');
  return d >= 0 ? n.substring(d).toLowerCase() : '';
}
