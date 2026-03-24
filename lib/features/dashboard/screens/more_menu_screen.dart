import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';

/// More — Stitch: tonal rows, icon tiles, chevrons.
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <({
      IconData icon,
      Color iconBg,
      Color iconFg,
      String title,
      String subtitle,
      String? route,
    })>[
      (
        icon: Icons.article_outlined,
        iconBg: AppTheme.primary.withValues(alpha: 0.1),
        iconFg: AppTheme.primary,
        title: 'Content Management',
        subtitle: 'Edit pages, blogs, and visual assets for your storefront.',
        route: '/content-management',
      ),
      (
        icon: Icons.group_outlined,
        iconBg: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        iconFg: theme.colorScheme.secondary,
        title: 'Customers',
        subtitle: 'View profiles, purchase history, and segment your audience.',
        route: '/customers',
      ),
      (
        icon: Icons.inventory_2_outlined,
        iconBg: const Color(0xFFDFE0FF),
        iconFg: AppTheme.primaryDark,
        title: 'Inventory',
        subtitle: 'Track stock levels, warehouse locations, and restock alerts.',
        route: null,
      ),
      (
        icon: Icons.campaign_outlined,
        iconBg: AppTheme.primary.withValues(alpha: 0.1),
        iconFg: AppTheme.primary,
        title: 'Sales & Promotions',
        subtitle: 'Create discount codes, flash sales, and campaign banners.',
        route: '/sales-editor',
      ),
      (
        icon: Icons.settings_outlined,
        iconBg: theme.colorScheme.surfaceContainerHigh,
        iconFg: theme.colorScheme.onSurfaceVariant,
        title: 'Store Settings',
        subtitle: 'Configure domain, payments, and team permissions.',
        route: '/settings',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary,
                child: const Text('BL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Text(
                'Tenant Dashboard',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'More',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your business operations and account settings from a single command center.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: item.route != null ? () => context.push(item.route!) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: item.iconBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: item.iconFg, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outlineVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
