import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../providers/pending_orders_count_provider.dart';

/// Order Fulfillment — Stitch layout (metrics, chips, order cards, processing goal).
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  int _filterIndex = 0;
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalPages = 1;
  int _totalItems = 0;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = true;
  String? _errorMessage;
  List<_OrderListItem> _allOrders = const [];
  bool _isLiveData = false;

  /// Top-row metrics (from API `metrics` / `summary` when present, else derived).
  int _metricActiveToday = 0;
  int _metricPendingShipment = 0;

  /// Processing goal: `processed` of `goalTotal` orders (API or derived for current list).
  int _goalProcessed = 0;
  int _goalTotal = 0;

  static const _filters = ['All Orders', 'Pending', 'Paid', 'Shipped'];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeStatus(String input) {
    final lower = input.trim().toLowerCase();
    if (lower.contains('pending')) return 'Pending';
    if (lower.contains('paid') || lower.contains('payment')) return 'Paid';
    if (lower.contains('ship') || lower.contains('fulfill') || lower.contains('deliver')) {
      return 'Shipped';
    }
    return 'Pending';
  }

  String _formatCurrency(dynamic amount, String? currencyCode) {
    if (amount is num) {
      final code = (currencyCode == null || currencyCode.isEmpty) ? 'KES' : currencyCode;
      return '$code ${amount.toStringAsFixed(2)}';
    }
    if (amount is String && amount.trim().isNotEmpty) return amount;
    return 'KES 0.00';
  }

  ({String? status, String? paymentStatus}) _apiFiltersFromSelection() {
    final selectedFilter = _filters[_filterIndex];
    return switch (selectedFilter) {
      'All Orders' => (status: null, paymentStatus: null),
      'Pending' => (status: 'pending', paymentStatus: null),
      // "Paid" is a payment-state filter, not an order lifecycle status.
      'Paid' => (status: null, paymentStatus: 'paid'),
      'Shipped' => (status: 'shipped', paymentStatus: null),
      _ => (status: null, paymentStatus: null),
    };
  }

  static int? _toIntOrNull(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static Map<String, dynamic>? _asStringKeyedMap(dynamic v) {
    if (v is! Map) return null;
    return Map<String, dynamic>.from(v);
  }

  /// Optional `data.metrics` / `data.summary` / etc. on `GET .../dashboard/orders`.
  static Map<String, dynamic>? _pickMetricsBucket(Map<String, dynamic> payload) {
    for (final key in ['metrics', 'summary', 'stats', 'ordersMetrics']) {
      final m = _asStringKeyedMap(payload[key]);
      if (m != null) return m;
    }
    return null;
  }

  static ({
    int activeToday,
    int pendingShipment,
    int goalProcessed,
    int goalTotal,
  }) _metricsFromApiBucket(Map<String, dynamic> bucket, int listTotal, List<_OrderListItem> mapped) {
    final activeToday = _toIntOrNull(
          bucket['activeToday'] ??
              bucket['active_today'] ??
              bucket['todayOrders'] ??
              bucket['today_orders'] ??
              bucket['newToday'] ??
              bucket['ordersToday'],
        ) ??
        0;
    final pendingShipment = _toIntOrNull(
          bucket['pendingShipment'] ??
              bucket['pending_shipment'] ??
              bucket['pendingFulfillment'] ??
              bucket['pending_fulfillment'] ??
              bucket['pending'] ??
              bucket['awaitingShipment'],
        ) ??
        0;
    var goalProcessed = _toIntOrNull(
          bucket['processedToday'] ??
              bucket['processed_today'] ??
              bucket['shippedToday'] ??
              bucket['completedToday'] ??
              bucket['fulfilledToday'],
        ) ??
        0;
    var goalTotal = _toIntOrNull(
          bucket['dayTotal'] ??
              bucket['day_total'] ??
              bucket['todayTotal'] ??
              bucket['processingGoalTotal'] ??
              bucket['totalActiveToday'],
        ) ??
        0;
    if (goalTotal <= 0) goalTotal = listTotal > 0 ? listTotal : activeToday;
    if (goalTotal <= 0) goalTotal = mapped.length;
    if (goalTotal > 0) {
      goalProcessed = goalProcessed.clamp(0, goalTotal);
    } else {
      goalProcessed = 0;
    }

    return (
      activeToday: activeToday,
      pendingShipment: pendingShipment,
      goalProcessed: goalProcessed,
      goalTotal: goalTotal,
    );
  }

  static bool _isCreatedTodayFromLabel(String dateText) {
    final d = DateTime.tryParse(dateText);
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  ({
    int activeToday,
    int pendingShipment,
    int goalProcessed,
    int goalTotal,
  }) _resolveOrderMetrics(
    Map<String, dynamic>? dataPayload,
    List<_OrderListItem> mapped, {
    required int totalItems,
    required int totalPages,
  }) {
    if (dataPayload != null) {
      final bucket = _pickMetricsBucket(dataPayload);
      if (bucket != null) {
        return _metricsFromApiBucket(bucket, totalItems, mapped);
      }
    }

    final pendingOnPage = mapped.where((o) => o.status == 'Pending').length;
    final nonPendingOnPage = mapped.where((o) => o.status != 'Pending').length;
    final todayOnPage = mapped.where((o) => _isCreatedTodayFromLabel(o.date)).length;

    final pendingShip = _filterIndex == 1 ? totalItems : pendingOnPage;
    final active = todayOnPage > 0 ? todayOnPage : (_filterIndex == 0 ? totalItems : mapped.length);
    final goalT = totalItems > 0 ? totalItems : mapped.length;

    var goalP = 0;
    if (goalT > 0) {
      if (totalPages <= 1) {
        goalP = nonPendingOnPage.clamp(0, goalT);
      } else {
        final n = mapped.length;
        goalP = n > 0 ? ((nonPendingOnPage / n) * goalT).round().clamp(0, goalT) : 0;
      }
    }

    return (
      activeToday: active,
      pendingShipment: pendingShip,
      goalProcessed: goalP,
      goalTotal: goalT,
    );
  }

  Future<void> _loadOrders({int? pageOverride}) async {
    final pageToLoad = pageOverride ?? _currentPage;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final filters = _apiFiltersFromSelection();
      final response = await api.getOrders(
        page: pageToLoad,
        limit: _pageSize,
        search: _searchController.text.trim(),
        status: filters.status,
        paymentStatus: filters.paymentStatus,
      );

      if (!response.success) {
        throw StateError(response.error?.message ?? 'Failed to load orders');
      }

      final payload = response.data;
      final items = payload is Map<String, dynamic>
          ? payload['items'] ?? payload['orders'] ?? payload['data']
          : payload;
      if (items is! List) {
        throw const FormatException('Invalid orders response');
      }

      final mapped = items.whereType<Map>().map((raw) {
        final order = Map<String, dynamic>.from(raw);
        final idValue = order['code'] ??
            order['orderNumber'] ??
            order['order_number'] ??
            order['id'] ??
            'UNKNOWN';
        final idText = idValue.toString();
        final idLine = idText.startsWith('#') ? 'ORDER $idText' : 'ORDER #$idText';
        final status = _normalizeStatus((order['status'] ?? '').toString());
        final currencyCode = (order['currencyCode'] ?? order['currency_code'])?.toString();
        final totalText = _formatCurrency(order['total'] ?? order['totalAmount'] ?? order['amount'], currencyCode);
        final quantity = order['itemCount'] ?? order['totalItems'] ?? order['itemsCount'];
        final quantityText = quantity is num ? '${quantity.toInt()} Items' : 'Items';
        final detail = '$quantityText • $totalText';
        final customer = (order['customerName'] ??
                order['customer_name'] ??
                order['customer'] ??
                order['email'] ??
                'Customer')
            .toString();
        final dateText = (order['createdAt'] ??
                order['created_at'] ??
                order['updatedAt'] ??
                order['updated_at'] ??
                'Recent')
            .toString();

        return _OrderListItem(
          orderKey: idText,
          idLine: idLine,
          date: dateText,
          customer: customer,
          status: status,
          detail: detail,
        );
      }).toList();

      final dataPayload = payload is Map<String, dynamic> ? payload : null;
      final totalPages = response.pagination?.totalPages ?? 1;
      final totalItems = response.pagination?.total ?? mapped.length;
      final metrics = _resolveOrderMetrics(
        dataPayload,
        mapped,
        totalItems: totalItems,
        totalPages: totalPages,
      );

      setState(() {
        _allOrders = mapped;
        _currentPage = response.pagination?.page ?? pageToLoad;
        _pageSize = response.pagination?.limit ?? _pageSize;
        _totalPages = totalPages;
        _totalItems = totalItems;
        _metricActiveToday = metrics.activeToday;
        _metricPendingShipment = metrics.pendingShipment;
        _goalProcessed = metrics.goalProcessed;
        _goalTotal = metrics.goalTotal;
        _isLiveData = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLiveData = false;
        _isLoading = false;
        _metricActiveToday = 0;
        _metricPendingShipment = 0;
        _goalProcessed = 0;
        _goalTotal = 0;
      });
    }
  }

  List<_OrderListItem> get _visibleOrders {
    return _allOrders;
  }

  void _onFilterChanged(int index) {
    setState(() => _filterIndex = index);
    _loadOrders(pageOverride: 1);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadOrders(pageOverride: 1),
    );
  }

  void _goPrevPage() {
    if (_currentPage <= 1 || _isLoading) return;
    _loadOrders(pageOverride: _currentPage - 1);
  }

  void _goNextPage() {
    if (_currentPage >= _totalPages || _isLoading) return;
    _loadOrders(pageOverride: _currentPage + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orders = _visibleOrders;
    final providerPendingCount = ref.watch(pendingOrdersCountProvider).maybeWhen(
          data: (count) => count,
          orElse: () => 0,
        );
    // Prefer the metric shown on this screen (pending shipment) so the badge
    // mirrors the same "pending orders" figure users see in the cards.
    final pendingOrdersCount =
        _metricPendingShipment > 0 ? _metricPendingShipment : providerPendingCount;
    final badgeLabel = pendingOrdersCount > 99 ? '99+' : '$pendingOrdersCount';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + MediaQuery.of(context).padding.top, 16, 24),
          children: [
            DashboardPageHeader(
              title: 'Order Fulfillment',
              subtitle: "Manage and process your store's incoming orders.",
              actions: [
                IconButton(
                  icon: Badge(
                    isLabelVisible: pendingOrdersCount > 0,
                    label: Text(badgeLabel),
                    child: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  onPressed: () => context.push('/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _OrdersDataSourceBadge(isLiveData: _isLiveData),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricCardActiveToday(value: '$_metricActiveToday')),
                const SizedBox(width: 10),
                Expanded(child: _MetricCardPendingShipment(value: '$_metricPendingShipment')),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = _filterIndex == index;
                  return _FilterChip(
                    label: _filters[index],
                    selected: selected,
                    onTap: () => _onFilterChanged(index),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SearchBar(
              hintText: 'Search orders...',
              controller: _searchController,
              onChanged: _onSearchChanged,
              leading: const Icon(Icons.search),
              trailing: _isLoading
                  ? const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ]
                  : null,
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(Colors.white),
              side: WidgetStateProperty.all(
                BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load orders',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadOrders,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No orders found for the selected filter.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...orders.map((order) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OrderCard(
                    idLine: order.idLine,
                    date: order.date,
                    customer: order.customer,
                    status: order.status,
                    detail: order.detail,
                    accentLeft: order.status == 'Pending',
                    onOpen: () => context.push('/orders/detail/${Uri.encodeComponent(order.orderKey)}'),
                  ),
                );
              }),
            if (!_isLoading && _errorMessage == null) ...[
              const SizedBox(height: 12),
              _OrdersPaginationBar(
                currentPage: _currentPage,
                totalPages: _totalPages,
                totalItems: _totalItems,
                onPrev: _goPrevPage,
                onNext: _goNextPage,
                canPrev: _currentPage > 1,
                canNext: _currentPage < _totalPages,
              ),
            ],
            const SizedBox(height: 8),
            _ProcessingGoalCard(
              processed: _goalProcessed,
              total: _goalTotal,
            ),
            const SizedBox(height: 12),
            const _QuickActionsCard(),
          ],
        ),
      ),
    );
  }
}

class _OrderListItem {
  const _OrderListItem({
    required this.orderKey,
    required this.idLine,
    required this.date,
    required this.customer,
    required this.status,
    required this.detail,
  });

  final String orderKey;
  final String idLine;
  final String date;
  final String customer;
  final String status;
  final String detail;
}

class _OrdersDataSourceBadge extends StatelessWidget {
  const _OrdersDataSourceBadge({required this.isLiveData});

  final bool isLiveData;

  @override
  Widget build(BuildContext context) {
    final bg = isLiveData ? const Color(0xFFD1FAE5) : const Color(0xFFFFF4E5);
    final fg = isLiveData ? const Color(0xFF065F46) : const Color(0xFF9A3412);
    final label = isLiveData ? 'LIVE ORDERS DATA' : 'FALLBACK / NO LIVE DATA';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiveData ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ).copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersPaginationBar extends StatelessWidget {
  const _OrdersPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPrev,
    required this.onNext,
    required this.canPrev,
    required this.canNext,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool canPrev;
  final bool canNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Page $currentPage of $totalPages • $totalItems total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: canPrev ? onPrev : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
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
    return Material(
      color: selected ? AppTheme.primaryDark : const Color(0xFFE8E8ED),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : const Color(0xFF1B1C1C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stitch: Active Today — surface-container-low, label on-surface-variant, value primary.
class _MetricCardActiveToday extends StatelessWidget {
  const _MetricCardActiveToday({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE TODAY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stitch: Pending Shipment — primary-container/10, label & value primary tones.
class _MetricCardPendingShipment extends StatelessWidget {
  const _MetricCardPendingShipment({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PENDING SHIPMENT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.idLine,
    required this.date,
    required this.customer,
    required this.status,
    required this.detail,
    required this.accentLeft,
    required this.onOpen,
  });

  final String idLine;
  final String date;
  final String customer;
  final String status;
  final String detail;
  final bool accentLeft;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (accentLeft) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            idLine.toUpperCase(),
                            style: metaStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(date, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      customer,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusPill(status: status),
                        Text(
                          detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _ChevronButton(onTap: onOpen),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (status) {
      'Pending' => (theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer),
      'Paid' => (const Color(0xFFDFE0FF), const Color(0xFF0A2ACF)),
      'Shipped' => (theme.colorScheme.surfaceContainerHigh, theme.colorScheme.onSurfaceVariant),
      _ => (const Color(0xFFF0F0F0), theme.colorScheme.onSurfaceVariant),
    };

    final label = status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.primaryDark,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ProcessingGoalCard extends StatelessWidget {
  const _ProcessingGoalCard({
    required this.processed,
    required this.total,
  });

  final int processed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total > 0 ? (100 * processed / total).round().clamp(0, 100) : 0;
    // Keep determinate at 0% when there's no data (no animated indeterminate bar).
    final progress = total > 0 ? (processed / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Processing Goal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$pct%',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                total > 0
                    ? 'You\'ve processed $processed out of $total orders in this view. '
                        'Great work staying on top of fulfillment.'
                    : 'No orders in this view yet. When new orders arrive, your progress will show here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ACTIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          _QuickActionTile(icon: Icons.print_outlined, label: 'Bulk Print Labels', onTap: () {}),
          const SizedBox(height: 8),
          _QuickActionTile(icon: Icons.local_shipping_outlined, label: 'Mark All as Shipped', onTap: () {}),
          const SizedBox(height: 8),
          _QuickActionTile(icon: Icons.file_download_outlined, label: 'Export CSV Report', onTap: () {}),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
