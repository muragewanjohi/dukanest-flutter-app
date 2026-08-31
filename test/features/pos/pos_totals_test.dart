import 'package:dukanest_app/features/pos/data/pos_cart.dart';
import 'package:dukanest_app/features/pos/data/pos_models.dart';
import 'package:dukanest_app/features/pos/data/pos_totals.dart';
import 'package:flutter_test/flutter_test.dart';

PosCatalogProduct _product({double price = 250, int? stock = 50}) =>
    PosCatalogProduct(
      id: 'p1',
      name: 'Widget',
      price: price,
      stockQuantity: stock,
    );

PosCartLine _line({
  int quantity = 2,
  double unitPrice = 250,
  double discount = 0,
  int? stock = 50,
}) =>
    PosCartLine(
      lineKey: 'k1',
      product: _product(price: unitPrice, stock: stock),
      quantity: quantity,
      discountAmount: discount,
    );

void main() {
  group('PosTotals.compute mirrors the server', () {
    test('no tax: total is the discounted subtotal', () {
      final t = PosTotals.compute(
        lines: [_line(quantity: 2, unitPrice: 250)],
        orderDiscount: 0,
        tax: PosTaxConfig.none,
      );
      expect(t.grossSubtotal, 500);
      expect(t.subtotal, 500);
      expect(t.taxAmount, 0);
      expect(t.total, 500);
    });

    test('exclusive tax is added on top', () {
      final t = PosTotals.compute(
        lines: [_line(quantity: 2, unitPrice: 250)],
        orderDiscount: 0,
        tax: const PosTaxConfig(
            enabled: true, rate: 16, pricingType: 'exclusive'),
      );
      expect(t.subtotal, 500);
      expect(t.taxAmount, 80);
      expect(t.total, 580);
    });

    test('inclusive tax is derived without changing the total', () {
      final t = PosTotals.compute(
        lines: [_line(quantity: 2, unitPrice: 250)],
        orderDiscount: 0,
        tax: const PosTaxConfig(
            enabled: true, rate: 16, pricingType: 'inclusive'),
      );
      expect(t.total, 500);
      expect(t.taxAmount, closeTo(68.97, 0.01));
    });

    test('line and order discounts both reduce the subtotal', () {
      final t = PosTotals.compute(
        lines: [_line(quantity: 2, unitPrice: 250, discount: 50)],
        orderDiscount: 20,
        tax: PosTaxConfig.none,
      );
      expect(t.discountTotal, 70);
      expect(t.subtotal, 430);
      expect(t.total, 430);
    });

    test('a line discount cannot exceed the line gross', () {
      final t = PosTotals.compute(
        lines: [_line(quantity: 1, unitPrice: 100, discount: 999)],
        orderDiscount: 0,
        tax: PosTaxConfig.none,
      );
      expect(t.subtotal, 0);
    });
  });

  group('PosCartLine', () {
    test('flags oversell against tracked stock', () {
      expect(_line(quantity: 3, stock: 1).isOversold, isTrue);
      expect(_line(quantity: 3, stock: 10).isOversold, isFalse);
      expect(_line(quantity: 99, stock: null).isOversold, isFalse);
    });

    test('toApiItem carries unit price and discount', () {
      final item = _line(quantity: 2, unitPrice: 250, discount: 40).toApiItem();
      expect(item['product_id'], 'p1');
      expect(item['quantity'], 2);
      expect(item['unit_price'], 250);
      expect(item['discount_amount'], 40);
    });
  });

  group('posUuidV4', () {
    test('is a v4 UUID with the correct version and variant nibbles', () {
      // Matches Zod v4's strict UUID pattern used by the server on client_sale_id.
      final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (var i = 0; i < 200; i++) {
        expect(re.hasMatch(posUuidV4()), isTrue);
      }
    });
  });
}
