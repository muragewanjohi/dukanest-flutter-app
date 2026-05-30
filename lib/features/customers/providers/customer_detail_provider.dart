import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Customer detail from `GET /dashboard/customers/:id`.
final customerDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final r = await api.getCustomerDetail(id);
  if (!r.success || r.data == null) {
    throw Exception(r.error?.message ?? 'Failed to load customer');
  }
  final root = r.data!;
  final data = root['data'];
  final inner = root['customer'] ??
      (data is Map<String, dynamic> ? data['customer'] : null);
  final map = inner is Map<String, dynamic>
      ? inner
      : data is Map<String, dynamic>
          ? data
          : root;

  return Map<String, dynamic>.from(map is Map ? map : {});
});
