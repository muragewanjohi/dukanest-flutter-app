import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/token_storage.dart';
import 'auth_interceptor.dart';

// Provider for TokenStorage
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

// Provider for generalized Dio client
final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:3000/api/v1/mobile', // Use localhost emulator alias by default
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(AuthInterceptor(tokenStorage, dio));
  
  // Add logging interceptor for debugging
  dio.interceptors.add(LogInterceptor(
    request: true,
    requestHeader: true,
    requestBody: true,
    responseHeader: true,
    responseBody: true,
    error: true,
  ));

  return dio;
});
