import 'package:dio/dio.dart';
import 'package:dukanest_app/core/api/dio_envelope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../helpers/test_dio.dart';

void main() {
  group('dioUserMessage', () {
    test('returns server error message from JSON envelope', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 500,
          data: {
            'success': false,
            'error': {'code': 'INTERNAL', 'message': 'Plan lookup failed'},
          },
        ),
        type: DioExceptionType.badResponse,
      );
      expect(dioUserMessage(e), 'Plan lookup failed');
    });

    test('returns friendly copy for bare 500', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      );
      expect(
        dioUserMessage(e, fallback: 'Could not load subscription.'),
        contains('Could not load subscription'),
      );
    });
  });

  group('dioGetEnvelope', () {
    test('returns parsed error envelope instead of throwing on 500', () async {
      final (dio, adapter) = buildMockDio();
      adapter.onGet(
        '/dashboard/subscription',
        (server) => server.reply(500, {
          'success': false,
          'error': {'code': 'INTERNAL', 'message': 'DB timeout'},
        }),
      );

      final res = await dioGetEnvelope(dio, '/dashboard/subscription');
      expect(res.success, isFalse);
      expect(res.error?.message, 'DB timeout');
    });
  });
}
