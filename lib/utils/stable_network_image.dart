import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Query parameters of an S3/R2 presigned URL (SigV4 query auth).
const _presignParams = {
  'X-Amz-Algorithm',
  'X-Amz-Credential',
  'X-Amz-Date',
  'X-Amz-Expires',
  'X-Amz-SignedHeaders',
  'X-Amz-Signature',
  'X-Amz-Security-Token',
};

/// The image-cache identity of [url]: a presigned object-storage URL minus its
/// signature, so the same object keeps one cache entry while the API hands out
/// a freshly signed URL (CRM-api-1 docs/STORAGE.md). Any other URL is returned
/// unchanged.
String stableImageCacheKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.queryParameters.containsKey('X-Amz-Signature')) {
    return url;
  }
  final kept = Map<String, String>.of(uri.queryParameters)
    ..removeWhere((key, _) => _presignParams.contains(key));
  final base = url.split('?').first;
  return kept.isEmpty ? base : '$base?${Uri(queryParameters: kept).query}';
}

/// Whether [url] is served by the CRM API at [apiBaseUrl] (same scheme, host and
/// port), i.e. whether it may be sent the user's token. Relative URLs count as
/// the API's own.
bool isApiOriginUrl(String url, String apiBaseUrl) {
  final target = Uri.tryParse(url);
  final api = Uri.tryParse(apiBaseUrl);
  if (target == null || api == null) return false;
  if (!target.hasScheme) return true;
  return target.scheme == api.scheme &&
      target.host == api.host &&
      target.port == api.port;
}

/// [NetworkImage] whose cache key ignores the presign query: Flutter's image
/// cache is keyed by the provider, and a plain [NetworkImage] would download
/// the same avatar again each time the API re-signs its URL. The newest URL is
/// still the one fetched on a cache miss, so an expired signature is never used.
@immutable
class StableNetworkImage extends ImageProvider<StableNetworkImage> {
  const StableNetworkImage(this.url, {this.scale = 1.0, this.headers});

  final String url;
  final double scale;
  final Map<String, String>? headers;

  String get cacheKey => stableImageCacheKey(url);

  @override
  Future<StableNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<StableNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
    StableNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    final inner = NetworkImage(key.url, scale: key.scale, headers: key.headers);
    // NetworkImage is its own key (obtainKey returns itself synchronously).
    // ignore: invalid_use_of_protected_member
    return inner.loadImage(inner, decode);
  }

  @override
  bool operator ==(Object other) =>
      other is StableNetworkImage &&
      other.cacheKey == cacheKey &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(cacheKey, scale);

  @override
  String toString() => 'StableNetworkImage("$cacheKey", scale: $scale)';
}
