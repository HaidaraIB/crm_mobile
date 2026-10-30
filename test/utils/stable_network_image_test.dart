import 'package:crm_mobile/utils/stable_network_image.dart';
import 'package:flutter_test/flutter_test.dart';

const _base =
    'https://acc0unt.r2.cloudflarestorage.com/loop-crm-media/companies/7/profile_photos/me.jpg';

String _signed(String date, String sig) =>
    '$_base?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AK%2F20261017%2Fauto%2Fs3%2Faws4_request'
    '&X-Amz-Date=$date&X-Amz-Expires=25200&X-Amz-SignedHeaders=host&X-Amz-Signature=$sig';

void main() {
  test('a re-signed URL for the same object keeps one cache key', () {
    final a = _signed('20261017T090000Z', 'aaa');
    final b = _signed('20261017T100000Z', 'bbb');
    expect(stableImageCacheKey(a), _base);
    expect(StableNetworkImage(a), StableNetworkImage(b));
    expect(StableNetworkImage(a).hashCode, StableNetworkImage(b).hashCode);
  });

  test('the newest URL is the one that gets fetched', () {
    final b = _signed('20261017T100000Z', 'bbb');
    expect(StableNetworkImage(b).url, b);
  });

  test('different objects and unsigned URLs are not merged', () {
    final other = _signed(
      '20261017T090000Z',
      'aaa',
    ).replaceFirst('me.jpg', 'you.jpg');
    expect(
      StableNetworkImage(_signed('20261017T090000Z', 'aaa')) ==
          StableNetworkImage(other),
      isFalse,
    );
    const local = 'http://10.0.2.2:8000/media/profile_photos/me.jpg?v=2';
    expect(stableImageCacheKey(local), local);
    const publicCover =
        'https://media.loopcrm.app/platform_content/guide/2026/10/cover.png';
    expect(stableImageCacheKey(publicCover), publicCover);
  });

  test('only the API origin may be sent the token', () {
    const api = 'https://api.loopcrm.app/api/v1';
    expect(
      isApiOriginUrl(
        'https://api.loopcrm.app/api/v1/company-library/3/download/',
        api,
      ),
      isTrue,
    );
    expect(isApiOriginUrl(_signed('20261017T090000Z', 'aaa'), api), isFalse);
    expect(isApiOriginUrl('https://api.loopcrm.app:8443/x', api), isFalse);
    expect(isApiOriginUrl('http://api.loopcrm.app/x', api), isFalse);
    expect(isApiOriginUrl('/media/x.png', api), isTrue);
  });

  test('non-signature query parameters stay part of the key', () {
    final withOverride =
        '${_signed('20261017T090000Z', 'aaa')}&response-content-type=image%2Fjpeg';
    expect(
      stableImageCacheKey(withOverride),
      '$_base?response-content-type=image%2Fjpeg',
    );
  });
}
