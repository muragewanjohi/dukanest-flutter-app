import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _storeNameKey = 'store_name';
  static const _storeSubdomainKey = 'store_subdomain';
  static const _storeUrlKey = 'store_url';
  static const _storeLogoUrlKey = 'store_logo_url';
  static const _productsListRefreshHintSeenKey =
      'products_list_refresh_hint_seen';
  static const _productDetailRefreshHintSeenKey =
      'product_detail_refresh_hint_seen';
  static const _productEditorDraftPrefix = 'product_editor_draft_';
  static const _onboardingSeenKey = 'onboarding_seen';
  static const _firstRunTutorialSeenKey = 'first_run_tutorial_seen';

  /// Legacy key from multi-store experiment; still cleared on logout.
  static const _legacySelectedTenantKey = 'selected_tenant_id';

  Future<void> saveTokens(
      {required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    return token == null || token.trim().isEmpty ? null : token;
  }

  Future<String?> getRefreshToken() async {
    final token = await _storage.read(key: _refreshTokenKey);
    return token == null || token.trim().isEmpty ? null : token;
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _legacySelectedTenantKey);
    await _storage.delete(key: _storeNameKey);
    await _storage.delete(key: _storeSubdomainKey);
    await _storage.delete(key: _storeUrlKey);
    await _storage.delete(key: _storeLogoUrlKey);
    await _storage.delete(key: _firstRunTutorialSeenKey);
  }

  Future<void> saveStoreIdentity({
    required String name,
    required String subdomain,
    required String storeUrl,
    String? logoUrl,
  }) async {
    await _storage.write(key: _storeNameKey, value: name);
    await _storage.write(key: _storeSubdomainKey, value: subdomain);
    await _storage.write(key: _storeUrlKey, value: storeUrl);
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      await _storage.write(key: _storeLogoUrlKey, value: logoUrl.trim());
    }
  }

  Future<({String? name, String? subdomain, String? storeUrl, String? logoUrl})>
      getStoreIdentity() async {
    final name = await _storage.read(key: _storeNameKey);
    final subdomain = await _storage.read(key: _storeSubdomainKey);
    final storeUrl = await _storage.read(key: _storeUrlKey);
    final logoUrl = await _storage.read(key: _storeLogoUrlKey);
    return (
      name: name,
      subdomain: subdomain,
      storeUrl: storeUrl,
      logoUrl: logoUrl
    );
  }

  Future<void> saveProductsListRefreshHintSeen(bool seen) async {
    await _storage.write(
        key: _productsListRefreshHintSeenKey, value: seen ? '1' : '0');
  }

  Future<bool> getProductsListRefreshHintSeen() async {
    return (await _storage.read(key: _productsListRefreshHintSeenKey)) == '1';
  }

  Future<void> saveProductDetailRefreshHintSeen(bool seen) async {
    await _storage.write(
        key: _productDetailRefreshHintSeenKey, value: seen ? '1' : '0');
  }

  Future<bool> getProductDetailRefreshHintSeen() async {
    return (await _storage.read(key: _productDetailRefreshHintSeenKey)) == '1';
  }

  Future<void> saveProductEditorDraft(String draftKey, String value) async {
    await _storage.write(
        key: '$_productEditorDraftPrefix$draftKey', value: value);
  }

  Future<void> saveOnboardingSeen(bool seen) async {
    await _storage.write(key: _onboardingSeenKey, value: seen ? '1' : '0');
  }

  Future<bool> getOnboardingSeen() async {
    return (await _storage.read(key: _onboardingSeenKey)) == '1';
  }

  Future<void> saveFirstRunTutorialSeen(bool seen) async {
    await _storage.write(key: _firstRunTutorialSeenKey, value: seen ? '1' : '0');
  }

  Future<bool> hasFirstRunTutorialSeenFlag() async {
    return (await _storage.read(key: _firstRunTutorialSeenKey)) != null;
  }

  Future<bool> getFirstRunTutorialSeen() async {
    final raw = await _storage.read(key: _firstRunTutorialSeenKey);
    if (raw == null) {
      // Treat unknown state as "not seen" so users are not accidentally
      // dropped into dashboard before finishing/skipping tutorial.
      return false;
    }
    return raw == '1';
  }
}
