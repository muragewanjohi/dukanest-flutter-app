import 'package:dukanest_app/features/subscription/subscription_snapshot_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('subscription_snapshot_helpers', () {
    test('accessRestrictionLevel reads nested level', () {
      expect(
        accessRestrictionLevel({
          'accessRestriction': {'level': 'read-only'},
        }),
        'read-only',
      );
    });

    test('needsRenewalPayment reads camelCase flag', () {
      expect(
        needsRenewalPayment({'needsRenewalPayment': true}),
        isTrue,
      );
    });

    test('planChangeType and isPlanChangeSame', () {
      final plan = {'changeType': 'same', 'name': 'Pro'};
      expect(planChangeType(plan), 'same');
      expect(isPlanChangeSame(plan), isTrue);
    });

    test('parseAvailablePlans prefers availablePlans', () {
      final plans = parseAvailablePlans({
        'availablePlans': [
          {'id': 'p1', 'name': 'Starter', 'changeType': 'upgrade'},
        ],
        'plans': [
          {'id': 'legacy'},
        ],
      });

      expect(plans, hasLength(1));
      expect(plans.first['name'], 'Starter');
    });

    test('scheduledDowngradeLabel formats names and date', () {
      final label = scheduledDowngradeLabel({
        'fromPlanName': 'Pro',
        'toPlanName': 'Starter',
        'effectiveDate': '2026-07-01',
      });

      expect(label, contains('Pro'));
      expect(label, contains('Starter'));
    });
  });
}
