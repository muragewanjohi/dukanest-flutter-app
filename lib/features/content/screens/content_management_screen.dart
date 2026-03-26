import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// Content Manager — Stitch: Content Management (Updated Nav & Sales)
/// (c0999576f9e44e32945d93fb39de9be4). No duplicate bottom nav.
class ContentManagementScreen extends StatelessWidget {
  const ContentManagementScreen({super.key});

  static const _imgProduce =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB-RhbTwmQGO7UvdR2U6bjhTE0QV1j0bn_rjO7Zbff5AD0auumX1vOJ5DE8LEn_gLuje4RgOlekKTafcU4cEFIg8YbLekZAKyGPq3L3MDRm-0Gqjck0PbWRH6PQIdPcbdvMN-Ok0UdDRPHRW5-8M5d0BpWPKNXd_2nh3dAzxC78Rq_GlqnJgPCWsoNFgErS_-Iro9monw-9mKSyTADS99pcqYYNUa1qEnRBdQItJpJTAUjk7px1Da4YmTUozVm-59C68TsDAyItFwGx';
  static const _imgPayments =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA80fodEKI9Bj8t9_PWXNRVSio0X8LXbHmaQINWZi93GaEY3SJMXgx-r3xh10yi38nh6j3sCx4xJiM74YL2qG-icVpHJOWYgz8crbDtQhz0DQjN24Qv1tvtq91jouyjm1BjXVpS6XG-9U6rChK2piJBmdT1nSW5R9qHzXC8qQ1TQMHyVguvvxnvTE_ALCkzmq6eYkUMCugfmxm2RqPReygULyV7cP-V70qOtAWIusE4vxetts1-FLRRoTIr8k2iTdfdeQwLZ7Pu6rhY';
  static const _imgLoyalty =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuClKuE-gQTnyop3ZW0H558UXJtiKoeQE0BvGO7WF7J5GfI_gAwBLphYC6QH6jZorgqDyop1FdRRU6nU8d86tZqhb64ykCqlCgRYRpvTO43J-G_cKjmlwbrn3PMq718hKHCT_XecwMCD4TMsvmI4ugABa_fACJXgOJQ-yIBqb4xXrfXdYiUtLayfiLf53ETo5t046pmpk20UxxhUph2Pr4u2hk_HJ5rQwv8DMmRyPdDlpHW1BZApTQhrWGnBobTw0NaGauyvDrK6Wyyt';
  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAad6vSBUp7TJUfwx6q_Zu98Ov5kBoXEE6qBmxohdxS3Xvva7vzUbTd5Y8YRBWNFTGzudNbQtShKEQH6NuGII-SsspXdB7DKKsz4Pimfw-Jw5ZbD3mkR2xLXoBuY18sQ55Wah_7XurHfjAkge6D7u_3_X-u4e-H1jxPrAIqkvKr208JNSiW_mN2sX_JILyDCrOLz4QvdqqC50F7jj7CEJhMVpBASAs5cMEfzX-FmTtgGIOTgkONTsfB_g9bii7TyqizG0D5kkTunZt5';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Content Manager',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 4),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              backgroundImage: const CachedNetworkImageProvider(_avatarUrl),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          _SearchAndActionsRow(theme: theme),
          const SizedBox(height: 32),
          Text(
            'Recent Blog Posts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('View All', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 12),
          _BlogCard(
            imageUrl: _imgProduce,
            status: 'PUBLISHED',
            title: 'How to source the best organic produce for your store',
            meta: 'Updated 2 days ago • 5 min read',
            publishedStyle: true,
            onEdit: () => context.push('/blog-post/edit/organic-produce'),
          ),
          _BlogCard(
            imageUrl: _imgPayments,
            status: 'DRAFT',
            title: 'Modernizing your checkout: Why digital payments matter',
            meta: 'Edited 5 hours ago',
            publishedStyle: false,
            onEdit: () => context.push('/blog-post/edit/checkout-digital'),
          ),
          _BlogCard(
            imageUrl: _imgLoyalty,
            status: 'PUBLISHED',
            title: 'Customer loyalty programs that actually work',
            meta: 'Updated 1 week ago • 8 min read',
            publishedStyle: true,
            accentBorder: true,
            onEdit: () => context.push('/blog-post/edit/loyalty-programs'),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text(
                'Pages',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.add_circle, color: theme.colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _PageRow(
                  title: 'Home',
                  updated: 'Last updated: Mar 1, 2024',
                  onTap: () => context.push('/page-editor/home'),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.35)),
                _PageRow(title: 'About Us', updated: 'Last updated: Mar 12, 2024'),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.35)),
                _PageRow(title: 'Privacy Policy', updated: 'Last updated: Jan 05, 2024'),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.35)),
                _PageRow(title: 'Terms of Service', updated: 'Last updated: Feb 20, 2024'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Active Sales',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          _FeaturedSaleCard(
            onEdit: () => context.push('/sales-editor'),
          ),
          const SizedBox(height: 12),
          _OutlinedSaleCard(
            onEdit: () => context.push('/sales-editor'),
          ),
        ],
      ),
    );
  }
}

class _SearchAndActionsRow extends StatelessWidget {
  const _SearchAndActionsRow({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search blog, pages, or banners...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
            prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  foregroundColor: theme.colorScheme.onSurface,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.filter_list_rounded, size: 20, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 8),
                    Text('Filter', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF001790), Color(0xFF0025CC)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/blog-post/new'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Create New Post',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BlogCard extends StatelessWidget {
  const _BlogCard({
    required this.imageUrl,
    required this.status,
    required this.title,
    required this.meta,
    required this.publishedStyle,
    this.accentBorder = false,
    this.onEdit,
  });

  final String imageUrl;
  final String status;
  final String title;
  final String meta;
  final bool publishedStyle;
  final bool accentBorder;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: accentBorder ? const Border(left: BorderSide(color: AppTheme.primary, width: 4)) : null,
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => ColoredBox(color: theme.colorScheme.surfaceContainerLow),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerLow,
                        child: Icon(Icons.article_outlined, color: theme.colorScheme.outline),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: publishedStyle
                                  ? theme.colorScheme.secondaryContainer
                                  : theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: publishedStyle
                                    ? theme.colorScheme.onSecondaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant, size: 22),
                            onPressed: onEdit,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({required this.title, required this.updated, this.onTap});

  final String title;
  final String updated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      updated,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedSaleCard extends StatelessWidget {
  const _FeaturedSaleCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACTIVE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Summer Flash Sale: 20% Off Storewide',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlinedSaleCard extends StatelessWidget {
  const _OutlinedSaleCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ACTIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppTheme.primaryDark.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Buy 2 Get 1 Free: Organic Greens',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryDark,
              backgroundColor: AppTheme.primaryDark.withValues(alpha: 0.06),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
