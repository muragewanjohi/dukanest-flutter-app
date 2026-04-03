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
  /// Legacy key from multi-store experiment; still cleared on logout.
  static const _legacySelectedTenantKey = 'selected_tenant_id';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _legacySelectedTenantKey);
    await _storage.delete(key: _storeNameKey);
    await _storage.delete(key: _storeSubdomainKey);
    await _storage.delete(key: _storeUrlKey);
  }

  Future<void> saveStoreIdentity({
    required String name,
    required String subdomain,
    required String storeUrl,
  }) async {
    await _storage.write(key: _storeNameKey, value: name);
    await _storage.write(key: _storeSubdomainKey, value: subdomain);
    await _storage.write(key: _storeUrlKey, value: storeUrl);
  }

  Future<({String? name, String? subdomain, String? storeUrl})> getStoreIdentity() async {
    final name = await _storage.read(key: _storeNameKey);
    final subdomain = await _storage.read(key: _storeSubdomainKey);
    final storeUrl = await _storage.read(key: _storeUrlKey);
    return (name: name, subdomain: subdomain, storeUrl: storeUrl);
  }
}
