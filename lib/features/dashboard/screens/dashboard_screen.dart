import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers/store_identity_provider.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../../onboarding/providers/auth_provider.dart';
import '../providers/dashboard_getting_started_provider.dart';
import '../providers/dashboard_local_onboarding_provider.dart';
import '../providers/dashboard_overview_provider.dart';
import '../providers/dashboard_reward_checklist_provider.dart';
import '../../products/demo_product_cleanup.dart';
import '../widgets/reward_checklist_card.dart';

/// Home dashboard aligned with Stitch screen
/// `projects/13184140852829986275/screens/a93fc25cee2c4ac98d30472dc7535058`
/// (HTML + screenshot in `docs/backend-context/stitch-exports/`).

final dashboardLastSyncedAtProvider = StateProvider<DateTime?>((ref) => null);

final connectivityStatusProvider =
    StreamProvider.autoDispose<ConnectivityResult>((ref) {
  final connectivity = Connectivity();
  ConnectivityResult toStatus(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;
    if (results.contains(ConnectivityResult.none)) {
      return ConnectivityResult.none;
    }
    return results.first;
  }

  return (() async* {
    final initial = await connectivity.checkConnectivity();
    yield toStatus(initial);
    yield* connectivity.onConnectivityChanged.map(toStatus);
  })();
});

List<_OnboardingStepUi> _mergeLocalStepCompletion(
  List<_OnboardingStepUi> steps,
  Set<String> localKeys,
) {
  if (localKeys.isEmpty) return steps;
  return steps.map((s) {
    final key = canonicalDashboardOnboardingStepKey(s.stepKey ?? '');
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

String _normalizeGettingStartedServerId(String id) =>
    canonicalDashboardOnboardingStepKey(id);

String _displayTitleForOnboardingStep(String title) {
  return title.replaceAll(
    RegExp('checkout preferences', caseSensitive: false),
    'payment preferences',
  );
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

bool _onboardingStepUiIsPreview(_OnboardingStepUi s) {
  final key = (s.stepKey ?? '').toLowerCase();
  final title = s.title.toLowerCase();
  return key.contains('preview_store') ||
      key == 'preview' ||
      (title.contains('preview') && title.contains('store'));
}

bool _onboardingStepUiIsProduct(_OnboardingStepUi s) {
  final key = (s.stepKey ?? '').toLowerCase();
  final title = s.title.toLowerCase();
  return key == 'product' ||
      key == 'first_product' ||
      key == 'catalog' ||
      (title.contains('product') &&
          title.contains('first') &&
          !title.contains('demo'));
}

bool _onboardingStepUiIsCategory(_OnboardingStepUi s) {
  final key = (s.stepKey ?? '').toLowerCase();
  final title = s.title.toLowerCase();
  return key.contains('category') || title.contains('categor');
}

bool _onboardingStepUiIsAttributes(_OnboardingStepUi s) {
  final key = (s.stepKey ?? '').toLowerCase();
  final title = s.title.toLowerCase();
  return key.contains('attribute') || title.contains('attribute');
}

bool _onboardingStepUiIsShare(_OnboardingStepUi s) {
  final key = (s.stepKey ?? '').toLowerCase();
  final title = s.title.toLowerCase();
  return key.contains('share_store') ||
      key.contains('copy_link') ||
      (title.contains('share') && title.contains('store')) ||
      title.contains('store link');
}

List<_OnboardingStepUi> _excludeAttributesFromGettingStarted(
  List<_OnboardingStepUi> steps,
) =>
    steps.where((s) => !_onboardingStepUiIsAttributes(s)).toList();

List<_OnboardingStepUi> _orderOnboardingSteps(List<_OnboardingStepUi> steps) {
  final products = <_OnboardingStepUi>[];
  final categories = <_OnboardingStepUi>[];
  final middle = <_OnboardingStepUi>[];
  final previews = <_OnboardingStepUi>[];
  final shares = <_OnboardingStepUi>[];
  for (final s in steps) {
    if (_onboardingStepUiIsShare(s)) {
      shares.add(s);
    } else if (_onboardingStepUiIsPreview(s)) {
      previews.add(s);
    } else if (_onboardingStepUiIsProduct(s)) {
      products.add(s);
    } else if (_onboardingStepUiIsCategory(s)) {
      categories.add(s);
    } else if (_onboardingStepUiIsAttributes(s)) {
      continue;
    } else {
      middle.add(s);
    }
  }
  return [
    ...categories,
    ...products,
    ...middle,
    ...previews,
    ...shares
  ];
}

void _postGettingStartedPreview(WidgetRef ref) {
  unawaited(
      ref.read(apiClientProvider).postGettingStartedAction('preview_done'));
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
  return '';
}

/// Uses the device's local clock (same as [DateTime.now]).
String _timeOfDayGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
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

int? _toIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Trial snapshot from `GET /dashboard/overview` → `data.subscription`.
class _TrialSnapshot {
  const _TrialSnapshot({
    required this.daysRemaining,
    this.totalDays,
    this.planName,
  });

  final int daysRemaining;
  final int? totalDays;
  final String? planName;

  bool get isUrgent => daysRemaining <= 3;

  double? get progressFraction {
    final total = totalDays;
    if (total == null || total <= 0) return null;
    return (daysRemaining / total).clamp(0.0, 1.0);
  }

  String get daysLabel =>
      '$daysRemaining day${daysRemaining == 1 ? '' : 's'} left in trial';
}

_TrialSnapshot? _trialSnapshotFromOverview(Map<String, dynamic>? data) {
  if (data == null) return null;
  final raw = data['subscription'];
  if (raw is! Map) return null;
  final sub = Map<String, dynamic>.from(raw);

  final daysUntilExpire = _toIntOrNull(sub['daysUntilExpire']) ??
      _toIntOrNull(sub['days_until_expire']);
  if (daysUntilExpire != null && daysUntilExpire <= 0) return null;

  var days = _toIntOrNull(sub['trialDaysRemaining']);
  if (days == null || days <= 0) {
    if (sub['inTrial'] != true) return null;
    days = daysUntilExpire;
  }
  if (days == null || days <= 0) return null;

  final planRaw = sub['planName'] ?? sub['plan_name'];
  final planName =
      planRaw is String && planRaw.trim().isNotEmpty ? planRaw.trim() : null;

  return _TrialSnapshot(
    daysRemaining: days,
    totalDays: _toIntOrNull(sub['trialDays']),
    planName: planName,
  );
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
    rawSteps = container['steps'] as List<dynamic>? ??
        container['items'] as List<dynamic>?;
  }
  rawSteps ??= data['onboardingSteps'] as List<dynamic>? ??
      data['checklist'] as List<dynamic>?;

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
        rawSteps = container['steps'] as List<dynamic>? ??
            container['items'] as List<dynamic>?;
      }
    }
  }

  if (rawSteps == null || rawSteps.isEmpty) return defaultSteps;

  final out = <_OnboardingStepUi>[];
  for (final item in rawSteps) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final completed = m['completed'] == true || m['done'] == true;
    final title =
        (m['title'] ?? m['label'] ?? m['name'] ?? '').toString().trim();
    if (title.isEmpty) continue;
    final actionLabel = (m['actionLabel'] ??
            m['action_label'] ??
            m['cta'] ??
            (completed ? 'View' : 'Continue'))
        .toString()
        .trim();
    final sk = m['key'] ?? m['id'] ?? m['stepKey'];
    final stepKey = sk is String ? sk.trim() : null;
    final descRaw = (m['description'] ?? m['subtitle'] ?? m['body'] ?? '')
        .toString()
        .trim();
    final durRaw = (m['durationHint'] ??
            m['duration_hint'] ??
            m['duration'] ??
            m['estimatedTime'] ??
            '')
        .toString()
        .trim();
    out.add(_OnboardingStepUi(
      completed: completed,
      title: _displayTitleForOnboardingStep(title),
      actionLabel: actionLabel.isEmpty ? 'Open' : actionLabel,
      description: descRaw.isEmpty ? null : descRaw,
      durationHint: durRaw.isEmpty ? null : durRaw,
      stepKey: stepKey != null && stepKey.isNotEmpty ? stepKey : null,
      onAction: null,
    ));
  }
  return out.isEmpty
      ? _excludeAttributesFromGettingStarted(defaultSteps)
      : _excludeAttributesFromGettingStarted(_orderOnboardingSteps(out));
}

/// Matches web dashboard onboarding; only SMS alerts complete right after registration.
/// Preview and share are always last (preview second-to-last, share last).
List<_OnboardingStepUi> _defaultOnboardingStepsAfterRegistration() {
  return const [
    _OnboardingStepUi(
      completed: false,
      title: 'Create your first category',
      description:
          'Group products into sections like Footwear or Groceries so shoppers can browse.',
      durationHint: 'Takes 1 minute',
      actionLabel: 'Add Category',
      stepKey: 'category',
    ),
    _OnboardingStepUi(
      completed: false,
      title: 'Add your first product',
      description: 'Create a product so customers can start buying.',
      durationHint: 'Takes 2 minutes',
      actionLabel: 'Add product',
      stepKey: 'product',
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
      title: 'Set up payment preferences',
      description:
          'Turn on Tumizi wallet as your preferred method. You can also enable Cash or M-Pesa.',
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
        final name = (item['name'] ?? item['productName'] ?? 'Low stock item')
            .toString();
        final qty = item['stock'] ??
            item['stockQuantity'] ??
            item['quantity'] ??
            item['available'];
        final subtitle =
            qty is num ? 'Only ${qty.toInt()} units left' : 'Needs restock';
        return (name: name, subtitle: subtitle);
      }).toList();
      if (mapped.isNotEmpty) return mapped.take(3).toList();
    }
    final lowCount = _toInt(
      productsMetrics?['lowStock'] ??
          productsMetrics?['low_stock'] ??
          data['lowStockCount'],
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

  String? _comparisonSubtitle(Map<String, dynamic> revenueMetrics,
      {required bool weekly}) {
    final keys = weekly
        ? [
            'weekOverWeekChangePercent',
            'weekOverWeekPercent',
            'wowPercent',
            'weekOverWeekChange'
          ]
        : ['monthOverMonthChangePercent', 'momPercent', 'monthOverMonthChange'];
    for (final k in keys) {
      final v = revenueMetrics[k];
      if (v is num) {
        final sign = v >= 0 ? '+' : '';
        return '$sign${v.toStringAsFixed(1)}% from last ${weekly ? 'week' : 'month'}';
      }
    }
    final label =
        revenueMetrics['comparisonLabel'] ?? revenueMetrics['trendLabel'];
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
      } else if (k == 'category' ||
          k == 'categories' ||
          k == 'first_category' ||
          k == 'catalog_category') {
        onAction = () => context.push('/categories/new');
      } else if (k == 'attribute' ||
          k == 'attributes' ||
          k == 'product_attributes') {
        onAction = () => context.push('/attributes/new');
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
      } else if (k == 'demo_products' ||
          k.contains('demo_product') ||
          k == 'remove_demo_products') {
        onAction = () => handleDemoProductCleanup(context: context, ref: ref);
      } else if (k == 'payment' || k == 'payments' || k == 'checkout') {
        onAction = () => context.push('/payment-settings');
      } else if (k == 'shipping' || k == 'delivery') {
        onAction = () => context.push('/shipping-delivery');
      } else if (k == 'logo' || k == 'store_logo') {
        onAction = () =>
            context.push('/store-identity?tutorial=1&focus=logo');
      } else if (k == 'design' ||
          k == 'theme' ||
          k == 'branding' ||
          k == 'store_identity') {
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
        } else if (t.contains('categor')) {
          onAction = () => context.push('/categories/new');
        } else if (t.contains('attribute')) {
          onAction = () => context.push('/attributes/new');
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
                  const SnackBar(
                      content: Text('Store link copied to clipboard')),
                );
              });
            };
          }
        } else if (t.contains('payment') || t.contains('checkout')) {
          onAction = () => context.push('/payment-settings');
        } else if (t.contains('shipping') || t.contains('delivery')) {
          onAction = () => context.push('/shipping-delivery');
        } else if (t.contains('logo')) {
          onAction = () =>
              context.push('/store-identity?tutorial=1&focus=logo');
        } else if (t.contains('demo') &&
            (t.contains('product') || t.contains('sample'))) {
          onAction = () => handleDemoProductCleanup(context: context, ref: ref);
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
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    final isOnline = connectivityStatus.maybeWhen(
      data: (status) => status != ConnectivityResult.none,
      orElse: () => true,
    );
    final overview = ref.watch(dashboardOverviewProvider);
    final data = overview.asData?.value;
    final isLiveData = data != null;
    final storeIdentity = ref.watch(storeIdentityProvider).asData?.value;
    final storeName = storeIdentity?.name;
    final storeUrl = storeIdentity?.storeUrl;
    final lastSyncedAt = ref.watch(dashboardLastSyncedAtProvider);
    if (isLiveData && lastSyncedAt == null) {
      Future.microtask(() {
        ref.read(dashboardLastSyncedAtProvider.notifier).state = DateTime.now();
      });
    }
    final authUser = ref.watch(authProvider).user;
    final tenantMap = _firstMap(data, ['tenant', 'store']);
    final tenantNameFromApi = tenantMap == null
        ? null
        : (tenantMap['name'] ?? tenantMap['storeName'])?.toString();
    final displayStoreName = (storeName != null && storeName.trim().isNotEmpty)
        ? storeName
        : tenantNameFromApi;
    final greetingName = _dashboardGreetingName(authUser, displayStoreName);
    final greetingPrefix = _timeOfDayGreeting(DateTime.now());

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
        (revenueMetrics['currencyCode'] ?? metrics['currencyCode'] ?? 'KES')
            .toString();
    final weeklyPaid =
        revenueMetrics['weeklyPaid'] ?? revenueMetrics['weeklyTotal'];
    final weeklySeriesRaw = revenueMetrics['weeklySeries'] ??
        revenueMetrics['last7Days'] ??
        revenueMetrics['dailySeries'];
    final useWeekly = weeklyPaid is num ||
        (weeklySeriesRaw is List && weeklySeriesRaw.isNotEmpty);
    num? weeklyFromSeries;
    if (weeklySeriesRaw is List) {
      for (final e in weeklySeriesRaw) {
        if (e is num) weeklyFromSeries = (weeklyFromSeries ?? 0) + e;
      }
    }
    final revenuePrimaryAmount = useWeekly
        ? (weeklyPaid is num ? weeklyPaid : weeklyFromSeries ?? 0)
        : (revenueMetrics['monthlyPaid'] ??
            metrics['weeklyRevenue'] ??
            metrics['revenue']);
    final revenueValue = _toCurrency(revenuePrimaryAmount, currency: currency);
    final comparisonLineWeekly = useWeekly;
    final revenueComparisonSubtitle =
        _comparisonSubtitle(revenueMetrics, weekly: comparisonLineWeekly);
    final revenueSecondaryLine = revenueComparisonSubtitle ??
        (useWeekly ? 'Last 7 days' : 'Current month');
    final seriesForChart = useWeekly
        ? (weeklySeriesRaw is List ? weeklySeriesRaw : null)
        : (revenueMetrics['monthlySeries'] is List
            ? revenueMetrics['monthlySeries'] as List<dynamic>
            : null);
    final barFractions = _normalizeChartFractions(seriesForChart);
    final chartHighlightIndex = _lastPositiveIndex(barFractions);
    final revenueBadge = useWeekly ? '7 DAYS' : 'THIS MONTH';
    final revenueCaption = useWeekly ? 'Total this week' : 'Paid this month';

    final pendingOrdersValue = _toInt(
      ordersMetrics['pending'] ??
          metrics['pendingOrders'] ??
          metrics['pending_orders'] ??
          metrics['activeOrders'],
      fallback: 0,
    ).toString();
    final productsLiveValue = _toInt(
      productsMetrics['live'] ??
          productsMetrics['active'] ??
          productsMetrics['published'] ??
          productsMetrics['total'] ??
          metrics['productsLive'] ??
          metrics['totalProducts'],
      fallback: 0,
    ).toString();
    final storeViewsValue = _toInt(
      metrics['storeViews'] ??
          metrics['store_views'] ??
          metrics['visitors'] ??
          metrics['views'] ??
          tenantMap?['views'] ??
          tenantMap?['storeViews'],
      fallback: 0,
    ).toString();
    final completedOrdersValue = _toInt(
      ordersMetrics['completed'] ??
          ordersMetrics['total'] ??
          metrics['completedOrders'] ??
          metrics['completed_orders'] ??
          metrics['ordersLast30Days'],
      fallback: 0,
    ).toString();
    final lowStockItems =
        _extractLowStockItems(data, productsMetrics: productsMetrics);
    final lowStockCount = _toInt(
      productsMetrics['lowStock'] ??
          productsMetrics['low_stock'] ??
          data?['lowStockCount'],
      fallback: lowStockItems.isEmpty ? 0 : lowStockItems.length,
    );

    final gsData = ref.watch(dashboardGettingStartedProvider).valueOrNull;
    final onboardingDefaults = _defaultOnboardingStepsAfterRegistration();
    final gsItems =
        gsData != null ? (gsData['items'] ?? gsData['steps']) : null;
    final List<_OnboardingStepUi> parsedSteps =
        gsItems is List && gsItems.isNotEmpty
            ? _mergeGettingStartedItems(onboardingDefaults, gsItems)
            : _parseOnboardingStepsFromOverview(data,
                defaultSteps: onboardingDefaults);
    final localStepCompletions =
        ref.watch(dashboardLocalStepCompletionsProvider);
    final mergedSteps =
        _mergeLocalStepCompletion(parsedSteps, localStepCompletions);
    final gettingStartedSteps = _excludeAttributesFromGettingStarted(mergedSteps);
    final onboardingSteps = _attachOnboardingActions(
      context,
      ref,
      steps: gettingStartedSteps,
      storeName: displayStoreName,
      storeUrl: storeUrl,
    );
    final onboardingDone = onboardingSteps.where((s) => s.completed).length;
    final onboardingTotal = onboardingSteps.length;
    final allOnboardingComplete =
        onboardingSteps.isNotEmpty && onboardingSteps.every((s) => s.completed);
    final trial = _trialSnapshotFromOverview(data);

    Future<void> refreshDashboard() async {
      ref.invalidate(dashboardOverviewProvider);
      ref.invalidate(dashboardGettingStartedProvider);
      ref.invalidate(dashboardRewardChecklistProvider);
      await Future.wait([
        ref.read(dashboardOverviewProvider.future),
        ref.read(dashboardGettingStartedProvider.future),
        ref.read(dashboardRewardChecklistProvider.future),
      ]);
      ref.read(dashboardLastSyncedAtProvider.notifier).state = DateTime.now();
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: refreshDashboard,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              20, 8 + MediaQuery.of(context).padding.top, 20, 120),
          children: [
            DashboardPageHeader(
              title: greetingName.isEmpty
                  ? greetingPrefix
                  : '$greetingPrefix, $greetingName',
              subtitle: isOnline ? 'Online' : 'Offline',
              subtitleColor: isOnline
                  ? const Color(0xFF16A34A)
                  : theme.colorScheme.onSurfaceVariant,
              actions: [
                IconButton.filledTonal(
                  onPressed: () => refreshDashboard(),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton.filledTonal(
                  onPressed: () => context.push('/notifications'),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton.filledTonal(
                  onPressed: () => context.push('/settings'),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Store Settings',
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
            if (trial != null) ...[
              const SizedBox(height: 12),
              _TrialPeriodBanner(
                trial: trial,
                onUpgrade: () => context.push('/subscription'),
              ),
            ],
            if (storeUrl != null && storeUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _storeUrlShareRow(
                context,
                ref,
                storeUrl: storeUrl,
                storeName: displayStoreName,
              ),
            ],
            const SizedBox(height: 14),
            const RewardChecklistCard(),
            const SizedBox(height: 16),
            _quickActionRow(context),
            const SizedBox(height: 18),
            _metricsGrid(
              theme,
              revenueValue: revenueValue,
              revenueCaption: revenueCaption,
              pendingOrdersValue: pendingOrdersValue,
              productsLiveValue: productsLiveValue,
              storeViewsValue: storeViewsValue,
            ),
            const SizedBox(height: 14),
            _weeklyRevenueCard(
              context,
              theme,
              revenueValue: revenueValue,
              title: 'Revenue trend',
              badge: revenueBadge,
              subtitle: revenueSecondaryLine,
              caption: revenueCaption,
              barFractions: barFractions,
              highlightedIndex: chartHighlightIndex,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _compactSummaryCard(
                    theme,
                    label: 'ORDERS COMPLETED',
                    value: completedOrdersValue,
                    caption: 'Last 30 days',
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _compactSummaryCard(
                    theme,
                    label: 'STOCK ALERTS',
                    value: lowStockCount.toString(),
                    caption: lowStockItems.isEmpty
                        ? 'All in stock'
                        : 'Review inventory',
                    icon: Icons.inventory_2_outlined,
                    accentColor: lowStockItems.isEmpty
                        ? const Color(0xFF16A34A)
                        : theme.colorScheme.error,
                    onTap: () => context.go('/products'),
                  ),
                ),
              ],
            ),
            if (lowStockItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              _stockAlertsCard(context, theme, items: lowStockItems),
            ],
            if (!allOnboardingComplete) ...[
              const SizedBox(height: 14),
              _GettingStartedCarousel(
                completed: onboardingDone,
                total: onboardingTotal,
                steps: onboardingSteps,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _storeUrlShareRow(
    BuildContext context,
    WidgetRef ref, {
    required String storeUrl,
    required String? storeName,
  }) {
    final theme = Theme.of(context);
    final trimmedUrl = storeUrl.trim();
    final resolvedName = (storeName != null && storeName.trim().isNotEmpty)
        ? storeName.trim()
        : 'my store';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.language_rounded,
              size: 18,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: trimmedUrl)).then((_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store URL copied')),
                  );
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YOUR STORE URL',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trimmedUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: trimmedUrl)).then((_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Store URL copied')),
                );
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceContainerLow,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              minimumSize: const Size(34, 34),
              fixedSize: const Size(34, 34),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            tooltip: 'Copy store URL',
            icon: const Icon(Icons.copy_rounded, size: 17),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: () {
              final shareText =
                  'Shop with $resolvedName on DukaNest.\nBrowse products and order here: $trimmedUrl';
              SharePlus.instance.share(ShareParams(text: shareText)).then((_) {
                ref
                    .read(dashboardLocalStepCompletionsProvider.notifier)
                    .markComplete(DashboardOnboardingStepKeys.shareStore);
                _postGettingStartedShare(ref);
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(34, 34),
              fixedSize: const Size(34, 34),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            tooltip: 'Share store',
            icon: const Icon(Icons.share_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _quickActionRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _quickActionChip(
            context,
            icon: Icons.add_rounded,
            label: 'Add product',
            onTap: () => context.push('/products/new'),
          ),
          _quickActionChip(
            context,
            icon: Icons.shopping_bag_outlined,
            label: 'Orders',
            onTap: () => context.go('/orders'),
          ),
          _quickActionChip(
            context,
            icon: Icons.bar_chart_rounded,
            label: 'Analytics',
            onTap: () => context.go('/analytics'),
          ),
          _quickActionChip(
            context,
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
            onTap: () => context.go('/products'),
          ),
        ],
      ),
    );
  }

  Widget _quickActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: AppTheme.primaryDark),
        label: Text(label),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: AppTheme.primaryDark,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: AppTheme.surfaceContainerLowest,
        side:
            BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onPressed: onTap,
      ),
    );
  }

  Widget _metricsGrid(
    ThemeData theme, {
    required String revenueValue,
    required String revenueCaption,
    required String pendingOrdersValue,
    required String productsLiveValue,
    required String storeViewsValue,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _homeMetricCard(
                theme,
                title: 'Revenue',
                value: revenueValue,
                caption: revenueCaption,
                icon: Icons.payments_outlined,
                highlighted: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _homeMetricCard(
                theme,
                title: 'Pending orders',
                value: pendingOrdersValue,
                caption: pendingOrdersValue == '0'
                    ? 'No orders yet'
                    : 'Needs attention',
                icon: Icons.shopping_bag_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _homeMetricCard(
                theme,
                title: 'Products live',
                value: productsLiveValue,
                caption: productsLiveValue == '0'
                    ? 'Add your first'
                    : 'Published items',
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _homeMetricCard(
                theme,
                title: 'Store views',
                value: storeViewsValue,
                caption:
                    storeViewsValue == '0' ? 'Not yet shared' : 'Total visits',
                icon: Icons.visibility_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _homeMetricCard(
    ThemeData theme, {
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    bool highlighted = false,
  }) {
    final foreground = highlighted ? Colors.white : theme.colorScheme.onSurface;
    final muted = highlighted
        ? Colors.white.withValues(alpha: 0.72)
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.primary : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? null
            : Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: highlighted ? _cardShadow : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(icon, size: 17, color: muted),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactSummaryCard(
    ThemeData theme, {
    required String label,
    required String value,
    required String caption,
    required IconData icon,
    Color? accentColor,
    VoidCallback? onTap,
  }) {
    final accent = accentColor ?? theme.colorScheme.onSurfaceVariant;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Icon(icon, size: 17, color: accent),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
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
    const chartHeight = 124.0;
    const barGap = 4.0;
    final fractions = barFractions.isEmpty
        ? List<double>.filled(7, 0.12)
        : barFractions.length < 7
            ? [
                ...barFractions,
                ...List<double>.filled(7 - barFractions.length, 0.12)
              ]
            : barFractions;
    final safeHighlight = highlightedIndex.clamp(0, fractions.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(16),
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
                        fontWeight: FontWeight.w800,
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
              _periodChip(theme, '7d', selected: badge == '7 DAYS'),
              const SizedBox(width: 4),
              _periodChip(theme, '30d', selected: badge != '7 DAYS'),
              const SizedBox(width: 4),
              _periodChip(theme, '3m'),
            ],
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.65),
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      revenueValue,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: subtitle.startsWith('+')
                      ? const Color(0xFF16A34A)
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodChip(ThemeData theme, String label, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? Colors.white : AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: selected
            ? Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.45))
            : null,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: selected
              ? AppTheme.primaryDark
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                padding:
                    EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 16),
                child: _stockRow(context, theme, item.name, item.subtitle),
              );
            }),
        ],
      ),
    );
  }

  Widget _stockRow(
      BuildContext context, ThemeData theme, String title, String subtitle) {
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
            child: Icon(Icons.inventory_2_outlined,
                color: theme.colorScheme.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
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
}

class _TrialPeriodBanner extends StatelessWidget {
  const _TrialPeriodBanner({
    required this.trial,
    required this.onUpgrade,
  });

  final _TrialSnapshot trial;
  final VoidCallback onUpgrade;

  static const _amber = Color(0xFFB45309);
  static const _amberSoft = Color(0xFFFFF7ED);
  static const _amberBorder = Color(0xFFFCD34D);
  static const _urgent = Color(0xFFDC2626);
  static const _urgentSoft = Color(0xFFFEF2F2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgent = trial.isUrgent;
    final accent = urgent ? _urgent : _amber;
    final background = urgent ? _urgentSoft : _amberSoft;
    final border = urgent
        ? _urgent.withValues(alpha: 0.28)
        : _amberBorder.withValues(alpha: 0.85);
    final progress = trial.progressFraction;

    return Semantics(
      label: trial.daysLabel,
      button: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onUpgrade,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        urgent
                            ? Icons.schedule_rounded
                            : Icons.auto_awesome_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FREE TRIAL',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              children: [
                                TextSpan(
                                  text: '${trial.daysRemaining}',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' day${trial.daysRemaining == 1 ? '' : 's'} left',
                                ),
                              ],
                            ),
                          ),
                          if (trial.planName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${trial.planName} plan',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      color: accent,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: onUpgrade,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.12),
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      urgent ? 'Upgrade before trial ends' : 'View plans',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
  State<_GettingStartedCarousel> createState() =>
      _GettingStartedCarouselState();
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
  bool _expanded = false;
  int? _lastChecklistScrollTarget;
  final Map<int, GlobalKey> _checklistItemKeys = <int, GlobalKey>{};

  static const _checklistHeight = 118.0;
  static const _doneGreen = Color(0xFF16A34A);

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

  int _firstIncompleteStepIndex(List<_OnboardingStepUi> steps) {
    final idx = steps.indexWhere((s) => !s.completed);
    return idx >= 0 ? idx : 0;
  }

  int _resolveFocusIndex(List<_OnboardingStepUi> steps) {
    if (steps.isEmpty) return 0;
    final idx = _index.clamp(0, steps.length - 1);
    if (!steps[idx].completed) return idx;
    for (var i = idx + 1; i < steps.length; i++) {
      if (!steps[i].completed) return i;
    }
    for (var i = 0; i < idx; i++) {
      if (!steps[i].completed) return i;
    }
    return idx;
  }

  GlobalKey _checklistKeyFor(int index) {
    return _checklistItemKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'getting_started_checklist:$index'),
    );
  }

  void _scrollChecklistToIndex(int index) {
    if (_lastChecklistScrollTarget == index) return;
    _lastChecklistScrollTarget = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _checklistKeyFor(index).currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.35,
      );
    });
  }

  Future<void> _goToStep(int target) async {
    if (!mounted) return;
    final steps = widget.steps;
    if (steps.isEmpty) return;
    final clamped = target.clamp(0, steps.length - 1);
    if (clamped != _index) {
      setState(() => _index = clamped);
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          clamped,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
    _lastChecklistScrollTarget = null;
    _scrollChecklistToIndex(clamped);
  }

  bool _stepsCompletionChanged(
    List<_OnboardingStepUi> before,
    List<_OnboardingStepUi> after,
  ) {
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      if (before[i].completed != after[i].completed) return true;
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant _GettingStartedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_stepsCompletionChanged(oldWidget.steps, widget.steps)) return;

    final focus = _resolveFocusIndex(widget.steps);
    if (focus != _index && _pageController.hasClients) {
      setState(() => _index = focus);
      _pageController.animateToPage(
        focus,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    _lastChecklistScrollTarget = null;
    _scrollChecklistToIndex(focus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();

    final safeTotal = widget.total <= 0 ? 1 : widget.total;
    final progress = (widget.completed / safeTotal).clamp(0.0, 1.0);
    final focusIndex = _resolveFocusIndex(steps);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_expanded) return;
      _scrollChecklistToIndex(focusIndex);
    });

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rtl,
                      color: AppTheme.primaryDark, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Getting started',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: AppTheme.surfaceContainerLow,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${widget.completed}/${widget.total} done',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Text(
                  'Complete these steps to get your store ready.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 252,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: steps.length,
                    onPageChanged: (i) {
                      setState(() => _index = i);
                      _lastChecklistScrollTarget = null;
                      _scrollChecklistToIndex(i);
                    },
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
                          ? () => _goToStep(_index - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Step ${_index + 1} of ${steps.length}',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _index < steps.length - 1
                          ? () => _goToStep(_index + 1)
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
                        color: active
                            ? AppTheme.primaryDark
                            : AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: SizedBox(
                    height: _checklistHeight,
                    child: ListView.separated(
                      itemCount: steps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final step = steps[i];
                        final selected = i == focusIndex;
                        final inProgress = selected && !step.completed;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _goToStep(i),
                            child: Container(
                              key: _checklistKeyFor(i),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primary.withValues(alpha: 0.08)
                                    : AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.primary.withValues(alpha: 0.3)
                                      : AppTheme.outlineVariant
                                          .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    step.completed
                                        ? Icons.check_circle_rounded
                                        : inProgress
                                            ? Icons.hourglass_top_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded,
                                    size: 16,
                                    color: step.completed
                                        ? _doneGreen
                                        : inProgress
                                            ? AppTheme.primary
                                            : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      step.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: step.completed
                                            ? theme.colorScheme.onSurfaceVariant
                                            : selected
                                                ? AppTheme.primaryDark
                                                : theme.colorScheme.onSurface,
                                        decoration: step.completed
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    step.completed
                                        ? 'Done'
                                        : inProgress
                                            ? 'Next'
                                            : 'Todo',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: step.completed
                                          ? _doneGreen
                                          : inProgress
                                              ? AppTheme.primary
                                              : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
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
                const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 26),
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
              Icon(Icons.radio_button_unchecked,
                  color: theme.colorScheme.outline, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (step.durationHint != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                step.actionLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
        );
      },
    );
  }
}
