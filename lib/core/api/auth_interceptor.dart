import 'package:dio/dio.dart';
import 'dart:async';
import '../auth/token_storage.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage tokenStorage;
  final Dio dio;
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

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
    final response = err.response;
    
    // Trap Unauthorized responses automatically
    if (response?.statusCode == 401) {
      final path = err.requestOptions.path;
      // Prevent recursive cycles if the refresh routing or login are fundamentally expired
      if (path.contains('/auth/refresh') || path.contains('/auth/login')) {
        return handler.next(err);
      }

      if (_isRefreshing) {
        final completer = _refreshCompleter;
        if (completer != null) {
          await completer.future;
          final latestAccessToken = await tokenStorage.getAccessToken();
          if (latestAccessToken != null) {
            final retryOptions = err.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $latestAccessToken';
            final retryResponse = await dio.fetch(retryOptions);
            return handler.resolve(retryResponse);
          }
        }
        return handler.next(err);
      }
      
      _isRefreshing = true;
      _refreshCompleter = Completer<void>();
      try {
        final refreshToken = await tokenStorage.getRefreshToken();
        if (refreshToken == null) {
          throw err;
        }

        // Boot up a virgin Dio client void of Auth Interceptors tracking the fallback endpoint
        final refreshDio = Dio(dio.options);
        final refreshResult = await refreshDio.post('/auth/refresh', data: {
          'refresh_token': refreshToken,
        });

        if (refreshResult.data != null && refreshResult.data['success'] == true) {
          final dataMap = refreshResult.data['data'] as Map<String, dynamic>?;
          final sessionRaw = dataMap?['session'];
          final session = sessionRaw is Map<String, dynamic>
              ? sessionRaw
              : dataMap;
          if (session != null) {
            final newToken = session['access_token'] ?? session['accessToken'];
            final newRefresh = session['refresh_token'] ?? session['refreshToken'];
            
            if (newToken != null && newRefresh != null) {
              await tokenStorage.saveTokens(
                accessToken: newToken, 
                refreshToken: newRefresh
              );
              
              // Rewrite the original header map and reissue
              final retryOptions = err.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $newToken';
              
              final retryResponse = await dio.fetch(retryOptions);
              _refreshCompleter?.complete();
              _refreshCompleter = null;
              _isRefreshing = false;
              return handler.resolve(retryResponse);
            }
          }
        }
      } catch (e) {
        // If the refresh protocol ultimately crashes, defensively scrub the credentials forcing a hard relogin
        await tokenStorage.clearTokens();
      } finally {
        if (!(_refreshCompleter?.isCompleted ?? true)) {
          _refreshCompleter?.complete();
        }
        _refreshCompleter = null;
        _isRefreshing = false;
      }
    }
    return handler.next(err);
  }
}
