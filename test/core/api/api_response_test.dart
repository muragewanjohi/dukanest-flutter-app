import 'package:dukanest_app/core/api/api_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiResponse.fromJson', () {
    test('parses a success envelope with passthrough data', () {
      final res = ApiResponse<dynamic>.fromJson({
        'success': true,
        'data': {'items': []},
      }, (json) => json);
      expect(res.success, isTrue);
      expect(res.error, isNull);
      expect(res.data, isA<Map>());
    });

    test('parses an error envelope', () {
      final res = ApiResponse<dynamic>.fromJson({
        'success': false,
        'error': {'code': 'BAD_REQUEST', 'message': 'Nope'},
      }, (json) => json);
      expect(res.success, isFalse);
      expect(res.error, isNotNull);
      expect(res.error!.code, 'BAD_REQUEST');
      expect(res.error!.message, 'Nope');
    });

    test('parses pagination metadata', () {
      final res = ApiResponse<dynamic>.fromJson({
        'success': true,
        'data': [],
        'pagination': {
          'page': 2,
          'limit': 20,
          'total': 45,
          'totalPages': 3,
        },
      }, (json) => json);
      expect(res.pagination, isNotNull);
      expect(res.pagination!.page, 2);
      expect(res.pagination!.total, 45);
      expect(res.pagination!.totalPages, 3);
    });
  });
}
