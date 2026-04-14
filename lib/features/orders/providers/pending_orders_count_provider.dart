import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

final pendingOrdersCountProvider = FutureProvider<int>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getOrders(
    page: 1,
    limit: 1,
    status: 'pending',
  );
  if (!response.success) {
    return 0;
  }
  return response.pagination?.total ?? 0;
});
