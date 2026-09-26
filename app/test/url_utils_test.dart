import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/utils/url_utils.dart';

void main() {
  group('normalizeServerUrl', () {
    test('adds http:// when scheme is missing', () {
      expect(normalizeServerUrl('omvnas:4000'), 'http://omvnas:4000');
    });

    test('keeps https://', () {
      expect(
        normalizeServerUrl('https://yuvomi.example:8443'),
        'https://yuvomi.example:8443',
      );
    });

    test('strips trailing slash', () {
      expect(normalizeServerUrl('http://omvnas:4000/'), 'http://omvnas:4000');
    });

    test('trims whitespace', () {
      expect(
        normalizeServerUrl('  http://omvnas:4000  '),
        'http://omvnas:4000',
      );
    });

    test('throws on empty', () {
      expect(() => normalizeServerUrl(''), throwsFormatException);
      expect(() => normalizeServerUrl('   '), throwsFormatException);
    });

    test('throws on unsupported scheme', () {
      expect(
        () => normalizeServerUrl('ftp://omvnas:4000'),
        throwsFormatException,
      );
    });

    test('throws on missing host', () {
      expect(() => normalizeServerUrl('http://'), throwsFormatException);
    });
  });

  group('validateServerUrl', () {
    test('returns null when valid', () {
      expect(validateServerUrl('http://omvnas:4000'), isNull);
      expect(validateServerUrl('https://yuvomi.example'), isNull);
    });

    test('returns a message when invalid', () {
      expect(validateServerUrl(''), isNotNull);
      expect(validateServerUrl('ftp://x'), isNotNull);
    });
  });
}
