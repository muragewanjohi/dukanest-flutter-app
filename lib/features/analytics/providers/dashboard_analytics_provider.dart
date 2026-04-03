import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Mobile `GET /dashboard/analytics?days=` — raw `data` object from [ApiResponse.data].
final dashboardAnalyticsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, int>((ref, days) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getDashboardAnalytics(days: days.clamp(1, 365));
  if (!response.success || response.data == null) return null;
  final payload = response.data;
  if (payload is! Map<String, dynamic>) return null;
  final inner = payload['data'];
  if (inner is Map<String, dynamic>) return Map<String, dynamic>.from(inner);
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return Map<String, dynamic>.from(payload);
});
