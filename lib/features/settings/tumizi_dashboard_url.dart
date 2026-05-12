import '../../config/app_config.dart';

/// Tenant web URL for the StoreFlow Tumizi dashboard (`tumizi-dashboard-client.tsx` route).
///
/// Uses [storeUrl] origin when present; otherwise builds `https://{subdomain}.{publicRoot}`.
/// Returns `null` when the URL cannot be determined.
Uri? buildTumiziWebDashboardUri({String? storeUrl, String? subdomain}) {
  var origin = (storeUrl ?? '').trim();
  if (origin.isEmpty) {
    final sub = (subdomain ?? '').trim();
    if (sub.isEmpty) return null;
    final host = Uri.tryParse(AppConfig.publicApiBaseUrl)?.host ?? 'dukanest.com';
    final rootHost = host.startsWith('www.') ? host.substring(4) : host;
    origin = 'https://$sub.$rootHost';
  }

  final parsed = Uri.tryParse(origin);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return null;
  }

  final root = Uri(
    scheme: parsed.scheme,
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
  );
  return root.replace(path: '/dashboard/tumizi');
}
