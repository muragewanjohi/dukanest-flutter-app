import 'package:dukanest_app/features/subscription/subscription_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPlanFreeActivatable', () {
    test('true when an explicit free/no-payment flag is set', () {
      expect(isPlanFreeActivatable({'isFree': true}), isTrue);
      expect(isPlanFreeActivatable({'free': true}), isTrue);
      expect(isPlanFreeActivatable({'allowDirectActivation': true}), isTrue);
      expect(isPlanFreeActivatable({'noPayment': true}), isTrue);
    });

    test('true when requiresPayment is explicitly false', () {
      expect(isPlanFreeActivatable({'requiresPayment': false}), isTrue);
      expect(isPlanFreeActivatable({'requires_payment': false}), isTrue);
      expect(isPlanFreeActivatable({'paymentRequired': false}), isTrue);
    });

    test('true when all discoverable prices are zero', () {
      expect(
          isPlanFreeActivatable({'monthlyPrice': 0, 'yearlyPrice': 0}), isTrue);
      expect(isPlanFreeActivatable({'price': 0}), isTrue);
      expect(isPlanFreeActivatable({'price': '0'}), isTrue);
    });

    test('false for a paid plan', () {
      expect(isPlanFreeActivatable({'monthlyPrice': 999, 'yearlyPrice': 9990}),
          isFalse);
      expect(isPlanFreeActivatable({'price': '1500'}), isFalse);
    });

    test('false when a monthly price is non-zero even if yearly is zero', () {
      expect(
        isPlanFreeActivatable({'monthlyPrice': 500, 'yearlyPrice': 0}),
        isFalse,
      );
    });

    test('false when no price and no flags are present (cannot infer free)',
        () {
      expect(isPlanFreeActivatable({'name': 'Mystery'}), isFalse);
      expect(isPlanFreeActivatable(<String, dynamic>{}), isFalse);
    });
  });

  group('formatPlanPriceLines', () {
    test('reads generic price field for Pro-style plans', () {
      final lines = formatPlanPriceLines({
        'name': 'Pro',
        'price': 2500,
        'yearlyPriceKes': 25000,
        'currencySymbol': 'KSh',
      });

      expect(lines.monthly, 'KSh 2500');
      expect(lines.yearly, 'KSh 25000');
    });

    test('reads priceKes when price is absent', () {
      final lines = formatPlanPriceLines({
        'priceKes': 1999,
      });

      expect(lines.monthly, 'KSh 1999');
    });
  });
}
