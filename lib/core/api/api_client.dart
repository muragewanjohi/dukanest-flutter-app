import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';
import '../auth/token_storage.dart';
import 'auth_interceptor.dart';
import 'api_response.dart';
import 'dio_envelope.dart';

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
        // Never print auth headers, request bodies, or response bodies. Debug
        // consoles are easy to share and previously exposed bearer tokens.
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
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
    final response =
        await _dio.get('/dashboard/products', queryParameters: query);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getOrders({
    int page = 1,
    int limit = 20,
    String search = '',
    String? status,
    String? paymentStatus,
  }) async {
    final normalizedStatus = (status ?? '').trim().toLowerCase();
    final normalizedPayment = (paymentStatus ?? '').trim().toLowerCase();
    final effectivePaymentStatus = normalizedPayment.isNotEmpty
        ? normalizedPayment
        : (normalizedStatus == 'paid' ? 'paid' : '');
    final effectiveStatus = normalizedStatus == 'paid' ? '' : normalizedStatus;

    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'search': search,
      if (effectiveStatus.isNotEmpty) 'status': effectiveStatus,
      if (effectivePaymentStatus.isNotEmpty)
        'payment_status': effectivePaymentStatus,
    };
    final response =
        await _dio.get('/dashboard/orders', queryParameters: query);
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
    final response =
        await _dio.post('/dashboard/getting-started', data: {'action': action});
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDashboardAnalytics({int days = 30}) async {
    final response = await _dio.get(
      '/dashboard/analytics',
      queryParameters: {'days': days.clamp(1, 365)},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDashboardPnl({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String formatDate(DateTime date) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final response = await _dio.get(
      '/dashboard/analytics/pnl',
      queryParameters: {
        if (startDate != null) 'start_date': formatDate(startDate),
        if (endDate != null) 'end_date': formatDate(endDate),
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getExpenses({
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
    String? categoryId,
  }) async {
    final response = await _dio.get(
      '/dashboard/expenses',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createExpense(Map<String, dynamic> input) async {
    final response = await _dio.post('/dashboard/expenses', data: input);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateExpense(
    String id,
    Map<String, dynamic> input,
  ) async {
    final response = await _dio.patch('/dashboard/expenses/$id', data: input);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteExpense(String id) async {
    final response = await _dio.delete('/dashboard/expenses/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getOrderDetail(String orderId) async {
    final response = await _dio.get('/dashboard/orders/$orderId');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> patchOrder(
      String orderId, Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/orders/$orderId', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> cancelOrder(
    String orderId, {
    required String reason,
    bool refund = false,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/dashboard/orders/$orderId/cancel',
      data: {
        'reason': reason,
        if (refund) 'refund': true,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
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

  Future<ApiResponse<dynamic>> updateProduct(
      String productId, Map<String, dynamic> input) async {
    final response =
        await _dio.put('/dashboard/products/$productId', data: input);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteProduct(String productId) async {
    final response = await _dio.delete('/dashboard/products/$productId');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> removeDemoProducts() async {
    final response = await _dio.delete('/dashboard/products/demo');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getProductVariants(String productId) async {
    final response = await _dio.get('/dashboard/products/$productId/variants');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createProductVariant(
    String productId,
    Map<String, dynamic> body,
  ) async {
    final response =
        await _dio.post('/dashboard/products/$productId/variants', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateProductVariant(
    String productId,
    String variantId,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio
        .put('/dashboard/products/$productId/variants/$variantId', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteProductVariant(
    String productId,
    String variantId,
  ) async {
    final response =
        await _dio.delete('/dashboard/products/$productId/variants/$variantId');
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
    final response =
        await _dio.get('/dashboard/categories', queryParameters: query);
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

  Future<ApiResponse<dynamic>> updateCategory(
      String id, Map<String, dynamic> body) async {
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

  Future<ApiResponse<dynamic>> patchDashboardSettings(
      Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/settings', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getTumiziSettings() async {
    final response = await _dio.get('/dashboard/tumizi/settings');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> postTumiziSettings(
      Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/tumizi/settings', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getTumiziMerchant() async {
    final response = await _dio.get('/dashboard/tumizi/merchant');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> patchTumiziMerchant(
      Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/tumizi/merchant', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getTumiziWallet() async {
    final response = await _dio.get('/dashboard/tumizi/wallet');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> postTumiziWalletWithdrawal(
      Map<String, dynamic> body) async {
    final response =
        await _dio.post('/dashboard/tumizi/wallet/withdrawals', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getTumiziRefunds() async {
    final response = await _dio.get('/dashboard/tumizi/refunds');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDeliveryZones() async {
    final response = await _dio.get('/dashboard/delivery-zones');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createDeliveryZone(
      Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/delivery-zones', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateDeliveryZone(
      String id, Map<String, dynamic> body) async {
    final response =
        await _dio.patch('/dashboard/delivery-zones/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteDeliveryZone(String id) async {
    final response = await _dio.delete('/dashboard/delivery-zones/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  /// StoreFlow mobile: `GET /notifications/list` (see Postman).
  Future<ApiResponse<dynamic>> getNotifications() async {
    try {
      final response = await _dio.get('/notifications');
      return ApiResponse.fromJson(response.data, (json) => json);
    } on DioException catch (e) {
      // Backward compatibility for deployments still exposing /notifications/list.
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
      final fallback = await _dio.get('/notifications/list');
      return ApiResponse.fromJson(fallback.data, (json) => json);
    }
  }

  Future<ApiResponse<dynamic>> getNotificationPreferences() async {
    final response = await _dio.get('/notifications/preferences');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateNotificationPreferences(
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.put('/notifications/preferences', data: body);
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

  Future<ApiResponse<dynamic>> uploadMedia(
    FormData formData, {
    ProgressCallback? onSendProgress,
  }) async {
    final response = await _dio.post(
      '/media/upload',
      data: formData,
      onSendProgress: onSendProgress,
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> postDeleteAccount(
      Map<String, dynamic> body) async {
    final response =
        await _dio.post('/dashboard/settings/delete-account', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDashboardAttributes() async {
    final response = await _dio.get('/dashboard/attributes');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getDashboardAttribute(String id) async {
    final response = await _dio.get('/dashboard/attributes/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createDashboardAttribute(
      Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/attributes', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateDashboardAttribute(
      String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/attributes/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteDashboardAttribute(String id) async {
    final response = await _dio.delete('/dashboard/attributes/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createAttributeValue(
      String attributeId, Map<String, dynamic> body) async {
    final response = await _dio
        .post('/dashboard/attributes/$attributeId/values', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateAttributeValue(
    String attributeId,
    String valueId,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch(
        '/dashboard/attributes/$attributeId/values/$valueId',
        data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteAttributeValue(
      String attributeId, String valueId) async {
    final response =
        await _dio.delete('/dashboard/attributes/$attributeId/values/$valueId');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getBlogs({
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    final response = await _dio.get(
      '/dashboard/blogs',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getBlog(String id) async {
    final response = await _dio.get('/dashboard/blogs/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createBlog(Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/blogs', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateBlog(
      String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/blogs/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteBlog(String id) async {
    final response = await _dio.delete('/dashboard/blogs/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getPages({
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    final response = await _dio.get(
      '/dashboard/pages',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getPage(String id) async {
    final response = await _dio.get('/dashboard/pages/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updatePage(
      String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/pages/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getSales({
    int page = 1,
    int limit = 20,
    String search = '',
    String? status,
  }) async {
    final response = await _dio.get(
      '/dashboard/sales',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getSale(String id) async {
    final response = await _dio.get('/dashboard/sales/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createSale(Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/sales', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateSale(
      String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/sales/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteSale(String id) async {
    final response = await _dio.delete('/dashboard/sales/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getInventory({
    int page = 1,
    int limit = 20,
    String search = '',
    bool lowStockOnly = false,
  }) async {
    final response = await _dio.get(
      '/dashboard/inventory',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
        if (lowStockOnly) 'low_stock_only': 'true',
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Orders: Tumizi payment sync ---

  Future<ApiResponse<dynamic>> syncTumiziOrderPayment(String orderId) async {
    final response =
        await _dio.get('/dashboard/orders/$orderId/tumizi/sync-payment');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> initiateTumiziOrderPayment(
    String orderId, {
    required String phoneNumber,
    num? amount,
    String? narration,
  }) async {
    final response = await _dio.post(
      '/dashboard/orders/$orderId/tumizi/initiate-payment',
      data: {
        'phoneNumber': phoneNumber,
        if (amount != null) 'amount': amount,
        if (narration != null && narration.trim().isNotEmpty)
          'narration': narration.trim(),
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Subscription & billing ---

  Future<ApiResponse<dynamic>> getSubscription() async {
    return dioGetEnvelope(_dio, '/dashboard/subscription');
  }

  Future<ApiResponse<dynamic>> getSubscriptionBilling() async {
    final response = await _dio.get('/dashboard/subscription/billing');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> activateSubscription(
      Map<String, dynamic> body) async {
    final response =
        await _dio.post('/dashboard/subscription/activate', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> initiateSubscriptionMpesa(
      Map<String, dynamic> body) async {
    final response =
        await _dio.post('/dashboard/subscription/mpesa/initiate', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getSubscriptionMpesaStatus(
      String checkoutRequestId) async {
    final response = await _dio.get(
      '/dashboard/subscription/mpesa/status',
      queryParameters: {'checkoutRequestId': checkoutRequestId},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getPesapalConfig() async {
    return dioGetEnvelope(_dio, '/dashboard/subscription/pesapal/config');
  }

  Future<ApiResponse<dynamic>> initiatePesapalCheckout(
      Map<String, dynamic> body) async {
    final response =
        await _dio.post('/dashboard/subscription/pesapal/initiate', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Dashboard reward checklist ---

  Future<ApiResponse<dynamic>> getRewardChecklist() async {
    return dioGetEnvelope(_dio, '/dashboard/reward-checklist');
  }

  // --- Customers ---

  Future<ApiResponse<dynamic>> updateCustomer(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch('/dashboard/customers/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteCustomer(String id) async {
    final response = await _dio.delete('/dashboard/customers/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<Response<dynamic>> exportCustomers({
    String search = '',
    String email = '',
    String format = 'csv',
  }) async {
    return _dio.get(
      '/dashboard/customers/export',
      queryParameters: {
        if (search.isNotEmpty) 'search': search,
        if (email.isNotEmpty) 'email': email,
        'format': format,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  // --- Inventory mutations ---

  Future<ApiResponse<dynamic>> adjustInventory(
      Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/inventory/adjust', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> bulkAdjustInventory(
      Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/inventory/bulk', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getInventoryHistory({
    int page = 1,
    int limit = 20,
    String? productId,
    String? variantId,
    String? adjustmentType,
  }) async {
    final response = await _dio.get(
      '/dashboard/inventory/history',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (productId != null && productId.isNotEmpty) 'productId': productId,
        if (variantId != null && variantId.isNotEmpty) 'variantId': variantId,
        if (adjustmentType != null && adjustmentType.isNotEmpty)
          'adjustmentType': adjustmentType,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getInventorySettings() async {
    final response = await _dio.get('/dashboard/inventory/settings');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateInventorySettings(
      Map<String, dynamic> body) async {
    final response =
        await _dio.put('/dashboard/inventory/settings', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getInventoryAlerts() async {
    final response = await _dio.get('/dashboard/inventory/alerts');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Sales product assignments ---

  Future<ApiResponse<dynamic>> getSaleProducts(String saleId) async {
    final response = await _dio.get('/dashboard/sales/$saleId/products');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> addSaleProduct(
    String saleId,
    Map<String, dynamic> body,
  ) async {
    final response =
        await _dio.post('/dashboard/sales/$saleId/products', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateSaleProduct(
    String saleId,
    Map<String, dynamic> body,
  ) async {
    final response =
        await _dio.patch('/dashboard/sales/$saleId/products', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> removeSaleProduct(
    String saleId,
    String productId,
  ) async {
    final response = await _dio.delete(
      '/dashboard/sales/$saleId/products',
      queryParameters: {'productId': productId},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Expense categories ---

  Future<ApiResponse<dynamic>> getExpenseCategories() async {
    final response = await _dio.get('/dashboard/expense-categories');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getExpenseCategory(String id) async {
    final response = await _dio.get('/dashboard/expense-categories/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createExpenseCategory(
      Map<String, dynamic> body) async {
    final response =
        await _dio.post('/dashboard/expense-categories', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateExpenseCategory(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response =
        await _dio.patch('/dashboard/expense-categories/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteExpenseCategory(String id) async {
    final response = await _dio.delete('/dashboard/expense-categories/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Blog categories ---

  Future<ApiResponse<dynamic>> getBlogCategories() async {
    final response = await _dio.get('/dashboard/blogs/categories');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createBlogCategory(
      Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/blogs/categories', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getBlogCategory(String id) async {
    final response = await _dio.get('/dashboard/blogs/categories/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateBlogCategory(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response =
        await _dio.patch('/dashboard/blogs/categories/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteBlogCategory(String id) async {
    final response = await _dio.delete('/dashboard/blogs/categories/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Pages ---

  Future<ApiResponse<dynamic>> createPage(Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/pages', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deletePage(String id) async {
    final response = await _dio.delete('/dashboard/pages/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Media library ---

  Future<ApiResponse<dynamic>> getMedia({
    int limit = 50,
    int offset = 0,
    String search = '',
    bool sync = false,
  }) async {
    final response = await _dio.get(
      '/dashboard/media',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (search.isNotEmpty) 'search': search,
        if (sync) 'sync': 'true',
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateMedia(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch('/dashboard/media/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteMedia(String id) async {
    final response = await _dio.delete('/dashboard/media/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Forms ---

  Future<ApiResponse<dynamic>> getForms({
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    final response = await _dio.get(
      '/dashboard/forms',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createForm(Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/forms', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getForm(String id) async {
    final response = await _dio.get('/dashboard/forms/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateForm(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch('/dashboard/forms/$id', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteForm(String id) async {
    final response = await _dio.delete('/dashboard/forms/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getFormSubmissions(
    String formId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/dashboard/forms/$formId/submissions',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Themes ---

  Future<ApiResponse<dynamic>> getThemes({
    String? status,
    bool? isPremium,
  }) async {
    final response = await _dio.get(
      '/dashboard/themes',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (isPremium != null) 'is_premium': isPremium.toString(),
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getCurrentTheme() async {
    final response = await _dio.get('/dashboard/themes/current');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> updateCurrentTheme(
      Map<String, dynamic> body) async {
    final response = await _dio.patch('/dashboard/themes/current', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getInstalledThemes() async {
    final response = await _dio.get('/dashboard/themes/installed');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getTheme(String id) async {
    final response = await _dio.get('/dashboard/themes/$id');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> installTheme(Map<String, dynamic> body) async {
    final response = await _dio.post('/dashboard/themes/install', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- Analytics segments & scheduled reports ---

  Future<ApiResponse<dynamic>> getAnalyticsSegment(
    String segment, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get(
      '/dashboard/analytics/$segment',
      queryParameters: queryParameters,
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<Response<dynamic>> exportAnalytics({
    required String type,
    String format = 'csv',
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(
      '/dashboard/analytics/export',
      queryParameters: {
        'type': type,
        'format': format,
        ...?queryParameters,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<ApiResponse<dynamic>> getScheduledReports() async {
    final response = await _dio.get('/dashboard/analytics/scheduled-reports');
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> createScheduledReport(
      Map<String, dynamic> body) async {
    final response = await _dio.post(
      '/dashboard/analytics/scheduled-reports',
      data: body,
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> deleteScheduledReport(String id) async {
    final response = await _dio.delete(
      '/dashboard/analytics/scheduled-reports',
      queryParameters: {'id': id},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // --- M-Pesa (generic mobile flow) ---

  Future<ApiResponse<dynamic>> initiateMpesa(Map<String, dynamic> body) async {
    final response = await _dio.post('/mpesa/initiate', data: body);
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  Future<ApiResponse<dynamic>> getMpesaStatus(String checkoutRequestId) async {
    final response = await _dio.get(
      '/mpesa/status',
      queryParameters: {'checkoutRequestId': checkoutRequestId},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }
}
