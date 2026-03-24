import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String subtitle, String? route})>[
      (
        icon: Icons.article_outlined,
        title: 'Content Management',
        subtitle: 'Edit pages, blogs, and visual assets for your storefront.',
        route: '/content-management',
      ),
      (
        icon: Icons.group_outlined,
        title: 'Customers',
        subtitle: 'View profiles, purchase history, and segment your audience.',
        route: '/customers',
      ),
      (
        icon: Icons.inventory_2_outlined,
        title: 'Inventory',
        subtitle: 'Track stock levels, warehouse locations, and restock alerts.',
        route: null,
      ),
      (
        icon: Icons.campaign_outlined,
        title: 'Sales & Promotions',
        subtitle: 'Create discount codes, flash sales, and campaign banners.',
        route: '/sales-editor',
      ),
      (
        icon: Icons.settings_outlined,
        title: 'Store Settings',
        subtitle: 'Configure domain, payments, and team permissions.',
        route: '/settings',
      ),
    ];

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('More', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your business operations and account settings from a single command center.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          final item = items[index - 1];
          return Card(
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (item.route != null) {
                  context.push(item.route!);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
