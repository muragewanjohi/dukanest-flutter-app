import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_response.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(dioProvider));
});

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  static Map<String, dynamic>? _asObjectMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static ApiResponse<Map<String, dynamic>> _invalidEnvelope() {
    return ApiResponse(
      success: false,
      error: ApiError(
        code: 'INVALID_RESPONSE',
        message: 'Unexpected response from server',
      ),
    );
  }

  /// `GET /auth/me` — session restore (see API_MULTI_STORE_CHANGES / flutter_apis.md).
  Future<ApiResponse<Map<String, dynamic>>> getAuthMe() async {
    try {
      final response = await _dio.get('/auth/me');
      final map = _asObjectMap(response.data);
      if (map == null) return _invalidEnvelope();
      return ApiResponse.fromJson(
        map,
        (json) => json as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final errMap = _asObjectMap(e.response?.data);
      if (errMap != null) {
        return ApiResponse.fromJson(
            errMap, (json) => json as Map<String, dynamic>);
      }
      return ApiResponse(
        success: false,
        error: ApiError(
            code: 'NETWORK_ERROR', message: e.message ?? 'Network error'),
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> login(
      String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final map = _asObjectMap(response.data);
      if (map == null) return _invalidEnvelope();
      return ApiResponse.fromJson(map, (json) => json as Map<String, dynamic>);
    } on DioException catch (e) {
      final errMap = _asObjectMap(e.response?.data);
      if (errMap != null) {
        return ApiResponse.fromJson(
            errMap, (json) => json as Map<String, dynamic>);
      }
      return ApiResponse(
          success: false,
          error: ApiError(
              code: 'NETWORK_ERROR', message: e.message ?? 'Network error'));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> verifyMfa({
    required String userId,
    required String code,
    required String tempAccessToken,
    required String tempRefreshToken,
  }) async {
    try {
      final response = await _dio.post('/auth/mfa/verify', data: {
        'userId': userId,
        'code': code,
        'tempSession': {
          'accessToken': tempAccessToken,
          'refreshToken': tempRefreshToken,
        },
      });
      final map = _asObjectMap(response.data);
      if (map == null) return _invalidEnvelope();
      return ApiResponse.fromJson(
        map,
        (json) => json as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final errMap = _asObjectMap(e.response?.data);
      if (errMap != null) {
        return ApiResponse.fromJson(
          errMap,
          (json) => json as Map<String, dynamic>,
        );
      }
      return ApiResponse(
        success: false,
        error: ApiError(
            code: 'NETWORK_ERROR', message: e.message ?? 'Network error'),
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> sendMfaCode(
    String userId, {
    String? channel,
    List<String>? channels,
    String? phone,
  }) async {
    try {
      final payload = <String, dynamic>{
        'userId': userId,
      };
      if (channel != null && channel.trim().isNotEmpty) {
        payload['channel'] = channel.trim();
      }
      if (channels != null && channels.isNotEmpty) {
        payload['channels'] = channels;
      }
      if (phone != null && phone.trim().isNotEmpty) {
        payload['phone'] = phone.trim();
      }
      final response = await _dio.post('/auth/mfa/send-code', data: payload);
      final map = _asObjectMap(response.data);
      if (map == null) return _invalidEnvelope();
      return ApiResponse.fromJson(
        map,
        (json) => json as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final errMap = _asObjectMap(e.response?.data);
      if (errMap != null) {
        return ApiResponse.fromJson(
          errMap,
          (json) => json as Map<String, dynamic>,
        );
      }
      return ApiResponse(
        success: false,
        error: ApiError(
            code: 'NETWORK_ERROR', message: e.message ?? 'Network error'),
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> requestPasswordReset(
    String email,
  ) async {
    try {
      final response = await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });
      final map = _asObjectMap(response.data);
      if (map == null) return _invalidEnvelope();
      return ApiResponse.fromJson(
        map,
        (json) => json as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final errMap = _asObjectMap(e.response?.data);
      if (errMap != null) {
        return ApiResponse.fromJson(
          errMap,
          (json) => json as Map<String, dynamic>,
        );
      }
      return ApiResponse(
        success: false,
        error: ApiError(
          code: 'NETWORK_ERROR',
          message: e.message ?? 'Network error',
        ),
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> googleSignIn(
    String? idToken, {
    String? accessToken,
  }) async {
    if ((idToken == null || idToken.isEmpty) &&
        (accessToken == null || accessToken.isEmpty)) {
      return ApiResponse(
        success: false,
        error: ApiError(
          code: 'MISSING_GOOGLE_TOKEN',
          message: 'Missing Google sign-in token',
        ),
      );
    }
    try {
      final response = await _dio.post(
        '/auth/google',
        data: {
          if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
          if (accessToken != null && accessToken.isNotEmpty)
            'accessToken': accessToken,
        },
      );
      final map = _asObjectMap(response.data);
      if (map == null) return _invalidEnvelope();
      return ApiResponse.fromJson(map, (json) => json as Map<String, dynamic>);
    } on DioException catch (e) {
      final errMap = _asObjectMap(e.response?.data);
      if (errMap != null) {
        return ApiResponse.fromJson(
            errMap, (json) => json as Map<String, dynamic>);
      }
      return ApiResponse(
          success: false,
          error: ApiError(
              code: 'NETWORK_ERROR', message: e.message ?? 'Network error'));
    }
  }

  Future<ApiResponse<void>> logout() async {
    try {
      await _dio.post('/auth/logout');
      return ApiResponse(success: true);
    } catch (_) {
      return ApiResponse(success: true); // Graceful fallback
    }
  }
}
