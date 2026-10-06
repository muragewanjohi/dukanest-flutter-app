import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../../settings/providers/dashboard_settings_provider.dart';
import '../../onboarding/data/business_type_categories.dart';

/// More tab — grouped for WhatsApp/Jiji sellers (Sell / Manage / Store / Account).
class MoreMenuScreen extends ConsumerWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(dashboardSettingsProvider).valueOrNull;
    final store = settingsSection(settings, 'store');
    final businessType =
        settingsPick(store, ['businessType', 'business_type']);
    final showBookings = isServiceOnlyBusinessType(businessType) ||
        businessType.toLowerCase().contains('service') ||
        businessType.toLowerCase().contains('salon') ||
        businessType.toLowerCase().contains('spa') ||
        businessType.toLowerCase().contains('clinic');

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            24, 8 + MediaQuery.of(context).padding.top, 24, 24),
        children: [
          DashboardPageHeader(
            title: 'More',
            subtitle: 'Sell, manage, and set up your store.',
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel(theme, 'Sell'),
          _MoreItem(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFFBA1A1A),
            iconBackground: const Color(0x66FFDAD6),
            title: 'Sales & Promotions',
            subtitle: 'Discounts, flash sales, and banners.',
            onTap: () => context.push('/sales'),
            bordered: true,
          ),
          if (showBookings) ...[
            const SizedBox(height: 10),
            _MoreItem(
              icon: Icons.calendar_month_outlined,
              iconColor: const Color(0xFF0F766E),
              iconBackground: const Color(0xFFCCFBF1),
              title: 'Bookings',
              subtitle: 'Appointments for bookable services.',
              onTap: () => context.push('/bookings'),
              bordered: true,
            ),
          ],
          const SizedBox(height: 22),
          _sectionLabel(theme, 'Manage'),
          _MoreItem(
            icon: Icons.group_outlined,
            iconColor: theme.colorScheme.secondary,
            iconBackground: const Color(0x4DDBD1FF),
            title: 'Customers',
            subtitle: 'Profiles and purchase history.',
            onTap: () => context.push('/customers'),
            bordered: true,
          ),
          const SizedBox(height: 10),
          _MoreItem(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF0A2ACF),
            iconBackground: const Color(0xFFDFE0FF),
            title: 'Inventory',
            subtitle: 'Stock levels and restock alerts.',
            onTap: () => context.push('/inventory'),
            bordered: true,
          ),
          const SizedBox(height: 10),
          _MoreItem(
            icon: Icons.bluetooth_searching_outlined,
            iconColor: const Color(0xFF0F766E),
            iconBackground: const Color(0xFFCCFBF1),
            title: 'In-store beacons',
            subtitle: 'Write the in-store beacon profile from this phone.',
            onTap: () => context.push('/proximity'),
            bordered: true,
          ),
          const SizedBox(height: 10),
          _MoreItem(
            icon: Icons.bar_chart_outlined,
            iconColor: const Color(0xFF7C2D92),
            iconBackground: const Color(0xFFF3E8FF),
            title: 'Analytics',
            subtitle: 'Revenue and order reports.',
            onTap: () => context.push('/analytics'),
            bordered: true,
          ),
          const SizedBox(height: 22),
          _sectionLabel(theme, 'Store'),
          _MoreItem(
            icon: Icons.settings_outlined,
            iconColor: theme.colorScheme.outline,
            iconBackground: const Color(0xFFF1F5F9),
            title: 'Store Settings',
            subtitle: 'Payments, delivery, and team.',
            onTap: () => context.push('/settings'),
            bordered: true,
          ),
          const SizedBox(height: 10),
          _MoreItem(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF0F766E),
            iconBackground: const Color(0xFFCCFBF1),
            title: 'Tumizi wallet',
            subtitle: 'M-Pesa verification and withdrawals.',
            onTap: () => context.push('/tumizi-dashboard'),
            bordered: true,
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Advanced store tools',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            children: [
              _MoreItem(
                icon: Icons.point_of_sale_outlined,
                iconColor: const Color(0xFF0025CC),
                iconBackground: const Color(0xFFDFE0FF),
                title: 'Point of Sale',
                subtitle: 'Walk-in sales and receipts.',
                onTap: () => context.push('/pos'),
              ),
              const SizedBox(height: 10),
              _MoreItem(
                icon: Icons.article_outlined,
                iconColor: AppTheme.primary,
                iconBackground: const Color(0x1A0025CC),
                title: 'Content Management',
                subtitle: 'Pages, blogs, and storefront assets.',
                onTap: () => context.push('/content-management'),
              ),
              const SizedBox(height: 10),
              _MoreItem(
                icon: Icons.palette_outlined,
                iconColor: const Color(0xFF7C3AED),
                iconBackground: const Color(0xFFEDE9FE),
                title: 'Themes',
                subtitle: 'Storefront look and colors.',
                onTap: () => context.push('/themes'),
              ),
              const SizedBox(height: 10),
              _MoreItem(
                icon: Icons.dynamic_form_outlined,
                iconColor: const Color(0xFF0369A1),
                iconBackground: const Color(0xFFE0F2FE),
                title: 'Forms',
                subtitle: 'Contact forms and submissions.',
                onTap: () => context.push('/forms'),
              ),
              const SizedBox(height: 10),
              _MoreItem(
                icon: Icons.photo_library_outlined,
                iconColor: const Color(0xFF059669),
                iconBackground: const Color(0xFFD1FAE5),
                title: 'Media library',
                subtitle: 'Uploaded images and alt text.',
                onTap: () => context.push('/media-library'),
              ),
              const SizedBox(height: 10),
              _MoreItem(
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFF8A4B00),
                iconBackground: const Color(0xFFFFF4E5),
                title: 'Expenses',
                subtitle: 'Operating costs for P&L.',
                onTap: () => context.push('/analytics/expenses'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Account'),
          _MoreItem(
            icon: Icons.card_membership_outlined,
            iconColor: const Color(0xFF1D4ED8),
            iconBackground: const Color(0xFFDBEAFE),
            title: 'Subscription & billing',
            subtitle: 'Plan, limits, and payment history.',
            onTap: () => context.push('/subscription'),
            bordered: true,
          ),
          const SizedBox(height: 10),
          _MoreItem(
            icon: Icons.card_giftcard_outlined,
            iconColor: const Color(0xFF0F766E),
            iconBackground: const Color(0xFFCCFBF1),
            title: 'Referral program',
            subtitle: 'Earn free subscription months.',
            onTap: () => context.push('/referrals'),
            bordered: true,
          ),
          const SizedBox(height: 10),
          _MoreItem(
            icon: Icons.school_outlined,
            iconColor: const Color(0xFFD97706),
            iconBackground: const Color(0xFFFFF4E5),
            title: 'View Tutorial Again',
            subtitle: 'Replay the getting-started walkthrough.',
            onTap: () => context.push('/first-run-tutorial?replay=1'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: bordered
                ? Border.all(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.35),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
