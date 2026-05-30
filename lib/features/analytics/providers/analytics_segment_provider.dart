import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Raw `data` from `GET /dashboard/analytics/:segment` (query e.g. date range).
final analyticsSegmentProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>?,
    ({String segment, Map<String, dynamic>? query})>((ref, arg) async {
  try {
    final api = ref.read(apiClientProvider);
    final response = await api.getAnalyticsSegment(
      arg.segment,
      queryParameters: arg.query,
    );
    if (!response.success || response.data == null) return null;
    final payload = response.data;
    if (payload is! Map<String, dynamic>) return null;
    final inner = payload['data'];
    if (inner is Map<String, dynamic>) return Map<String, dynamic>.from(inner);
    return payload;
  } catch (_) {
    return null;
  }
});
