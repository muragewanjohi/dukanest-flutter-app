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

    test('resolveCurrentPlan reads currentPlan object from mobile snapshot', () {
      final plan = resolveCurrentPlan(
        data: {
          'currentPlan': {
            'id': 'plan-basic',
            'name': 'Basic',
            'price': 10,
            'currencySymbol': 'Ksh',
          },
          'availablePlans': [
            {'id': 'plan-basic', 'name': 'Basic', 'changeType': 'same'},
            {'id': 'plan-pro', 'name': 'Pro', 'changeType': 'upgrade'},
          ],
        },
        plans: parseAvailablePlans({
          'availablePlans': [
            {'id': 'plan-basic', 'name': 'Basic', 'changeType': 'same'},
            {'id': 'plan-pro', 'name': 'Pro', 'changeType': 'upgrade'},
          ],
        }),
      );

      expect(plan, isNotNull);
      expect(plan!['name'], 'Basic');
      expect(plan['changeType'], 'same');
    });

    test('resolveCurrentPlan falls back to isCurrentPlan in catalog', () {
      final plans = [
        {'id': 'p1', 'name': 'Basic', 'isCurrentPlan': true, 'price': 10},
        {'id': 'p2', 'name': 'Pro', 'changeType': 'upgrade'},
      ];
      final plan = resolveCurrentPlan(
        data: const {},
        plans: plans,
      );

      expect(plan?['name'], 'Basic');
    });
  });
}
