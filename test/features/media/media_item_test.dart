import 'package:dukanest_app/features/media/media_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mediaItemId', () {
    test('reads id then _id', () {
      expect(mediaItemId({'id': 'm1'}), 'm1');
      expect(mediaItemId({'_id': 'm2'}), 'm2');
    });

    test('trims and returns empty when absent/blank', () {
      expect(mediaItemId({'id': '  m3 '}), 'm3');
      expect(mediaItemId({'id': '   '}), '');
      expect(mediaItemId(<String, dynamic>{}), '');
    });
  });

  group('mediaItemUrl', () {
    test('prefers url, then public variants, then path/src', () {
      expect(mediaItemUrl({'url': 'https://h/u.png'}), 'https://h/u.png');
      expect(mediaItemUrl({'publicUrl': 'https://h/p.png'}), 'https://h/p.png');
      expect(
          mediaItemUrl({'public_url': 'https://h/s.png'}), 'https://h/s.png');
      expect(mediaItemUrl({'path': '/x.png'}), '/x.png');
      expect(mediaItemUrl({'src': 'y.png'}), 'y.png');
    });

    test('honors priority when multiple keys present', () {
      expect(
        mediaItemUrl({'src': 'low', 'url': 'high'}),
        'high',
      );
    });

    test('ignores non-string and blank values', () {
      expect(mediaItemUrl({'url': 123, 'path': 'ok.png'}), 'ok.png');
      expect(mediaItemUrl({'url': '   '}), '');
      expect(mediaItemUrl(<String, dynamic>{}), '');
    });
  });
}
