import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'dashboard_settings_provider.dart';

/// Rows from `GET /dashboard/delivery-zones` (`items` or `zones`).
final deliveryZonesListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = await api.getDeliveryZones();
  if (!r.success || r.data == null) {
    throw StateError(r.error?.message ?? 'Failed to load delivery zones');
  }
  final root = unwrapSettingsData(r.data) ?? r.data;
  if (root is! Map<String, dynamic>) {
    throw const FormatException('Invalid zones response');
  }
  final items = root['items'] ?? root['zones'] ?? root['data'];
  if (items is! List) return [];
  return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
});

List<String> zoneAreasFromMap(Map<String, dynamic> z) {
  final ar = z['areas'] ?? z['locations'] ?? z['coveredAreas'] ?? z['regions'];
  if (ar is List) {
    return ar.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
  if (ar is String && ar.trim().isNotEmpty) {
    return ar.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

String zoneName(Map<String, dynamic> z) => (z['name'] ?? 'Zone').toString();

String zoneId(Map<String, dynamic> z) => (z['id'] ?? z['_id'] ?? '').toString();

num zoneFee(Map<String, dynamic> z) {
  final v = z['fee'] ?? z['deliveryFee'] ?? z['amount'] ?? z['price'] ?? 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

num zoneFreeOver(Map<String, dynamic> z) {
  final v = z['freeShippingThreshold'] ?? z['freeOver'] ?? z['free_shipping_threshold'] ?? 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

int zoneHandlingDays(Map<String, dynamic> z) {
  final v = z['estimatedDays'] ?? z['handlingDays'] ?? z['deliveryDays'] ?? 1;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 1;
}

bool zoneIsDefault(Map<String, dynamic> z) =>
    z['isDefault'] == true || z['default'] == true || z['is_default'] == true;
