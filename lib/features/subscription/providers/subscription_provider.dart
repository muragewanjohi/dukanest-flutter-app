import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Mobile `GET /dashboard/subscription` — unwraps nested `data` when present.
final subscriptionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getSubscription();
  if (!response.success || response.data == null) return null;
  return _unwrapDataMap(response.data);
});

Map<String, dynamic>? _unwrapDataMap(dynamic payload) {
  if (payload is! Map) return null;
  final outer = Map<String, dynamic>.from(payload);
  final inner = outer['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return outer;
}

/// Separate `GET /dashboard/subscription/pesapal/config` (yearly discount, etc.).
final subscriptionPesapalConfigProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getPesapalConfig();
  if (!response.success || response.data == null) return null;
  return _unwrapDataMap(response.data);
});
