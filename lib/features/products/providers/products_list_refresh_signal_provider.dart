import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increment to tell [ProductsListScreen] to clear its cache and reload.
final productsListRefreshSignalProvider = StateProvider<int>((ref) => 0);

void bumpProductsListRefresh(WidgetRef ref) {
  ref.read(productsListRefreshSignalProvider.notifier).state++;
}

/// Same signal bump for non-widget [Ref] callers (e.g. assistant notifier).
void bumpProductsListRefreshFromRef(Ref ref) {
  ref.read(productsListRefreshSignalProvider.notifier).state++;
}
