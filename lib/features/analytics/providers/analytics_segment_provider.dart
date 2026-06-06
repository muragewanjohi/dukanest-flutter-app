import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Stable family key for segment requests (avoids Map identity churn).
typedef AnalyticsSegmentParams = ({
  String segment,
  String? startDate,
  String? endDate,
});

AnalyticsSegmentParams analyticsSegmentParamsFor(String segment, int days) {
  if (segment == 'overview' || segment == 'realtime') {
    return (segment: segment, startDate: null, endDate: null);
  }
  final end = DateTime.now();
  final start = DateTime(end.year, end.month, end.day)
      .subtract(Duration(days: days - 1));
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return (segment: segment, startDate: fmt(start), endDate: fmt(end));
}

Map<String, dynamic>? queryFromAnalyticsSegmentParams(
    AnalyticsSegmentParams params) {
  return _queryFromParams(params);
}

Map<String, dynamic>? _queryFromParams(AnalyticsSegmentParams params) {
  if (params.startDate == null && params.endDate == null) return null;
  return {
    if (params.startDate != null) 'startDate': params.startDate,
    if (params.endDate != null) 'endDate': params.endDate,
  };
}

/// Raw `data` from `GET /dashboard/analytics/:segment` (query e.g. date range).
final analyticsSegmentProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, AnalyticsSegmentParams>((ref, params) async {
  final link = ref.keepAlive();
  try {
    final api = ref.read(apiClientProvider);
    final response = await api.getAnalyticsSegment(
      params.segment,
      queryParameters: _queryFromParams(params),
    );
    if (!response.success) {
      throw StateError(
        response.error?.message ??
            'Could not load ${params.segment} analytics.',
      );
    }
    if (response.data == null) return null;
    final payload = response.data;
    if (payload is! Map<String, dynamic>) return null;
    final inner = payload['data'];
    if (inner is Map<String, dynamic>) {
      return Map<String, dynamic>.from(inner);
    }
    return payload;
  } catch (_) {
    link.close();
    rethrow;
  }
});
