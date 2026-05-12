import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';

/// Cached first authenticated tutorial completion flag (secure storage).
/// Invalidate after [TokenStorage.saveFirstRunTutorialSeen].
final firstRunTutorialSeenProvider = FutureProvider<bool>((ref) async {
  return ref.watch(tokenStorageProvider).getFirstRunTutorialSeen();
});
