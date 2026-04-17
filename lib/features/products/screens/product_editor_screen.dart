import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../data/attribute_value_format.dart';
import '../data/attributes_repository.dart';
import '../providers/attributes_list_provider.dart';
import '../providers/categories_list_provider.dart';

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
    this.variantId,
    required this.options,
    required String initialSku,
    required String initialStock,
    String initialRegularPrice = '',
    String initialSalePrice = '',
    String initialImageUrl = '',
  })  : sku = TextEditingController(text: initialSku),
        stock = TextEditingController(text: initialStock),
        regularPrice = TextEditingController(text: initialRegularPrice),
        salePrice = TextEditingController(text: initialSalePrice),
        imageUrl = TextEditingController(text: initialImageUrl);

  /// Attribute display name → displayed option value (e.g. Color → Red).
  final String? variantId;
  final Map<String, String> options;
  final TextEditingController sku;
  final TextEditingController stock;
  final TextEditingController regularPrice;
  final TextEditingController salePrice;
  final TextEditingController imageUrl;

  String get optionSummary =>
      options.entries.map((e) => '${e.key}: ${e.value}').join('  |  ');

  void dispose() {
    sku.dispose();
    stock.dispose();
    regularPrice.dispose();
    salePrice.dispose();
    imageUrl.dispose();
  }
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen> {
  static const Duration _productCacheTtl = Duration(minutes: 5);
  static final Map<String, ({Map<String, dynamic> product, DateTime savedAt})> _productDetailCache = {};

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
  /// Remote gallery URLs (from API) + local file paths pending upload.
  final List<String> _remoteImageUrls = [];
  final List<String> _localImagePaths = [];
  String? _productApiId;
  final ScrollController _scrollController = ScrollController();
  final List<_VariantLine> _variantLines = [];
  final Set<String> _loadedVariantIds = <String>{};
  bool _isLiveData = false;
  bool _isLoadingRemote = false;
  bool _isSaving = false;
  String? _dataSourceError;
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
    _loadedVariantIds.clear();
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
          initialRegularPrice: _regularPrice.text.trim(),
          initialSalePrice: _salePrice.text.trim(),
          initialImageUrl: _remoteImageUrls.isNotEmpty ? _remoteImageUrls.first : '',
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

  void _applyVariantsFromProduct(Map<String, dynamic> p) {
    _disposeVariantLines();
    final rawVariants =
        p['variants'] ?? p['productVariants'] ?? p['product_variants'] ?? p['variantList'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      for (final item in rawVariants.whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        final vId = _asString(m['id'] ?? m['variantId']);
        final vSku = _asString(m['sku'] ?? m['code'], fallback: _sku.text.trim());
        final stockRaw = m['stock'] ?? m['stockQuantity'] ?? m['stock_quantity'] ?? m['quantity'];
        final vStock = stockRaw == null ? '0' : stockRaw.toString();
        final vRegular = _moneyToKes(m['regularPrice'] ?? m['regular_price'] ?? m['price']);
        final vSale = _moneyToKes(m['salePrice'] ?? m['sale_price']);
        final vImage = _asString(
          m['image'] ?? m['imageUrl'] ?? m['image_url'] ?? m['thumbnail'],
        );
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
            variantId: vId.isEmpty ? null : vId,
            options: options,
            initialSku: vSku.isEmpty ? 'SKU' : vSku,
            initialStock: vStock,
            initialRegularPrice: vRegular,
            initialSalePrice: vSale,
            initialImageUrl: vImage,
          ),
        );
        if (vId.isNotEmpty) {
          _loadedVariantIds.add(vId);
        }
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
    final looksLikeUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(trimmed);
    if (looksLikeUuid) {
      return trimmed;
    }
    if (trimmed.contains('-')) {
      final api = ref.read(apiClientProvider);
      try {
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
      } on DioException {
        // If listing fails (e.g. expired auth), fall back to the input key and let
        // the detail request surface a clearer error state.
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
      fallback: _categoryOptions.isNotEmpty ? _categoryOptions.first : '',
    );
    _category = _categoryOptions.contains(category)
        ? category
        : (_categoryOptions.isNotEmpty ? _categoryOptions.first : '');

    final statusRaw = (p['status'] ?? '').toString().toLowerCase();
    if (statusRaw.isNotEmpty) {
      _visible = statusRaw == 'active' || statusRaw == 'enabled';
    } else {
      _visible = p['isActive'] == true || p['active'] == true;
    }

    _remoteImageUrls.clear();
    void pushUrl(String? u) {
      if (u == null || u.trim().isEmpty) return;
      if (_remoteImageUrls.length >= 5) return;
      _remoteImageUrls.add(u.trim());
    }

    final imgs = p['images'] ?? p['media'] ?? p['gallery'];
    if (imgs is List) {
      for (final e in imgs) {
        if (e is String) {
          pushUrl(e);
        } else if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          pushUrl(
            (m['url'] ?? m['src'] ?? m['imageUrl'] ?? m['image_url'] ?? m['thumbnail'])?.toString(),
          );
        }
      }
    }
    if (_remoteImageUrls.isEmpty) {
      final primary = _primaryImageFromMap(p);
      pushUrl(primary);
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
          _localImagePaths.clear();
          _isLiveData = true;
          _isLoadingRemote = false;
          _lastSyncedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        final friendlyMessage = e is DioException && e.response?.statusCode == 401
            ? 'Session expired. Please sign in again.'
            : e.toString();
        setState(() {
          _isLiveData = false;
          _isLoadingRemote = false;
          _dataSourceError = friendlyMessage;
        });
      }
    }
  }

  Future<void> _openAddVariantSheet() async {
    final rootContext = context;
    final attrs = ref.read(dashboardAttributesProvider).valueOrNull ?? [];
    if (attrs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create attributes first (Manage Attributes).')),
      );
      return;
    }
    final selected = <String, String>{}; // attribute name -> chosen value label
    final regularPriceCtrl = TextEditingController(text: _regularPrice.text.trim());
    final salePriceCtrl = TextEditingController(text: _salePrice.text.trim());
    final imageUrlCtrl = TextEditingController(
      text: _remoteImageUrls.isNotEmpty ? _remoteImageUrls.first : '',
    );

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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Add variant',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select one value per attribute.',
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
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: a.values.map((raw) {
                                  final label = _valueLabel(a, raw);
                                  final isSelected = selected[a.name] == label;
                                  return ChoiceChip(
                                    label: Text(label),
                                    selected: isSelected,
                                    showCheckmark: false,
                                    selectedColor: AppTheme.primary,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
                                    labelStyle: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Colors.transparent
                                          : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                    onSelected: (_) {
                                      setModal(() {
                                        if (isSelected) {
                                          selected.remove(a.name);
                                        } else {
                                          selected[a.name] = label;
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                      Text(
                        'Variant price & image',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: regularPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Regular price',
                          prefixText: 'KES ',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: salePriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Sale price (optional)',
                          prefixText: 'KES ',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Variant image (optional)',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (imageUrlCtrl.text.trim().isNotEmpty)
                              Row(
                                children: [
                                  _VariantImagePreview(
                                    imagePathOrUrl: imageUrlCtrl.text.trim(),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      imageUrlCtrl.text
                                          .replaceAll(r'\', '/')
                                          .split('/')
                                          .last,
                                      style: Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'No image selected',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: () async {
                                    final source = await _showPhotoSourcePicker();
                                    if (source == null) return;
                                    final path = await _pickImagePath(source);
                                    if (path == null) return;
                                    setModal(() => imageUrlCtrl.text = path);
                                  },
                                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                                  label: const Text('Add image'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryDark,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (imageUrlCtrl.text.trim().isNotEmpty)
                                  TextButton(
                                    onPressed: () => setModal(() => imageUrlCtrl.clear()),
                                    child: const Text('Remove'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          final missing = attrs.where((a) => selected[a.name] == null).toList();
                          if (missing.isNotEmpty) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Select values for: ${missing.map((a) => a.name).join(', ')}',
                                ),
                              ),
                            );
                            return;
                          }
                          final variantRegular = _toDouble(regularPriceCtrl.text);
                          final variantSale = _toDouble(salePriceCtrl.text);
                          final variantPrimaryPrice =
                              variantRegular > 0 ? variantRegular : variantSale;
                          if (variantPrimaryPrice <= 0) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Add a price for this variant (regular or sale).',
                                ),
                              ),
                            );
                            return;
                          }
                          if (variantRegular > 0 && variantSale > variantRegular) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Variant sale price cannot be greater than regular price.',
                                ),
                              ),
                            );
                            return;
                          }
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
                            initialRegularPrice: regularPriceCtrl.text.trim(),
                            initialSalePrice: salePriceCtrl.text.trim(),
                            initialImageUrl: imageUrlCtrl.text.trim(),
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
    // Let bottom-sheet closing animations finish before disposal.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    regularPriceCtrl.dispose();
    salePriceCtrl.dispose();
    imageUrlCtrl.dispose();
  }

  Future<void> _openEditVariantSheet(_VariantLine line) async {
    final attrs = ref.read(dashboardAttributesProvider).valueOrNull ?? [];
    final selected = Map<String, String>.from(line.options);
    final regularCtrl = TextEditingController(text: line.regularPrice.text);
    final saleCtrl = TextEditingController(text: line.salePrice.text);
    final imageCtrl = TextEditingController(text: line.imageUrl.text);

    await showModalBottomSheet<void>(
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
              final theme = Theme.of(context);
              return DraggableScrollableSheet(
                initialChildSize: 0.8,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    children: [
                      Text(
                        'Edit variant details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Update selected attributes, price, and product image for this option.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (attrs.isEmpty)
                        Text(
                          'No attributes available for editing.',
                          style: theme.textTheme.bodySmall,
                        )
                      else
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
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: a.values.map((raw) {
                                    final label = _valueLabel(a, raw);
                                    final isSelected = selected[a.name] == label;
                                    return ChoiceChip(
                                      label: Text(label),
                                      selected: isSelected,
                                      showCheckmark: false,
                                      selectedColor: AppTheme.primary,
                                      backgroundColor: theme.colorScheme.surfaceContainerLow,
                                      labelStyle: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.onSurfaceVariant,
                                      ),
                                      side: BorderSide(
                                        color: isSelected
                                            ? Colors.transparent
                                            : theme.colorScheme.outlineVariant
                                                .withValues(alpha: 0.5),
                                      ),
                                      onSelected: (_) {
                                        setModal(() => selected[a.name] = label);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      TextField(
                        controller: regularCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Regular price',
                          prefixText: 'KES ',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: saleCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Sale price (optional)',
                          prefixText: 'KES ',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Variant image (optional)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (imageCtrl.text.trim().isNotEmpty)
                              Row(
                                children: [
                                  _VariantImagePreview(
                                    imagePathOrUrl: imageCtrl.text.trim(),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      imageCtrl.text.replaceAll(r'\', '/').split('/').last,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'No image selected',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: () async {
                                    final source = await _showPhotoSourcePicker();
                                    if (source == null) return;
                                    final path = await _pickImagePath(source);
                                    if (path == null) return;
                                    setModal(() => imageCtrl.text = path);
                                  },
                                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                                  label: const Text('Change image'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryDark,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (imageCtrl.text.trim().isNotEmpty)
                                  TextButton(
                                    onPressed: () => setModal(() => imageCtrl.clear()),
                                    child: const Text('Remove'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          final variantRegular = _toDouble(regularCtrl.text);
                          final variantSale = _toDouble(saleCtrl.text);
                          final variantPrimaryPrice =
                              variantRegular > 0 ? variantRegular : variantSale;
                          if (variantPrimaryPrice <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Add a price for this variant (regular or sale).',
                                ),
                              ),
                            );
                            return;
                          }
                          if (variantRegular > 0 && variantSale > variantRegular) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Variant sale price cannot be greater than regular price.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            if (selected.isNotEmpty) {
                              line.options
                                ..clear()
                                ..addAll(selected);
                            }
                            line.regularPrice.text = regularCtrl.text.trim();
                            line.salePrice.text = saleCtrl.text.trim();
                            line.imageUrl.text = imageCtrl.text.trim();
                          });
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Save changes',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

    // Let bottom-sheet closing animations finish before disposal.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    regularCtrl.dispose();
    saleCtrl.dispose();
    imageCtrl.dispose();
  }

  double _toDouble(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }

  String? _validateBeforeSave() {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Product name is required.';

    final stockRaw = _stock.text.trim();
    if (stockRaw.isNotEmpty && int.tryParse(stockRaw) == null) {
      return 'Stock must be a whole number.';
    }

    final regular = _toDouble(_regularPrice.text);
    final sale = _toDouble(_salePrice.text);
    final primaryPrice = regular > 0 ? regular : sale;
    if (primaryPrice <= 0) {
      return 'Enter a regular price or sale price greater than 0.';
    }
    if (regular > 0 && sale > regular) {
      return 'Sale price cannot be greater than regular price.';
    }

    for (var i = 0; i < _variantLines.length; i++) {
      final line = _variantLines[i];
      if (line.options.isEmpty) {
        return 'Variant ${i + 1} is missing selected attributes.';
      }
      final variantRegular = _toDouble(line.regularPrice.text);
      final variantSale = _toDouble(line.salePrice.text);
      final variantPrimaryPrice =
          variantRegular > 0 ? variantRegular : variantSale;
      if (variantPrimaryPrice <= 0) {
        return 'Add a price for variant ${i + 1}.';
      }
      if (variantRegular > 0 && variantSale > variantRegular) {
        return 'Variant ${i + 1} sale price cannot be greater than regular price.';
      }
    }

    return null;
  }

  int get _totalPhotoSlotsUsed =>
      (_remoteImageUrls.length + _localImagePaths.length).clamp(0, 5);

  String _generateSkuIfNeeded(String productName) {
    final base = productName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final prefix = base.isEmpty ? 'sku' : base;
    final tail = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final combined = '$prefix-$tail';
    return combined.length > 80 ? combined.substring(0, 80) : combined;
  }

  String? _resolveCategoryIdForSave() {
    final target = _category.trim().toLowerCase();
    if (target.isEmpty) return null;
    final async = ref.read(categoriesListProvider);
    final cats = async.valueOrNull;
    if (cats == null) return null;
    for (final c in cats) {
      if (c.name.trim().toLowerCase() == target) {
        final id = c.id.trim();
        if (id.isEmpty) return null;
        return id;
      }
    }
    return null;
  }

  String? _extractUploadedMediaUrl(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final inner = m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : m;
    for (final k in ['url', 'publicUrl', 'public_url', 'src', 'path']) {
      final v = inner[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  Future<String?> _uploadLocalImagePath(ApiClient api, String path) async {
    final name = path.replaceAll(r'\', '/').split('/').last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: name),
    });
    final r = await api.uploadMedia(form);
    if (!r.success || r.data == null) return null;
    return _extractUploadedMediaUrl(r.data);
  }

  bool _looksLikeRemoteImage(String value) {
    final v = value.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  Future<String> _resolveVariantImageUrl(ApiClient api, String rawValue) async {
    final v = rawValue.trim();
    if (v.isEmpty) return '';
    if (_looksLikeRemoteImage(v)) return v;
    final uploaded = await _uploadLocalImagePath(api, v);
    return uploaded ?? '';
  }

  Map<String, dynamic> _buildVariantPayload(
    _VariantLine line, {
    required int stock,
    required double regular,
    required double sale,
    required String imageUrl,
  }) {
    final payload = <String, dynamic>{
      'sku': line.sku.text.trim(),
      'stock': stock,
      'stockQuantity': stock,
      'stock_quantity': stock,
      'quantity': stock,
      'options': Map<String, String>.from(line.options),
      'attributes': Map<String, String>.from(line.options),
      'attribute_values': Map<String, String>.from(line.options),
    };
    if (regular > 0) {
      payload['price'] = regular;
      payload['regularPrice'] = regular;
      payload['regular_price'] = regular;
    }
    if (sale > 0) {
      payload['salePrice'] = sale;
      payload['sale_price'] = sale;
    }
    if (imageUrl.isNotEmpty) {
      payload['image'] = imageUrl;
      payload['imageUrl'] = imageUrl;
      payload['images'] = [imageUrl];
    }
    return payload;
  }

  String _extractPersistedProductId(dynamic payload, String fallbackId) {
    if (payload is Map<String, dynamic>) {
      final direct = (payload['id'] ?? payload['productId'] ?? '').toString().trim();
      if (direct.isNotEmpty) return direct;
      final nested = payload['product'] ?? payload['item'] ?? payload['data'];
      if (nested is Map) {
        final id = (nested['id'] ?? nested['productId'] ?? '').toString().trim();
        if (id.isNotEmpty) return id;
      }
    }
    return fallbackId;
  }

  Future<void> _syncVariantsForProduct(ApiClient api, String productId) async {
    final existingLines = _variantLines
        .where((v) => (v.variantId ?? '').trim().isNotEmpty)
        .toList();
    final currentIds = existingLines.map((v) => v.variantId!.trim()).toSet();
    final removedIds = _loadedVariantIds.difference(currentIds);

    for (final removedId in removedIds) {
      await api.deleteProductVariant(productId, removedId);
    }

    for (final line in _variantLines) {
      final stock = int.tryParse(line.stock.text.trim()) ?? 0;
      final regular = _toDouble(line.regularPrice.text);
      final sale = _toDouble(line.salePrice.text);
      final imageUrl = await _resolveVariantImageUrl(api, line.imageUrl.text);
      final body = _buildVariantPayload(
        line,
        stock: stock,
        regular: regular,
        sale: sale,
        imageUrl: imageUrl,
      );

      final variantId = (line.variantId ?? '').trim();
      if (variantId.isEmpty) {
        await api.createProductVariant(productId, body);
      } else {
        await api.updateProductVariant(productId, variantId, body);
      }
    }
  }

  String _formatSaveError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        final err = data['error'];
        if (err is Map && err['message'] is String) return err['message'] as String;
        if (err is String && err.isNotEmpty) return err;
      }
      if (e.message != null && e.message!.isNotEmpty) return e.message!;
    }
    return e.toString();
  }

  Future<ImageSource?> _showPhotoSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickImagePath(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      return file?.path;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildProductPayload({
    required String name,
    required String sku,
    required double regular,
    required double sale,
    required int stockVal,
    required List<String> imageUrls,
    required List<Map<String, dynamic>> variants,
    String? categoryId,
  }) {
    final desc = _description.text.trim();
    final hasVariants = variants.isNotEmpty;
    final payload = <String, dynamic>{
      'name': name,
      'description': desc,
      'sku': sku,
      'price': regular,
      'regularPrice': regular,
      'regular_price': regular,
      'category': _category,
      'categoryName': _category,
      'isActive': _visible,
      'is_active': _visible,
      'status': _visible ? 'active' : 'draft',
    };
    // Per API contract: product stock is managed at product level only when
    // there are no variants. When variants exist, backend derives totals.
    if (!hasVariants) {
      payload['stock'] = stockVal;
      payload['stockQuantity'] = stockVal;
      payload['stock_quantity'] = stockVal;
      payload['quantity'] = stockVal;
    }
    if (sale > 0) {
      payload['salePrice'] = sale;
      payload['sale_price'] = sale;
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      payload['categoryId'] = categoryId;
      payload['category_id'] = categoryId;
    }
    if (imageUrls.isNotEmpty) {
      payload['images'] = imageUrls;
      payload['imageUrls'] = imageUrls;
      payload['image'] = imageUrls.first;
      payload['imageUrl'] = imageUrls.first;
      payload['featuredImage'] = imageUrls.first;
      payload['featured_image'] = imageUrls.first;
    }
    if (variants.isNotEmpty) {
      payload['variants'] = variants;
      payload['productVariants'] = variants;
      payload['product_variants'] = variants;
    }
    return payload;
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    final validationError = _validateBeforeSave();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    final name = _name.text.trim();

    var sku = _sku.text.trim();
    if (sku.isEmpty) {
      sku = _generateSkuIfNeeded(name);
      _sku.text = sku;
    }

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);

      final uploaded = <String>[];
      for (final path in _localImagePaths) {
        final url = await _uploadLocalImagePath(api, path);
        if (url != null && url.isNotEmpty) {
          uploaded.add(url);
        }
      }
      final imageUrls = [..._remoteImageUrls, ...uploaded];

      final regular = _toDouble(_regularPrice.text);
      final sale = _toDouble(_salePrice.text);
      final stockVal = int.tryParse(_stock.text.trim()) ?? 0;

      final primaryPrice = regular > 0 ? regular : sale;
      if (primaryPrice <= 0) {
        throw StateError('Enter a regular price or sale price greater than 0.');
      }

      final categoryId = _resolveCategoryIdForSave();

      final payload = _buildProductPayload(
        name: name,
        sku: sku,
        regular: regular > 0 ? regular : primaryPrice,
        sale: sale,
        stockVal: stockVal,
        imageUrls: imageUrls,
        variants: const [],
        categoryId: categoryId,
      );

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

      final persistedProductId = _extractPersistedProductId(
        response.data,
        (updateKey ?? '').toString().trim(),
      );
      if (persistedProductId.isEmpty) {
        throw StateError('Product saved, but missing product id for variant sync.');
      }
      await _syncVariantsForProduct(api, persistedProductId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNew ? 'Product created' : 'Product updated')),
      );
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatSaveError(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatSaveError(e))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final path = await _pickImagePath(source);
      if (path == null || !mounted) return;
      setState(() {
        if (_totalPhotoSlotsUsed < 5) {
          _localImagePaths.add(path);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick photo: $e')),
      );
    }
  }

  Future<void> _showAddPhotoSourceSheet() async {
    if (_totalPhotoSlotsUsed >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 photos reached')),
      );
      return;
    }
    final source = await _showPhotoSourcePicker();
    if (source != null) {
      await _pickPhoto(source);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRefreshHintPref();
    final isNew = widget.initialSku == null;
    _categoryOptions = <String>[];
    _category = '';
    _name = TextEditingController();
    _description = TextEditingController();
    _regularPrice = TextEditingController();
    _salePrice = TextEditingController();
    _sku = TextEditingController(text: widget.initialSku ?? '');
    _stock = TextEditingController();
    _remoteImageUrls.clear();
    _localImagePaths.clear();
    _productApiId = null;
    _initVariantLines();
    if (!isNew) {
      _loadLiveProductIfEditing();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoriesListProvider.future).then((list) {
        if (!mounted) return;
        setState(() {
          final names = list
              .map((c) => c.name.trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          _categoryOptions = names;
          if (_categoryOptions.isNotEmpty) {
            if (!_categoryOptions.contains(_category)) {
              _category = _categoryOptions.first;
            }
          } else {
            _category = '';
          }
        });
      }).catchError((_) {});
    });
  }

  Future<void> _loadRefreshHintPref() async {
    final seen = await ref.read(tokenStorageProvider).getProductDetailRefreshHintSeen();
    if (!mounted) return;
    setState(() => _hasSeenRefreshHint = seen);
  }

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
    final hasVariants = _variantLines.isNotEmpty;
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
            ),
          ),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveProduct,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'Saving product...' : 'Save product'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (isNew) return;
          await _loadLiveProductIfEditing(forceRefresh: true);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          buildDashboardSliverAppBar(
            context: context,
            title: isNew ? 'Add Product' : 'Edit Product',
            showDivider: true,
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
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MediaSectionHeader(
                  title: 'Media',
                  trailing: Text(
                    '$_totalPhotoSlotsUsed / 5 Photos',
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
                      ..._remoteImageUrls.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _MediaThumb(
                                imageUrl: e.value,
                                localImagePath: null,
                                onRemove: () =>
                                    setState(() => _remoteImageUrls.removeAt(e.key)),
                              ),
                            ),
                          ),
                      ..._localImagePaths.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _MediaThumb(
                                imageUrl: '',
                                localImagePath: e.value,
                                onRemove: () =>
                                    setState(() => _localImagePaths.removeAt(e.key)),
                              ),
                            ),
                          ),
                      _AddPhotoButton(onTap: _showAddPhotoSourceSheet),
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
                            value: _categoryOptions.contains(_category) ? _category : null,
                            isExpanded: true,
                            icon: Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
                            hint: Text(
                              _categoryOptions.isEmpty
                                  ? 'No categories yet. Create one first.'
                                  : 'Select category',
                            ),
                            items: _categoryOptions
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: _categoryOptions.isEmpty
                                ? null
                                : (v) => setState(() => _category = v ?? _category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Inventory',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasVariants
                            ? 'Product stock is auto-calculated from your variants.'
                            : 'Leave SKU empty to auto-generate when you publish.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                                decoration: _inventoryFieldDeco(theme, hint: 'Auto if empty'),
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
                                enabled: !hasVariants,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                decoration: _inventoryFieldDeco(
                                  theme,
                                  hint: hasVariants ? 'Managed by variants' : '0',
                                ),
                              ),
                            ),
                          ),
                        ],
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
                const SizedBox(height: 16),
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
                                          'Product options',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primaryDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Add options your customers understand, like Size, Color, or Material. Each option can have its own SKU, stock, price, and image.',
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
                                            ? 'No attributes yet. Add product attributes like Size or Color first.'
                                            : '${value.length} attribute(s) available — use them to build product options below.',
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
                                    'No product options yet. Tap "Add variant" to create one.',
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
                                      onEdit: () => _openEditVariantSheet(line),
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

  /// Stronger contrast vs `_CardShell` so SKU/stock read as inputs, not bare background.
  InputDecoration _inventoryFieldDeco(ThemeData theme, {String? hint}) {
    final idle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
      ),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest,
      border: idle,
      enabledBorder: idle,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
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
  const _MediaThumb({
    required this.imageUrl,
    required this.onRemove,
    this.localImagePath,
  });

  final String imageUrl;
  final VoidCallback onRemove;
  final String? localImagePath;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    final localPath = (localImagePath ?? '').trim();
    final hasLocalImage = localPath.isNotEmpty;
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
          child: hasLocalImage
              ? Image.file(
                  File(localPath),
                  width: 128,
                  height: 128,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 128,
                    height: 128,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                )
              : hasImage
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
        if (hasImage || hasLocalImage)
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
    required this.onEdit,
    required this.onRemove,
  });

  final _VariantLine line;
  final VoidCallback onEdit;
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
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                tooltip: 'Edit variant details',
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                tooltip: 'Remove variant',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (line.regularPrice.text.trim().isNotEmpty)
                _VariantChip(label: 'Price: KES ${line.regularPrice.text.trim()}'),
              if (line.salePrice.text.trim().isNotEmpty)
                _VariantChip(label: 'Sale: KES ${line.salePrice.text.trim()}'),
              if (line.imageUrl.text.trim().isNotEmpty)
                _VariantImagePreview(imagePathOrUrl: line.imageUrl.text.trim()),
            ],
          ),
          if (line.regularPrice.text.trim().isNotEmpty ||
              line.salePrice.text.trim().isNotEmpty ||
              line.imageUrl.text.trim().isNotEmpty)
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
    final idle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );
    return InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest,
      border: idle,
      enabledBorder: idle,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _VariantImagePreview extends StatelessWidget {
  const _VariantImagePreview({required this.imagePathOrUrl});

  final String imagePathOrUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRemote =
        imagePathOrUrl.startsWith('http://') || imagePathOrUrl.startsWith('https://');

    Widget img;
    if (isRemote) {
      img = Image.network(
        imagePathOrUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _variantImageFallback(theme),
      );
    } else {
      img = Image.file(
        File(imagePathOrUrl),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _variantImageFallback(theme),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: img,
      ),
    );
  }

  Widget _variantImageFallback(ThemeData theme) {
    return Container(
      width: 44,
      height: 44,
      color: theme.colorScheme.surfaceContainerLow,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
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
