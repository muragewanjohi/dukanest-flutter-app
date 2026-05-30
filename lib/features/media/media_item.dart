/// Pure helpers for reading identity/URL out of a media item map returned by
/// `/dashboard/media`, kept separate from the widget for unit testing.
library;

/// Resolves a media item's id across key variants ('id' / '_id').
String mediaItemId(Map<String, dynamic> m) {
  for (final k in ['id', '_id']) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) return '$v'.trim();
  }
  return '';
}

/// Resolves a media item's URL across key variants, in priority order.
String mediaItemUrl(Map<String, dynamic> m) {
  for (final k in ['url', 'publicUrl', 'public_url', 'path', 'src']) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}
