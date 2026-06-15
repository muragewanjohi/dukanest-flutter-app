import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/providers/first_run_tutorial_seen_provider.dart';
import '../../../core/providers/store_identity_provider.dart';
import '../../dashboard/providers/dashboard_getting_started_provider.dart';
import '../../dashboard/providers/dashboard_local_onboarding_provider.dart';
import '../../products/demo_product_cleanup.dart';

class _TutorialStep {
  const _TutorialStep({
    required this.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.completed,
    required this.icon,
    this.route,
  });

  final String key;
  final String title;
  final String description;
  final String actionLabel;
  final bool completed;
  final IconData icon;
  final String? route;

  _TutorialStep copyWith({
    String? key,
    String? title,
    String? description,
    String? actionLabel,
    bool? completed,
    IconData? icon,
    String? route,
  }) {
    return _TutorialStep(
      key: key ?? this.key,
      title: title ?? this.title,
      description: description ?? this.description,
      actionLabel: actionLabel ?? this.actionLabel,
      completed: completed ?? this.completed,
      icon: icon ?? this.icon,
      route: route ?? this.route,
    );
  }
}

class FirstRunTutorialScreen extends ConsumerStatefulWidget {
  const FirstRunTutorialScreen({super.key});

  @override
  ConsumerState<FirstRunTutorialScreen> createState() =>
      _FirstRunTutorialScreenState();
}

class _FirstRunTutorialScreenState
    extends ConsumerState<FirstRunTutorialScreen> {
  static const _doneGreen = Color(0xFF16A34A);
  final _pageController = PageController();
  final Set<String> _localCompleted = <String>{};
  int _index = 0;
  bool _finishing = false;
  bool _pageSyncScheduled = false;
  int? _lastChecklistScrollTarget;
  final Map<int, GlobalKey> _checklistItemKeys = <int, GlobalKey>{};

  static const _fallbackSteps = <_TutorialStep>[
    _TutorialStep(
      key: 'first_category',
      title: 'Create your first category',
      description:
          'Group products into catalog sections like Footwear or Groceries so shoppers can browse.',
      actionLabel: 'Add Category',
      completed: false,
      icon: Icons.category_outlined,
      route: '/categories/new',
    ),
    _TutorialStep(
      key: 'product',
      title: 'Add your first product',
      description:
          'Create at least one product so shoppers can browse and place orders.',
      actionLabel: 'Open products',
      completed: false,
      icon: Icons.inventory_2_outlined,
      route: '/products/new',
    ),
    _TutorialStep(
      key: 'shipping',
      title: 'Configure delivery & shipping',
      description: 'Set up flat rate or delivery zones for orders.',
      actionLabel: 'Configure shipping',
      completed: false,
      icon: Icons.local_shipping_outlined,
      route: '/shipping-delivery',
    ),
    _TutorialStep(
      key: 'payment',
      title: 'Set up payment preferences',
      description:
          'Turn on Tumizi wallet as your preferred method. You can also enable Cash or M-Pesa.',
      actionLabel: 'Set up payments',
      completed: false,
      icon: Icons.payments_outlined,
      route: '/payment-settings',
    ),
    _TutorialStep(
      key: 'logo',
      title: 'Add your store logo',
      description: 'Brand your storefront with a logo.',
      actionLabel: 'Add logo',
      completed: false,
      icon: Icons.storefront_outlined,
      route: '/store-identity',
    ),
    _TutorialStep(
      key: 'preview_store',
      title: 'Preview your store',
      description:
          'Open your storefront in the browser to see what buyers see.',
      actionLabel: 'Preview store',
      completed: false,
      icon: Icons.visibility_outlined,
      route: '/dashboard',
    ),
    _TutorialStep(
      key: 'share_store',
      title: 'Share your store',
      description: 'Copy and share your store URL with customers.',
      actionLabel: 'Open dashboard',
      completed: false,
      icon: Icons.share_outlined,
      route: '/dashboard',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  IconData _iconForStep(String key, String title) {
    final k = key.toLowerCase();
    final t = title.toLowerCase();
    if (k.contains('attribute') || t.contains('attribute')) {
      return Icons.tune_outlined;
    }
    if (k.contains('category') || t.contains('categor')) {
      return Icons.category_outlined;
    }
    return _iconForKey(key);
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'product':
        return Icons.inventory_2_outlined;
      case 'shipping':
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'payment':
        return Icons.payments_outlined;
      case 'logo':
        return Icons.storefront_outlined;
      case 'preview':
      case 'preview_store':
        return Icons.visibility_outlined;
      case 'share':
      case 'share_store':
        return Icons.share_outlined;
      case 'sms':
      case 'contact_phone':
        return Icons.sms_outlined;
      case 'category':
      case 'categories':
      case 'first_category':
        return Icons.category_outlined;
      case 'attribute':
      case 'attributes':
      case 'product_attributes':
        return Icons.tune_outlined;
      default:
        return Icons.checklist_rtl;
    }
  }

  /// When the API omits a step id we still map common titles to deep links.
  String? _inferRouteFromTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('attribute')) return '/attributes/new';
    if (t.contains('categor')) return '/categories/new';
    if (t.contains('product') &&
        (t.contains('first') ||
            t.contains('add your') ||
            t.contains('add a'))) {
      return '/products/new';
    }
    if (t.contains('shipping') || t.contains('delivery')) {
      return '/shipping-delivery';
    }
    if (t.contains('payment') ||
        (t.contains('checkout') && t.contains('prefer'))) {
      return '/payment-settings';
    }
    if (t.contains('logo') || (t.contains('brand') && t.contains('store'))) {
      return '/store-identity';
    }
    return null;
  }

  String _displayTitleForStep(String title) {
    return title.replaceAll(
      RegExp('checkout preferences', caseSensitive: false),
      'payment preferences',
    );
  }

  String _footerCtaLabel(_TutorialStep step) {
    if (_isShareStoreStep(step)) return 'Share link';
    if (_isPreviewStoreStep(step)) return 'Preview store';
    if (_isRemoveDemoProductsStep(step)) return 'Remove demo products';
    final k = step.key.toLowerCase();
    final t = step.title.toLowerCase();
    if (k.contains('category') || t.contains('categor')) return 'Add Category';
    if (k.contains('attribute') || t.contains('attribute')) {
      return 'Add attribute';
    }
    if (k.contains('product') ||
        k.contains('catalog') ||
        (t.contains('product') && !t.contains('demo'))) {
      return 'Add product';
    }
    if (k.contains('shipping') ||
        k.contains('delivery') ||
        t.contains('shipping') ||
        t.contains('deliver')) {
      return 'Configure shipping';
    }
    if (k.contains('sms') ||
        k.contains('contact_phone') ||
        (t.contains('sms') || (t.contains('phone') && t.contains('alert')))) {
      return 'Open settings';
    }
    if (k.contains('payment') ||
        k.contains('checkout') ||
        t.contains('payment') ||
        t.contains('checkout')) {
      return 'Set up payments';
    }
    if (k.contains('logo') ||
        k.contains('store_identity') ||
        t.contains('logo')) {
      return 'Add logo';
    }
    if (step.actionLabel.trim().isNotEmpty) return step.actionLabel.trim();
    return 'Continue';
  }

  bool _isStepMarkedCompleteLocally(
    String stepKey,
    String canonical,
    Set<String> syncedCompletions,
  ) {
    final raw = stepKey.toLowerCase();
    if (_localCompleted.contains(raw)) return true;
    if (canonical.isNotEmpty && _localCompleted.contains(canonical)) {
      return true;
    }
    return canonical.isNotEmpty && syncedCompletions.contains(canonical);
  }

  void _persistGettingStartedPreviewOrShare({
    required String stepKey,
    required bool preview,
  }) {
    final raw = stepKey.trim().toLowerCase();
    final canonical = canonicalDashboardOnboardingStepKey(stepKey);
    if (raw.isNotEmpty) _localCompleted.add(raw);
    if (canonical.isNotEmpty) _localCompleted.add(canonical);

    final storeKey = preview
        ? DashboardOnboardingStepKeys.previewStore
        : DashboardOnboardingStepKeys.shareStore;
    ref.read(dashboardLocalStepCompletionsProvider.notifier).markComplete(
          storeKey,
        );
    unawaited(
      ref.read(apiClientProvider).postGettingStartedAction(
            preview ? 'preview_done' : 'share_done',
          ),
    );
  }

  List<_TutorialStep> _mergedSteps() {
    final gsData = ref.read(dashboardGettingStartedProvider).valueOrNull;
    final syncedCompletions = ref.read(dashboardLocalStepCompletionsProvider);
    final stepsBase = _stepsFromGettingStarted(gsData);
    return stepsBase.map((s) {
      final canonical = canonicalDashboardOnboardingStepKey(s.key);
      final done = s.completed ||
          _isStepMarkedCompleteLocally(s.key, canonical, syncedCompletions);
      return s.copyWith(completed: done);
    }).toList();
  }

  /// Index to show in the carousel and checklist when the current step is done.
  int _resolveFocusIndex(List<_TutorialStep> steps) {
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

  void _schedulePageSyncIfNeeded(List<_TutorialStep> steps) {
    final target = _resolveFocusIndex(steps);
    if (target == _index || _pageSyncScheduled) return;
    _pageSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _pageSyncScheduled = false;
      if (!mounted) return;
      await _goToStep(target);
    });
  }

  Future<void> _goToStep(int target) async {
    if (!mounted) return;
    final merged = _mergedSteps();
    if (merged.isEmpty) return;
    final clamped = target.clamp(0, merged.length - 1);
    if (clamped != _index) {
      setState(() => _index = clamped);
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          clamped,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    }
    _scrollChecklistToIndex(clamped);
  }

  GlobalKey _checklistKeyFor(int index) {
    return _checklistItemKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'tutorial_checklist:$index'),
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

  void _syncChecklistScrollToFocus(int focusIndex) {
    _scrollChecklistToIndex(focusIndex);
  }

  Future<void> _primaryFooterAction(
      List<_TutorialStep> steps, int total) async {
    if (_finishing) return;
    final safeIndex = _resolveFocusIndex(steps).clamp(0, total - 1);
    final isLast = safeIndex >= total - 1;
    if (isLast && steps[safeIndex].completed) {
      await _completeTutorial();
      return;
    }
    final step = steps[safeIndex];
    if (!step.completed && _canExecuteStep(step)) {
      await _openStep(step);
      if (!mounted) return;
      _schedulePageSyncIfNeeded(_mergedSteps());
      return;
    }
    if (!step.completed) {
      await _next(total);
      return;
    }
    final nextFocus = _resolveFocusIndex(steps);
    if (nextFocus != safeIndex) {
      await _goToStep(nextFocus);
      return;
    }
    if (isLast) {
      await _completeTutorial();
      return;
    }
    await _next(total);
  }

  String? _routeForKey(String key) {
    switch (key) {
      case 'product':
      case 'first_product':
      case 'catalog':
        return '/products/new';
      case 'category':
      case 'categories':
      case 'first_category':
      case 'catalog_category':
        return '/categories/new';
      case 'attribute':
      case 'attributes':
      case 'product_attributes':
        return '/attributes/new';
      case 'shipping':
      case 'delivery':
        return '/shipping-delivery';
      case 'payment':
      case 'payments':
      case 'checkout':
        return '/payment-settings';
      case 'logo':
      case 'store_logo':
      case 'design':
      case 'branding':
      case 'store_identity':
        return '/store-identity';
      case 'sms':
      case 'contact_phone':
      case 'store_phone':
        return '/settings';
      case 'preview':
      case 'preview_store':
      case 'share':
      case 'share_store':
        return '/dashboard';
      default:
        return null;
    }
  }

  List<_TutorialStep> _stepsFromGettingStarted(Map<String, dynamic>? gsData) {
    final items = gsData?['items'] ?? gsData?['steps'];
    if (items is! List || items.isEmpty) {
      return _orderTutorialSteps(List<_TutorialStep>.of(_fallbackSteps));
    }

    final out = <_TutorialStep>[];
    for (final raw in items.whereType<Map>()) {
      final m = Map<String, dynamic>.from(raw);
      final key = (m['id'] ?? m['key'] ?? m['stepKey'] ?? '').toString().trim();
      final title = (m['label'] ?? m['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final normalizedKey =
          key.isEmpty ? title.toLowerCase() : key.toLowerCase();
      if (_isAttributesKeyOrTitle(normalizedKey, title)) continue;
      final desc = (m['description'] ?? m['subtitle'] ?? '').toString().trim();
      final cta =
          (m['cta'] ?? m['actionLabel'] ?? 'Continue').toString().trim();
      final completed = m['completed'] == true || m['done'] == true;
      final route = _routeForKey(normalizedKey) ?? _inferRouteFromTitle(title);
      out.add(
        _TutorialStep(
          key: normalizedKey,
          title: _displayTitleForStep(title),
          description: desc.isEmpty
              ? 'Complete this setup step to keep your store ready.'
              : desc,
          actionLabel: cta.isEmpty ? 'Continue' : cta,
          completed: completed,
          icon: _iconForStep(normalizedKey, title),
          route: route,
        ),
      );
    }
    if (out.isEmpty) {
      return _orderTutorialSteps(List<_TutorialStep>.of(_fallbackSteps));
    }
    return _orderTutorialSteps(out);
  }

  bool _isAttributesKeyOrTitle(String key, String title) {
    final k = key.toLowerCase();
    final t = title.toLowerCase();
    return k.contains('attribute') || t.contains('attribute');
  }

  /// Category, then product; preview/share stay last.
  List<_TutorialStep> _orderTutorialSteps(List<_TutorialStep> steps) {
    final products = <_TutorialStep>[];
    final categories = <_TutorialStep>[];
    final middle = <_TutorialStep>[];
    final previews = <_TutorialStep>[];
    final shares = <_TutorialStep>[];
    for (final s in steps) {
      if (_isShareStoreStep(s)) {
        shares.add(s);
      } else if (_isPreviewStoreStep(s)) {
        previews.add(s);
      } else if (_isProductStep(s)) {
        products.add(s);
      } else if (_isCategoryStep(s)) {
        categories.add(s);
      } else if (_isAttributesStep(s)) {
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

  Future<void> _completeTutorial() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref.read(tokenStorageProvider).saveFirstRunTutorialSeen(true);
    ref.invalidate(firstRunTutorialSeenProvider);
    await ref.read(firstRunTutorialSeenProvider.future);
    if (!mounted) return;
    context.go('/dashboard');
  }

  Future<void> _next(int total) async {
    if (_index >= total - 1) {
      await _completeTutorial();
      return;
    }
    await _pageController.animateToPage(
      _index + 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _back() async {
    if (_index <= 0) return;
    await _pageController.animateToPage(
      _index - 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openStep(_TutorialStep step) async {
    if (_isRemoveDemoProductsStep(step)) {
      await _removeDemoProducts(step);
      return;
    }
    if (_isPreviewStoreStep(step)) {
      await _previewStore(step);
      return;
    }
    if (_isShareStoreStep(step)) {
      await _shareStoreLink(step);
      return;
    }
    final route = step.route;
    if (route == null || route.isEmpty) return;
    final uri = Uri.parse(route);
    final nextQuery = Map<String, String>.from(uri.queryParameters);
    nextQuery['tutorial'] = '1';
    if (_isLogoStep(step)) {
      nextQuery['focus'] = 'logo';
    }
    final routedUri = uri.replace(queryParameters: nextQuery);
    await context.push(routedUri.toString());
    if (!mounted) return;
    ref.invalidate(dashboardGettingStartedProvider);
  }

  bool _isRemoveDemoProductsStep(_TutorialStep step) {
    final key = step.key.toLowerCase();
    final title = step.title.toLowerCase();
    return (key.contains('demo') && key.contains('product')) ||
        (title.contains('demo') && title.contains('product'));
  }

  bool _isProductStep(_TutorialStep step) {
    final key = step.key.toLowerCase();
    final title = step.title.toLowerCase();
    return key == 'product' ||
        key == 'first_product' ||
        key == 'catalog' ||
        (title.contains('product') &&
            title.contains('first') &&
            !title.contains('demo'));
  }

  bool _isCategoryStep(_TutorialStep step) {
    final key = step.key.toLowerCase();
    final title = step.title.toLowerCase();
    return key.contains('category') || title.contains('categor');
  }

  bool _isAttributesStep(_TutorialStep step) {
    final key = step.key.toLowerCase();
    final title = step.title.toLowerCase();
    return key.contains('attribute') || title.contains('attribute');
  }

  bool _isLogoStep(_TutorialStep step) {
    final key = step.key.toLowerCase();
    final title = step.title.toLowerCase();
    return key.contains('logo') ||
        key.contains('store_identity') ||
        key.contains('branding') ||
        (title.contains('logo') && title.contains('store')) ||
        title.contains('store logo');
  }

  _TutorialIllustrKind _illustrationKind(_TutorialStep step) {
    if (_isRemoveDemoProductsStep(step)) return _TutorialIllustrKind.demo;
    if (_isShareStoreStep(step)) return _TutorialIllustrKind.share;
    if (_isPreviewStoreStep(step)) return _TutorialIllustrKind.preview;
    if (_isAttributesStep(step)) return _TutorialIllustrKind.attributes;
    final k = step.key.toLowerCase();
    final t = step.title.toLowerCase();
    if (k.contains('category') || t.contains('categor')) {
      return _TutorialIllustrKind.category;
    }
    if (k.contains('product') ||
        k.contains('catalog') ||
        (t.contains('product') && !t.contains('demo'))) {
      return _TutorialIllustrKind.product;
    }
    if (k.contains('shipping') ||
        k.contains('delivery') ||
        t.contains('shipping') ||
        t.contains('deliver')) {
      return _TutorialIllustrKind.shipping;
    }
    if (k.contains('payment') ||
        k.contains('checkout') ||
        t.contains('payment') ||
        (t.contains('checkout') && t.contains('prefer'))) {
      return _TutorialIllustrKind.payment;
    }
    if (k.contains('logo') ||
        k.contains('store_identity') ||
        k.contains('branding') ||
        t.contains('logo') ||
        (t.contains('brand') && t.contains('store'))) {
      return _TutorialIllustrKind.logo;
    }
    if (k.contains('sms') ||
        k.contains('contact_phone') ||
        (t.contains('sms') || (t.contains('phone') && t.contains('alert')))) {
      return _TutorialIllustrKind.settings;
    }
    return _TutorialIllustrKind.generic;
  }

  bool _canExecuteStep(_TutorialStep step) {
    return (step.route != null && step.route!.isNotEmpty) ||
        _isRemoveDemoProductsStep(step) ||
        _isPreviewStoreStep(step) ||
        _isShareStoreStep(step);
  }

  bool _isPreviewStoreStep(_TutorialStep step) {
    final key = step.key.toLowerCase();
    final title = step.title.toLowerCase();
    return key.contains('preview_store') ||
        key == 'preview' ||
        (title.contains('preview') && title.contains('store'));
  }

  Future<void> _previewStore(_TutorialStep step) async {
    try {
      final identity = await ref.read(storeIdentityProvider.future);
      final storeUrl = (identity.storeUrl ?? '').trim();
      if (!mounted) return;
      if (storeUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store URL is not available yet.')),
        );
        return;
      }
      final uri = Uri.tryParse(storeUrl);
      if (uri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store URL is invalid.')),
        );
        return;
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open storefront preview.')),
        );
        return;
      }
      _persistGettingStartedPreviewOrShare(
        stepKey: step.key,
        preview: true,
      );
      setState(() {});
      ref.invalidate(dashboardGettingStartedProvider);
      _schedulePageSyncIfNeeded(_mergedSteps());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open storefront preview.')),
      );
    }
  }

  bool _isShareStoreStep(_TutorialStep step) {
    final key = step.key.toLowerCase();
    final title = step.title.toLowerCase();
    return key.contains('share_store') ||
        key.contains('copy_link') ||
        (title.contains('share') && title.contains('store')) ||
        title.contains('store link');
  }

  Future<void> _shareStoreLink(_TutorialStep step) async {
    try {
      final identity = await ref.read(storeIdentityProvider.future);
      final storeUrl = (identity.storeUrl ?? '').trim();
      if (!mounted) return;
      if (storeUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store URL is not available yet.')),
        );
        return;
      }
      await SharePlus.instance.share(ShareParams(text: storeUrl));
      if (!mounted) return;
      _persistGettingStartedPreviewOrShare(
        stepKey: step.key,
        preview: false,
      );
      setState(() {});
      ref.invalidate(dashboardGettingStartedProvider);
      _schedulePageSyncIfNeeded(_mergedSteps());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store link shared.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share store link right now.')),
      );
    }
  }

  Future<void> _removeDemoProducts(_TutorialStep step) async {
    await handleDemoProductCleanup(context: context, ref: ref);
    if (!mounted) return;
    _localCompleted.add(step.key);
    setState(() {});
    _schedulePageSyncIfNeeded(_mergedSteps());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.height < 760;
    final titleSize = compact ? 34.0 : 42.0;
    final descriptionSize = compact ? 15.0 : 17.0;
    final cardPadding = compact ? 16.0 : 20.0;
    final checklistHeight = compact ? 108.0 : 130.0;
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      dashboardGettingStartedProvider,
      (_, next) {
        next.whenData((_) {
          if (!mounted) return;
          _schedulePageSyncIfNeeded(_mergedSteps());
        });
      },
    );

    final gsData = ref.watch(dashboardGettingStartedProvider).valueOrNull;
    final syncedCompletions = ref.watch(dashboardLocalStepCompletionsProvider);
    final stepsBase = _stepsFromGettingStarted(gsData);
    final steps = stepsBase.map((s) {
      final canonical = canonicalDashboardOnboardingStepKey(s.key);
      final done = s.completed ||
          _isStepMarkedCompleteLocally(s.key, canonical, syncedCompletions);
      return s.copyWith(completed: done);
    }).toList();
    _schedulePageSyncIfNeeded(steps);

    final total = steps.isEmpty ? 1 : steps.length;
    final safeIndex = _resolveFocusIndex(steps).clamp(0, total - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncChecklistScrollToFocus(safeIndex);
    });
    final isLast = safeIndex == total - 1;
    final completedCount = steps.where((s) => s.completed).length;
    final progress =
        total == 0 ? 0.0 : (completedCount / total).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Getting started',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing ? null : _completeTutorial,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedCount/$total done',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: total,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _lastChecklistScrollTarget = null;
                  _scrollChecklistToIndex(i);
                },
                itemBuilder: (context, i) {
                  final step = steps[i];
                  final isInProgress = !step.completed && i == safeIndex;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(14, 4, 14, compact ? 8 : 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(step.icon,
                                    color: theme.colorScheme.primary, size: 30),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: step.completed
                                      ? const Color(0xFFF0FDF4)
                                      : isInProgress
                                          ? theme.colorScheme.primaryContainer
                                              .withValues(alpha: 0.35)
                                          : theme
                                              .colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(999),
                                  border: step.completed
                                      ? Border.all(
                                          color: _doneGreen.withValues(
                                              alpha: 0.35))
                                      : isInProgress
                                          ? Border.all(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.45),
                                            )
                                          : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      step.completed
                                          ? Icons.check_circle_rounded
                                          : isInProgress
                                              ? Icons.hourglass_top_rounded
                                              : Icons
                                                  .radio_button_unchecked_rounded,
                                      size: 14,
                                      color: step.completed
                                          ? _doneGreen
                                          : isInProgress
                                              ? theme.colorScheme.primary
                                              : theme
                                                  .colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      step.completed
                                          ? 'Completed'
                                          : isInProgress
                                              ? 'In progress'
                                              : 'Pending',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: step.completed
                                            ? _doneGreen
                                            : isInProgress
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme
                                                    .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            step.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: titleSize,
                              height: 1.06,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            step.description,
                            style: GoogleFonts.inter(
                              fontSize: descriptionSize,
                              height: 1.45,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 16),
                          Expanded(
                            child: _TutorialIllustration(
                              kind: _illustrationKind(step),
                              compact: compact,
                              onTap: _isLogoStep(step) &&
                                      !step.completed &&
                                      _canExecuteStep(step)
                                  ? () => _openStep(step)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: SizedBox(
                height: checklistHeight,
                child: ListView.separated(
                  itemCount: steps.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final step = steps[i];
                    final selected = i == safeIndex;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          _lastChecklistScrollTarget = null;
                          await _pageController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                        },
                        child: Container(
                          key: _checklistKeyFor(i),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 8 : 10,
                            vertical: compact ? 7 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.08)
                                : theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.3)
                                  : theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                step.completed
                                    ? Icons.check_circle_rounded
                                    : (i == safeIndex && !step.completed)
                                        ? Icons.hourglass_top_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: step.completed
                                    ? Colors.green.shade700
                                    : (i == safeIndex && !step.completed)
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: compact ? 12 : 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                    decoration: step.completed
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    decorationColor:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                step.completed
                                    ? 'Done'
                                    : (i == safeIndex && !step.completed)
                                        ? 'In progress'
                                        : 'Todo',
                                style: GoogleFonts.inter(
                                  fontSize: compact ? 10 : 11,
                                  fontWeight: FontWeight.w700,
                                  color: step.completed
                                      ? _doneGreen
                                      : (i == safeIndex && !step.completed)
                                          ? theme.colorScheme.primary
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
            Padding(
              padding: EdgeInsets.fromLTRB(
                  14, compact ? 6 : 8, 14, compact ? 12 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_finishing || safeIndex == 0) ? null : _back,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _finishing
                          ? null
                          : () => _primaryFooterAction(steps, total),
                      child: _finishing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isLast
                                  ? 'Finish'
                                  : _footerCtaLabel(steps[safeIndex]),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TutorialIllustrKind {
  category,
  attributes,
  product,
  shipping,
  payment,
  logo,
  share,
  preview,
  demo,
  settings,
  generic,
}

class _TutorialIllustration extends StatelessWidget {
  const _TutorialIllustration({
    required this.kind,
    required this.compact,
    this.onTap,
  });

  final _TutorialIllustrKind kind;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            ],
          ),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: switch (kind) {
                      _TutorialIllustrKind.category =>
                        const _CategoryIllustrationBody(),
                      _TutorialIllustrKind.attributes =>
                        const _AttributesIllustrationBody(),
                      _TutorialIllustrKind.product =>
                        const _ProductIllustrationBody(),
                      _TutorialIllustrKind.shipping =>
                        const _ShippingIllustrationBody(),
                      _TutorialIllustrKind.payment =>
                        const _PaymentIllustrationBody(),
                      _TutorialIllustrKind.logo =>
                        _LogoIllustrationBody(onTap: onTap),
                      _TutorialIllustrKind.share ||
                      _TutorialIllustrKind.preview =>
                        const _StorefrontIllustrationBody(),
                      _TutorialIllustrKind.demo =>
                        const _DemoCleanupIllustrationBody(),
                      _TutorialIllustrKind.settings =>
                        const _SettingsIllustrationBody(),
                      _TutorialIllustrKind.generic =>
                        const _GenericIllustrationBody(),
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IllustrCaption extends StatelessWidget {
  const _IllustrCaption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 15,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _IllustrSpecRow extends StatelessWidget {
  const _IllustrSpecRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18,
              color: theme.colorScheme.primary.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryIllustrationBody extends StatelessWidget {
  const _CategoryIllustrationBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IllustrCaption(text: 'Catalog sections shoppers browse'),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.category_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Footwear',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          Text(
                            'Each product is assigned one category',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.3,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5)),
                const _IllustrSpecRow(
                  icon: Icons.folder_outlined,
                  label: 'Groceries',
                  value: 'Flour, rice, oil',
                ),
                const _IllustrSpecRow(
                  icon: Icons.folder_outlined,
                  label: 'Beverages',
                  value: 'Juice, water, soda',
                ),
                const _IllustrSpecRow(
                  icon: Icons.folder_outlined,
                  label: 'Electronics',
                  value: 'Phones, chargers',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AttributesIllustrationBody extends StatelessWidget {
  const _AttributesIllustrationBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IllustrCaption(text: 'Variant options on products'),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.tune_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Product attributes',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AttributesIllustrationBody._attributeChip(
                      theme,
                      Icons.straighten_rounded,
                      'Size',
                      'S, M, L',
                    ),
                    _AttributesIllustrationBody._attributeChip(
                      theme,
                      Icons.scale_rounded,
                      'Weight',
                      '250g, 500g',
                    ),
                    _AttributesIllustrationBody._attributeChip(
                      theme,
                      Icons.palette_outlined,
                      'Colour',
                      'Black, Blue',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _attributeChip(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductIllustrationBody extends StatelessWidget {
  const _ProductIllustrationBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IllustrCaption(text: 'What you’ll list'),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.25),
                          theme.colorScheme.tertiary.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 34,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arabica whole beans',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '250 g · Medium roast · Whole bean',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          height: 1.35,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'KES 1,200',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'In stock',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShippingIllustrationBody extends StatelessWidget {
  const _ShippingIllustrationBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IllustrCaption(text: 'Delivery you can set'),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _ShippingIllustrationBody._zoneRow(
                    theme, 'City center', 'Flat rate', 'KES 250'),
                const SizedBox(height: 10),
                _ShippingIllustrationBody._zoneRow(
                    theme, 'Greater area', 'Zone', 'KES 450'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _zoneRow(
      ThemeData theme, String zone, String type, String price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined,
              color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  type,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentIllustrationBody extends StatelessWidget {
  const _PaymentIllustrationBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IllustrCaption(text: 'Methods shoppers see'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _PaymentIllustrationBody._payChip(
              theme,
              Icons.account_balance_wallet_rounded,
              'Tumizi wallet',
            ),
            _PaymentIllustrationBody._payChip(
                theme, Icons.payments_outlined, 'Cash on delivery'),
            _PaymentIllustrationBody._payChip(
                theme, Icons.phone_android_rounded, 'M-Pesa'),
            _PaymentIllustrationBody._payChip(
                theme, Icons.credit_card_outlined, 'Card'),
          ],
        ),
      ],
    );
  }

  static Widget _payChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LogoIllustrationBody extends StatelessWidget {
  const _LogoIllustrationBody({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoPreview = CustomPaint(
      painter: _DashedRoundedRectPainter(
        color: theme.colorScheme.primary.withValues(alpha: 0.45),
        radius: 16,
      ),
      child: Container(
        width: 220,
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 36,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              onTap != null ? 'Tap to add logo' : 'Logo preview',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _IllustrCaption(text: 'Your brand on the storefront'),
        const SizedBox(height: 12),
        if (onTap != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: logoPreview,
            ),
          )
        else
          logoPreview,
      ],
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const dash = 5.0;
    const gap = 4.0;
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final next = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _StorefrontIllustrationBody extends StatelessWidget {
  const _StorefrontIllustrationBody();

  static const _storeScreenshotAsset = 'assets/images/store_screenshot.png';
  static const _demoStoreHost = 'yourstore.dukanest.com';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IllustrCaption(text: 'Your live storefront'),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.8),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _demoStoreHost,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(11)),
                child: SizedBox(
                  height: 152,
                  width: double.infinity,
                  child: Image.asset(
                    _storeScreenshotAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        _StorefrontIllustrationBody._screenshotFallback(theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _screenshotFallback(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            theme.colorScheme.surfaceContainerHigh,
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.storefront_outlined,
            size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _DemoCleanupIllustrationBody extends StatelessWidget {
  const _DemoCleanupIllustrationBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _IllustrCaption(text: 'Sample items'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                color: theme.colorScheme.outline, size: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded,
                  color: theme.colorScheme.primary, size: 22),
            ),
            Icon(Icons.delete_outline_rounded,
                color: theme.colorScheme.error, size: 30),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Remove placeholder products when you’re ready',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.35,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SettingsIllustrationBody extends StatelessWidget {
  const _SettingsIllustrationBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _IllustrCaption(text: 'Store contact & alerts'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Icon(Icons.sms_outlined,
                  color: theme.colorScheme.primary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+254 712 ··· 889',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Order SMS & phone alerts',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenericIllustrationBody extends StatelessWidget {
  const _GenericIllustrationBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.checklist_rtl_rounded,
            size: 48,
            color: theme.colorScheme.primary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 10),
          Text(
            'One step closer to a ready store',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
