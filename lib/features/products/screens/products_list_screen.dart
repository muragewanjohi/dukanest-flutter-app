import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';

/// Product Management — Stitch: Product Catalog, search, category, product rows.
class ProductsListScreen extends StatelessWidget {
  const ProductsListScreen({super.key});

  static const _kSneaker =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBItpyh7rifhulInTnFVxDIGg-AgrcC3dNLPMXbdw1QqOBNP-rF6vjac2o8a4ZxGE5iuht_h7q0yXNKub5Rm-TNJ_PSiFKpMdA54Wxnfa1i6ASERO_Hdung32CBZZVqy-kINY0JOsfm1fsgaM42KaOeFldn7sPtE0UIivsZMyG1_B9eD2q7R4ytB8bAmQ3hXU7wEEXbTza-mIpaY1YIiEOARaf61fVunRr4wtJNDHF096AEFOjVZGl4VXJunIdlDvTFIaPahiBAc9GG';
  static const _kWatch =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC0ei8XqCEmV8Zsq5Lv3E9w-dqx_f9FBaGX_NtmPyGDvsbqMO5w26wmb4DwQKtMNn8G7BAdrz1q74g1Kto-2e7h5rUwiAWhFrIZcQtztnqm9iI6X3D0Iv6TyjU_zPNWQxpotj7e5bndssIZsXOago1HETIinyDA3QAA2YT4O4P-6tBHmdeFPgrls1GNhErRK4XHE_KME8qkXjv4FsJCm7onxa0xF2uWrybLUks7O1yBZOFXePKNpP7frYkKFTZVtFXiFBKQ9rJ1NGiK';
  static const _kHeadphones =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD9cWmwiE-_lsX7IB3rEswMD2xUB-QYYIvTSR8jPsKAnxUdlperQpbtwgC2fzrRrSLFT6gHVTY4d1mKcgcsfMWE68jvOEQLbhz-19GYfd3EygJ5wHRMf0x0TqfrkpCFQNEA2dGov2KgaKcVcyc8Zr-JRBVwidom5CIfH_w3DSg3R4xmMKL3z0L7TSgqzaGh8eP-xIHOLjc-bPvG_iKrshB9CCskI8ZZQlUzsVUJ5KYYi46dmmWgtiTjLnyy3SP4GUEf4SjCq2-XY0eT';
  static const _kAviators =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDuRZSDgVO8zLQfz9qgW7UgcfYppVXgR1YjV6lvUHp6lEtQrB3shE4GKMQecGWG-TG1t5CHFNEHhdR3eMTlqzXO0omYY2-4s4UZjJU2xjXJWud6xyyq7A41Q9jwgeYb2uiF27phDBDx1n2ZyoKax62T3Orl3-Ih5LuM4thz5K9QYR7AcQx84RnXhloSoWU8J3eJyGooJwggfD81exp9XUtokbVsipUDp8fHK9P5eqhCYjIYpjQqcfuBAnJBbtnD5CbXSn2hivnU3oT3';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final products = <({
      String name,
      String meta,
      String status,
      bool active,
      String stock,
      bool stockWarn,
      String price,
      String sku,
      String imageUrl,
      bool accentBar,
    })>[
      (
        name: 'Velocity Nitro Runner',
        meta: 'Footwear • SKU: VN-2024-RD',
        status: 'Active',
        active: true,
        stock: '124 units',
        stockWarn: false,
        price: '\$129.00',
        sku: 'VN-2024-RD',
        imageUrl: _kSneaker,
        accentBar: true,
      ),
      (
        name: 'Minimalist Slate Watch',
        meta: 'Accessories • SKU: MW-SL-01',
        status: 'Active',
        active: true,
        stock: '42 units',
        stockWarn: false,
        price: '\$85.50',
        sku: 'MW-SL-01',
        imageUrl: _kWatch,
        accentBar: false,
      ),
      (
        name: 'Studio Pro Wireless',
        meta: 'Electronics • SKU: SPW-BLK-99',
        status: 'Inactive',
        active: false,
        stock: '0 units',
        stockWarn: false,
        price: '\$199.00',
        sku: 'SPW-BLK-99',
        imageUrl: _kHeadphones,
        accentBar: false,
      ),
      (
        name: 'Golden Aviators',
        meta: 'Accessories • SKU: GA-GLD-45',
        status: 'Active',
        active: true,
        stock: 'Low (5)',
        stockWarn: true,
        price: '\$45.00',
        sku: 'GA-GLD-45',
        imageUrl: _kAviators,
        accentBar: false,
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryDark, AppTheme.primary],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/products/new'),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.person, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'DukaNest',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'INVENTORY MANAGEMENT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 520;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      'Product Catalog',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (wide)
                    FilledButton.icon(
                      onPressed: () => context.push('/products/new'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add New Product'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search products by name, SKU or category...',
                prefixIcon: Icon(Icons.search, size: 22),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'All Categories',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.expand_more, color: theme.colorScheme.outline),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.filter_list, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...products.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductRow(
                product: p,
                onTap: () => context.push('/products/edit/${Uri.encodeComponent(p.sku)}'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing 1-4 of 32 products',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  _PageBtn(icon: Icons.chevron_left, onPressed: () {}),
                  const SizedBox(width: 6),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  _PageBtn(label: '2', onPressed: () {}),
                  const SizedBox(width: 6),
                  _PageBtn(icon: Icons.chevron_right, onPressed: () {}),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  const _PageBtn({this.icon, this.label, required this.onPressed});

  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: icon != null
              ? Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant)
              : Center(
                  child: Text(
                    label!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final ({
    String name,
    String meta,
    String status,
    bool active,
    String stock,
    bool stockWarn,
    String price,
    String sku,
    String imageUrl,
    bool accentBar,
  }) product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = product.active ? 1.0 : 0.75;

    return Material(
      color: product.active ? Colors.white : Colors.white.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Opacity(
                          opacity: product.active ? 1 : 0.85,
                          child: ColorFiltered(
                            colorFilter: product.active
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                : const ColorFilter.matrix(<double>[
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                            child: Image.network(
                              product.imageUrl,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 96,
                                height: 96,
                                color: theme.colorScheme.surfaceContainerLow,
                                child: Icon(Icons.image_outlined, color: theme.colorScheme.outline),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (product.accentBar)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppTheme.primaryDark.withValues(alpha: opacity),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _StatusChip(product: product),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.meta,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STOCK',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.stock,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: product.stockWarn ? theme.colorScheme.error : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRICE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.price,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.more_vert, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.product});

  final ({
    String name,
    String meta,
    String status,
    bool active,
    String stock,
    bool stockWarn,
    String price,
    String sku,
    String imageUrl,
    bool accentBar,
  }) product;

  @override
  Widget build(BuildContext context) {
    final bg = product.active
        ? const Color(0xFFECFDF5)
        : const Color(0xFFF1F5F9);
    final fg = product.active
        ? const Color(0xFF047857)
        : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        product.status.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}
