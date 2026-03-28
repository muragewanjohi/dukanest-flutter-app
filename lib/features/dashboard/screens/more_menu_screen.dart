import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// More tab layout based on Stitch "More Menu" screen.
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your business operations and account settings from a single command center.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          _MoreItem(
            icon: Icons.article_outlined,
            iconColor: AppTheme.primary,
            iconBackground: const Color(0x1A0025CC),
            title: 'Content Management',
            subtitle: 'Edit pages, blogs, and visual assets for your storefront.',
            onTap: () => context.push('/content-management'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.group_outlined,
            iconColor: theme.colorScheme.secondary,
            iconBackground: const Color(0x4DDBD1FF),
            title: 'Customers',
            subtitle: 'View profiles, purchase history, and segment your audience.',
            onTap: () => context.push('/customers'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF0A2ACF),
            iconBackground: const Color(0xFFDFE0FF),
            title: 'Inventory',
            subtitle: 'Track stock levels, warehouse locations, and restock alerts.',
            onTap: () => context.go('/products'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFFBA1A1A),
            iconBackground: const Color(0x66FFDAD6),
            title: 'Sales & Promotions',
            subtitle: 'Create discount codes, flash sales, and campaign banners.',
            onTap: () => context.push('/sales-editor'),
          ),
          const SizedBox(height: 22),
          _MoreItem(
            icon: Icons.settings_outlined,
            iconColor: theme.colorScheme.outline,
            iconBackground: const Color(0xFFF1F5F9),
            title: 'Store Settings',
            subtitle: 'Configure domain, payments, and team permissions.',
            onTap: () => context.push('/settings'),
            bordered: true,
          ),
          const SizedBox(height: 24),
          Text(
            'Dashboard Version 2.4.0-Architect',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.bordered = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: bordered
          ? theme.colorScheme.surfaceContainerLowest
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: bordered
                ? Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
