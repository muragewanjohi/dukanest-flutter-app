import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_page_header.dart';

class _CustomerRow {
  const _CustomerRow({
    required this.id,
    required this.name,
    required this.email,
    required this.orderCount,
    required this.totalSpentLabel,
    required this.lastOrderLabel,
    this.isVip = false,
    this.isNewThisMonth = false,
  });

  final String id;
  final String name;
  final String email;
  final int orderCount;
  final String totalSpentLabel;
  final String lastOrderLabel;
  final bool isVip;
  final bool isNewThisMonth;
}

/// Customer Directory — Stitch: header, search row, chips, bordered cards.
class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  String _query = '';
  int _chip = 0;
  Timer? _searchDebounce;
  bool _loading = true;
  String? _error;
  List<_CustomerRow> _customers = const [];

  static const _chips = ['All Customers', 'VIP Customers', 'Repeat Buyers', 'New This Month'];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.getCustomers(
        page: 1,
        limit: 100,
        search: _query.trim(),
      );
      if (!response.success || response.data == null) {
        throw StateError(response.error?.message ?? 'Failed to load customers');
      }
      var root = response.data;
      if (root is Map<String, dynamic> && root['data'] is Map) {
        root = root['data'];
      }
      final items = root is Map<String, dynamic>
          ? (root['items'] ?? root['customers'] ?? root['data'])
          : null;
      if (items is! List) {
        throw const FormatException('Invalid customers response');
      }
      final mapped = items.whereType<Map>().map((raw) {
        final p = Map<String, dynamic>.from(raw);
        final id = (p['id'] ?? p['customerId'] ?? '').toString();
        final name = (p['name'] ?? p['fullName'] ?? p['displayName'] ?? p['email'] ?? 'Customer')
            .toString();
        final email = (p['email'] ?? '').toString();
        final orderCountRaw = p['orderCount'] ?? p['ordersCount'] ?? p['totalOrders'] ?? 0;
        final orderCount =
            orderCountRaw is num ? orderCountRaw.toInt() : int.tryParse(orderCountRaw.toString()) ?? 0;
        final spent = p['totalSpent'] ?? p['lifetimeValue'] ?? p['total_spent'];
        final spentLabel = spent is num ? spent.toStringAsFixed(0) : spent?.toString() ?? '—';
        final lastRaw = p['lastOrderAt'] ?? p['last_order_at'] ?? p['lastOrder'];
        String lastLabel = '—';
        if (lastRaw is String && lastRaw.isNotEmpty) {
          lastLabel = lastRaw;
        } else if (lastRaw != null) {
          lastLabel = lastRaw.toString();
        }
        final isVip = p['isVip'] == true || p['vip'] == true;
        final isNew = p['isNewThisMonth'] == true || p['newThisMonth'] == true;
        return _CustomerRow(
          id: id.isEmpty ? name.hashCode.toString() : id,
          name: name,
          email: email,
          orderCount: orderCount,
          totalSpentLabel: spentLabel,
          lastOrderLabel: lastLabel,
          isVip: isVip,
          isNewThisMonth: isNew,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _customers = mapped;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_CustomerRow> get _visible {
    var list = _customers;
    switch (_chip) {
      case 1:
        list = list.where((c) => c.isVip).toList();
        break;
      case 2:
        list = list.where((c) => c.orderCount > 1).toList();
        break;
      case 3:
        list = list.where((c) => c.isNewThisMonth).toList();
        break;
      default:
        break;
    }
    if (_query.trim().isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where((c) => c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q))
        .toList();
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/more');
    }
  }

  void _onSearchChanged(String v) {
    setState(() => _query = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadCustomers);
  }

  void _showCustomerSheet(_CustomerRow c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(_initials(c.name), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        Text(c.email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _SheetStat(label: 'Orders', value: '${c.orderCount}')),
                  Expanded(child: _SheetStat(label: 'Lifetime value', value: c.totalSpentLabel)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Last order · ${c.lastOrderLabel}', style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;

    if (_loading && _customers.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _customers.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadCustomers, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadCustomers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            DashboardPageHeader(
              title: 'Customers',
              leading: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => _goBack(context),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search customer name...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.tune, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _chips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final sel = _chip == i;
                  return Material(
                    color: sel ? AppTheme.primary : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: () => setState(() => _chip = i),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          _chips[i],
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: sel ? Colors.white : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    _customers.isEmpty ? 'No customers yet' : 'No matches for your filters.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              )
            else
              ...List.generate(visible.length, (index) {
                final c = visible[index];
                final highlight = index == 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _showCustomerSheet(c),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: highlight
                              ? const Border(left: BorderSide(color: AppTheme.primary, width: 4))
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                              child: Text(
                                _initials(c.name),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  Text(
                                    c.email,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
