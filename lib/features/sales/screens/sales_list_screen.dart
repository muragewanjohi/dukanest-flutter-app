import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

/// Invalidates after list mutations (save/delete from editor).
final salesListRefreshTokenProvider = StateProvider<int>((ref) => 0);

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _loading = true;
  String? _error;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getSales(
        page: targetPage,
        limit: _pageSize,
        search: _searchController.text.trim(),
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
      if (!r.success) throw StateError(r.error?.message ?? 'Failed to load sales');
      final payload = r.data;
      final root = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final rawList = root['items'] ?? root['sales'] ?? root['data'];
      final list = rawList is List
          ? rawList.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      final pag = r.pagination;
      setState(() {
        _items = list;
        _page = pag?.page ?? targetPage;
        _totalPages = pag?.totalPages ?? 1;
        _totalItems = pag?.total ?? list.length;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _load(page: 1);
    });
  }

  Future<void> _deleteSale(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sale?'),
        content: const Text('This will remove the sale campaign.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.deleteSale(id);
      if (!r.success) throw StateError(r.error?.message ?? 'Delete failed');
      ref.read(salesListRefreshTokenProvider.notifier).state++;
      await _load(page: _page);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  static String _pickString(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return fallback;
  }

  static String _formatDate(dynamic raw) {
    DateTime? d;
    if (raw is String) d = DateTime.tryParse(raw);
    if (raw is int) {
      final ms = raw < 20000000000 ? raw * 1000 : raw;
      d = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (d == null) return '—';
    return DateFormat.yMMMd().format(d);
  }

  static int _countProducts(Map<String, dynamic> sale) {
    final list = sale['product_sales'] ?? sale['productSales'] ?? sale['products'] ?? sale['items'];
    if (list is List) return list.length;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.listen<int>(salesListRefreshTokenProvider, (previous, next) {
      if (previous == null || previous == next || !mounted) return;
      _load(page: _page);
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Sales & Promotions'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sales/new'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search sales…',
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _statusFilter.isEmpty,
                  onTap: () {
                    setState(() => _statusFilter = '');
                    _page = 1;
                    _load(page: 1);
                  },
                ),
                _FilterChip(
                  label: 'Draft',
                  selected: _statusFilter == 'draft',
                  onTap: () {
                    setState(() => _statusFilter = 'draft');
                    _page = 1;
                    _load(page: 1);
                  },
                ),
                _FilterChip(
                  label: 'Active',
                  selected: _statusFilter == 'active',
                  onTap: () {
                    setState(() => _statusFilter = 'active');
                    _page = 1;
                    _load(page: 1);
                  },
                ),
                _FilterChip(
                  label: 'Inactive',
                  selected: _statusFilter == 'inactive',
                  onTap: () {
                    setState(() => _statusFilter = 'inactive');
                    _page = 1;
                    _load(page: 1);
                  },
                ),
                _FilterChip(
                  label: 'Archived',
                  selected: _statusFilter == 'archived',
                  onTap: () {
                    setState(() => _statusFilter = 'archived');
                    _page = 1;
                    _load(page: 1);
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _load(page: _page),
                    child: _items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              Center(
                                child: Text(
                                  'No sales match your filters.',
                                  style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final sale = _items[i];
                              final id = _pickString(sale, ['id', '_id']);
                              final title = _pickString(sale, ['name', 'title'], fallback: 'Sale');
                              final start = _formatDate(sale['start_date'] ?? sale['startDate']);
                              final end = _formatDate(sale['end_date'] ?? sale['endDate']);
                              final status = _pickString(sale, ['status'], fallback: 'draft');
                              final count = _countProducts(sale);

                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: id.isEmpty ? null : () => context.push('/sales/edit/${Uri.encodeComponent(id)}'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.primaryDark,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$start - $end',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$count product${count == 1 ? '' : 's'} • ${status.toUpperCase()}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Edit',
                                          onPressed: id.isEmpty ? null : () => context.push('/sales/edit/${Uri.encodeComponent(id)}'),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          onPressed: id.isEmpty ? null : () => _deleteSale(id),
                                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
          if (_totalPages > 1 || _totalItems > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Page $_page of $_totalPages • $_totalItems total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading || _page <= 1 ? null : () => _load(page: _page - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: _loading || _page >= _totalPages ? null : () => _load(page: _page + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppTheme.primaryDark : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
