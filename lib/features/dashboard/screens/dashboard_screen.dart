import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/token_storage.dart';
import '../../onboarding/providers/auth_provider.dart';
import '../providers/dashboard_getting_started_provider.dart';
import '../providers/dashboard_local_onboarding_provider.dart';

/// Home dashboard aligned with Stitch screen
/// `projects/13184140852829986275/screens/a93fc25cee2c4ac98d30472dc7535058`
/// (HTML + screenshot in `docs/backend-context/stitch-exports/`).
final dashboardOverviewProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final response = await api.getDashboardOverview();
    if (!response.success || response.data == null) return null;
    final payload = response.data;
    if (payload is! Map<String, dynamic>) return null;
    final data = payload['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    return data;
  } catch (_) {
    return null;
  }
});

final dashboardStoreIdentityProvider = FutureProvider<({String? name, String? subdomain, String? storeUrl})>(
  (ref) async => ref.read(tokenStorageProvider).getStoreIdentity(),
);

List<_OnboardingStepUi> _mergeLocalStepCompletion(
  List<_OnboardingStepUi> steps,
  Set<String> localKeys,
) {
  if (localKeys.isEmpty) return steps;
  return steps.map((s) {
    final key = (s.stepKey ?? '').toLowerCase();
    if (key.isEmpty || !localKeys.contains(key) || s.completed) return s;
    return _OnboardingStepUi(
      completed: true,
      title: s.title,
      actionLabel: s.actionLabel,
      description: s.description,
      durationHint: s.durationHint,
      stepKey: s.stepKey,
      onAction: null,
    );
  }).toList();
}

String _normalizeGettingStartedServerId(String id) {
  switch (id.toLowerCase().trim()) {
    case 'preview':
      return 'preview_store';
    case 'share':
      return 'share_store';
    case 'contact_phone':
    case 'sms_alerts':
    case 'order_alerts_sms':
      return 'sms';
    case 'delivery':
      return 'shipping';
    default:
      return id.toLowerCase().trim();
  }
}

List<_OnboardingStepUi> _mergeGettingStartedItems(
  List<_OnboardingStepUi> defaults,
  List<dynamic> items,
) {
  bool isCompletedForAppKey(String? appStepKey) {
    if (appStepKey == null || appStepKey.isEmpty) return false;
    final target = appStepKey.toLowerCase();
    for (final item in items.whereType<Map>()) {
      final m = Map<String, dynamic>.from(item);
      final id = (m['id'] ?? m['key'] ?? m['stepKey'] ?? '').toString();
      if (id.isEmpty) continue;
      if (_normalizeGettingStartedServerId(id) == target) {
        return m['completed'] == true || m['done'] == true;
      }
    }
    return false;
  }

  return defaults.map((s) {
    final key = s.stepKey?.toLowerCase();
    if (key == null) return s;
    final done = isCompletedForAppKey(key);
    if (done == s.completed) return s;
    return _OnboardingStepUi(
      completed: done,
      title: s.title,
      actionLabel: s.actionLabel,
      description: s.description,
      durationHint: s.durationHint,
      stepKey: s.stepKey,
      onAction: null,
    );
  }).toList();
}

void _postGettingStartedPreview(WidgetRef ref) {
  unawaited(ref.read(apiClientProvider).postGettingStartedAction('preview_done'));
}

void _postGettingStartedShare(WidgetRef ref) {
  unawaited(ref.read(apiClientProvider).postGettingStartedAction('share_done'));
}

/// Parsed onboarding row for the home checklist (from `dashboard/overview` or defaults).
class _OnboardingStepUi {
  const _OnboardingStepUi({
    required this.completed,
    required this.title,
    required this.actionLabel,
    this.description,
    this.durationHint,
    this.stepKey,
    this.onAction,
  });

  final bool completed;
  final String title;
  final String actionLabel;
  final String? description;
  final String? durationHint;
  final String? stepKey;
  final VoidCallback? onAction;
}

String _dashboardGreetingName(AuthUser? user, String? storeName) {
  if (user?.name != null && user!.name!.trim().isNotEmpty) {
    return user.name!.trim();
  }
  if (storeName != null && storeName.trim().isNotEmpty) {
    return storeName.trim();
  }
  final email = user?.email ?? '';
  final at = email.indexOf('@');
  if (at > 0) return email.substring(0, at).trim();
  if (email.isNotEmpty) return email;
  return 'there';
}

List<double> _normalizeChartFractions(List<dynamic>? raw, {int length = 7}) {
  if (raw == null || raw.isEmpty) {
    return List<double>.filled(length, 0.12);
  }
  final nums = raw.map((e) => e is num ? e.toDouble() : 0.0).toList();
  if (nums.length < length) {
    for (var i = nums.length; i < length; i++) {
      nums.add(0);
    }
  } else if (nums.length > length) {
    nums.removeRange(length, nums.length);
  }
  var max = 0.0;
  for (final n in nums) {
    if (n > max) max = n;
  }
  if (max <= 0) {
    return List<double>.filled(length, 0.12);
  }
  return nums.map((n) => (n / max).clamp(0.10, 1.0)).toList();
}

int _lastPositiveIndex(List<double> fractions) {
  for (var i = fractions.length - 1; i >= 0; i--) {
    if (fractions[i] > 0.15) return i;
  }
  return fractions.isEmpty ? 0 : fractions.length - 1;
}

Map<String, dynamic>? _firstMap(Map<String, dynamic>? data, List<String> keys) {
  if (data == null) return null;
  for (final k in keys) {
    final v = data[k];
    if (v is Map) return Map<String, dynamic>.from(v);
  }
  return null;
}

List<_OnboardingStepUi> _parseOnboardingStepsFromOverview(
  Map<String, dynamic>? data, {
  required List<_OnboardingStepUi> defaultSteps,
}) {
  if (data == null) return defaultSteps;

  Map<String, dynamic>? container = _firstMap(data, [
    'gettingStarted',
    'getting_started',
    'onboarding',
    'setupChecklist',
    'setup_checklist',
  ]);

  List<dynamic>? rawSteps;
  if (container != null) {
    rawSteps = container['steps'] as List<dynamic>? ?? container['items'] as List<dynamic>?;
  }
  rawSteps ??= data['onboardingSteps'] as List<dynamic>? ?? data['checklist'] as List<dynamic>?;

  if (rawSteps == null || rawSteps.isEmpty) {
    final tenant = _firstMap(data, ['tenant', 'store']);
    if (tenant != null) {
      container ??= _firstMap(tenant, [
        'gettingStarted',
        'getting_started',
        'onboarding',
        'setupChecklist',
        'setup_checklist',
      ]);
      if (container != null) {
        rawSteps = container['steps'] as List<dynamic>? ?? container['items'] as List<dynamic>?;
      }
    }
  }

  if (rawSteps == null || rawSteps.isEmpty) return defaultSteps;

  final out = <_OnboardingStepUi>[];
  for (final item in rawSteps) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final completed = m['completed'] == true || m['done'] == true;
    final title = (m['title'] ?? m['label'] ?? m['name'] ?? '').toString().trim();
    if (title.isEmpty) continue;
    final actionLabel = (m['actionLabel'] ??
            m['action_label'] ??
            m['cta'] ??
            (completed ? 'View' : 'Continue'))
        .toString()
        .trim();
    final sk = m['key'] ?? m['id'] ?? m['stepKey'];
    final stepKey = sk is String ? sk.trim() : null;
    final descRaw = (m['description'] ?? m['subtitle'] ?? m['body'] ?? '').toString().trim();
    final durRaw = (m['durationHint'] ??
            m['duration_hint'] ??
            m['duration'] ??
            m['estimatedTime'] ??
            '')
        .toString()
        .trim();
    out.add(_OnboardingStepUi(
      completed: completed,
      title: title,
      actionLabel: actionLabel.isEmpty ? 'Open' : actionLabel,
      description: descRaw.isEmpty ? null : descRaw,
      durationHint: durRaw.isEmpty ? null : durRaw,
      stepKey: stepKey != null && stepKey.isNotEmpty ? stepKey : null,
      onAction: null,
    ));
  }
  return out.isEmpty ? defaultSteps : out;
}

/// Matches web dashboard onboarding: 7 steps; only SMS alerts complete right after registration.
List<_OnboardingStepUi> _defaultOnboardingStepsAfterRegistration() {
  return const [
    _OnboardingStepUi(
      completed: false,
      title: 'Add your first product',
      description: 'Create a product so customers can start buying.',
      durationHint: 'Takes 2 minutes',
      actionLabel: 'Add product',
      stepKey: 'product',
    ),
    _OnboardingStepUi(
      completed: false,
      title: 'Preview your store',
      description: 'Open your storefront and confirm it looks right.',
      durationHint: 'Takes 1 minute',
      actionLabel: 'Preview store',
      stepKey: 'preview_store',
    ),
    _OnboardingStepUi(
      completed: false,
      title: 'Share your store',
      description: 'Copy and share your store URL with customers.',
      actionLabel: 'Copy link',
      stepKey: 'share_store',
    ),
    _OnboardingStepUi(
      completed: true,
      title: 'Get order alerts via SMS',
      description: 'Add your phone number so you never miss a customer order.',
      actionLabel: 'View',
      stepKey: 'sms',
    ),
    _OnboardingStepUi(
      completed: false,
      title: 'Set up checkout preferences',
      description: 'Enable Cash, M-Pesa, or other payment methods.',
      actionLabel: 'Set up payments',
      stepKey: 'payment',
    ),
    _OnboardingStepUi(
      completed: false,
      title: 'Configure delivery & shipping',
      description: 'Set up flat rate or delivery zones for orders.',
      actionLabel: 'Configure shipping',
      stepKey: 'shipping',
    ),
    _OnboardingStepUi(
      completed: false,
      title: 'Add your store logo',
      description: 'Brand your storefront with a logo.',
      actionLabel: 'Add logo',
      stepKey: 'logo',
    ),
  ];
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(12, 5, 40, 0.06),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  String _toCurrency(dynamic v, {String currency = 'KES'}) {
    if (v is num) return '$currency ${v.toStringAsFixed(2)}';
    if (v is String && v.trim().isNotEmpty) return v;
    return '$currency 0.00';
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  List<({String name, String subtitle})> _extractLowStockItems(
    Map<String, dynamic>? data, {
    Map<String, dynamic>? productsMetrics,
  }) {
    if (data == null) return const [];
    final candidates = data['lowStockItems'] ??
        data['stockAlerts'] ??
        data['lowStock'] ??
        data['inventoryAlerts'];
    if (candidates is List && candidates.isNotEmpty) {
      final mapped = candidates.whereType<Map>().map((raw) {
        final item = Map<String, dynamic>.from(raw);
        final name = (item['name'] ?? item['productName'] ?? 'Low stock item').toString();
        final qty = item['stock'] ?? item['stockQuantity'] ?? item['quantity'] ?? item['available'];
        final subtitle = qty is num ? 'Only ${qty.toInt()} units left' : 'Needs restock';
        return (name: name, subtitle: subtitle);
      }).toList();
      if (mapped.isNotEmpty) return mapped.take(3).toList();
    }
    final lowCount = _toInt(
      productsMetrics?['lowStock'] ?? productsMetrics?['low_stock'] ?? data['lowStockCount'],
      fallback: 0,
    );
    if (lowCount > 0) {
      return [
        (
          name: 'Low stock summary',
          subtitle:
              '$lowCount product${lowCount == 1 ? '' : 's'} below threshold — review inventory.',
        ),
      ];
    }
    return const [];
  }

  String? _comparisonSubtitle(Map<String, dynamic> revenueMetrics, {required bool weekly}) {
    final keys = weekly
        ? ['weekOverWeekChangePercent', 'weekOverWeekPercent', 'wowPercent', 'weekOverWeekChange']
        : ['monthOverMonthChangePercent', 'momPercent', 'monthOverMonthChange'];
    for (final k in keys) {
      final v = revenueMetrics[k];
      if (v is num) {
        final sign = v >= 0 ? '+' : '';
        return '$sign${v.toStringAsFixed(1)}% from last ${weekly ? 'week' : 'month'}';
      }
    }
    final label = revenueMetrics['comparisonLabel'] ?? revenueMetrics['trendLabel'];
    if (label is String && label.trim().isNotEmpty) return label.trim();
    return null;
  }

  List<_OnboardingStepUi> _attachOnboardingActions(
    BuildContext context,
    WidgetRef ref, {
    required List<_OnboardingStepUi> steps,
    required String? storeName,
    required String? storeUrl,
  }) {
    return steps.map((s) {
      if (s.completed) {
        return _OnboardingStepUi(
          completed: true,
          title: s.title,
          actionLabel: s.actionLabel,
          description: s.description,
          durationHint: s.durationHint,
          stepKey: s.stepKey,
          onAction: null,
        );
      }
      VoidCallback? onAction;
      final k = (s.stepKey ?? '').toLowerCase();
      final url = storeUrl?.trim();
      if (k == 'phone' ||
          k == 'store_phone' ||
          k == 'sms' ||
          k == 'sms_alerts' ||
          k == 'order_alerts_sms') {
        onAction = () => context.push('/settings');
      } else if (k == 'product' || k == 'first_product' || k == 'catalog') {
        onAction = () => context.push('/products/new');
      } else if (k == 'preview_store' || k == 'preview') {
        if (url != null && url.isNotEmpty) {
          onAction = () {
            final u = Uri.tryParse(url);
            if (u == null) return;
            ref
                .read(dashboardLocalStepCompletionsProvider.notifier)
                .markComplete(DashboardOnboardingStepKeys.previewStore);
            _postGettingStartedPreview(ref);
            launchUrl(u, mode: LaunchMode.externalApplication);
          };
        }
      } else if (k == 'share_store' || k == 'copy_link') {
        if (url != null && url.isNotEmpty) {
          onAction = () {
            Clipboard.setData(ClipboardData(text: url)).then((_) {
              ref
                  .read(dashboardLocalStepCompletionsProvider.notifier)
                  .markComplete(DashboardOnboardingStepKeys.shareStore);
              _postGettingStartedShare(ref);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Store link copied to clipboard')),
              );
            });
          };
        }
      } else if (k == 'payment' || k == 'payments' || k == 'checkout') {
        onAction = () => context.push('/payment-settings');
      } else if (k == 'shipping' || k == 'delivery') {
        onAction = () => context.push('/shipping-delivery');
      } else if (k == 'logo' || k == 'store_logo') {
        onAction = () => context.push('/store-identity');
      } else if (k == 'design' || k == 'theme' || k == 'branding' || k == 'store_identity') {
        onAction = () => context.push('/store-identity');
      } else if (k == 'share' || k == 'store_link') {
        if (url != null && url.isNotEmpty) {
          onAction = () {
            SharePlus.instance.share(ShareParams(text: url)).then((_) {
              ref
                  .read(dashboardLocalStepCompletionsProvider.notifier)
                  .markComplete(DashboardOnboardingStepKeys.shareStore);
              _postGettingStartedShare(ref);
            });
          };
        }
      } else {
        final t = s.title.toLowerCase();
        if (t.contains('sms') || (t.contains('phone') && t.contains('alert'))) {
          onAction = () => context.push('/settings');
        } else if (t.contains('product') && t.contains('first')) {
          onAction = () => context.push('/products/new');
        } else if (t.contains('preview')) {
          if (url != null && url.isNotEmpty) {
            onAction = () {
              final u = Uri.tryParse(url);
              if (u == null) return;
              ref
                  .read(dashboardLocalStepCompletionsProvider.notifier)
                  .markComplete(DashboardOnboardingStepKeys.previewStore);
              _postGettingStartedPreview(ref);
              launchUrl(u, mode: LaunchMode.externalApplication);
            };
          }
        } else if (t.contains('share') && t.contains('store')) {
          if (url != null && url.isNotEmpty) {
            onAction = () {
              Clipboard.setData(ClipboardData(text: url)).then((_) {
                ref
                    .read(dashboardLocalStepCompletionsProvider.notifier)
                    .markComplete(DashboardOnboardingStepKeys.shareStore);
                _postGettingStartedShare(ref);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Store link copied to clipboard')),
                );
              });
            };
          }
        } else if (t.contains('payment') || t.contains('checkout')) {
          onAction = () => context.push('/payment-settings');
        } else if (t.contains('shipping') || t.contains('delivery')) {
          onAction = () => context.push('/shipping-delivery');
        } else if (t.contains('logo')) {
          onAction = () => context.push('/store-identity');
        } else if (t.contains('phone')) {
          onAction = () => context.push('/settings');
        } else if (t.contains('design') || t.contains('customize')) {
          onAction = () => context.push('/store-identity');
        } else if (t.contains('share') || t.contains('store link')) {
          if (url != null && url.isNotEmpty) {
            onAction = () {
              SharePlus.instance.share(ShareParams(text: url)).then((_) {
                ref
                    .read(dashboardLocalStepCompletionsProvider.notifier)
                    .markComplete(DashboardOnboardingStepKeys.shareStore);
                _postGettingStartedShare(ref);
              });
            };
          }
        }
      }
      return _OnboardingStepUi(
        completed: s.completed,
        title: s.title,
        actionLabel: s.actionLabel,
        description: s.description,
        durationHint: s.durationHint,
        stepKey: s.stepKey,
        onAction: onAction ?? s.onAction,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overview = ref.watch(dashboardOverviewProvider);
    final data = overview.asData?.value;
    final isLiveData = data != null;
    final storeIdentity = ref.watch(dashboardStoreIdentityProvider).asData?.value;
    final storeName = storeIdentity?.name;
    final storeUrl = storeIdentity?.storeUrl;
    final authUser = ref.watch(authProvider).user;
    final tenantMap = _firstMap(data, ['tenant', 'store']);
    final tenantNameFromApi = tenantMap == null
        ? null
        : (tenantMap['name'] ?? tenantMap['storeName'])?.toString();
    final displayStoreName = (storeName != null && storeName.trim().isNotEmpty)
        ? storeName
        : tenantNameFromApi;
    final greetingName = _dashboardGreetingName(authUser, displayStoreName);

    final metrics = data?['metrics'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data!['metrics'] as Map)
        : <String, dynamic>{};

    final productsMetrics = metrics['products'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(metrics['products'] as Map)
        : <String, dynamic>{};
    final ordersMetrics = metrics['orders'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(metrics['orders'] as Map)
        : <String, dynamic>{};
    final revenueMetrics = metrics['revenue'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(metrics['revenue'] as Map)
        : <String, dynamic>{};

    final currency =
        (revenueMetrics['currencyCode'] ?? metrics['currencyCode'] ?? 'KES').toString();
    final weeklyPaid = revenueMetrics['weeklyPaid'] ?? revenueMetrics['weeklyTotal'];
    final weeklySeriesRaw = revenueMetrics['weeklySeries'] ??
        revenueMetrics['last7Days'] ??
        revenueMetrics['dailySeries'];
    final useWeekly = weeklyPaid is num || (weeklySeriesRaw is List && weeklySeriesRaw.isNotEmpty);
    num? weeklyFromSeries;
    if (weeklySeriesRaw is List) {
      for (final e in weeklySeriesRaw) {
        if (e is num) weeklyFromSeries = (weeklyFromSeries ?? 0) + e;
      }
    }
    final revenuePrimaryAmount = useWeekly
        ? (weeklyPaid is num ? weeklyPaid : weeklyFromSeries ?? 0)
        : (revenueMetrics['monthlyPaid'] ?? metrics['weeklyRevenue'] ?? metrics['revenue']);
    final revenueValue = _toCurrency(
      isLiveData ? revenuePrimaryAmount : 12450,
      currency: currency,
    );
    final comparisonLineWeekly = useWeekly;
    final revenueComparisonSubtitle = isLiveData
        ? _comparisonSubtitle(revenueMetrics, weekly: comparisonLineWeekly)
        : '+12.5% from last week';
    final revenueSecondaryLine = revenueComparisonSubtitle ??
        (useWeekly ? 'Last 7 days' : 'Current month');
    final seriesForChart = useWeekly
        ? (weeklySeriesRaw is List ? weeklySeriesRaw : null)
        : (revenueMetrics['monthlySeries'] is List
            ? revenueMetrics['monthlySeries'] as List<dynamic>
            : null);
    final barFractions = _normalizeChartFractions(seriesForChart);
    final chartHighlightIndex = _lastPositiveIndex(barFractions);
    final revenueCardTitle = useWeekly ? 'Weekly Revenue' : 'Revenue';
    final revenueBadge = useWeekly ? '7 DAYS' : 'THIS MONTH';
    final revenueCaption = useWeekly ? 'Total this week' : 'Paid this month';

    final pendingOrdersValue = _toInt(
      ordersMetrics['pending'] ??
          metrics['pendingOrders'] ??
          metrics['pending_orders'] ??
          metrics['activeOrders'],
      fallback: data == null ? 24 : 0,
    ).toString();
    final completedOrdersValue = _toInt(
      ordersMetrics['completed'] ??
          ordersMetrics['total'] ??
          metrics['completedOrders'] ??
          metrics['completed_orders'] ??
          metrics['ordersLast30Days'],
      fallback: data == null ? 182 : 0,
    ).toString();
    final lowStockItems = _extractLowStockItems(data, productsMetrics: productsMetrics);

    final gsData = ref.watch(dashboardGettingStartedProvider).valueOrNull;
    final onboardingDefaults = _defaultOnboardingStepsAfterRegistration();
    final gsItems = gsData != null ? (gsData['items'] ?? gsData['steps']) : null;
    final List<_OnboardingStepUi> parsedSteps = gsItems is List && gsItems.isNotEmpty
        ? _mergeGettingStartedItems(onboardingDefaults, gsItems)
        : _parseOnboardingStepsFromOverview(data, defaultSteps: onboardingDefaults);
    final localStepCompletions = ref.watch(dashboardLocalStepCompletionsProvider);
    final mergedSteps = _mergeLocalStepCompletion(parsedSteps, localStepCompletions);
    final onboardingSteps = _attachOnboardingActions(
      context,
      ref,
      steps: mergedSteps,
      storeName: displayStoreName,
      storeUrl: storeUrl,
    );
    final onboardingDone = onboardingSteps.where((s) => s.completed).length;
    final onboardingTotal = onboardingSteps.length;
    final allOnboardingComplete =
        onboardingSteps.isNotEmpty && onboardingSteps.every((s) => s.completed);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8 + MediaQuery.of(context).padding.top, 24, 120),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                child: Icon(Icons.person, size: 22, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Text(
                'DukaNest',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'OVERVIEW',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.primaryDark,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back, $greetingName',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if ((displayStoreName != null && displayStoreName.trim().isNotEmpty) ||
              (storeUrl != null && storeUrl.trim().isNotEmpty)) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayStoreName != null && displayStoreName.trim().isNotEmpty)
                        Text(
                          displayStoreName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      if (storeUrl != null && storeUrl.trim().isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                storeUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Copy store URL',
                              onPressed: () {
                                final u = storeUrl.trim();
                                Clipboard.setData(ClipboardData(text: u)).then((_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Store URL copied')),
                                  );
                                });
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              style: IconButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppTheme.primaryDark,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (storeUrl != null && storeUrl.trim().isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      final u = storeUrl.trim();
                      SharePlus.instance.share(ShareParams(text: u)).then((_) {
                        ref
                            .read(dashboardLocalStepCompletionsProvider.notifier)
                            .markComplete(DashboardOnboardingStepKeys.shareStore);
                        _postGettingStartedShare(ref);
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          _OverviewDataSourceBadge(isLiveData: isLiveData),
          if (!allOnboardingComplete) ...[
            const SizedBox(height: 12),
            _GettingStartedCarousel(
              completed: onboardingDone,
              total: onboardingTotal,
              steps: onboardingSteps,
            ),
          ],
          const SizedBox(height: 24),
          _weeklyRevenueCard(
            context,
            theme,
            revenueValue: revenueValue,
            title: revenueCardTitle,
            badge: revenueBadge,
            subtitle: revenueSecondaryLine,
            caption: revenueCaption,
            barFractions: barFractions,
            highlightedIndex: chartHighlightIndex,
          ),
          const SizedBox(height: 24),
          _pendingOrdersCard(theme, value: pendingOrdersValue),
          const SizedBox(height: 24),
          _completedOrdersCard(theme, value: completedOrdersValue),
          const SizedBox(height: 24),
          _stockAlertsCard(context, theme, items: lowStockItems),
          const SizedBox(height: 24),
          _growCard(context, theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _weeklyRevenueCard(
    BuildContext context,
    ThemeData theme, {
    required String revenueValue,
    required String title,
    required String badge,
    required String subtitle,
    required String caption,
    required List<double> barFractions,
    required int highlightedIndex,
  }) {
    const chartHeight = 192.0; // Tailwind h-48
    const barGap = 4.0;
    final fractions = barFractions.isEmpty
        ? List<double>.filled(7, 0.12)
        : barFractions.length < 7
            ? [...barFractions, ...List<double>.filled(7 - barFractions.length, 0.12)]
            : barFractions;
    final safeHighlight = highlightedIndex.clamp(0, fractions.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < fractions.length; i++) ...[
                  if (i > 0) const SizedBox(width: barGap),
                  Expanded(
                    child: _WeeklyRevenueBar(
                      heightFraction: fractions[i],
                      highlighted: i == safeHighlight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                revenueValue,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                caption,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pendingOrdersCard(ThemeData theme, {required String value}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppTheme.primaryDark, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryDark, size: 26),
              Text(
                'PENDING',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active Orders',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedOrdersCard(ThemeData theme, {required String value}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.check_circle_outline, color: theme.colorScheme.onSurfaceVariant, size: 26),
              Text(
                'COMPLETED',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 30 days',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockAlertsCard(
    BuildContext context,
    ThemeData theme, {
    required List<({String name, String subtitle})> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stock Alerts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ACTION REQUIRED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (items.isEmpty)
            Text(
              'No low stock alerts right now.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 16),
                child: _stockRow(context, theme, item.name, item.subtitle),
              );
            }),
        ],
      ),
    );
  }

  Widget _stockRow(BuildContext context, ThemeData theme, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/products'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              'Restock',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _growCard(BuildContext context, ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(child: ColoredBox(color: AppTheme.primaryDark)),
          Positioned(
            right: -48,
            top: -48,
            child: IgnorePointer(
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 64,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grow your store',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add new products or explore marketing insights.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.push('/products/new'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(
                        'Add Product',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/orders'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'View Orders',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal pager: one onboarding step at a time (parity with web checklist).
class _GettingStartedCarousel extends StatefulWidget {
  const _GettingStartedCarousel({
    required this.completed,
    required this.total,
    required this.steps,
  });

  final int completed;
  final int total;
  final List<_OnboardingStepUi> steps;

  @override
  State<_GettingStartedCarousel> createState() => _GettingStartedCarouselState();
}

class _GettingStartedCarouselState extends State<_GettingStartedCarousel> {
  static const _cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(12, 5, 40, 0.06),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    final steps = widget.steps;
    final firstIncomplete = steps.indexWhere((s) => !s.completed);
    final initialPage = firstIncomplete >= 0 ? firstIncomplete : 0;
    _index = initialPage;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();

    final safeTotal = widget.total <= 0 ? 1 : widget.total;
    final progress = (widget.completed / safeTotal).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.checklist_rtl, color: AppTheme.primaryDark, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Getting Started',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete these steps to get your store ready. ${widget.completed} of ${widget.total} done.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.completed}/${widget.total}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceContainerLow,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 252,
            child: PageView.builder(
              controller: _pageController,
              itemCount: steps.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _OnboardingStepCarouselCard(step: steps[i]),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _index > 0
                    ? () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Step ${_index + 1} of ${steps.length}',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _index < steps.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(steps.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primaryDark : AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepCarouselCard extends StatelessWidget {
  const _OnboardingStepCarouselCard({required this.step});

  final _OnboardingStepUi step;

  static const _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (step.completed) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _green.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (step.description != null) ...[
              const SizedBox(height: 10),
              Text(
                step.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.radio_button_unchecked, color: theme.colorScheme.outline, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (step.durationHint != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  step.durationHint!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (step.description != null) ...[
            const SizedBox(height: 10),
            Text(
              step.description!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: step.onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                step.actionLabel,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewDataSourceBadge extends StatelessWidget {
  const _OverviewDataSourceBadge({required this.isLiveData});

  final bool isLiveData;

  @override
  Widget build(BuildContext context) {
    final bg = isLiveData ? const Color(0xFFD1FAE5) : const Color(0xFFFFF4E5);
    final fg = isLiveData ? const Color(0xFF065F46) : const Color(0xFF9A3412);
    final label = isLiveData ? 'LIVE OVERVIEW DATA' : 'FALLBACK OVERVIEW DATA';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiveData ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyRevenueBar extends StatelessWidget {
  const _WeeklyRevenueBar({
    required this.heightFraction,
    required this.highlighted,
  });

  final double heightFraction;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final track = AppTheme.surfaceContainerLow;
    final fill = highlighted ? AppTheme.primary : track;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight * heightFraction;
        return Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
        );
      },
    );
  }
}

