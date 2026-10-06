/// Resolves a link handed to the app (from the AI assistant's next-step CTAs,
/// cited help articles, or anywhere else) to an in-app route when the target
/// is something the Flutter app has natively.
///
/// Returns a GoRouter path (e.g. `/themes`) when the link should stay in the
/// app, or `null` when it should open in an external browser (the storefront,
/// marketing pages, help articles with no in-app equivalent).
///
/// Accepts:
///   * full URLs on a dukanest.com host — `https://x.dukanest.com/dashboard/themes`
///   * bare dashboard paths — `/dashboard/themes`, `/dashboard/settings`
///   * already-native app paths — `/themes`, `/products` (passed through)
///   * help-article URLs — `/help/<slug>` — mapped only when the slug clearly
///     names a configuration screen (theme, payments, tax, delivery, branding)
library;

/// Dashboard area (first path segment after an optional `/dashboard`) → app route.
const Map<String, String> _areaRoutes = {
  'themes': '/themes',
  'settings': '/settings',
  'store-identity': '/store-identity',
  'branding': '/store-identity',
  'payment-settings': '/payment-settings',
  'payments': '/payment-settings',
  'tax-settings': '/tax-settings',
  'tax': '/tax-settings',
  'shipping-delivery': '/shipping-delivery',
  'shipping': '/shipping-delivery',
  'delivery': '/shipping-delivery',
  'delivery-zones': '/shipping-delivery',
  'shipping-zones': '/shipping-zones',
  'products': '/products',
  'categories': '/categories',
  'attributes': '/attributes',
  'inventory': '/inventory',
  'orders': '/orders',
  'customers': '/customers',
  'sales': '/sales',
  'analytics': '/analytics',
  'expenses': '/analytics/expenses',
  'blogs': '/content-management',
  'pages': '/content-management',
  'content-management': '/content-management',
  'forms': '/forms',
  'media': '/media-library',
  'media-library': '/media-library',
  'themes-customize': '/themes/customize',
  'subscription': '/subscription',
  'billing': '/subscription',
  'referrals': '/referrals',
  'notifications': '/notifications',
  'pos': '/pos',
  'assistant': '/assistant',
};

/// A few multi-segment paths that map to a dedicated screen.
const Map<String, String> _exactPathRoutes = {
  'themes/customize': '/themes/customize',
  'settings/domains': '/settings',
  'analytics/expenses': '/analytics/expenses',
  'products/new': '/products/new',
  'categories/new': '/categories/new',
  'attributes/new': '/attributes/new',
  'sales/new': '/sales/new',
};

/// Help-article slug keyword → app route. Only for slugs that clearly point at
/// a task the merchant performs on a screen (not conceptual/learning docs).
const Map<String, String> _helpKeywordRoutes = {
  'theme': '/themes',
  'payment': '/payment-settings',
  'mpesa': '/payment-settings',
  'tax': '/tax-settings',
  'vat': '/tax-settings',
  'deliver': '/shipping-delivery',
  'shipping': '/shipping-delivery',
  'logo': '/store-identity',
  'branding': '/store-identity',
  'store-identity': '/store-identity',
};

bool _isDukanestHost(String host) {
  if (host.isEmpty) return true; // relative link
  final h = host.toLowerCase();
  return h == 'dukanest.com' || h.endsWith('.dukanest.com');
}

String? resolveInAppRoute(String rawHref) {
  final href = rawHref.trim();
  if (href.isEmpty) return null;

  final uri = Uri.tryParse(href);
  if (uri == null) return null;

  if (!_isDukanestHost(uri.host)) return null;

  // `/dashboard?openAssistant=1` and friends.
  if (uri.queryParameters['openAssistant'] == '1') return '/assistant';

  // Preserve original segment casing for IDs/SKUs — only lowercase when
  // matching route tables. (Lowercasing `/products/edit/<SKU>` used to break
  // product lookup after AI "Add a photo".)
  final segments =
      uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
  if (segments.isEmpty) return null;

  final lower = segments.map((s) => s.toLowerCase()).toList(growable: false);

  // Help articles: only map when the slug names a config screen.
  final helpIdx = lower.indexOf('help');
  if (helpIdx == 0 || (helpIdx == 1 && lower[0] == 'dashboard')) {
    final slug = lower.sublist(helpIdx + 1).join('/');
    if (slug.isEmpty) return null;
    for (final entry in _helpKeywordRoutes.entries) {
      if (slug.contains(entry.key)) return entry.value;
    }
    return null; // read it on the web
  }

  var start = 0;
  final hadDashboardPrefix = lower[0] == 'dashboard';
  if (hadDashboardPrefix) start = 1;
  if (start >= lower.length) return null;

  final appLower = lower.sublist(start).join('/');
  if (_exactPathRoutes.containsKey(appLower)) return _exactPathRoutes[appLower]!;

  final firstSegment = lower[start];
  final areaRoute = _areaRoutes[firstSegment];
  if (areaRoute == null) return null;

  // A bare app path (no `/dashboard` prefix) that already targets a known area
  // is passed through with original casing so deep links like
  // `/products/edit/<uuid-or-sku>` keep a usable lookup key. A `/dashboard/*`
  // web path is translated to the area root (web sub-paths rarely line up
  // with the app's routes).
  if (hadDashboardPrefix) return areaRoute;
  return '/${segments.sublist(start).join('/')}';
}
