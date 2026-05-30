/// Pure parsers for the themes endpoints (`/dashboard/themes`,
/// `/dashboard/themes/installed`, `/dashboard/themes/current`).
///
/// The payloads vary (flat list, `{items:[]}`, `{themes:[]}`, or nested under
/// `data`), so the resolution lives here and is unit-tested independently of
/// the widget.
library;

/// Normalizes any themes-list payload shape into a list of maps.
List<Map<String, dynamic>> themeListFrom(dynamic payload) {
  final root = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
  final nested = root['data'];
  final bag = nested is Map<String, dynamic>
      ? nested
      : nested is Map
          ? Map<String, dynamic>.from(nested)
          : root;
  final raw = bag['items'] ??
      bag['themes'] ??
      root['items'] ??
      (nested is List ? nested : null) ??
      (payload is List ? payload : null);
  return raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
}

/// Resolves a stable identifier for a theme map across key variants.
String themeId(Map<String, dynamic> m) {
  for (final k in ['id', '_id', 'themeId', 'slug', 'key']) {
    final v = m[k];
    if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
  }
  return '';
}

/// Extracts the active theme id from the `/themes/current` payload, or null.
String? currentThemeId(dynamic payload) {
  final root = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
  final cur = root['data'] ?? root['theme'] ?? root;
  if (cur is Map) {
    final id = themeId(Map<String, dynamic>.from(cur));
    if (id.isNotEmpty) return id;
  }
  return null;
}
