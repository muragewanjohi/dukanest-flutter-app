import 'package:dukanest_app/features/themes/theme_list_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('themeListFrom', () {
    test('reads a flat list payload', () {
      final list = themeListFrom([
        {'id': 'a'},
        {'id': 'b'},
      ]);
      expect(list.map((e) => e['id']), ['a', 'b']);
    });

    test('reads {items: []}', () {
      final list = themeListFrom({
        'items': [
          {'id': 'a'},
        ],
      });
      expect(list.single['id'], 'a');
    });

    test('reads {themes: []}', () {
      final list = themeListFrom({
        'themes': [
          {'id': 'z'},
        ],
      });
      expect(list.single['id'], 'z');
    });

    test('reads a nested {data: {items: []}} envelope', () {
      final list = themeListFrom({
        'data': {
          'items': [
            {'id': 'n1'},
            {'id': 'n2'},
          ],
        },
      });
      expect(list.length, 2);
    });

    test('reads {data: []} (nested list)', () {
      final list = themeListFrom({
        'data': [
          {'id': 'd1'},
        ],
      });
      expect(list.single['id'], 'd1');
    });

    test('returns empty for unrecognized shapes', () {
      expect(themeListFrom(null), isEmpty);
      expect(themeListFrom(42), isEmpty);
      expect(themeListFrom({'nope': true}), isEmpty);
    });
  });

  group('themeId', () {
    test('prefers id, then falls back through variants', () {
      expect(themeId({'id': '1'}), '1');
      expect(themeId({'_id': '2'}), '2');
      expect(themeId({'themeId': '3'}), '3');
      expect(themeId({'slug': 'aurora'}), 'aurora');
      expect(themeId({'key': 'k'}), 'k');
    });

    test('trims and ignores blank values', () {
      expect(themeId({'id': '   ', 'slug': 'fallback'}), 'fallback');
      expect(themeId(<String, dynamic>{}), '');
    });
  });

  group('currentThemeId', () {
    test('reads from data envelope', () {
      expect(
          currentThemeId({
            'data': {'id': 'active'}
          }),
          'active');
    });

    test('reads from theme key', () {
      expect(
          currentThemeId({
            'theme': {'slug': 'current'}
          }),
          'current');
    });

    test('reads from a flat map', () {
      expect(currentThemeId({'id': 'flat'}), 'flat');
    });

    test('null when no resolvable id', () {
      expect(currentThemeId(null), isNull);
      expect(
          currentThemeId({
            'data': {'name': 'no-id'}
          }),
          isNull);
    });
  });
}
