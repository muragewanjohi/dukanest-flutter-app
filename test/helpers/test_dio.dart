import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Builds a [Dio] instance whose requests are intercepted by [DioAdapter] so
/// tests can return canned responses without hitting the network.
///
/// Usage:
/// ```dart
/// final (dio, adapter) = buildMockDio();
/// adapter.onGet('/dashboard/themes', (s) => s.reply(200, {...}));
/// ```
(Dio, DioAdapter) buildMockDio({String baseUrl = 'https://test.local'}) {
  final dio =
      Dio(BaseOptions(baseUrl: baseUrl, contentType: 'application/json'));
  final adapter = DioAdapter(dio: dio);
  dio.httpClientAdapter = adapter;
  return (dio, adapter);
}
