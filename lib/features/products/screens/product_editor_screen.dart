import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../data/attribute_value_format.dart';
import '../data/attributes_repository.dart';
import '../providers/attributes_list_provider.dart';

/// Add/Edit Product — Stitch: Add/Edit Product (with Variants)
/// (screen 6a3e6b8d009b4574bb092c68b80dfcc0; variant module + attributes integration).
class ProductEditorScreen extends ConsumerStatefulWidget {
  const ProductEditorScreen({
    super.key,
    this.initialSku,
  });

  final String? initialSku;

  @override
  ConsumerState<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

/// One sellable variant (option combination + SKU + stock).
class _VariantLine {
  _VariantLine({
    required this.options,
    required String initialSku,
    required String initialStock,
  })  : sku = TextEditingController(text: initialSku),
        stock = TextEditingController(text: initialStock);

  /// Attribute display name → displayed option value (e.g. Color → Red).
  final Map<String, String> options;
  final TextEditingController sku;
  final TextEditingController stock;

  String get optionSummary => options.values.join(' · ');

  void dispose() {
    sku.dispose();
    stock.dispose();
  }
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen> {
  static const Duration _productCacheTtl = Duration(minutes: 5);
  static final Map<String, ({Map<String, dynamic> product, DateTime savedAt})> _productDetailCache = {};

  /// Leave empty if the API returns no image.
  static const _placeholderHeroImage = '';

  static const _defaultCategorySeeds = [
    'Bags & Accessories',
    'Electronics',
    'Fashion',
    'Home Decor',
  ];

  static const _campaigns = [
    'Summer Flash Sale 2024',
    'Weekend Clearance',
    'New Arrival Promo',
  ];

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _regularPrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _sku;
  late final TextEditingController _stock;

  late List<String> _categoryOptions;
  late String _category;
  String? _campaign;
  bool _visible = true;
  int _photoCount = 0;
  String? _loadedHeroImageUrl;
  String? _productApiId;
  final ScrollController _scrollController = ScrollController();
  final List<_VariantLine> _variantLines = [];
  bool _isLiveData = false;
  bool _isLoadingRemote = false;
  bool _isSaving = false;
  String? _dataSourceError;
  bool _loadAttributes = false;
  DateTime? _lastSyncedAt;
  bool _hasSeenRefreshHint = false;

  static String _valueLabel(ProductAttribute a, String raw) {
    return AttributeValueFormat.shortLabel(raw, a.displayType);
  }

  void _disposeVariantLines() {
    for (final v in _variantLines) {
      v.dispose();
    }
    _variantLines.clear();
  }

  void _initVariantLines() {
    _disposeVariantLines();
    final sku = widget.initialSku;
    final baseSku = _sku.text.trim().isEmpty ? (sku ?? 'SKU') : _sku.text.trim();

    if (sku != null && sku.isNotEmpty) {
      _variantLines.add(
        _VariantLine(
          options: {'Default': 'Standard'},
          initialSku: baseSku,
          initialStock: _stock.text.trim().isEmpty ? '0' : _stock.text.trim(),
        ),
      );
    }
  }

  bool _optionsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value;
    if (value is num) return value.toString();
    return fallback;
  }

  String _moneyToKes(dynamic value) {
    if (value is num) return value.toStringAsFixed(0);
    if (value is String && value.trim().isNotEmpty) return value;
    return '';
  }

  String? _primaryImageFromMap(Map<String, dynamic> p) {
    String normalize(dynamic raw) {
      if (raw is! String) return '';
      final s = raw.trim();
      if (s.isEmpty) return '';
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
      if (s.startsWith('//')) return 'https:$s';
      return '';
    }

    final direct = p['image'] ??
        p['imageUrl'] ??
        p['image_url'] ??
        p['featuredImage'] ??
        p['featured_image'] ??
        p['thumbnail'] ??
        p['thumbnail_url'];
    final nDirect = normalize(direct);
    if (nDirect.isNotEmpty) return nDirect;
    final imgs = p['images'] ?? p['media'] ?? p['gallery'];
    if (imgs is List) {
      for (final e in imgs) {
        final n = normalize(e);
        if (n.isNotEmpty) return n;
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final nested = normalize(
            m['url'] ??
                m['src'] ??
                m['imageUrl'] ??
                m['image_url'] ??
                m['thumbnail'] ??
                m['thumbnail_url'],
          );
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return null;
  }

  void _ensureCategoryOption(String category) {
    final c = category.trim();
    if (c.isEmpty) return;
    if (!_categoryOptions.contains(c)) {
      _categoryOptions = [c, ..._categoryOptions];
    }
  }

  void _applyVariantsFromProduct(Map<String, dynamic> p) {
    _disposeVariantLines();
    final rawVariants =
        p['variants'] ?? p['productVariants'] ?? p['product_variants'] ?? p['variantList'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      for (final item in rawVariants.whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        final vSku = _asString(m['sku'] ?? m['code'], fallback: _sku.text.trim());
        final stockRaw = m['stock'] ?? m['stockQuantity'] ?? m['stock_quantity'] ?? m['quantity'];
        final vStock = stockRaw == null ? '0' : stockRaw.toString();
        var options = <String, String>{'Default': 'Standard'};
        final opt = m['options'] ??
            m['attributes'] ??
            m['attributeValues'] ??
            m['attribute_values'] ??
            m['option_values'];
        if (opt is Map) {
          options = opt.map((k, v) => MapEntry(k.toString(), v.toString()));
        } else if (opt is List && opt.isNotEmpty) {
          options = {};
          for (final row in opt.whereType<Map>()) {
            final r = Map<String, dynamic>.from(row);
            final key = _asString(r['name'] ?? r['attribute_name'], fallback: 'Option');
            final value = _asString(r['value'] ?? r['label'], fallback: '');
            if (value.isNotEmpty) options[key] = value;
          }
          if (options.isEmpty) {
            options = {'Default': 'Standard'};
          }
        }
        _variantLines.add(
          _VariantLine(
            options: options,
            initialSku: vSku.isEmpty ? 'SKU' : vSku,
            initialStock: vStock,
          ),
        );
      }
      return;
    }
    _initVariantLines();
  }

  Map<String, dynamic>? _extractProductMap(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;
    final raw = payload['product'] ?? payload['item'] ?? payload['data'] ?? payload;
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  Future<String> _resolveProductLookupKey(String inputKey) async {
    final trimmed = inputKey.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.contains('-')) {
      final api = ref.read(apiClientProvider);
      final list = await api.getProducts(page: 1, limit: 50, search: trimmed);
      if (list.success && list.data is Map<String, dynamic>) {
        final data = list.data as Map<String, dynamic>;
        final items = data['items'] ?? data['products'] ?? data['data'];
        if (items is List) {
          for (final raw in items.whereType<Map>()) {
            final m = Map<String, dynamic>.from(raw);
            final sku = (m['sku'] ?? m['code'] ?? '').toString();
            final id = (m['id'] ?? '').toString();
            if (sku == trimmed && id.isNotEmpty) return id;
          }
        }
      }
    }
    return trimmed;
  }

  void _applyProductData(Map<String, dynamic> p) {
    final idStr = p['id']?.toString().trim();
    _productApiId = (idStr != null && idStr.isNotEmpty) ? idStr : null;

    _name.text = _asString(p['name']);
    _description.text = _asString(p['description']);
    _regularPrice.text =
        _moneyToKes(p['regularPrice'] ?? p['regular_price'] ?? p['price'] ?? p['unitPrice']);
    final saleRaw = p['salePrice'] ?? p['sale_price'] ?? p['discountPrice'] ?? p['discount_price'];
    _salePrice.text = saleRaw == null ? '' : _moneyToKes(saleRaw);
    _sku.text = _asString(p['sku'] ?? p['code'], fallback: _sku.text);
    final stock = p['stock'] ?? p['stockQuantity'] ?? p['stock_quantity'] ?? p['quantity'];
    _stock.text = stock == null ? '' : stock.toString();

    final category = _asString(
      p['categoryName'] ?? p['category'],
      fallback: _category,
    );
    _ensureCategoryOption(category);
    _category = category;

    final statusRaw = (p['status'] ?? '').toString().toLowerCase();
    if (statusRaw.isNotEmpty) {
      _visible = statusRaw == 'active' || statusRaw == 'enabled';
    } else {
      _visible = p['isActive'] == true || p['active'] == true;
    }

    _loadedHeroImageUrl = _primaryImageFromMap(p);
    final imgs = p['images'] ?? p['media'] ?? p['gallery'];
      if (imgs is List && imgs.isNotEmpty) {
      _photoCount = imgs.length.clamp(1, 5);
    } else if (_loadedHeroImageUrl != null) {
      _photoCount = 1;
    } else {
        _photoCount = 0;
    }

    _applyVariantsFromProduct(p);
  }

  Future<void> _loadLiveProductIfEditing({bool forceRefresh = false}) async {
    final initialKey = widget.initialSku;
    if (initialKey == null || initialKey.isEmpty) return;

    if (!forceRefresh) {
      final cached = _productDetailCache[initialKey];
      if (cached != null && DateTime.now().difference(cached.savedAt) < _productCacheTtl) {
        setState(() {
          _applyProductData(cached.product);
          _isLiveData = true;
          _isLoadingRemote = false;
          _dataSourceError = null;
          _lastSyncedAt = cached.savedAt;
        });
        return;
      }
    }

    setState(() {
      _isLoadingRemote = true;
      _dataSourceError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final lookupKey = await _resolveProductLookupKey(initialKey);
      final response = await api.getProductDetail(lookupKey);
      if (!response.success || response.data == null) {
        throw StateError(response.error?.message ?? 'Failed to load product');
      }

      final p = _extractProductMap(response.data);
      if (p == null) {
        throw const FormatException('Invalid product payload');
      }

      _productDetailCache[initialKey] = (product: p, savedAt: DateTime.now());

      if (mounted) {
        setState(() {
          _applyProductData(p);
          _isLiveData = true;
          _isLoadingRemote = false;
          _lastSyncedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiveData = false;
          _isLoadingRemote = false;
          _dataSourceError = e.toString();
        });
      }
    }
  }

  Future<void> _openAddVariantSheet() async {
    final attrs = ref.read(dashboardAttributesProvider).valueOrNull ?? [];
    if (attrs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create attributes first (Manage Attributes).')),
      );
      return;
    }
    final selected = <String, String>{}; // attribute name → value label
    for (final a in attrs) {
      selected[a.name] = _valueLabel(a, a.values.first);
    }

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.45,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    children: [
                      Text(
                        'Add variant',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick one value per attribute. SKU can match your warehouse labels.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...attrs.map((a) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: selected[a.name],
                                    items: a.values
                                        .map(
                                          (raw) => DropdownMenuItem(
                                            value: _valueLabel(a, raw),
                                            child: Text(_valueLabel(a, raw)),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setModal(() => selected[a.name] = v);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          final combo = Map<String, String>.from(selected);
                          if (_variantLines.any((l) => _optionsEqual(l.options, combo))) {
                            Navigator.pop(ctx, false);
                            return;
                          }
                          final base = _sku.text.trim().isEmpty ? 'VAR' : _sku.text.trim();
                          final idx = _variantLines.length + 1;
                          _variantLines.add(_VariantLine(
                            options: combo,
                            initialSku: '$base-V$idx',
                            initialStock: '0',
                          ));
                          Navigator.pop(ctx, true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Add variant', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
    if (added == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Variant added')));
    } else if (added == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That combination already exists')),
      );
    }
  }

  double _toDouble(String value) {
    final normalized = value.replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    final name = _name.text.trim();
    final sku = _sku.text.trim();
    if (name.isEmpty || sku.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name and SKU are required')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final api = container.read(apiClientProvider);

      final payload = <String, dynamic>{
        'name': name,
        'description': _description.text.trim(),
        'sku': sku,
        'regularPrice': _toDouble(_regularPrice.text),
        'salePrice': _toDouble(_salePrice.text),
        'stock': int.tryParse(_stock.text.trim()) ?? 0,
        'category': _category,
        'isActive': _visible,
      };

      final isNew = widget.initialSku == null;
      final updateKey = _productApiId ?? widget.initialSku;
      if (!isNew && (updateKey == null || updateKey.isEmpty)) {
        throw StateError('Missing product id for update. Reload the product and try again.');
      }
      final response = isNew
          ? await api.createProduct(payload)
          : await api.updateProduct(updateKey!, payload);

      if (!response.success) {
        throw StateError(response.error?.message ?? 'Failed to save product');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNew ? 'Product created' : 'Product updated')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRefreshHintPref();
    final isNew = widget.initialSku == null;
    _categoryOptions = List<String>.from(_defaultCategorySeeds);
    _category = _categoryOptions.first;
    _name = TextEditingController();
    _description = TextEditingController();
    _regularPrice = TextEditingController();
    _salePrice = TextEditingController();
    _sku = TextEditingController(text: widget.initialSku ?? '');
    _stock = TextEditingController();
    _loadedHeroImageUrl = null;
    _productApiId = null;
    _loadAttributes = !isNew;
    _initVariantLines();
    if (!isNew) {
      _loadLiveProductIfEditing();
    }
  }

  Future<void> _loadRefreshHintPref() async {
    final seen = await ref.read(tokenStorageProvider).getProductDetailRefreshHintSeen();
    if (!mounted) return;
    setState(() => _hasSeenRefreshHint = seen);
  }

  String get _heroImageUrl => _loadedHeroImageUrl ?? _placeholderHeroImage;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _regularPrice.dispose();
    _salePrice.dispose();
    _sku.dispose();
    _stock.dispose();
    _scrollController.dispose();
    for (final v in _variantLines) {
      v.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.initialSku == null;
    String lastUpdatedLabel() {
      final at = _lastSyncedAt;
      if (at == null) return 'Not synced yet';
      final diff = DateTime.now().difference(at);
      if (diff.inMinutes < 1) return 'Updated just now';
      if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
      return 'Updated ${diff.inDays}d ago';
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          if (isNew) return;
          await _loadLiveProductIfEditing(forceRefresh: true);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.primaryDark),
              onPressed: () => context.pop(),
            ),
            title: Text(
              isNew ? 'Add Product' : 'Edit Product',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (!isNew)
                IconButton(
                  tooltip: 'Refresh details',
                  onPressed: _isLoadingRemote ? null : () => _loadLiveProductIfEditing(forceRefresh: true),
                  icon: _isLoadingRemote
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              TextButton(
                onPressed: _isSaving ? null : _saveProduct,
                child: Text(
                  _isSaving ? 'Saving...' : 'Publish',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MediaSectionHeader(
                  title: 'Media',
                  trailing: Text(
                    '$_photoCount / 5 Photos',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!isNew) ...[
                  _EditorDataSourceBadge(
                    isLoading: _isLoadingRemote,
                    isLiveData: _isLiveData,
                    errorMessage: _dataSourceError,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${lastUpdatedLabel()} • Swipe down to refresh',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!_hasSeenRefreshHint) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.swipe_down_alt_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pull down to fetch the latest product details.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              setState(() => _hasSeenRefreshHint = true);
                              await ref.read(tokenStorageProvider).saveProductDetailRefreshHintSeen(true);
                            },
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  height: 132,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (_heroImageUrl.trim().isNotEmpty) ...[
                        _MediaThumb(
                          imageUrl: _heroImageUrl,
                          onRemove: () {
                            setState(() {
                              _loadedHeroImageUrl = null;
                              if (_photoCount > 0) _photoCount--;
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                      ],
                      _AddPhotoButton(onTap: () {
                        if (_photoCount < 5) setState(() => _photoCount++);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LabeledField(
                        label: 'Product Name',
                        child: TextField(
                          controller: _name,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          decoration: _fieldDeco(theme, hint: 'Enter product name'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _FmtIcon(icon: Icons.format_bold),
                                  _FmtIcon(icon: Icons.format_italic),
                                  _FmtIcon(icon: Icons.format_list_bulleted),
                                ],
                              ),
                            ),
                            TextField(
                              controller: _description,
                              maxLines: 5,
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                              decoration: InputDecoration(
                                hintText: 'Tell customers about your product...',
                                hintStyle: TextStyle(color: theme.colorScheme.outline),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Category',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                _categoryOptions.contains(_category) ? _category : _categoryOptions.first,
                            isExpanded: true,
                            icon: Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
                            items: _categoryOptions
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(() => _category = v ?? _categoryOptions.first),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Pricing',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PriceField(
                        label: 'REGULAR PRICE',
                        controller: _regularPrice,
                        accent: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PriceField(
                        label: 'SALE PRICE',
                        controller: _salePrice,
                        accent: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Inventory',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.push('/attributes'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Manage attributes',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18, color: AppTheme.primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _LabeledField(
                              label: 'SKU',
                              child: TextField(
                                controller: _sku,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                decoration: _fieldDeco(theme),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LabeledField(
                              label: 'Stock',
                              child: TextField(
                                controller: _stock,
                                keyboardType: TextInputType.number,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                decoration: _fieldDeco(theme),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!_loadAttributes)
                  _CardShell(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product variants',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Load attributes when you are ready to configure variants.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => setState(() => _loadAttributes = true),
                          icon: const Icon(Icons.layers_outlined, size: 18),
                          label: const Text('Load variant options'),
                        ),
                      ],
                    ),
                  )
                else
                  ...switch (ref.watch(dashboardAttributesProvider)) {
                    AsyncLoading<List<ProductAttribute>>() => [
                        _CardShell(
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      ],
                    AsyncError(:final error) => [
                        _CardShell(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('$error', style: theme.textTheme.bodySmall),
                          ),
                        ),
                      ],
                    AsyncData(:final value) => [
                        _CardShell(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Product variants',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primaryDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Each variant is a unique combination of your attributes, with its own SKU and stock.',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            height: 1.35,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.layers_outlined, color: AppTheme.primaryDark, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        value.isEmpty
                                            ? 'No attributes yet. Tap “Manage attributes” above to define options like Color or Size.'
                                            : '${value.length} attribute(s) available — use them to build variants below.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: AppTheme.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (_variantLines.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No variants yet. Add one manually.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              else
                                ..._variantLines.asMap().entries.map((e) {
                                  final i = e.key;
                                  final line = e.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _VariantRowTile(
                                      line: line,
                                      onRemove: () {
                                        setState(() {
                                          line.dispose();
                                          _variantLines.removeAt(i);
                                        });
                                      },
                                    ),
                                  );
                                }),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: value.isEmpty ? null : _openAddVariantSheet,
                                icon: const Icon(Icons.add, size: 20),
                                label: Text(
                                  'Add variant',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    _ => [
                        _CardShell(child: const SizedBox.shrink()),
                      ],
                  },
                const SizedBox(height: 16),
                _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sales & Promotions',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Add to Existing Sale',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _campaign,
                            isExpanded: true,
                            hint: Text(
                              'Select a campaign...',
                              style: TextStyle(color: theme.colorScheme.outline),
                            ),
                            icon: Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
                            items: _campaigns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _campaign = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Apply this product to active flash sales or discount campaigns.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.visibility_outlined, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Visibility',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Active in your online store',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _visible,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _visible = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(ThemeData theme, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _MediaSectionHeader extends StatelessWidget {
  const _MediaSectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.controller,
    required this.accent,
  });

  final String label;
  final TextEditingController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              prefixText: 'KES ',
              prefixStyle: theme.textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _FmtIcon extends StatelessWidget {
  const _FmtIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.imageUrl, required this.onRemove});

  final String imageUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    String fallbackUrl(String raw) {
      try {
        final u = Uri.parse(raw);
        if (u.host == 'auth.dukanest.com' && u.path.startsWith('/storage/v1/object/public/')) {
          final base = Uri.parse(AppConfig.publicApiBaseUrl);
          return u.replace(
            scheme: base.scheme,
            host: base.host,
            port: base.hasPort ? base.port : null,
          ).toString();
        }
      } catch (_) {}
      return raw;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: hasImage
              ? Image.network(
                  imageUrl,
                  width: 128,
                  height: 128,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    final alt = fallbackUrl(imageUrl);
                    if (alt != imageUrl) {
                      return Image.network(
                        alt,
                        width: 128,
                        height: 128,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 128,
                          height: 128,
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      );
                    }
                    return Container(
                      width: 128,
                      height: 128,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: const Icon(Icons.image_not_supported_outlined),
                    );
                  },
                )
              : Container(
                  width: 128,
                  height: 128,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
        ),
        if (hasImage)
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VariantRowTile extends StatelessWidget {
  const _VariantRowTile({
    required this.line,
    required this.onRemove,
  });

  final _VariantLine line;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppTheme.primary, width: 4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.optionSummary,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                tooltip: 'Remove variant',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SKU',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: line.sku,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      decoration: _variantFieldDeco(theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: line.stock,
                      keyboardType: TextInputType.number,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      decoration: _variantFieldDeco(theme),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static InputDecoration _variantFieldDeco(ThemeData theme) {
    return InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onTap});

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
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: AppTheme.primary, size: 28),
              const SizedBox(height: 6),
              Text(
                'ADD PHOTO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorDataSourceBadge extends StatelessWidget {
  const _EditorDataSourceBadge({
    required this.isLoading,
    required this.isLiveData,
    required this.errorMessage,
  });

  final bool isLoading;
  final bool isLiveData;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final isFallback = !isLiveData;
    final bg = isLiveData ? const Color(0xFFD1FAE5) : const Color(0xFFE6F2FF);
    final fg = isLiveData ? const Color(0xFF065F46) : const Color(0xFF1E40AF);
    final label = isLoading
        ? 'Syncing product details...'
        : isLiveData
            ? 'Product details are up to date'
            : 'Showing saved details';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                isLoading
                    ? Icons.sync
                    : isLiveData
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                size: 14,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
        if (isFallback && errorMessage != null && errorMessage!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            errorMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}
