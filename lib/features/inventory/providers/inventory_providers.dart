import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Low-stock alerts from `GET /dashboard/inventory/alerts`.
final inventoryAlertsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = await api.getInventoryAlerts();
  if (!r.success || r.data == null) {
    throw Exception(r.error?.message ?? 'Failed to load alerts');
  }
  final root = r.data!;
  final data = root['data'];
  if (data is Map<String, dynamic>) return data;
  return Map<String, dynamic>.from(root);
});

/// Threshold and related settings from `GET /dashboard/inventory/settings`.
final inventorySettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = await api.getInventorySettings();
  if (!r.success || r.data == null) {
    throw Exception(r.error?.message ?? 'Failed to load settings');
  }
  final root = r.data!;
  final data = root['data'] ?? root['settings'];
  if (data is Map<String, dynamic>) return data;
  return Map<String, dynamic>.from(root);
});
