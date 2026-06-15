import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../models/expense_category.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  static const _pageSize = 20;

  List<Map<String, dynamic>> _items = [];
  List<ExpenseCategory> _apiCategories = [];
  int _page = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _loading = true;
  bool _categoriesLoading = true;
  bool _saving = false;
  String? _error;

  /// Empty = all categories; otherwise expense category UUID.
  String _categoryFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadCategories();
    await _load(page: 1);
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getExpenseCategories();
      if (!r.success) {
        throw StateError(r.error?.message ?? 'Failed to load categories');
      }
      if (!mounted) return;
      setState(() {
        _apiCategories = parseExpenseCategoryList(r.data);
        _categoriesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiCategories = const [];
        _categoriesLoading = false;
      });
    }
  }

  Future<ExpenseCategory?> _createCategoryViaDialog() async {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New expense category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            TextField(
              controller: slugCtrl,
              decoration: const InputDecoration(
                labelText: 'Slug (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final slug = slugCtrl.text.trim();
    nameCtrl.dispose();
    slugCtrl.dispose();

    if (ok != true || !mounted || name.isEmpty) return null;
    try {
      final body = <String, dynamic>{
        'name': name,
        if (slug.isNotEmpty) 'slug': slug,
      };
      final r = await ref.read(apiClientProvider).createExpenseCategory(body);
      if (!r.success) {
        throw StateError(r.error?.message ?? 'Create failed');
      }
      final created = parseExpenseCategoryFromCreateResponse(r.data);
      if (!mounted) return null;
      await _loadCategories();
      if (created != null && created.id.isNotEmpty) return created;
      for (final c in _apiCategories) {
        if (c.name == name) return c;
      }
      return null;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError ? e.message : 'Could not create category',
          ),
        ),
      );
      return null;
    }
  }

  Future<void> _openCreateCategoryDialog() async {
    final created = await _createCategoryViaDialog();
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category created')),
      );
    }
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.getExpenses(
        page: targetPage,
        limit: _pageSize,
        startDate: _formatApiDate(_startDate),
        endDate: _formatApiDate(_endDate),
        categoryId: _categoryFilter.isEmpty ? null : _categoryFilter,
      );
      if (!response.success) {
        throw StateError(response.error?.message ?? 'Failed to load expenses');
      }

      final payload = response.data;
      final root =
          payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final nestedData = root['data'];
      final dataRoot = nestedData is Map<String, dynamic>
          ? nestedData
          : nestedData is Map
              ? Map<String, dynamic>.from(nestedData)
              : root;
      final rawList =
          dataRoot['items'] ?? dataRoot['expenses'] ?? root['items'];
      final list = rawList is List
          ? rawList
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      final pagination = response.pagination;
      final paginationRoot = _mapFrom(root['pagination']) ??
          _mapFrom(dataRoot['pagination']) ??
          const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _items = list;
        _page =
            pagination?.page ?? _intFrom(paginationRoot['page'], targetPage);
        _totalPages = pagination?.totalPages ??
            _intFrom(
              paginationRoot['totalPages'] ?? paginationRoot['total_pages'],
              1,
            );
        _totalItems =
            pagination?.total ?? _intFrom(paginationRoot['total'], list.length);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load expenses.';
        _loading = false;
      });
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final id = _pickString(expense, const ['id', '_id']);
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This removes the expense from your P&L records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final response = await ref.read(apiClientProvider).deleteExpense(id);
      if (!response.success) {
        throw StateError(response.error?.message ?? 'Delete failed');
      }
      await _load(page: _page);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete expense. Try again.')),
      );
    }
  }

  Future<void> _openExpenseSheet([Map<String, dynamic>? expense]) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _ExpenseFormSheet(
        expense: expense,
        categories: _apiCategories,
        onCreateCategory: _createCategoryViaDialog,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final id =
          expense == null ? '' : _pickString(expense, const ['id', '_id']);
      final response = id.isEmpty
          ? await api.createExpense(result)
          : await api.updateExpense(id, result);
      if (!response.success) {
        throw StateError(response.error?.message ?? 'Save failed');
      }
      await _load(page: id.isEmpty ? 1 : _page);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(id.isEmpty ? 'Expense added' : 'Expense updated')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save expense. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _pickString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return fallback;
  }

  static double _toDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final normalized = raw.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  static String _formatMoney(num value) {
    final formatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KES ',
      decimalDigits: value % 1 == 0 ? 0 : 2,
    );
    return formatter.format(value);
  }

  static Map<String, dynamic>? _mapFrom(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static int _intFrom(dynamic raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  static String? _formatApiDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String _formatDate(dynamic raw) {
    DateTime? date;
    if (raw is String) date = DateTime.tryParse(raw);
    if (raw is int) {
      final ms = raw < 20000000000 ? raw * 1000 : raw;
      date = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (date == null) return 'No date';
    return DateFormat.yMMMd().format(date);
  }

  String _selectedFilterDescription() {
    if (_categoryFilter.isEmpty) return 'All categories';
    for (final c in _apiCategories) {
      if (c.id == _categoryFilter) return c.label;
    }
    return _categoryFilter;
  }

  String _categoryLabelForExpense(Map<String, dynamic> expense) {
    return expenseCategoryLabelFromExpense(
      expense,
      categories: _apiCategories,
    );
  }

  double get _visibleTotal => _items.fold<double>(
        0,
        (sum, item) => sum + _toDouble(item['amount']),
      );

  String get _dateFilterLabel {
    if (_startDate == null && _endDate == null) return 'All dates';
    if (_startDate != null && _endDate != null) {
      final start = DateFormat.MMMd().format(_startDate!);
      final end = DateFormat.MMMd().format(_endDate!);
      return '$start - $end';
    }
    if (_startDate != null) {
      return 'From ${DateFormat.MMMd().format(_startDate!)}';
    }
    return 'Until ${DateFormat.MMMd().format(_endDate!)}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    await _load(page: 1);
  }

  Future<void> _clearDateRange() async {
    if (_startDate == null && _endDate == null) return;
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    await _load(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalLabel = _formatMoney(_visibleTotal);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Expenses',
        showDivider: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Manage categories',
            onPressed: _categoriesLoading
                ? null
                : () => context.push('/analytics/expense-categories'),
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'New category',
            onPressed: _categoriesLoading ? null : _openCreateCategoryDialog,
            icon: const Icon(Icons.new_label_outlined),
          ),
          IconButton(
            tooltip: 'Refresh expenses',
            onPressed: _loading ? null : () => _load(page: _page),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _openExpenseSheet(),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(page: _page),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              'Track costs that reduce net profit, from ads to packaging.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _ExpensesSummaryCard(
              totalLabel: totalLabel,
              count: _items.length,
              filterLabel: _selectedFilterDescription(),
              dateLabel: _dateFilterLabel,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _pickDateRange,
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    label: Text(_dateFilterLabel),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                if (_startDate != null || _endDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear date filter',
                    onPressed: _loading ? null : _clearDateRange,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ExpenseFilterChip(
                    label: 'All',
                    selected: _categoryFilter.isEmpty,
                    onTap: () {
                      setState(() => _categoryFilter = '');
                      _load(page: 1);
                    },
                  ),
                  ..._apiCategories.map(
                    (category) => _ExpenseFilterChip(
                      label: category.label,
                      selected: _categoryFilter == category.id,
                      onTap: () {
                        setState(() => _categoryFilter = category.id);
                        _load(page: 1);
                      },
                    ),
                  ),
                  if (_categoriesLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _RetryState(onRetry: () => _load(page: _page))
            else if (_items.isEmpty)
              const _EmptyExpensesState()
            else ...[
              for (final expense in _items) ...[
                _ExpenseCard(
                  expense: expense,
                  categoryLabel: _categoryLabelForExpense(expense),
                  amountLabel: _formatMoney(_toDouble(expense['amount'])),
                  dateLabel: _formatDate(
                    expense['expense_date'] ??
                        expense['expenseDate'] ??
                        expense['date'],
                  ),
                  onEdit: () => _openExpenseSheet(expense),
                  onDelete: () => _deleteExpense(expense),
                ),
                const SizedBox(height: 10),
              ],
              if (_totalPages > 1 || _totalItems > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
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
                        onPressed: _loading || _page <= 1
                            ? null
                            : () => _load(page: _page - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        onPressed: _loading || _page >= _totalPages
                            ? null
                            : () => _load(page: _page + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpensesSummaryCard extends StatelessWidget {
  const _ExpensesSummaryCard({
    required this.totalLabel,
    required this.count,
    required this.filterLabel,
    required this.dateLabel,
  });

  final String totalLabel;
  final int count;
  final String filterLabel;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visible expenses',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totalLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count record${count == 1 ? '' : 's'} • $filterLabel • $dateLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ExpenseFilterChip extends StatelessWidget {
  const _ExpenseFilterChip({
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
        color:
            selected ? AppTheme.primary : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.categoryLabel,
    required this.amountLabel,
    required this.dateLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> expense;
  final String categoryLabel;
  final String amountLabel;
  final String dateLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _pick(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = expense[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = _pick(const ['notes', 'description']);
    final reference = _pick(const ['reference', 'payment_reference']);
    final method = _pick(const ['payment_method', 'paymentMethod']);

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            categoryLabel,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.primaryDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          amountLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primaryDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        dateLabel,
                        if (method.isNotEmpty) method.toUpperCase(),
                        if (reference.isNotEmpty) reference,
                      ].join(' • '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Center(
        child: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ),
    );
  }
}

class _EmptyExpensesState extends StatelessWidget {
  const _EmptyExpensesState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No expenses yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your ads, packaging, rent, and delivery costs to see cleaner profit reports.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({
    required this.categories,
    this.expense,
    this.onCreateCategory,
  });

  final List<ExpenseCategory> categories;
  final Map<String, dynamic>? expense;
  final Future<ExpenseCategory?> Function()? onCreateCategory;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _taxAmount;
  late final TextEditingController _reference;
  late final TextEditingController _notes;
  late List<ExpenseCategory> _categories;
  late String _categoryId;
  late String _paymentMethod;
  late DateTime _date;

  /// When set ('amount'), that field shows error styling alongside the snackbar.
  String? _fieldErrorKey;

  @override
  void initState() {
    super.initState();
    _categories = List<ExpenseCategory>.from(widget.categories);
    final expense = widget.expense ?? const <String, dynamic>{};
    _amount = TextEditingController(text: _moneyText(expense['amount']));
    _taxAmount = TextEditingController(
        text: _moneyText(expense['tax_amount'] ?? expense['taxAmount']));
    _reference = TextEditingController(
      text: _string(expense['reference'] ?? expense['payment_reference']),
    );
    _notes = TextEditingController(text: _string(expense['notes']));
    final apiId = _string(expense['category_id'] ?? expense['categoryId']);
    if (apiId.isNotEmpty && _categories.any((c) => c.id == apiId)) {
      _categoryId = apiId;
    } else if (_categories.isNotEmpty) {
      _categoryId = _categories.first.id;
    } else {
      _categoryId = '';
    }
    final initialPaymentMethod = _string(
      expense['payment_method'] ?? expense['paymentMethod'],
      fallback: 'mpesa',
    );
    _paymentMethod = const {'mpesa', 'cash', 'card', 'bank', 'other'}
            .contains(initialPaymentMethod)
        ? initialPaymentMethod
        : 'other';
    final rawDate =
        expense['expense_date'] ?? expense['expenseDate'] ?? expense['date'];
    _date = rawDate is String
        ? DateTime.tryParse(rawDate) ?? DateTime.now()
        : DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _taxAmount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return fallback;
  }

  static String _moneyText(dynamic value) {
    if (value is num && value > 0) {
      return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    }
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return '';
  }

  static double _toMoney(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    final amount = _toMoney(_amount.text);
    if (amount <= 0) {
      setState(() => _fieldErrorKey = 'amount');
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: cs.error,
            content: const Text(
              'Enter an expense amount greater than 0 (KES).',
            ),
          ),
        );
      return;
    }
    if (_categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an expense category before adding expenses.'),
        ),
      );
      return;
    }
    final taxAmount = _toMoney(_taxAmount.text);
    Navigator.pop(context, {
      'expense_date': DateFormat('yyyy-MM-dd').format(_date),
      'category_id': _categoryId,
      'amount': amount,
      'tax_amount': taxAmount,
      'payment_method': _paymentMethod,
      'reference': _reference.text.trim(),
      'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.expense == null ? 'Add expense' : 'Edit expense',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Text('Category', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (_categories.isEmpty)
                Text(
                  'No categories yet — use "+" on the expense list header.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _categories.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : _categories.first.id,
                  decoration: _sheetInputDecoration(theme),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _categoryId = value);
                  },
                ),
                if (widget.onCreateCategory != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final created = await widget.onCreateCategory!();
                        if (!mounted || created == null) return;
                        setState(() {
                          if (!_categories.any((c) => c.id == created.id)) {
                            _categories = [..._categories, created];
                          }
                          _categoryId = created.id;
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New category…'),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SheetTextField(
                      controller: _amount,
                      label: 'Amount',
                      hint: '0',
                      prefixText: 'KES ',
                      keyboardType: TextInputType.number,
                      isInvalid: _fieldErrorKey == 'amount',
                      onChanged: (_) {
                        if (_fieldErrorKey != null) {
                          setState(() => _fieldErrorKey = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetTextField(
                      controller: _taxAmount,
                      label: 'Tax (optional)',
                      hint: '0',
                      prefixText: 'KES ',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Expense date', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(DateFormat.yMMMd().format(_date)),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Payment method', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: _sheetInputDecoration(theme),
                items: const [
                  DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                controller: _reference,
                label: 'Reference (optional)',
                hint: 'e.g. META-ADS-001',
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                controller: _notes,
                label: 'Notes (optional)',
                hint: 'What was this expense for?',
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                    widget.expense == null ? 'Save expense' : 'Update expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _sheetInputDecoration(ThemeData theme) {
    final outline = theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
    return InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefixText,
    this.keyboardType,
    this.maxLines = 1,
    this.isInvalid = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefixText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool isInvalid;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final idleOutline =
        theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
    final borderColor = isInvalid ? errorColor : idleOutline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isInvalid ? errorColor : theme.textTheme.labelLarge?.color,
            fontWeight: isInvalid ? FontWeight.w700 : null,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            filled: true,
            fillColor: isInvalid
                ? errorColor.withValues(alpha: 0.06)
                : theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: borderColor, width: isInvalid ? 1.5 : 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: borderColor, width: isInvalid ? 1.5 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isInvalid ? errorColor : theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
