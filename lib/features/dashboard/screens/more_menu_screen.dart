import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_page_header.dart';

/// More tab layout based on Stitch "More Menu" screen.
class MoreMenuScreen extends ConsumerWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            24, 8 + MediaQuery.of(context).padding.top, 24, 24),
        children: [
          DashboardPageHeader(
            title: 'More',
            subtitle:
                'Manage your business operations and account settings from a single command center.',
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _MoreItem(
            icon: Icons.settings_outlined,
            iconColor: theme.colorScheme.outline,
            iconBackground: const Color(0xFFF1F5F9),
            title: 'Store Settings',
            subtitle: 'Configure domain, payments, and team permissions.',
            onTap: () => context.push('/settings'),
            bordered: true,
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF0F766E),
            iconBackground: const Color(0xFFCCFBF1),
            title: 'Tumizi wallet',
            subtitle:
                'Automatic M-Pesa verification, separate business money, and withdraw wallet funds to M-Pesa.',
            onTap: () => context.push('/tumizi-dashboard'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.article_outlined,
            iconColor: AppTheme.primary,
            iconBackground: const Color(0x1A0025CC),
            title: 'Content Management',
            subtitle:
                'Edit pages, blogs, and visual assets for your storefront.',
            onTap: () => context.push('/content-management'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.group_outlined,
            iconColor: theme.colorScheme.secondary,
            iconBackground: const Color(0x4DDBD1FF),
            title: 'Customers',
            subtitle:
                'View profiles, purchase history, and segment your audience.',
            onTap: () => context.push('/customers'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF0A2ACF),
            iconBackground: const Color(0xFFDFE0FF),
            title: 'Inventory',
            subtitle:
                'Track stock levels, warehouse locations, and restock alerts.',
            onTap: () => context.push('/inventory'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFFBA1A1A),
            iconBackground: const Color(0x66FFDAD6),
            title: 'Sales & Promotions',
            subtitle:
                'Create discount codes, flash sales, and campaign banners.',
            onTap: () => context.push('/sales'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.card_membership_outlined,
            iconColor: const Color(0xFF1D4ED8),
            iconBackground: const Color(0xFFDBEAFE),
            title: 'Subscription & billing',
            subtitle: 'Manage your plan, usage limits, and payment history.',
            onTap: () => context.push('/subscription'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.palette_outlined,
            iconColor: const Color(0xFF7C3AED),
            iconBackground: const Color(0xFFEDE9FE),
            title: 'Themes',
            subtitle: 'Install storefront themes and customize colors.',
            onTap: () => context.push('/themes'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.dynamic_form_outlined,
            iconColor: const Color(0xFF0369A1),
            iconBackground: const Color(0xFFE0F2FE),
            title: 'Forms',
            subtitle: 'Build contact forms and review submissions.',
            onTap: () => context.push('/forms'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.photo_library_outlined,
            iconColor: const Color(0xFF059669),
            iconBackground: const Color(0xFFD1FAE5),
            title: 'Media library',
            subtitle: 'Browse uploaded images and manage alt text.',
            onTap: () => context.push('/media-library'),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.receipt_long_outlined,
            iconColor: const Color(0xFF8A4B00),
            iconBackground: const Color(0xFFFFF4E5),
            title: 'Expenses',
            subtitle: 'Log operating costs for profit and loss reporting.',
            onTap: () => context.push('/analytics/expenses'),
          ),
          const SizedBox(height: 22),
          _MoreItem(
            icon: Icons.school_outlined,
            iconColor: const Color(0xFFD97706),
            iconBackground: const Color(0xFFFFF4E5),
            title: 'View Tutorial Again',
            subtitle: 'Replay the getting-started walkthrough anytime.',
            onTap: () => context.push('/first-run-tutorial?replay=1'),
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
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.35),
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
