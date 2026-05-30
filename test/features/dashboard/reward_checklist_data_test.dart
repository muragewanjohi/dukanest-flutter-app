import 'package:dukanest_app/features/dashboard/reward_checklist_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rewardBool', () {
    test('accepts the various truthy shapes', () {
      for (final v in [true, 1, '1', 'true', 'completed', 'done']) {
        expect(rewardBool(v), isTrue, reason: 'value: $v');
      }
    });

    test('rejects falsey shapes', () {
      for (final v in [false, 0, '0', 'false', 'pending', null, 'no']) {
        expect(rewardBool(v), isFalse, reason: 'value: $v');
      }
    });
  });

  group('humanizeRewardKey', () {
    test('splits camelCase (preserving subsequent word casing)', () {
      expect(humanizeRewardKey('heroImage'), 'Hero Image');
    });

    test('replaces snake/kebab separators', () {
      expect(humanizeRewardKey('hero_description'), 'Hero description');
      expect(humanizeRewardKey('split-layout-image'), 'Split layout image');
    });

    test('leaves an already-spaced label alone', () {
      expect(humanizeRewardKey('Add a logo'), 'Add a logo');
    });
  });

  group('shouldShowReward', () {
    test('false when data or reward is missing', () {
      expect(shouldShowReward(null), isFalse);
      expect(shouldShowReward({'foo': 'bar'}), isFalse);
    });

    test('false when reward is disabled', () {
      expect(
        shouldShowReward({
          'reward': {'enabled': false, 'eligible': true},
        }),
        isFalse,
      );
    });

    test('true when enabled and eligible', () {
      expect(
        shouldShowReward({
          'reward': {'enabled': true, 'eligible': true},
        }),
        isTrue,
      );
    });

    test('true when enabled and already granted', () {
      expect(
        shouldShowReward({
          'reward': {'enabled': true, 'granted': true},
        }),
        isTrue,
      );
    });

    test('false when enabled but neither eligible nor granted', () {
      expect(
        shouldShowReward({
          'reward': {'enabled': true},
        }),
        isFalse,
      );
    });
  });

  group('rewardSteps', () {
    test('returns empty when there is no steps array', () {
      expect(rewardSteps({'reward': {}}), isEmpty);
    });

    test('parses items with mixed key names and completion shapes', () {
      final steps = rewardSteps({
        'items': [
          {'key': 'heroImage', 'completed': true, 'description': 'Add a hero'},
          {'label': 'Add a logo', 'status': 'pending'},
          {'title': 'split_layout_image', 'done': 1},
          {'noTitleHere': true}, // skipped: no resolvable title
        ],
      });

      expect(steps.length, 3);

      expect(steps[0].title, 'Hero Image');
      expect(steps[0].subtitle, 'Add a hero');
      expect(steps[0].done, isTrue);

      expect(steps[1].title, 'Add a logo');
      expect(steps[1].done, isFalse);

      expect(steps[2].title, 'Split layout image');
      expect(steps[2].done, isTrue);
    });
  });
}
