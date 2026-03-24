import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProductsListScreen extends StatelessWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = [
      ('Velocity Nitro Runner', 'Footwear • SKU: VN-2024-RD', 'Active', '124 units', '\$129.00', 'VN-2024-RD'),
      ('Minimalist Slate Watch', 'Accessories • SKU: MW-SL-01', 'Active', '42 units', '\$85.50', 'MW-SL-01'),
      ('Studio Pro Wireless', 'Electronics • SKU: SPW-BLK-99', 'Inactive', '0 units', '\$199.00', 'SPW-BLK-99'),
      ('Golden Aviators', 'Accessories • SKU: GA-GLD-45', 'Active', 'Low (5)', '\$45.00', 'GA-GLD-45'),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/products/new'),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text('Inventory Management', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text('Product Catalog', style: Theme.of(context).textTheme.headlineSmall)),
              FilledButton.icon(
                onPressed: () => context.push('/products/new'),
                icon: const Icon(Icons.add),
                label: const Text('Add New Product'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SearchBar(
            hintText: 'Search',
            leading: const Icon(Icons.search),
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: 'All Categories',
                  trailing: Icon(Icons.expand_more, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              const _FilterChip(label: '', iconOnly: Icons.filter_list_outlined),
            ],
          ),
          const SizedBox(height: 12),
          ...products.map((product) {
            final stockColor = product.$4.contains('Low') || product.$4.startsWith('0') ? Colors.orange : Colors.green;
            final sku = product.$6;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  onTap: () => context.push('/products/edit/${Uri.encodeComponent(sku)}'),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_outlined),
                  ),
                  title: Text(product.$1),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.$2),
                      const SizedBox(height: 4),
                      Chip(label: Text(product.$3)),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Stock', style: Theme.of(context).textTheme.bodySmall),
                      Text(product.$4, style: TextStyle(color: stockColor, fontWeight: FontWeight.w600)),
                      Text('Price ${product.$5}', style: Theme.of(context).textTheme.bodySmall),
                      const Icon(Icons.more_vert, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text('Showing 1-4 of 32 products', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chevron_left),
              SizedBox(width: 8),
              Text('1'),
              SizedBox(width: 8),
              Text('2'),
              SizedBox(width: 8),
              Icon(Icons.chevron_right),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.trailing,
    this.iconOnly,
  });

  final String label;
  final Widget? trailing;
  final IconData? iconOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: iconOnly != null
          ? Icon(iconOnly, color: Theme.of(context).colorScheme.onSurfaceVariant)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(label)),
                if (trailing != null) trailing!,
              ],
            ),
    );
  }
}
