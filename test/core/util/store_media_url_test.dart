import 'package:dukanest_app/core/util/store_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeStoreMediaUrl', () {
    test('returns empty string for null or blank input', () {
      expect(normalizeStoreMediaUrl(null), '');
      expect(normalizeStoreMediaUrl(''), '');
      expect(normalizeStoreMediaUrl('   '), '');
    });

    test('leaves an ordinary absolute https URL untouched', () {
      const url = 'https://cdn.example.com/img/a.png';
      expect(normalizeStoreMediaUrl(url), url);
    });

    test('promotes a protocol-relative URL to https', () {
      expect(
        normalizeStoreMediaUrl('//cdn.example.com/x.png'),
        'https://cdn.example.com/x.png',
      );
    });

    test('rewrites the host for Supabase public storage paths', () {
      final out = normalizeStoreMediaUrl(
        'https://www.dukanest.com/storage/v1/object/public/store/logo.png',
      );
      final uri = Uri.parse(out);
      expect(uri.scheme, 'https');
      expect(uri.host, kStoreMediaPublicHost);
      expect(uri.path, '/storage/v1/object/public/store/logo.png');
    });

    test('does not rewrite the host for non-public-storage paths', () {
      const url = 'https://www.dukanest.com/storage/v1/object/sign/x.png';
      expect(normalizeStoreMediaUrl(url), url);
    });
  });

  group('extractMediaUploadUrl', () {
    test('returns empty for null and non-map, non-string input', () {
      expect(extractMediaUploadUrl(null), '');
      expect(extractMediaUploadUrl(42), '');
    });

    test('normalizes a bare string', () {
      expect(
        extractMediaUploadUrl('//cdn.example.com/y.png'),
        'https://cdn.example.com/y.png',
      );
    });

    test('reads publicUrl from a flat map', () {
      expect(
        extractMediaUploadUrl({'publicUrl': 'https://h/x.png'}),
        'https://h/x.png',
      );
    });

    test('reads url from a nested data envelope', () {
      final out = extractMediaUploadUrl({
        'data': {'url': 'https://h/nested.png'},
      });
      expect(out, 'https://h/nested.png');
    });

    test('falls back through key priority order', () {
      final out = extractMediaUploadUrl({'src': 'https://h/from-src.png'});
      expect(out, 'https://h/from-src.png');
    });

    test('returns empty when no url-like key is present', () {
      expect(extractMediaUploadUrl({'foo': 'bar'}), '');
    });
  });
}
