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

  /// `GET /auth/me` — session restore (see API_MULTI_STORE_CHANGES / flutter_apis.md).
  Future<ApiResponse<Map<String, dynamic>>> getAuthMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final raw = e.response!.data;
        if (raw is Map<String, dynamic>) {
          return ApiResponse.fromJson(raw, (json) => json as Map<String, dynamic>);
        }
      }
      return ApiResponse(
        success: false,
        error: ApiError(code: 'NETWORK_ERROR', message: e.message ?? 'Network error'),
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return ApiResponse.fromJson(response.data, (json) => json as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response != null) {
        return ApiResponse.fromJson(e.response!.data as Map<String, dynamic>, (json) => json as Map<String, dynamic>);
      }
      return ApiResponse(success: false, error: ApiError(code: 'NETWORK_ERROR', message: e.message ?? 'Network error'));
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
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return ApiResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
          (json) => json as Map<String, dynamic>,
        );
      }
      return ApiResponse(
        success: false,
        error: ApiError(code: 'NETWORK_ERROR', message: e.message ?? 'Network error'),
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> sendMfaCode(String userId) async {
    try {
      final response = await _dio.post('/auth/mfa/send-code', data: {
        'userId': userId,
      });
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return ApiResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
          (json) => json as Map<String, dynamic>,
        );
      }
      return ApiResponse(
        success: false,
        error: ApiError(code: 'NETWORK_ERROR', message: e.message ?? 'Network error'),
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
      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return ApiResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
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
    String idToken, {
    String? accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/google',
        data: {
          'idToken': idToken,
          if (accessToken != null && accessToken.isNotEmpty) 'accessToken': accessToken,
        },
      );
      return ApiResponse.fromJson(response.data, (json) => json as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response != null) {
        return ApiResponse.fromJson(e.response!.data as Map<String, dynamic>, (json) => json as Map<String, dynamic>);
      }
      return ApiResponse(success: false, error: ApiError(code: 'NETWORK_ERROR', message: e.message ?? 'Network error'));
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
