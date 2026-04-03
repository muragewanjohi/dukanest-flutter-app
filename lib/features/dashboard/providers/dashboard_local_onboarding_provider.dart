import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../onboarding/providers/auth_provider.dart';

/// Step keys aligned with dashboard defaults and `GET .../dashboard/overview` checklist.
abstract final class DashboardOnboardingStepKeys {
  static const product = 'product';
  static const previewStore = 'preview_store';
  static const shareStore = 'share_store';
  static const sms = 'sms';
  static const payment = 'payment';
  static const shipping = 'shipping';
  static const logo = 'logo';
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
