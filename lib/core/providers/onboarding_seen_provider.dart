import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';

/// Cached onboarding completion flag (secure storage). Invalidate after [TokenStorage.saveOnboardingSeen].
final onboardingSeenProvider = FutureProvider<bool>((ref) async {
  return ref.watch(tokenStorageProvider).getOnboardingSeen();
});
