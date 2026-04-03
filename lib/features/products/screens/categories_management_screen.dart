import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../data/categories_repository.dart';
import '../providers/categories_list_provider.dart';

/// Categories management — Stitch: "Categories Management"
/// (DukaNest Tenant App Plan, screen c2b52d24effe48a88c49e3d533e62515).
///
/// Routed at `/categories` (outside the dashboard shell — no bottom navigation).
class CategoriesManagementScreen extends ConsumerStatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  ConsumerState<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends ConsumerState<CategoriesManagementScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _totalProducts(List<CategoryEntry> categories) =>
      categories.fold<int>(0, (s, c) => s + c.productCount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final asyncCategories = ref.watch(categoriesListProvider);

    return asyncCategories.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: Text('Categories', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colorScheme.outline),
            onPressed: () => context.pop(),
          ),
          title: Text('Categories', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(err.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(categoriesListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (categories) {
        final filtered = _query.isEmpty
            ? categories
            : categories.where((c) => c.name.toLowerCase().contains(_query)).toList();

        final fabBottom = MediaQuery.of(context).padding.bottom + 24;

        return Scaffold(
          backgroundColor: AppTheme.surface,
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: fabBottom),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryDark, AppTheme.primary],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => context.push('/categories/new'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Add Category',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesListProvider);
              await ref.read(categoriesListProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: AppTheme.surface,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: colorScheme.outline),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Categories',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                    letterSpacing: -0.25,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.add_rounded, color: AppTheme.primaryDark),
                    onPressed: () => context.push('/categories/new'),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 15, color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search categories...',
                        hintStyle: GoogleFonts.inter(
                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Icon(Icons.search, color: colorScheme.outline),
                        filled: true,
                        fillColor: AppTheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.primaryDark.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 128,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryDark.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TOTAL ITEMS',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryDark,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        NumberFormat.decimalPattern('en_US')
                                            .format(_totalProducts(categories)),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '+12%',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 96,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.category_rounded, color: AppTheme.primaryDark),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${categories.length}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Categories',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        Text(
                          'Sorted by Name',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...filtered.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _CategoryTile(
                          category: c,
                          onTap: () => context.push('/categories/edit/${c.id}'),
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            'No categories match your search',
                            style: GoogleFonts.inter(
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final CategoryEntry category;
  final VoidCallback onTap;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final theme = Theme.of(context);

    return Material(
      color: AppTheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: _pressed ? 4 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: c.localImagePath != null
                          ? Image.file(
                              File(c.localImagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.category_outlined,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            )
                          : c.imageUrl != null
                              ? Image.network(
                                  c.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => ColoredBox(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.category_outlined,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                )
                              : ColoredBox(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.category_outlined,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${c.productCount} Products',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.outlineVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDark.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                c.active ? 'ACTIVE' : 'INACTIVE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryDark,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _pressed ? AppTheme.primaryDark : AppTheme.outlineVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
