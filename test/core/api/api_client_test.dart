import 'package:dukanest_app/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_dio.dart';

void main() {
  group('ApiClient with a mocked Dio', () {
    test('getThemes returns the parsed success envelope', () async {
      final (dio, adapter) = buildMockDio();
      adapter.onGet(
        '/dashboard/themes',
        (server) => server.reply(200, {
          'success': true,
          'data': {
            'items': [
              {'id': 't1', 'name': 'Aurora'},
            ],
          },
        }),
        queryParameters: {},
      );

      final api = ApiClient(dio);
      final res = await api.getThemes();

      expect(res.success, isTrue);
      final data = res.data as Map;
      expect((data['items'] as List).first['name'], 'Aurora');
    });

    test('getMedia surfaces an error envelope without throwing', () async {
      final (dio, adapter) = buildMockDio();
      adapter.onGet(
        '/dashboard/media',
        (server) => server.reply(200, {
          'success': false,
          'error': {'code': 'FORBIDDEN', 'message': 'No access'},
        }),
        queryParameters: {'limit': 50, 'offset': 0},
      );

      final api = ApiClient(dio);
      final res = await api.getMedia();

      expect(res.success, isFalse);
      expect(res.error?.code, 'FORBIDDEN');
    });

    test('getDashboardReferrals returns parsed success envelope', () async {
      final (dio, adapter) = buildMockDio();
      adapter.onGet(
        '/dashboard/referrals',
        (server) => server.reply(200, {
          'success': true,
          'data': {
            'shareSubdomain': 'demo-shop',
            'referralLink': 'https://www.dukanest.com/ref/demo-shop',
            'referralCount': 4,
            'rewardedMonths': 1,
          },
        }),
      );

      final api = ApiClient(dio);
      final res = await api.getDashboardReferrals();

      expect(res.success, isTrue);
      final data = res.data as Map;
      expect(data['shareSubdomain'], 'demo-shop');
      expect(data['referralCount'], 4);
    });

    test('login posts credentials and parses the response', () async {
      final (dio, adapter) = buildMockDio();
      adapter.onPost(
        '/auth/login',
        (server) => server.reply(200, {
          'success': true,
          'data': {'token': 'abc123'},
        }),
        data: {'email': 'a@b.com', 'password': 'secret'},
      );

      final api = ApiClient(dio);
      final res = await api.login('a@b.com', 'secret');

      expect(res.success, isTrue);
      expect((res.data as Map)['token'], 'abc123');
    });
  });
}
