import '../../core/api/api_client.dart';
import '../../core/api/api_response.dart';

/// Unwraps mobile Tumizi settings `data` (flat config or nested under `data`).
Map<String, dynamic>? tumiziConfigFromResponse(dynamic root) {
  if (root == null) return null;
  if (root is! Map) return null;
  final m = Map<String, dynamic>.from(root);
  final nested = m['data'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return m;
}

/// True when the tenant already has a linked Tumizi merchant (re-enable must not recreate).
bool tumiziHasLinkedMerchant(Map<String, dynamic>? config) {
  if (config == null) return false;
  for (final key in [
    'merchantExternalId',
    'merchant_external_id',
    'externalId',
    'external_id',
  ]) {
    final value = config[key];
    if (value is String && value.trim().isNotEmpty) return true;
  }
  return false;
}

/// Registration may queue async provisioning before `merchantExternalId` exists.
bool tumiziProvisioningPending(Map<String, dynamic>? config) {
  if (config == null) return false;
  final meta = config['metadata'];
  if (meta is! Map) return false;
  final status =
      (meta['provisioning_status'] ?? meta['provisioningStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  return status == 'pending';
}

/// Whether POST `/dashboard/tumizi/settings` should ask the server to create a merchant.
///
/// Bug fix: this used to also return false while registration's async queue
/// was still `provisioning_status: pending` — but pending means no merchant
/// has actually been created yet (the queue only drains via a server cron;
/// see storeflow vercel.json). Skipping creation in that state left the
/// tenant stuck: `enabled` gets set true locally, but `merchantExternalId`
/// never arrives, so every Tumizi action keeps failing with "Tumizi is not
/// enabled for this store" no matter how many times the merchant re-enables
/// it. Only an *already-linked* merchant should ever skip re-creation.
bool shouldRequestTumiziMerchantCreation(Map<String, dynamic>? existingConfig) {
  return !tumiziHasLinkedMerchant(existingConfig);
}

/// Syncs Tumizi integration (enable/disable + optional merchant create) before payment PATCH.
/// Returns an error message on failure, or `null` on success.
Future<String?> syncTumiziIntegration(
  ApiClient api, {
  required bool enabled,
}) async {
  if (enabled) {
    Map<String, dynamic>? existing;
    final getResponse = await api.getTumiziSettings();
    if (getResponse.success) {
      existing = tumiziConfigFromResponse(getResponse.data);
    }
    final createIfMissing = shouldRequestTumiziMerchantCreation(existing);
    final postResponse = await api.postTumiziSettings(<String, dynamic>{
      'enabled': true,
      'createMerchantIfMissing': createIfMissing,
    });
    return _errorFrom(postResponse, 'Could not enable Tumizi wallet');
  }

  final postResponse = await api.postTumiziSettings(<String, dynamic>{
    'enabled': false,
  });
  return _errorFrom(postResponse, 'Could not disable Tumizi wallet');
}

String? _errorFrom(ApiResponse<dynamic> response, String fallback) {
  if (response.success) return null;
  return response.error?.message ?? fallback;
}
