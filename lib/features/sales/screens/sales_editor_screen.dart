import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';
import 'sales_list_screen.dart';

class SalesEditorScreen extends ConsumerStatefulWidget {
  const SalesEditorScreen({super.key, this.saleId});

  final String? saleId;

  bool get isCreate => saleId == null || saleId!.isEmpty;

  @override
  ConsumerState<SalesEditorScreen> createState() => _SalesEditorScreenState();
}

class _SaleProduct {
  _SaleProduct({
    required this.productId,
    required this.saleItemId,
    required this.name,
    required this.original,
    required this.salePriceCtrl,
    required this.imageUrl,
  });

  final String productId;
  final String saleItemId;
  final String name;
  final double original;
  final TextEditingController salePriceCtrl;
  final String imageUrl;
}

class _SalesEditorScreenState extends ConsumerState<SalesEditorScreen>
    with FormErrorHighlightMixin {
  final _saleName = TextEditingController();
  final _note = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));
  String _status = 'draft';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_SaleProduct> _products = [];

  static String _pickString(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return fallback;
  }

  static double _pickDouble(Map<String, dynamic> map, List<String> keys, {double fallback = 0}) {
    for (final k in keys) {
      final v = map[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final n = double.tryParse(v.trim());
        if (n != null) return n;
      }
    }
    return fallback;
  }

  void _syncDates() {
    _startCtrl.text = '${_start.year}-${_start.month.toString().padLeft(2, '0')}-${_start.day.toString().padLeft(2, '0')}';
    _endCtrl.text = '${_end.year}-${_end.month.toString().padLeft(2, '0')}-${_end.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _syncDates();
    _load();
  }

  @override
  void dispose() {
    for (final p in _products) {
      p.salePriceCtrl.dispose();
    }
    _saleName.dispose();
    _note.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.isCreate) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getSale(widget.saleId!);
      if (!r.success || r.data == null) throw StateError(r.error?.message ?? 'Failed to load sale');
      final payload = r.data;
      if (payload is! Map<String, dynamic>) throw const FormatException('Invalid sale payload');
      final raw = payload['sale'] ?? payload['item'] ?? payload['data'] ?? payload;
      if (raw is! Map) throw const FormatException('Invalid sale record');
      final sale = Map<String, dynamic>.from(raw);

      _saleName.text = _pickString(sale, ['name', 'title'], fallback: 'Sale');
      _note.text = _pickString(sale, ['description', 'note', 'notes']);
      _status = _pickString(sale, ['status'], fallback: 'draft').toLowerCase();
      _start = DateTime.tryParse(_pickString(sale, ['start_date', 'startDate'])) ?? DateTime.now();
      _end = DateTime.tryParse(_pickString(sale, ['end_date', 'endDate'])) ?? _start.add(const Duration(days: 7));
      _syncDates();

      final itemsRaw = sale['product_sales'] ?? sale['productSales'] ?? sale['products'] ?? sale['items'];
      final items = itemsRaw is List ? itemsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      _products = items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final nested = item['product'] is Map ? Map<String, dynamic>.from(item['product'] as Map) : <String, dynamic>{};
        final name = _pickString(item, ['name', 'productName', 'title'], fallback: _pickString(nested, ['name', 'title'], fallback: 'Product ${i + 1}'));
        final salePrice = _pickDouble(item, ['sale_price', 'salePrice', 'discount_price', 'discountPrice']);
        final original = _pickDouble(item, ['original_price', 'originalPrice', 'price'], fallback: _pickDouble(nested, ['price']));
        return _SaleProduct(
          productId: _pickString(item, ['product_id', 'productId'], fallback: _pickString(nested, ['id', '_id'])),
          saleItemId: _pickString(item, ['id', '_id', 'sale_item_id', 'saleItemId']),
          name: name,
          original: original,
          salePriceCtrl: TextEditingController(text: salePrice.toStringAsFixed(2)),
          imageUrl: _pickString(item, ['image', 'image_url', 'imageUrl'], fallback: _pickString(nested, ['image', 'imageUrl', 'thumbnail', 'thumbnailUrl'])),
        );
      }).toList();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
      }
      _syncDates();
    });
  }

  void _addCatalogProduct(Map<String, dynamic> raw) {
    final id = _pickString(raw, ['id', '_id', 'sku']);
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product has no id/sku')));
      return;
    }
    if (_products.any((p) => p.productId == id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product already in this sale')));
      return;
    }
    final name = _pickString(raw, ['name', 'title'], fallback: 'Product');
    final price = _pickDouble(raw, ['price', 'base_price', 'amount', 'regular_price']);
    final nested = raw['product'] is Map ? Map<String, dynamic>.from(raw['product'] as Map) : <String, dynamic>{};
    final image = _pickString(raw, ['thumbnail', 'thumbnail_url', 'image', 'image_url', 'imageUrl'],
        fallback: _pickString(nested, ['thumbnail', 'image', 'image_url']));
    setState(() {
      _products.add(
        _SaleProduct(
          productId: id,
          saleItemId: '',
          name: name,
          original: price,
          salePriceCtrl: TextEditingController(text: price.toStringAsFixed(2)),
          imageUrl: image,
        ),
      );
    });
  }

  Future<void> _openAddProductsSheet() async {
    final existing = _products.map((p) => p.productId).where((id) => id.isNotEmpty).toSet();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.62,
            child: _SaleProductPicker(
              existingProductIds: existing,
              onPick: (map) {
                Navigator.of(sheetContext).pop();
                _addCatalogProduct(map);
              },
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _payload() {
    return {
      'name': _saleName.text.trim(),
      'description': _note.text.trim(),
      'start_date': _start.toIso8601String(),
      'end_date': _end.toIso8601String(),
      'status': _status,
      'product_sales': _products.map((p) => {
            if (p.saleItemId.isNotEmpty) 'id': p.saleItemId,
            if (p.productId.isNotEmpty) 'product_id': p.productId,
            'sale_price': double.tryParse(p.salePriceCtrl.text.trim()) ?? 0,
          }).toList(),
    };
  }

  Future<void> _save() async {
    if (_saleName.text.trim().isEmpty) {
      reportFieldError(
        fieldId: 'name',
        message: 'Sale name is required.',
      );
      return;
    }
    if (_end.isBefore(_start)) {
      reportFieldError(
        fieldId: 'end',
        message: 'End date cannot be before start date.',
      );
      return;
    }
    for (var i = 0; i < _products.length; i++) {
      final raw = _products[i].salePriceCtrl.text.trim();
      final price = double.tryParse(raw);
      if (raw.isEmpty || price == null || price <= 0) {
        reportFieldError(
          fieldId: 'product_$i',
          message: 'Sale price for "${_products[i].name}" must be greater than 0.',
        );
        return;
      }
    }
    clearAllFieldErrors();
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = widget.isCreate ? await api.createSale(_payload()) : await api.updateSale(widget.saleId!, _payload());
      if (!result.success) throw StateError(result.error?.message ?? 'Save failed');
      ref.read(salesListRefreshTokenProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale saved')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.isCreate) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this sale?'),
        content: const Text('This action cannot be undone.'),
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
    final api = ref.read(apiClientProvider);
    final r = await api.deleteSale(widget.saleId!);
    if (!r.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error?.message ?? 'Delete failed')));
      }
      return;
    }
    ref.read(salesListRefreshTokenProvider.notifier).state++;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.isCreate ? 'New Sale' : 'Edit Sale';
    if (_loading) {
      return Scaffold(backgroundColor: AppTheme.surface, appBar: DashboardAppBar(title: title), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: DashboardAppBar(title: title),
        body: Center(child: Text(_error!)),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: title,
        actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          KeyedSubtree(
            key: keyFor('name'),
            child: TextField(
              controller: _saleName,
              onChanged: (_) => clearFieldError('name'),
              decoration: _saleFieldDeco(
                theme,
                'Sale name',
                isInvalid: isFieldInvalid('name'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          KeyedSubtree(
            key: keyFor('start'),
            child: TextField(
              controller: _startCtrl,
              readOnly: true,
              onTap: () {
                clearFieldError('start');
                clearFieldError('end');
                _pickDate(true);
              },
              decoration: _saleFieldDeco(
                theme,
                'Start date',
                isInvalid: isFieldInvalid('start'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          KeyedSubtree(
            key: keyFor('end'),
            child: TextField(
              controller: _endCtrl,
              readOnly: true,
              onTap: () {
                clearFieldError('end');
                _pickDate(false);
              },
              decoration: _saleFieldDeco(
                theme,
                'End date',
                isInvalid: isFieldInvalid('end'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'draft', child: Text('Draft')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              DropdownMenuItem(value: 'archived', child: Text('Archived')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'draft'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Products in sale', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _openAddProductsSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add product'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_products.isEmpty)
            Text('No products found in this sale.', style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant))
          else
            ...List.generate(_products.length, (i) {
              final p = _products[i];
              final fieldId = 'product_$i';
              final invalid = isFieldInvalid(fieldId);
              final errorColor = theme.colorScheme.error;
              return Container(
                key: keyFor(fieldId),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: invalid ? errorColor.withValues(alpha: 0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: invalid
                      ? Border.all(color: errorColor, width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: p.imageUrl.isEmpty
                            ? ColoredBox(color: theme.colorScheme.surfaceContainerLow, child: const Icon(Icons.inventory_2_outlined))
                            : CachedNetworkImage(
                                imageUrl: p.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => ColoredBox(color: theme.colorScheme.surfaceContainerLow, child: const Icon(Icons.image_not_supported_outlined)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                          Text('Original: ${p.original.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 160,
                            child: TextField(
                              controller: p.salePriceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => clearFieldError(fieldId),
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: 'Sale price',
                                prefixText: 'KES ',
                                labelStyle: invalid
                                    ? TextStyle(color: errorColor)
                                    : null,
                                enabledBorder: invalid
                                    ? UnderlineInputBorder(
                                        borderSide: BorderSide(
                                            color: errorColor, width: 1.5),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        clearFieldError(fieldId);
                        setState(() {
                          final removed = _products.removeAt(i);
                          removed.salePriceCtrl.dispose();
                        });
                      },
                      icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.error),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
            child: _saving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Save sale'),
          ),
          if (!widget.isCreate) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete sale'),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _saleFieldDeco(
    ThemeData theme,
    String label, {
    bool isInvalid = false,
  }) {
    final errorColor = theme.colorScheme.error;
    final border = isInvalid
        ? UnderlineInputBorder(
            borderSide: BorderSide(color: errorColor, width: 1.5),
          )
        : null;
    return InputDecoration(
      labelText: label,
      labelStyle: isInvalid ? TextStyle(color: errorColor) : null,
      filled: isInvalid,
      fillColor: isInvalid ? errorColor.withValues(alpha: 0.06) : null,
      enabledBorder: border,
      focusedBorder: isInvalid
          ? UnderlineInputBorder(
              borderSide: BorderSide(color: errorColor, width: 1.5),
            )
          : null,
    );
  }
}

class _SaleProductPicker extends ConsumerStatefulWidget {
  const _SaleProductPicker({
    required this.existingProductIds,
    required this.onPick,
  });

  final Set<String> existingProductIds;
  final void Function(Map<String, dynamic> product) onPick;

  @override
  ConsumerState<_SaleProductPicker> createState() => _SaleProductPickerState();
}

class _SaleProductPickerState extends ConsumerState<_SaleProductPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getProducts(page: 1, limit: 40, search: q.trim());
      if (!r.success) throw StateError(r.error?.message ?? 'Search failed');
      final payload = r.data;
      final root = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final raw = root['items'] ?? root['data'] ?? root['products'];
      final list = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  static String _title(Map<String, dynamic> p) {
    for (final k in ['name', 'title', 'productName']) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return 'Product';
  }

  static String _id(Map<String, dynamic> p) {
    for (final k in ['id', '_id', 'sku']) {
      final v = p[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  static String _priceLine(Map<String, dynamic> p) {
    num? n;
    for (final k in ['price', 'base_price', 'amount']) {
      final v = p[k];
      if (v is num) {
        n = v;
        break;
      }
      if (v is String) {
        final parsed = num.tryParse(v.trim());
        if (parsed != null) {
          n = parsed;
          break;
        }
      }
    }
    if (n == null) return '';
    return 'KES ${n.toStringAsFixed(2)}';
  }

  static String? _thumb(Map<String, dynamic> p) {
    for (final k in ['thumbnail', 'thumbnail_url', 'image', 'image_url', 'imageUrl']) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Add product', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search catalog…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(v));
            },
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = _results[i];
                final id = _id(p);
                final inSale = id.isNotEmpty && widget.existingProductIds.contains(id);
                final thumb = _thumb(p);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: thumb == null
                          ? ColoredBox(color: theme.colorScheme.surfaceContainerLow, child: const Icon(Icons.inventory_2_outlined))
                          : CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => ColoredBox(
                                color: theme.colorScheme.surfaceContainerLow,
                                child: const Icon(Icons.image_not_supported_outlined),
                              ),
                            ),
                    ),
                  ),
                  title: Text(_title(p), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    _priceLine(p),
                    style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: inSale
                      ? Text('Added', style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.outline))
                      : const Icon(Icons.add_circle_outline),
                  onTap: inSale || id.isEmpty ? null : () => widget.onPick(p),
                );
              },
            ),
          ),
      ],
    );
  }
}
