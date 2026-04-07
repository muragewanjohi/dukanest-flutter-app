import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Unwraps mobile `{ success, data }` (or flat map) into the settings snapshot map.
Map<String, dynamic>? unwrapSettingsData(dynamic root) {
  if (root == null) return null;
  if (root is! Map) return null;
  final m = Map<String, dynamic>.from(root);
  final d = m['data'];
  if (d is Map) return Map<String, dynamic>.from(d);
  return m;
}

Map<String, dynamic>? settingsSection(Map<String, dynamic>? root, String key) {
  if (root == null) return null;
  final v = root[key];
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

String settingsPick(Map<String, dynamic>? m, List<String> keys, {String fallback = ''}) {
  if (m == null) return fallback;
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v is num) return v.toString();
  }
  return fallback;
}

bool settingsPickBool(Map<String, dynamic>? m, List<String> keys, {bool fallback = false}) {
  if (m == null) return fallback;
  for (final k in keys) {
    final v = m[k];
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
  }
  return fallback;
}

/// Cached GET `/dashboard/settings` for store / payment / tax / shipping editors.
final dashboardSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = await api.getDashboardSettings();
  if (!r.success || r.data == null) {
    throw StateError(r.error?.message ?? 'Failed to load settings');
  }
  final unwrapped = unwrapSettingsData(r.data);
  if (unwrapped == null) {
    throw const FormatException('Invalid settings response');
  }
  return unwrapped;
});
