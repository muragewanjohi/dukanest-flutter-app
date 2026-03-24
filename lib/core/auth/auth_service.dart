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

  Future<ApiResponse<Map<String, dynamic>>> verifyMfa(String code) async {
    try {
      final response = await _dio.post('/auth/mfa/verify', data: {
        'code': code,
      });
      return ApiResponse.fromJson(response.data, (json) => json as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response != null) {
         return ApiResponse.fromJson(e.response!.data as Map<String, dynamic>, (json) => json as Map<String, dynamic>);
      }
      return ApiResponse(success: false, error: ApiError(code: 'NETWORK_ERROR', message: e.message ?? 'Network error'));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> googleSignIn(String idToken) async {
    try {
      final response = await _dio.post('/auth/google', data: {
        'idToken': idToken,
      });
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
