import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Unwrapped `data` from `GET /api/v1/mobile/dashboard/getting-started`.
final dashboardGettingStartedProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final response = await api.getGettingStarted();
    if (!response.success || response.data == null) return null;
    final payload = response.data;
    if (payload is! Map<String, dynamic>) return null;
    final inner = payload['data'];
    if (inner is Map<String, dynamic>) {
      return Map<String, dynamic>.from(inner);
    }
    return payload;
  } catch (_) {
    return null;
  }
});
