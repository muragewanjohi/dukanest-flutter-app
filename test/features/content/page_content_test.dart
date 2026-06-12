import 'dart:convert';

import 'package:dukanest_app/features/content/data/page_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseContentField', () {
    test('decodes JSON string into map', () {
      final json = jsonEncode({
        'sections': [
          {'type': 'hero', 'title': 'Welcome'},
        ],
      });
      final parsed = parseContentField(json);
      expect(parsed['sections'], isA<List>());
      expect((parsed['sections'] as List).first['title'], 'Welcome');
    });

    test('returns empty map for invalid JSON string', () {
      expect(parseContentField('{not json'), isEmpty);
    });

    test('passes through map values', () {
      final map = {'sections': <dynamic>[]};
      expect(parseContentField(map), map);
    });
  });

  group('parseSections', () {
    test('parses sections array with types and hidden flag', () {
      final content = {
        'sections': [
          {'type': 'hero', 'title': 'Shop Now', 'hidden': false},
          {'type': 'banners', 'title': 'Deals', 'hidden': true},
          {'type': 'split_layout', 'left_side': {'type': 'banner'}},
        ],
      };
      final sections = parseSections(content);
      expect(sections, hasLength(3));
      expect(sections[0].key, 'hero');
      expect(sections[0].enabled, isTrue);
      expect(sections[0].sectionIndex, 0);
      expect(sections[1].key, 'banners');
      expect(sections[1].enabled, isFalse);
      expect(sections[2].key, 'split_layout');
      expect(sections[2].isEditable, isTrue);
    });
  });

  group('applySectionEnabled', () {
    test('writes hidden and enabled on section by index', () {
      final content = {
        'sections': [
          {'type': 'hero', 'hidden': false},
        ],
      };
      final section = parseSections(content).first;
      section.enabled = false;
      applySectionEnabled(content, section);
      final hero = (content['sections'] as List).first as Map;
      expect(hero['hidden'], isTrue);
      expect(hero['enabled'], isFalse);
    });
  });

  group('read/write section helpers', () {
    final content = {
      'sections': [
        {
          'type': 'hero',
          'title': 'Old',
          'image': 'a.png',
          'banner_image': 'bg.png',
        },
        {
          'type': 'banners',
          'banners': [
            {'id': 'b1', 'title': 'Sale'},
          ],
        },
        {
          'type': 'split_layout',
          'left_side': {'type': 'banner', 'image': 'left.png'},
        },
      ],
    };

    test('readHero and writeHero round-trip', () {
      final map = Map<String, dynamic>.from(content);
      final hero = readHero(map);
      expect(hero['title'], 'Old');
      writeHero(map, {'title': 'New', 'image': 'hero.png'});
      expect(readHero(map)['title'], 'New');
      expect(readHero(map)['image'], 'hero.png');
    });

    test('readBanners and writeBanners round-trip', () {
      final map = Map<String, dynamic>.from(content);
      final banners = readBanners(map);
      expect(banners['banners'], isA<List>());
      writeBanners(map, {
        'type': 'banners',
        'title': 'Promos',
        'banners': [
          {'id': 'b1', 'title': 'Updated'},
        ],
      });
      expect(readBanners(map)['title'], 'Promos');
      final items = readBanners(map)['banners'] as List;
      expect(items.first['title'], 'Updated');
    });

    test('readSplitLayout and writeSplitLayout round-trip', () {
      final map = Map<String, dynamic>.from(content);
      final split = readSplitLayout(map);
      final left = split['left_side'] as Map;
      expect(left['image'], 'left.png');
      writeSplitLayout(map, {
        'type': 'split_layout',
        'left_side': {
          'type': 'banner',
          'image': 'new-left.png',
          'cta_link': '/shop',
        },
      });
      final updated = readSplitLayout(map)['left_side'] as Map;
      expect(updated['image'], 'new-left.png');
      expect(updated['cta_link'], '/shop');
    });
  });

  group('sectionEditorRoute', () {
    test('builds paths for editable section types', () {
      expect(sectionEditorRoute('home', 'hero'),
          '/page-editor/home/sections/hero');
      expect(sectionEditorRoute('home', 'banners'),
          '/page-editor/home/sections/banners');
      expect(sectionEditorRoute('home', 'split_layout'),
          '/page-editor/home/sections/split-layout');
    });
  });
}
