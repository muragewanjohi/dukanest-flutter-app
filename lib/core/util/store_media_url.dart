import '../../config/app_config.dart';

/// Supabase public object URLs are served from the branded storage host.
/// `www.dukanest.com/storage/v1/...` returns 404; `auth.dukanest.com/storage/v1/...` works.
const String kStoreMediaPublicHost = 'auth.dukanest.com';

bool _isSupabasePublicStoragePath(String path) =>
    path.startsWith('/storage/v1/object/public/');

/// Normalizes media URLs for tenant storefront + dashboard (absolute, loadable host).
String normalizeStoreMediaUrl(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return '';

  var resolved = s;
  if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
    if (resolved.startsWith('//')) {
      resolved = 'https:$resolved';
    } else {
      final base = AppConfig.publicApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
      resolved =
          resolved.startsWith('/') ? '$base$resolved' : '$base/$resolved';
    }
  }

  try {
    final u = Uri.parse(resolved);
    if (_isSupabasePublicStoragePath(u.path)) {
      return u
          .replace(
            scheme: 'https',
            host: kStoreMediaPublicHost,
            port: null,
          )
          .toString();
    }
  } catch (_) {}

  return resolved;
}

/// Reads a public URL from `POST /media/upload` (mobile envelope or flat map).
String extractMediaUploadUrl(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) return normalizeStoreMediaUrl(raw);
  if (raw is! Map) return '';

  final root = Map<String, dynamic>.from(raw);
  final inner = root['data'] is Map
      ? Map<String, dynamic>.from(root['data'] as Map)
      : root;

  for (final key in ['publicUrl', 'public_url', 'url', 'src', 'path']) {
    final v = inner[key];
    if (v is String && v.trim().isNotEmpty) {
      return normalizeStoreMediaUrl(v);
    }
  }

  final nested = inner['data'];
  if (nested is Map) {
    final m = Map<String, dynamic>.from(nested);
    for (final key in ['publicUrl', 'public_url', 'url', 'path']) {
      final v = m[key];
      if (v is String && v.trim().isNotEmpty) {
        return normalizeStoreMediaUrl(v);
      }
    }
  }

  return '';
}
