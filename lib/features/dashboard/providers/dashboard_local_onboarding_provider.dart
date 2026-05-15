import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../onboarding/providers/auth_provider.dart';

/// Step keys aligned with dashboard defaults and `GET .../dashboard/overview` checklist.
abstract final class DashboardOnboardingStepKeys {
  static const product = 'product';
  static const category = 'category';
  static const attributes = 'attributes';
  static const previewStore = 'preview_store';
  static const shareStore = 'share_store';
  static const sms = 'sms';
  static const payment = 'payment';
  static const shipping = 'shipping';
  static const logo = 'logo';
}

/// Normalizes checklist / tutorial step ids so they match keys stored in
/// [dashboardLocalStepCompletionsProvider] ([DashboardLocalStepCompletionsNotifier]).
String canonicalDashboardOnboardingStepKey(String raw) {
  final id = raw.toLowerCase().trim();
  if (id.isEmpty) return '';
  switch (id) {
    case 'preview':
      return DashboardOnboardingStepKeys.previewStore;
    case 'share':
      return DashboardOnboardingStepKeys.shareStore;
    case 'contact_phone':
    case 'sms_alerts':
    case 'order_alerts_sms':
      return DashboardOnboardingStepKeys.sms;
    case 'delivery':
    case 'local_delivery':
    case 'shipping_delivery':
    case 'shipping_setup':
    case 'delivery_setup':
      return DashboardOnboardingStepKeys.shipping;
    case 'categories':
    case 'first_category':
    case 'catalog_category':
      return DashboardOnboardingStepKeys.category;
    case 'attribute':
    case 'product_attributes':
      return DashboardOnboardingStepKeys.attributes;
    case 'first_product':
    case 'catalog':
      return DashboardOnboardingStepKeys.product;
    case 'payments':
    case 'checkout':
      return DashboardOnboardingStepKeys.payment;
    case 'store_logo':
    case 'design':
    case 'branding':
    case 'store_identity':
      return DashboardOnboardingStepKeys.logo;
    default:
      return id;
  }
}

/// Client-side completion until the overview API reflects server state.
class DashboardLocalStepCompletionsNotifier extends StateNotifier<Set<String>> {
  DashboardLocalStepCompletionsNotifier() : super(<String>{});

  void markComplete(String stepKey) {
    final k = stepKey.trim().toLowerCase();
    if (k.isEmpty) return;
    if (state.contains(k)) return;
    state = Set<String>.from(state)..add(k);
  }

  void clear() => state = <String>{};
}

final dashboardLocalStepCompletionsProvider =
    StateNotifierProvider<DashboardLocalStepCompletionsNotifier, Set<String>>((ref) {
  final notifier = DashboardLocalStepCompletionsNotifier();
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.status == AuthStatus.unauthenticated) {
      notifier.clear();
    }
  });
  return notifier;
});
