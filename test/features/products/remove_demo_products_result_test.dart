import 'package:dukanest_app/features/products/models/remove_demo_products_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoveDemoProductsResult', () {
    test('tryParse unwraps data envelope', () {
      final result = RemoveDemoProductsResult.tryParse({
        'success': true,
        'data': {
          'matchedCount': 10,
          'deletedCount': 8,
          'archivedCount': 2,
          'removedCount': 10,
          'message': 'Demo products removed successfully',
        },
      });

      expect(result?.matchedCount, 10);
      expect(result?.deletedCount, 8);
      expect(result?.archivedCount, 2);
      expect(result?.removedCount, 10);
    });

    test('successSnackBarMessage includes archived count', () {
      const result = RemoveDemoProductsResult(
        matchedCount: 5,
        deletedCount: 3,
        archivedCount: 2,
        removedCount: 5,
      );

      expect(
        result.successSnackBarMessage,
        'Removed 3 demo products and archived 2 used in orders.',
      );
    });

    test('successSnackBarMessage for delete-only cleanup', () {
      const result = RemoveDemoProductsResult(
        matchedCount: 4,
        deletedCount: 4,
        archivedCount: 0,
        removedCount: 4,
      );

      expect(result.successSnackBarMessage, 'Removed 4 demo products.');
    });
  });
}
