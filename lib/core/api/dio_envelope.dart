import 'package:dio/dio.dart';

import 'api_response.dart';

Map<String, dynamic>? asObjectMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return null;
}

/// Runs a GET and always returns an [ApiResponse], even when Dio would throw
/// on 4xx/5xx (so callers never see a raw [DioException]).
Future<ApiResponse<dynamic>> dioGetEnvelope(
  Dio dio,
  String path, {
  Map<String, dynamic>? queryParameters,
}) async {
  try {
    final response = await dio.get(path, queryParameters: queryParameters);
    final map = asObjectMap(response.data);
    if (map == null) {
      return const ApiResponse(
        success: false,
        error: ApiError(code: 'INVALID', message: 'Invalid server response'),
      );
    }
    return ApiResponse.fromJson(map, (json) => json);
  } on DioException catch (e) {
    final errMap = asObjectMap(e.response?.data);
    if (errMap != null) {
      return ApiResponse.fromJson(errMap, (json) => json);
    }
    return ApiResponse(
      success: false,
      error: ApiError(
        code: dioErrorCode(e),
        message: dioUserMessage(e),
      ),
    );
  }
}

String dioErrorCode(DioException e) {
  final code = e.response?.statusCode;
  if (code != null) return 'HTTP_$code';
  return 'NETWORK_ERROR';
}

/// User-facing copy for failed HTTP calls (never the full DioException dump).
String dioUserMessage(DioException e, {String? fallback}) {
  final errMap = asObjectMap(e.response?.data);
  if (errMap != null) {
    final err = errMap['error'];
    if (err is Map) {
      final msg = err['message'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString().trim();
      }
    }
  }

  final code = e.response?.statusCode;
  if (code == 500) {
    return fallback ??
        'Our servers could not complete this request. Please try again shortly.';
  }
  if (code == 401 || code == 403) {
    return 'Your session may have expired. Please sign in again.';
  }
  if (code == 404) {
    return fallback ?? 'This feature is not available on the server yet.';
  }
  if (code != null) {
    return '${fallback ?? 'Request failed'} (HTTP $code).';
  }
  return fallback ?? (e.message ?? 'Network error. Check your connection.');
}
