import 'package:dukanest_app/features/analytics/models/expense_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpenseCategory parsers', () {
    test('parseExpenseCategoryList from categories array', () {
      final list = parseExpenseCategoryList({
        'categories': [
          {
            'id': '1',
            'tenant_id': 't1',
            'name': 'Fuel',
            'slug': 'fuel',
            'is_default': true,
          },
          {
            'id': '2',
            'tenant_id': 't1',
            'name': 'Custom',
            'slug': 'custom',
            'is_default': false,
          },
        ],
      });

      expect(list, hasLength(2));
      expect(list.first.name, 'Fuel');
      expect(list.first.isDefault, isTrue);
      expect(list.last.label, 'Custom');
    });

    test('parseExpenseCategoryFromCreateResponse unwraps category', () {
      final created = parseExpenseCategoryFromCreateResponse({
        'category': {
          'id': 'uuid',
          'name': 'Ads',
          'slug': 'ads',
        },
      });

      expect(created?.id, 'uuid');
      expect(created?.name, 'Ads');
    });

    test('expenseCategoryLabelFromExpense prefers category_details', () {
      final label = expenseCategoryLabelFromExpense({
        'category_details': {'name': 'Fuel'},
        'category': 'legacy-slug',
      });

      expect(label, 'Fuel');
    });
  });
}
