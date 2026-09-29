import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_mobile/core/utils/input_text_direction.dart';

void main() {
  test('composerTextDirection follows first strong letter', () {
    expect(composerTextDirection('', arabicUi: true), TextDirection.rtl);
    expect(composerTextDirection('', arabicUi: false), TextDirection.ltr);
    expect(composerTextDirection('123 مرحبا', arabicUi: false), TextDirection.rtl);
    expect(composerTextDirection('Hello', arabicUi: true), TextDirection.ltr);
    expect(composerTextDirection('مرحبا', arabicUi: false), TextDirection.rtl);
  });

  test('bidiIsolate wraps the string', () {
    expect(bidiIsolate('Hi.'), '\u2068Hi.\u2069');
  });

  test('ltrAnchoredHint pins Arabic hints without doubling', () {
    expect(ltrAnchoredHint('أدخل'), '\u200Eأدخل');
    expect(ltrAnchoredHint('\u200Eأدخل'), '\u200Eأدخل');
    expect(ltrAnchoredHint(''), '');
  });
}
