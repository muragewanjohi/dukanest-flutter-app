import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';
import '../auth/token_storage.dart';
import 'auth_interceptor.dart';
import 'api_response.dart';

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(AuthInterceptor(tokenStorage, dio));
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Future<ApiResponse<dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/auth/register', data: data);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getAuthMe() async {
    final response = await _dio.get('/auth/me');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getProducts({
    int page = 1,
    int limit = 20,
    String search = '',
    String? status,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final response = await _dio.get('/dashboard/products', queryParameters: query);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getOrders({
    int page = 1,
    int limit = 20,
    String search = '',
    String? status,
    String? paymentStatus,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      if (paymentStatus != null && paymentStatus.isNotEmpty) 'payment_status': paymentStatus,
    };
    final response = await _dio.get('/dashboard/orders', queryParameters: query);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDashboardOverview() async {
    final response = await _dio.get('/dashboard/overview');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getGettingStarted() async {
    final response = await _dio.get('/dashboard/getting-started');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> postGettingStartedAction(String action) async {
    final response = await _dio.post('/dashboard/getting-started', data: {'action': action});
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDashboardAnalytics({int days = 30}) async {
    final response = await _dio.get(
      '/dashboard/analytics',
      queryParameters: {'days': days.clamp(1, 365)},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getOrderDetail(String orderId) async {
    final response = await _dio.get('/dashboard/orders/$orderId');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> patchOrder(String orderId, Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/orders/$orderId', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getProductDetail(String productId) async {
    final response = await _dio.get('/dashboard/products/$productId');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createProduct(Map<String, dynamic> input) async {
    final response = await _dio.post('/dashboard/products', data: input);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateProduct(String productId, Map<String, dynamic> input) async {
    final response = await _dio.put('/dashboard/products/$productId', data: input);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteProduct(String productId) async {
    final response = await _dio.delete('/dashboard/products/$productId');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getCustomers({
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    final response = await _dio.get(
      '/dashboard/customers',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getCustomerDetail(String id) async {
    final response = await _dio.get('/dashboard/customers/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getCategories({
    String? parentId,
    String? status,
    bool includeChildren = false,
  }) async {
    final query = <String, dynamic>{
      if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (includeChildren) 'include_children': 'true',
    };
    final response = await _dio.get('/dashboard/categories', queryParameters: query);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getCategory(String id) async {
    final response = await _dio.get('/dashboard/categories/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createCategory(Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/categories', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateCategory(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/categories/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteCategory(String id) async {
    final response = await _dio.delete('/dashboard/categories/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDashboardSettings() async {
    final response = await _dio.get('/dashboard/settings');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> patchDashboardSettings(Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/settings', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDeliveryZones() async {
    final response = await _dio.get('/dashboard/delivery-zones');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createDeliveryZone(Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/delivery-zones', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateDeliveryZone(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/delivery-zones/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteDeliveryZone(String id) async {
    final response = await _dio.delete('/dashboard/delivery-zones/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  /// StoreFlow mobile: `GET /notifications/list` (see Postman).
  Future<ApiResponse<dynamic>> getNotifications() async {
    final response = await _dio.get('/notifications/list');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> registerDeviceToken({
    required String token,
    required String platform,
    required String deviceId,
    String? appVersion,
    String? deviceName,
  }) async {
    final response = await _dio.post(
      '/notifications/register-device',
      data: {
        'token': token,
        'platform': platform,
        'deviceId': deviceId,
        if (appVersion != null) 'appVersion': appVersion,
        if (deviceName != null) 'deviceName': deviceName,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> uploadMedia(FormData formData) async {
    final response = await _dio.post('/media/upload', data: formData);
    return ApiResponse.fromJson(response.data, (json) => json);
  }
}
