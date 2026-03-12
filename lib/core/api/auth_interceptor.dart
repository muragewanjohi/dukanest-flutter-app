import 'package:dio/dio.dart';
import '../auth/token_storage.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage tokenStorage;
  final Dio dio;

  AuthInterceptor(this.tokenStorage, this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final accessToken = await tokenStorage.getAccessToken();
    
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // NOTE: We will hook up the refresh token flow here later
      // The implementation will use TokenStorage to read the refresh token,
      // request a new access token, update the storage, and retry the request.
    }
    return handler.next(err);
  }
}
