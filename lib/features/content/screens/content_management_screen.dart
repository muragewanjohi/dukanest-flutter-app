import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/content_hub_provider.dart';

/// Content Manager — Stitch: Content Management (Updated Nav & Sales)
/// (c0999576f9e44e32945d93fb39de9be4). No duplicate bottom nav.
class ContentManagementScreen extends ConsumerStatefulWidget {
  const ContentManagementScreen({super.key});

  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAad6vSBUp7TJUfwx6q_Zu98Ov5kBoXEE6qBmxohdxS3Xvva7vzUbTd5Y8YRBWNFTGzudNbQtShKEQH6NuGII-SsspXdB7DKKsz4Pimfw-Jw5ZbD3mkR2xLXoBuY18sQ55Wah_7XurHfjAkge6D7u_3_X-u4e-H1jxPrAIqkvKr208JNSiW_mN2sX_JILyDCrOLz4QvdqqC50F7jj7CEJhMVpBASAs5cMEfzX-FmTtgGIOTgkONTsfB_g9bii7TyqizG0D5kkTunZt5';

  @override
  ConsumerState<ContentManagementScreen> createState() => _ContentManagementScreenState();
}

class _ContentManagementScreenState extends ConsumerState<ContentManagementScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hubAsync = ref.watch(contentHubProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Content Manager',
        showDivider: true,
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
              backgroundImage: CachedNetworkImageProvider(ContentManagementScreen._avatarUrl),
            ),
          ),
        ],
      ),
      body: hubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(contentHubProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (snap) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            _SearchAndActionsRow(
              theme: theme,
              searchController: _searchCtrl,
              onSearch: (q) => ref.read(contentHubSearchProvider.notifier).state = q,
            ),
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
                onPressed: () => ref.invalidate(contentHubProvider),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Refresh', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
            if (snap.blogs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'No blog posts yet.',
                  style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              ...snap.blogs.map((b) {
                final st = contentBlogStatusLabel(b);
                final published = st == 'PUBLISHED';
                return _BlogCard(
                  imageUrl: contentBlogImageUrl(b),
                  status: st,
                  title: contentBlogTitle(b),
                  meta: contentBlogMetaLine(b),
                  publishedStyle: published,
                  accentBorder: false,
                  onEdit: () {
                    final id = contentBlogId(b);
                    if (id.isEmpty) return;
                    context.push('/blog-post/edit/${Uri.encodeComponent(id)}');
                  },
                );
              }),
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
              child: snap.pages.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No pages loaded.',
                        style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < snap.pages.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.35)),
                          Builder(
                            builder: (context) {
                              final p = snap.pages[i];
                              final updated = contentPageUpdatedLine(p);
                              return _PageRow(
                                title: contentPageTitle(p),
                                updated: updated.isEmpty ? '—' : updated,
                                onTap: () => context.push(
                                  '/page-editor/${Uri.encodeComponent(contentPageSlug(p))}',
                                ),
                              );
                            },
                          ),
                        ],
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
            if (snap.sales.isEmpty)
              Text(
                'No sales campaigns yet.',
                style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
              )
            else ...[
              _FeaturedSaleCard(
                title: contentSaleTitle(snap.sales.first),
                onEdit: () => context.push('/sales-editor'),
              ),
              if (snap.sales.length > 1) ...[
                const SizedBox(height: 12),
                _OutlinedSaleCard(
                  title: contentSaleTitle(snap.sales[1]),
                  onEdit: () => context.push('/sales-editor'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchAndActionsRow extends StatelessWidget {
  const _SearchAndActionsRow({
    required this.theme,
    required this.searchController,
    required this.onSearch,
  });

  final ThemeData theme;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search blogs & pages — press enter',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
            prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: onSearch,
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
                    child: imageUrl.trim().isEmpty
                        ? ColoredBox(
                            color: theme.colorScheme.surfaceContainerLow,
                            child: Icon(Icons.article_outlined, color: theme.colorScheme.outline),
                          )
                        : CachedNetworkImage(
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
  const _FeaturedSaleCard({required this.title, required this.onEdit});

  final String title;
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
                title,
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
  const _OutlinedSaleCard({required this.title, required this.onEdit});

  final String title;
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
                  title,
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
