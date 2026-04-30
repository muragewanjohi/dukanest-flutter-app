import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

typedef DashboardPnlQuery = ({DateTime startDate, DateTime endDate});

/// Mobile `GET /dashboard/analytics/pnl` — raw `data` object from [ApiResponse.data].
final dashboardPnlProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, DashboardPnlQuery>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getDashboardPnl(
    startDate: query.startDate,
    endDate: query.endDate,
  );
  if (!response.success || response.data == null) return null;
  final payload = response.data;
  if (payload is! Map<String, dynamic>) return null;
  final inner = payload['data'];
  if (inner is Map<String, dynamic>) return Map<String, dynamic>.from(inner);
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return Map<String, dynamic>.from(payload);
});
