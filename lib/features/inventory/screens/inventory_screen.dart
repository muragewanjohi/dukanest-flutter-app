import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../providers/inventory_providers.dart';
import '../widgets/adjust_stock_sheet.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 20;

  late TabController _tabController;

  final TextEditingController _stockSearchController = TextEditingController();
  Timer? _stockSearchDebounce;
  List<Map<String, dynamic>> _stockItems = [];
  int _stockPage = 1;
  int _stockTotalPages = 1;
  int _stockTotalItems = 0;
  bool _stockLoading = true;
  String? _stockError;
  bool _lowStockOnly = false;

  List<Map<String, dynamic>> _historyItems = [];
  int _historyPage = 1;
  int _historyTotalPages = 1;
  int _historyTotalItems = 0;
  bool _historyLoading = true;
  String? _historyError;

  final TextEditingController _thresholdController = TextEditingController();
  bool _settingsLoading = true;
  String? _settingsError;
  bool _settingsSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadStock(page: 1);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final i = _tabController.index;
      if (i == 1 && _historyItems.isEmpty && !_historyLoading) {
        _loadHistory(page: 1);
      }
      if (i == 2 && _thresholdController.text.isEmpty && !_settingsLoading) {
        _hydrateSettingsFromProvider();
      }
    }
  }

  Future<void> _hydrateSettingsFromProvider() async {
    setState(() {
      _settingsLoading = true;
      _settingsError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getInventorySettings();
      if (!r.success || r.data == null) {
        throw Exception(r.error?.message ?? 'Failed to load settings');
      }
      final root = Map<String, dynamic>.from(r.data is Map ? r.data as Map : {});
      final data = root['data'] ?? root['settings'];
      final row = data is Map<String, dynamic>
          ? Map<String, dynamic>.from(data)
          : Map<String, dynamic>.from(root);
      final raw = row['lowStockThreshold'] ??
          row['low_stock_threshold'] ??
          row['threshold'] ??
          row['defaultThreshold'];
      if (!mounted) return;
      setState(() {
        if (raw is num) {
          _thresholdController.text = raw.round().toString();
        } else if (raw != null && raw.toString().isNotEmpty) {
          _thresholdController.text = raw.toString();
        }
        _settingsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settingsError = '$e';
        _settingsLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final v = int.tryParse(_thresholdController.text.trim());
    if (v == null || v < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a whole number threshold')),
      );
      return;
    }
    setState(() => _settingsSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = {'low_stock_threshold': v};
      final r = await api.updateInventorySettings(body);
      if (!r.success) {
        throw Exception(r.error?.message ?? 'Save failed');
      }
      ref.invalidate(inventoryAlertsProvider);
      ref.invalidate(inventorySettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Threshold saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _settingsSaving = false);
    }
  }

  @override
  void dispose() {
    _stockSearchDebounce?.cancel();
    _stockSearchController.dispose();
    _thresholdController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<void> _loadStock({int? page, bool refreshAlerts = false}) async {
    final target = page ?? _stockPage;
    setState(() {
      _stockLoading = true;
      _stockError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getInventory(
        page: target,
        limit: _pageSize,
        search: _stockSearchController.text.trim(),
        lowStockOnly: _lowStockOnly,
      );
      if (!r.success || r.data == null) {
        throw Exception(r.error?.message ?? 'Failed to load inventory');
      }
      final rawPayload = r.data!;
      final payload = rawPayload is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawPayload)
          : rawPayload is Map
              ? Map<String, dynamic>.from(rawPayload)
              : throw const FormatException('Invalid inventory response');
      final data = payload['data'];
      final root =
          data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : payload;

      List<Map<String, dynamic>> rows;
      rows = _asMapList(
        root['items'] ?? root['inventory'] ?? root['rows'],
      );

      final p = r.pagination;
      final pMap =
          payload['pagination'] is Map ? payload['pagination'] as Map : null;
      final pMap2 =
          root['pagination'] is Map ? root['pagination'] as Map : null;

      int pageNow = target;
      int totalPg = p?.totalPages ?? _pickInt(pMap ?? pMap2, ['total_pages', 'totalPages']) ?? 1;
      int total = p?.total ?? _pickInt(pMap ?? pMap2, ['total']) ?? rows.length;

      if (p?.page != null) pageNow = p!.page;

      setState(() {
        _stockItems = rows;
        _stockPage = pageNow;
        _stockTotalPages = totalPg < 1 ? 1 : totalPg;
        _stockTotalItems = total;
        _stockLoading = false;
      });
      if (refreshAlerts) ref.invalidate(inventoryAlertsProvider);
    } catch (e) {
      setState(() {
        _stockError = '$e';
        _stockLoading = false;
      });
    }
  }

  int? _pickInt(Map? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  Future<void> _loadHistory({int? page}) async {
    final target = page ?? _historyPage;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getInventoryHistory(page: target, limit: _pageSize);
      if (!r.success || r.data == null) {
        throw Exception(r.error?.message ?? 'Failed to load history');
      }
      final rawPayload = r.data!;
      final payload = rawPayload is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawPayload)
          : rawPayload is Map
              ? Map<String, dynamic>.from(rawPayload)
              : throw const FormatException('Invalid history response');
      final data = payload['data'];
      final root =
          data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : payload;
      List<Map<String, dynamic>> rows =
          _asMapList(root['items'] ?? root['history'] ?? root['entries']);

      final p = r.pagination;
      final pMap =
          payload['pagination'] is Map ? payload['pagination'] as Map : null;
      final pMap2 =
          root['pagination'] is Map ? root['pagination'] as Map : null;
      final pageNow = p?.page ?? _pickInt(pMap ?? pMap2, ['page']) ?? target;
      final totalPg =
          p?.totalPages ?? _pickInt(pMap ?? pMap2, ['total_pages', 'totalPages']) ?? 1;
      final total =
          p?.total ?? _pickInt(pMap ?? pMap2, ['total']) ?? rows.length;

      setState(() {
        _historyItems = rows;
        _historyPage = pageNow;
        _historyTotalPages = totalPg < 1 ? 1 : totalPg;
        _historyTotalItems = total;
        _historyLoading = false;
      });
    } catch (e) {
      setState(() {
        _historyError = '$e';
        _historyLoading = false;
      });
    }
  }

  void _onStockSearchChanged(String _) {
    _stockSearchDebounce?.cancel();
    _stockSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadStock(page: 1),
    );
  }

  AdjustmentRow _rowFromStockMap(Map<String, dynamic> row) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = row[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    String productIdEffective = pick(['product_id', 'productId']);
    final idFallback = pick(['id']);
    if (productIdEffective.isEmpty) productIdEffective = idFallback;

    final variantId = pick([
      'variant_id',
      'variantId',
      'product_variant_id',
    ]);
    final namePick =
        pick(['productName', 'name', 'product_name', 'title']);
    final name = namePick.isEmpty ? '(Product)' : namePick;
    final sku = pick(['sku', 'code']);
    final stockVal = row['stock'] ??
        row['quantity'] ??
        row['stockQuantity'] ??
        row['available'];
    final stockLabel = stockVal == null ? '' : stockVal.toString();

    return AdjustmentRow(
      productId: productIdEffective.isEmpty ? idFallback : productIdEffective,
      variantId: variantId,
      productName: name,
      skuLabel: sku,
      currentStockLabel: stockLabel,
    );
  }

  Widget _bannerFromAlerts(dynamic root) {
    final rootMap = root is Map<String, dynamic>
        ? root
        : root is Map
            ? Map<String, dynamic>.from(root)
            : <String, dynamic>{};
    final items = rootMap['items'] ??
        rootMap['alerts'] ??
        rootMap['data'];

    List<Map<String, dynamic>> list;
    if (items is List) {
      list = _asMapList(items);
    } else if (items is Map && items['items'] is List) {
      list = _asMapList(items['items']);
    } else {
      list = const [];
    }
    final theme = Theme.of(context);
    if (list.isEmpty) return const SizedBox.shrink();

    final summary =
        '${list.length} low-stock item${list.length == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _lowStockOnly = true;
                    _tabController.index = 0;
                  });
                  _loadStock(page: 1, refreshAlerts: true);
                },
                child: const Text('View stock'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatHistoryDate(dynamic raw) {
    if (raw == null) return '—';
    DateTime? d;
    if (raw is String) d = DateTime.tryParse(raw);
    if (raw is int) {
      final ms = raw < 20000000000 ? raw * 1000 : raw;
      d = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return d != null ? DateFormat.yMMMd().add_jm().format(d.toLocal()) : raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alertsAsync = ref.watch(inventoryAlertsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DashboardPageHeader(
                title: 'Inventory',
                subtitle: 'Stock counts, alerts, recent adjustments, thresholds.',
                leading: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/more');
                    }
                  },
                ),
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () {
                      ref.invalidate(inventoryAlertsProvider);
                      ref.invalidate(inventorySettingsProvider);
                      final i = _tabController.index;
                      if (i == 0) {
                        _loadStock(page: _stockPage, refreshAlerts: true);
                      }
                      if (i == 1) _loadHistory(page: _historyPage);
                      if (i == 2) _hydrateSettingsFromProvider();
                    },
                  ),
                ],
              ),
            ),
            alertsAsync.when(
              data: _bannerFromAlerts,
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryDark,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: AppTheme.primary,
                tabs: const [
                  Tab(text: 'Stock'),
                  Tab(text: 'History'),
                  Tab(text: 'Settings'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const PageScrollPhysics(),
                children: [
                  _buildStockTab(theme),
                  _buildHistoryTab(theme),
                  _buildSettingsTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () => _loadStock(page: _stockPage, refreshAlerts: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stockSearchController,
                  onChanged: _onStockSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search product or SKU…',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    prefixIcon:
                        Icon(Icons.search, color: theme.colorScheme.outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Low only'),
                selected: _lowStockOnly,
                onSelected: (v) {
                  setState(() => _lowStockOnly = v);
                  _loadStock(page: 1, refreshAlerts: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_stockLoading && _stockItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_stockError != null)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Column(
                  children: [
                    Text(_stockError!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _loadStock(page: _stockPage),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_stockItems.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 44, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'No stock rows',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ..._stockItems.map((row) => _inventoryCard(theme, row)),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Page $_stockPage of $_stockTotalPages • $_stockTotalItems total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _stockLoading || _stockPage <= 1
                        ? null
                        : () => _loadStock(page: _stockPage - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: _stockLoading || _stockPage >= _stockTotalPages
                        ? null
                        : () => _loadStock(page: _stockPage + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
          if (_stockLoading &&
              _stockItems.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Widget _inventoryCard(ThemeData theme, Map<String, dynamic> row) {
    final adj = _rowFromStockMap(row);
    final warning = row['lowStock'] == true ||
        row['isLowStock'] == true ||
        row['low_stock'] == true ||
        adj.currentStockLabel == '0';
    final stockText = adj.currentStockLabel.isEmpty
        ? '—'
        : adj.currentStockLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showAdjustStockSheet(
            context,
            ref,
            row: adj,
            onSuccess: () {
              _loadStock(page: _stockPage, refreshAlerts: true);
              if (_historyPage == 1) _loadHistory(page: 1);
            },
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adj.productName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: warning
                              ? const Color(0xFFB45309)
                              : AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (adj.skuLabel.isNotEmpty) 'SKU ${adj.skuLabel}',
                          'Stock $stockText',
                          if (adj.variantId.isNotEmpty) 'Variant',
                        ].join(' • '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Adjust stock',
                  onPressed: () => showAdjustStockSheet(
                    context,
                    ref,
                    row: adj,
                    onSuccess: () {
                      _loadStock(page: _stockPage, refreshAlerts: true);
                      if (_tabController.index == 1 ||
                          _historyItems.isNotEmpty) {
                        _loadHistory(page: _historyPage);
                      }
                    },
                  ),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () => _loadHistory(page: _historyPage),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (_historyLoading && _historyItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_historyError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Text(_historyError!, textAlign: TextAlign.center),
                    FilledButton(
                      onPressed: () => _loadHistory(page: 1),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_historyItems.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off_rounded,
                      size: 44, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'No adjustments yet',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            )
          else ...[
            for (final h in _historyItems) ...[
              Material(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (h['productName'] ??
                                h['product_name'] ??
                                h['name'] ??
                                'Adjustment')
                            .toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          _formatHistoryDate(h['createdAt'] ??
                              h['created_at'] ??
                              h['adjustedAt']),
                          (h['adjustmentType'] ?? h['adjustment_type'] ?? '')
                              .toString(),
                          '${h['quantity'] ?? h['change'] ?? h['qty'] ?? ''}',
                        ].where((e) => e.toString().isNotEmpty).join(' • '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Page $_historyPage of $_historyTotalPages • $_historyTotalItems',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _historyLoading || _historyPage <= 1
                      ? null
                      : () => _loadHistory(page: _historyPage - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed:
                      _historyLoading || _historyPage >= _historyTotalPages
                          ? null
                          : () => _loadHistory(page: _historyPage + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTab(ThemeData theme) {
    if (_thresholdController.text.isEmpty && _settingsLoading) {
      // First open
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hydrateSettingsFromProvider();
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        Text(
          'Low-stock threshold',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'When available quantity drops to this amount or lower, alerts appear.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (_settingsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_settingsError != null)
          Text(_settingsError!,
              style: TextStyle(color: theme.colorScheme.error))
        else ...[
          TextField(
            controller: _thresholdController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Threshold (units)',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _settingsSaving ? null : _saveSettings,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _settingsSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save threshold'),
          ),
          TextButton.icon(
            onPressed: () {
              ref.invalidate(inventorySettingsProvider);
              _hydrateSettingsFromProvider();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reload'),
          ),
        ],
      ],
    );
  }
}
