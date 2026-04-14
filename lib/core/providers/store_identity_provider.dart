import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../auth/token_storage.dart';

typedef StoreIdentity = ({String? name, String? subdomain, String? storeUrl, String? logoUrl});

String _normalizeAbsoluteUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('//')) return 'https:$s';
  final base = AppConfig.publicApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
  if (s.startsWith('/')) return '$base$s';
  return '$base/$s';
}

final storeIdentityProvider = FutureProvider<StoreIdentity>((ref) async {
  final identity = await ref.read(tokenStorageProvider).getStoreIdentity();
  final normalizedLogo = (identity.logoUrl == null || identity.logoUrl!.trim().isEmpty)
      ? null
      : _normalizeAbsoluteUrl(identity.logoUrl!);
  return (
    name: identity.name,
    subdomain: identity.subdomain,
    storeUrl: identity.storeUrl,
    logoUrl: normalizedLogo,
  );
});
