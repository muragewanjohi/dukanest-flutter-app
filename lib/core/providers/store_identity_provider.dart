import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/store_media_url.dart';
import '../auth/token_storage.dart';

typedef StoreIdentity = ({String? name, String? subdomain, String? storeUrl, String? logoUrl});

final storeIdentityProvider = FutureProvider<StoreIdentity>((ref) async {
  final identity = await ref.read(tokenStorageProvider).getStoreIdentity();
  final normalizedLogo = (identity.logoUrl == null || identity.logoUrl!.trim().isEmpty)
      ? null
      : normalizeStoreMediaUrl(identity.logoUrl!);
  return (
    name: identity.name,
    subdomain: identity.subdomain,
    storeUrl: identity.storeUrl,
    logoUrl: normalizedLogo,
  );
});
