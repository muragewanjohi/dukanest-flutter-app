import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../data/attribute_value_format.dart';
import '../data/attributes_repository.dart';
import '../providers/attributes_list_provider.dart';

/// Attributes management — Stitch: "Attributes Management"
/// (screen eb47190bf4884e469a6c82bec4d137e3).
///
/// Full-screen route `/attributes` (no dashboard bottom navigation).
class AttributesManagementScreen extends ConsumerStatefulWidget {
  const AttributesManagementScreen({super.key});

  @override
  ConsumerState<AttributesManagementScreen> createState() =>
      _AttributesManagementScreenState();
}

class _AttributesManagementScreenState extends ConsumerState<AttributesManagementScreen> {
  bool _showSearch = false;
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

  List<ProductAttribute> _filter(List<ProductAttribute> all) {
    if (_query.isEmpty) return all;
    return all.where((a) {
      final inName = a.name.toLowerCase().contains(_query);
      final inDesc = a.description.toLowerCase().contains(_query);
      final inValues = a.values.any((v) => v.toLowerCase().contains(_query));
      return inName || inDesc || inValues;
    }).toList();
  }

  void _openAttributeEditor({ProductAttribute? existing}) {
    if (existing == null) {
      context.push('/attributes/new');
    } else {
      context.push('/attributes/edit/${Uri.encodeComponent(existing.id)}');
    }
  }

  Future<void> _confirmDelete(ProductAttribute a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete attribute?'),
        content: Text('Remove "${a.name}" and its values from the catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.deleteDashboardAttribute(a.id);
      if (!r.success) {
        throw StateError(r.error?.message ?? 'Delete failed');
      }
      ref.invalidate(dashboardAttributesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "${a.name}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final asyncAttrs = ref.watch(dashboardAttributesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: asyncAttrs.when(
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
                  onPressed: () => ref.invalidate(dashboardAttributesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (attributes) {
          final filtered = _filter(attributes);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                toolbarHeight: kToolbarHeight,
                elevation: 0,
                backgroundColor: AppTheme.surface,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                title: const Text('Attributes'),
                actions: [
                  IconButton(
                    icon: Icon(
                      _showSearch ? Icons.close_rounded : Icons.search_rounded,
                      color: AppTheme.primaryDark,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchController.clear();
                          _query = '';
                        }
                      });
                    },
                  ),
                ],
                bottom: _showSearch
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(64),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search attributes…',
                              filled: true,
                              fillColor: AppTheme.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.search, color: colorScheme.outline),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Product Management',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Define Properties',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Attributes help organize your product variations effectively.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.4,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...filtered.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _AttributeCard(
                            attribute: a,
                            onEdit: () => _openAttributeEditor(existing: a),
                            onDelete: () => _confirmDelete(a),
                          ),
                        )),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Center(
                          child: Text(
                            'No attributes match your search',
                            style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryDark, AppTheme.primary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryDark.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openAttributeEditor(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Add Attribute',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
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
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AttributeCard extends StatelessWidget {
  const _AttributeCard({
    required this.attribute,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductAttribute attribute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppTheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: ColoredBox(color: AppTheme.primary),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attribute.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            attribute.description,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: attribute.values.map((v) {
                    final label =
                        AttributeValueFormat.shortLabel(v, attribute.displayType);
                    final swatch = attribute.displayType == AttributeDisplayType.color
                        ? AttributeValueFormat.parse(v).$2
                        : null;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (swatch != null) ...[
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: swatch,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.outlineVariant, width: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
