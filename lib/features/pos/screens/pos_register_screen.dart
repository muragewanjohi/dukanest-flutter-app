import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/dio_envelope.dart';
import '../data/pos_models.dart';
import '../providers/pos_providers.dart';

/// POS register — browse the catalogue, tap to add to the cart, then review.
class PosRegisterScreen extends ConsumerStatefulWidget {
  const PosRegisterScreen({super.key});

  @override
  ConsumerState<PosRegisterScreen> createState() => _PosRegisterScreenState();
}

class _PosRegisterScreenState extends ConsumerState<PosRegisterScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _pickVariant(PosCatalogProduct product) async {
    final currency =
        ref.read(posBootstrapProvider).valueOrNull?.settings.currency ??
            PosCurrency.fallback;
    final selected = await showModalBottomSheet<PosCatalogVariant>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(product.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final v in product.variants)
              ListTile(
                title: Text(v.label.isEmpty ? 'Variant' : v.label),
                subtitle: Text(_stockLabel(v.stockQuantity)),
                trailing: Text(currency.format(v.price),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, v),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      ref.read(posCartProvider.notifier).addItem(product, variant: selected);
      _confirmAdded(product.name);
    }
  }

  void _addProduct(PosCatalogProduct product) {
    if (product.hasVariants && product.variants.isNotEmpty) {
      _pickVariant(product);
      return;
    }
    ref.read(posCartProvider.notifier).addItem(product);
    _confirmAdded(product.name);
  }

  void _confirmAdded(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Added $name'),
        duration: const Duration(milliseconds: 900),
      ));
  }

  static String _stockLabel(int? stock) {
    if (stock == null) return 'Stock not tracked';
    if (stock <= 0) return 'Out of stock';
    return '$stock in stock';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bootstrap = ref.watch(posBootstrapProvider);
    final cart = ref.watch(posCartProvider);
    final totals = ref.watch(posTotalsProvider);
    final currency =
        bootstrap.valueOrNull?.settings.currency ?? PosCurrency.fallback;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Point of Sale'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/more'),
        ),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () {
                ref.read(posCartProvider.notifier).clear();
              },
              child: const Text('Clear'),
            ),
          IconButton(
            tooltip: 'Refresh catalogue',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(posBootstrapProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, SKU or barcode…',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: bootstrap.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(posBootstrapProvider),
              ),
              data: (data) {
                final products =
                    data.products.where((p) => p.matches(_query)).toList();
                if (products.isEmpty) {
                  return _EmptyState(
                    hasQuery: _query.isNotEmpty,
                    catalogueEmpty: data.products.isEmpty,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(posBootstrapProvider),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        16, 4, 16, cart.isEmpty ? 24 : 120),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ProductTile(
                      product: products[i],
                      currency: currency,
                      onAdd: () => _addProduct(products[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => context.push('/pos/cart'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Row(
                        children: [
                          Text(
                            currency.format(totals.total),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.currency,
    required this.onAdd,
  });

  final PosCatalogProduct product;
  final PosCurrency currency;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stock = product.stockQuantity;
    final outOfStock = stock != null && stock <= 0;

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumb(url: product.image),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        currency.format(product.price),
                        if (product.hasVariants) 'Choose variant',
                        if (outOfStock)
                          'Out of stock'
                        else if (stock != null)
                          '$stock in stock',
                      ].join('  •  '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: outOfStock
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.inventory_2_outlined,
          size: 22, color: theme.colorScheme.onSurfaceVariant),
    );
    if (url == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery, required this.catalogueEmpty});
  final bool hasQuery;
  final bool catalogueEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.storefront_outlined,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'No products match that search'
                  : catalogueEmpty
                      ? 'No products yet — add some to your store first'
                      : 'No products to show',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
