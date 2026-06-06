import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Home metrics from `GET /dashboard/overview`.
final dashboardOverviewProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final response = await api.getDashboardOverview();
    if (!response.success || response.data == null) return null;
    final payload = response.data;
    if (payload is! Map<String, dynamic>) return null;
    final data = payload['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    return data;
  } catch (_) {
    return null;
  }
});
