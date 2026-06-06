import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increment to tell [ProductsListScreen] to clear its cache and reload.
final productsListRefreshSignalProvider = StateProvider<int>((ref) => 0);

void bumpProductsListRefresh(WidgetRef ref) {
  ref.read(productsListRefreshSignalProvider.notifier).state++;
}
