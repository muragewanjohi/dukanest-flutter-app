import 'dart:convert';
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
import '../../../core/util/store_media_url.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../media/screens/media_library_screen.dart';
import '../data/attribute_value_format.dart';
import '../data/attributes_repository.dart';
import '../data/categories_repository.dart';
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
  ConsumerState<ProductEditorScreen> createState() =>
      _ProductEditorScreenState();
}

enum _ProductEditorTab {
  details('Details'),
  pricing('Pricing'),
  variants('Variants'),
  visibility('Visibility');

  const _ProductEditorTab(this.label);

  final String label;
}

/// Shown under labels so merchants know what to enter (placeholder hints use shorter text).
const _kProductNameExample = 'Fresh Maize Flour 2kg – Grade 1';
const _kProductDescriptionExample =
    'Grade 1 maize flour in a 2 kg bag. Milled locally. Store in a cool, dry place.';

/// One sellable variant (option combination + SKU + stock).
class _VariantLine {
  _VariantLine({
    this.variantId,
    required this.options,
    required String initialSku,
    required String initialStock,
    String initialRegularPrice = '',
    String initialSalePrice = '',
    String initialCostPrice = '',
    String initialImageUrl = '',
  })  : sku = TextEditingController(text: initialSku),
        stock = TextEditingController(text: initialStock),
        regularPrice = TextEditingController(text: initialRegularPrice),
        salePrice = TextEditingController(text: initialSalePrice),
        costPrice = TextEditingController(text: initialCostPrice),
        imageUrl = TextEditingController(text: initialImageUrl);

  /// Attribute display name → displayed option value (e.g. Color → Red).
  final String? variantId;
  final Map<String, String> options;
  final TextEditingController sku;
  final TextEditingController stock;
  final TextEditingController regularPrice;
  final TextEditingController salePrice;
  final TextEditingController costPrice;
  final TextEditingController imageUrl;

  String get optionSummary =>
      options.entries.map((e) => '${e.key}: ${e.value}').join('  |  ');

  void dispose() {
    sku.dispose();
    stock.dispose();
    regularPrice.dispose();
    salePrice.dispose();
    costPrice.dispose();
    imageUrl.dispose();
  }
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen> {
  static const Duration _productCacheTtl = Duration(minutes: 5);
  static final Map<String, ({Map<String, dynamic> product, DateTime savedAt})>
      _productDetailCache = {};

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _regularPrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _costPrice;
  late final TextEditingController _sku;
  late final TextEditingController _stock;

  late String _category;
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
  bool _initialVisible = true;
  _ProductEditorTab _activeEditorTab = _ProductEditorTab.details;
  String? _dataSourceError;
  DateTime? _lastSyncedAt;
  bool _hasSeenRefreshHint = false;
  bool _refreshHintPrefLoaded = false;

  /// Tracks the single field currently flagged as invalid so we can highlight
  /// it in red and scroll it into view. Cleared when the user edits the field
  /// or another save attempt succeeds.
  String? _errorFieldId;
  final Map<String, GlobalKey> _fieldKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String fieldId) => _fieldKeys.putIfAbsent(
      fieldId, () => GlobalKey(debugLabel: 'field:$fieldId'));

  bool _isInvalid(String fieldId) => _errorFieldId == fieldId;

  void _clearErrorFor(String fieldId) {
    if (_errorFieldId == fieldId && mounted) {
      setState(() => _errorFieldId = null);
    }
  }

  void _scrollToFieldKey(String fieldId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BuildContext? ctx = _fieldKeys[fieldId]?.currentContext;
      if (ctx == null) {
        // Variant sub-fields (e.g. `variant_0_stock`, `variant_0_price`) live
        // inside the variant tile — fall back to scrolling to that tile.
        final m = RegExp(r'^(variant_\d+)_').firstMatch(fieldId);
        if (m != null) {
          ctx = _fieldKeys[m.group(1)!]?.currentContext;
        }
      }
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    });
  }

  /// Explains what's missing before variants can be added (snackbar + variants section scroll).
  void _showVariantSetupRequired(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
    _scrollVariantsSectionIntoView();
  }

  void _scrollVariantsSectionIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _keyFor('section_variants').currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

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
    final baseSku =
        _sku.text.trim().isEmpty ? (sku ?? 'SKU') : _sku.text.trim();

    if (sku != null && sku.isNotEmpty) {
      _variantLines.add(
        _VariantLine(
          options: {'Default': 'Standard'},
          initialSku: baseSku,
          initialStock: _stock.text.trim().isEmpty ? '0' : _stock.text.trim(),
          initialRegularPrice: _regularPrice.text.trim(),
          initialSalePrice: _salePrice.text.trim(),
          initialCostPrice: _costPrice.text.trim(),
          initialImageUrl:
              _remoteImageUrls.isNotEmpty ? _remoteImageUrls.first : '',
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

  bool _isPlaceholderVariant(_VariantLine line) {
    if (line.options.length != 1) return false;
    final entry = line.options.entries.first;
    return entry.key.trim().toLowerCase() == 'default' &&
        entry.value.trim().toLowerCase() == 'standard';
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
    final rawVariants = p['variants'] ??
        p['productVariants'] ??
        p['product_variants'] ??
        p['variantList'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      for (final item in rawVariants.whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        final vId = _asString(m['id'] ?? m['variantId']);
        final vSku =
            _asString(m['sku'] ?? m['code'], fallback: _sku.text.trim());
        final stockRaw = m['stock'] ??
            m['stockQuantity'] ??
            m['stock_quantity'] ??
            m['quantity'];
        final vStock = stockRaw == null ? '0' : stockRaw.toString();
        final vRegular =
            _moneyToKes(m['regularPrice'] ?? m['regular_price'] ?? m['price']);
        final vSale = _moneyToKes(m['salePrice'] ?? m['sale_price']);
        final vCost =
            _moneyToKes(m['costPrice'] ?? m['cost_price'] ?? m['cost']);
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
            final key =
                _asString(r['name'] ?? r['attribute_name'], fallback: 'Option');
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
            initialCostPrice: vCost,
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
    final raw =
        payload['product'] ?? payload['item'] ?? payload['data'] ?? payload;
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
    _regularPrice.text = _moneyToKes(p['regularPrice'] ??
        p['regular_price'] ??
        p['price'] ??
        p['unitPrice']);
    final saleRaw = p['salePrice'] ??
        p['sale_price'] ??
        p['discountPrice'] ??
        p['discount_price'];
    _salePrice.text = saleRaw == null ? '' : _moneyToKes(saleRaw);
    final costRaw = p['costPrice'] ?? p['cost_price'] ?? p['cost'];
    _costPrice.text = costRaw == null ? '' : _moneyToKes(costRaw);
    _sku.text = _asString(p['sku'] ?? p['code'], fallback: _sku.text);
    final stock = p['stock'] ??
        p['stockQuantity'] ??
        p['stock_quantity'] ??
        p['quantity'];
    _stock.text = stock == null ? '' : stock.toString();

    _category = _asString(
      p['categoryName'] ??
          p['category'] ??
          p['category_name'] ??
          p['categoryLabel'],
    );

    final statusRaw = (p['status'] ?? '').toString().toLowerCase();
    if (statusRaw.isNotEmpty) {
      _visible = statusRaw == 'active' || statusRaw == 'enabled';
    } else {
      _visible = p['isActive'] == true || p['active'] == true;
    }
    _initialVisible = _visible;

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
            (m['url'] ??
                    m['src'] ??
                    m['imageUrl'] ??
                    m['image_url'] ??
                    m['thumbnail'])
                ?.toString(),
          );
        }
      }
    }
    if (_remoteImageUrls.isEmpty) {
      final primary = _primaryImageFromMap(p);
      pushUrl(primary);
    }

    _applyVariantsFromProduct(p);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(categoriesListProvider).whenData(_syncCategoryAfterCategoriesLoad);
    });
  }

  Future<void> _loadLiveProductIfEditing({bool forceRefresh = false}) async {
    final initialKey = widget.initialSku;
    if (initialKey == null || initialKey.isEmpty) return;

    if (!forceRefresh) {
      final cached = _productDetailCache[initialKey];
      if (cached != null &&
          DateTime.now().difference(cached.savedAt) < _productCacheTtl) {
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
        final friendlyMessage =
            e is DioException && e.response?.statusCode == 401
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
    final attrsAsync = ref.read(dashboardAttributesProvider);
    final all = attrsAsync.valueOrNull ?? [];
    final attrs =
        all.where((a) => a.values.isNotEmpty).toList(growable: false);
    if (attrs.isEmpty) {
      if (!mounted) return;
      if (attrsAsync.hasError) {
        _showVariantSetupRequired(
          'Could not load product attributes: ${attrsAsync.error}',
        );
        return;
      }
      if (attrsAsync.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Still loading attributes. Wait a moment, then tap Add variant again.',
            ),
          ),
        );
        _scrollVariantsSectionIntoView();
        return;
      }
      if (all.isEmpty) {
        _showVariantSetupRequired(
          'Add at least one product attribute — for example Size or Color — before you add variants. Open Attributes from the catalog or settings.',
        );
      } else {
        _showVariantSetupRequired(
          'Each attribute needs option values — for example Small, Medium, Large for Size. Open Manage attributes, edit the attribute, and add options.',
        );
      }
      return;
    }
    final selected = <String, String>{}; // attribute name -> chosen value label
    final regularPriceCtrl =
        TextEditingController(text: _regularPrice.text.trim());
    final salePriceCtrl = TextEditingController(text: _salePrice.text.trim());
    final costPriceCtrl = TextEditingController(text: _costPrice.text.trim());
    final stockQtyCtrl = TextEditingController();
    final imageUrlCtrl = TextEditingController(
      text: _remoteImageUrls.isNotEmpty ? _remoteImageUrls.first : '',
    );

    final variantSheetError = <String?>[null];

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModal) {
              void reportVariantSheetError(String fieldId, String message) {
                variantSheetError[0] = fieldId;
                setModal(() {});
                final cs = Theme.of(rootContext).colorScheme;
                ScaffoldMessenger.of(rootContext)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(message),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: cs.error,
                      duration: const Duration(seconds: 4),
                    ),
                  );
              }

              void clearVariantSheetError([String? only]) {
                final e = variantSheetError[0];
                if (e == null) return;
                if (only == null || e == only) {
                  variantSheetError[0] = null;
                  setModal(() {});
                }
              }

              void clearVariantPricingErrors() {
                final e = variantSheetError[0];
                if (e != 'variantPrice' && e != 'variantSale') return;
                variantSheetError[0] = null;
                setModal(() {});
              }

              return DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.45,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  final sheetErr = variantSheetError[0];
                  final attrsInvalid = sheetErr == 'variantAttributes';
                  final priceInvalid = sheetErr == 'variantPrice';
                  final saleInvalid = sheetErr == 'variantSale';
                  final costInvalid = sheetErr == 'variantCost';
                  final stockInvalid = sheetErr == 'variantStock';

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
                        'Select at least one attribute value.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: attrsInvalid
                            ? const EdgeInsets.all(10)
                            : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            width: attrsInvalid ? 1.5 : 0,
                            color: attrsInvalid
                                ? Theme.of(context).colorScheme.error
                                : Colors.transparent,
                          ),
                          color: attrsInvalid
                              ? Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.05)
                              : null,
                        ),
                        child: Column(
                          children: attrs
                              .map((a) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        children:
                                            a.values.map((raw) {
                                          final label =
                                              _valueLabel(a, raw);
                                          final isSelected =
                                              selected[a.name] == label;
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
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppTheme.onSurfaceVariant,
                                            ),
                                            side: BorderSide(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .outlineVariant
                                                      .withValues(
                                                          alpha: 0.5),
                                            ),
                                            onSelected: (_) {
                                              setModal(() {
                                                if (isSelected) {
                                                  selected.remove(a.name);
                                                } else {
                                                  selected[a.name] = label;
                                                }
                                              });
                                              clearVariantSheetError(
                                                  'variantAttributes');
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
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
                        onChanged: (_) => clearVariantPricingErrors(),
                        decoration: _variantPricingInputDecoration(
                          Theme.of(context),
                          labelText: 'Regular price',
                          prefixText: 'KES ',
                          isInvalid: priceInvalid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: salePriceCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => clearVariantPricingErrors(),
                        decoration: _variantPricingInputDecoration(
                          Theme.of(context),
                          labelText: 'Sale price (optional)',
                          prefixText: 'KES ',
                          isInvalid: saleInvalid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: costPriceCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) =>
                            clearVariantSheetError('variantCost'),
                        decoration: _variantPricingInputDecoration(
                          Theme.of(context),
                          labelText: 'Cost of goods (optional)',
                          helperText: 'Used for profit reporting only.',
                          prefixText: 'KES ',
                          isInvalid: costInvalid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: stockQtyCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) =>
                            clearVariantSheetError('variantStock'),
                        decoration: _variantPricingInputDecoration(
                          Theme.of(context),
                          labelText: 'Stock quantity',
                          isInvalid: stockInvalid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.55),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Variant image (optional)',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'No image selected',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: () async {
                                    final source =
                                        await _showPhotoSourcePicker();
                                    if (source == null) return;
                                    final path = await _pickImagePath(source);
                                    if (path == null) return;
                                    setModal(() => imageUrlCtrl.text = path);
                                  },
                                  icon: const Icon(Icons.add_a_photo_outlined,
                                      size: 18),
                                  label: const Text('Add image'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryDark,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (imageUrlCtrl.text.trim().isNotEmpty)
                                  TextButton(
                                    onPressed: () =>
                                        setModal(() => imageUrlCtrl.clear()),
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
                          if (selected.isEmpty) {
                            reportVariantSheetError(
                              'variantAttributes',
                              'Select at least one attribute value.',
                            );
                            return;
                          }
                          final variantRegular =
                              _toDouble(regularPriceCtrl.text);
                          final variantSale = _toDouble(salePriceCtrl.text);
                          final variantCost =
                              _toDouble(costPriceCtrl.text);
                          final variantPrimaryPrice =
                              variantRegular > 0
                                  ? variantRegular
                                  : variantSale;
                          if (variantPrimaryPrice <= 0) {
                            reportVariantSheetError(
                              'variantPrice',
                              'Enter a regular or sale price for this variant (KES).',
                            );
                            return;
                          }
                          if (variantRegular > 0 &&
                              variantSale > variantRegular) {
                            reportVariantSheetError(
                              'variantSale',
                              'Variant sale price cannot be greater than regular price.',
                            );
                            return;
                          }
                          if (costPriceCtrl.text.trim().isNotEmpty &&
                              variantCost <= 0) {
                            reportVariantSheetError(
                              'variantCost',
                              'Variant cost of goods must be greater than 0 when provided.',
                            );
                            return;
                          }
                          final variantStockRaw =
                              stockQtyCtrl.text.trim();
                          if (variantStockRaw.isEmpty) {
                            reportVariantSheetError(
                              'variantStock',
                              'Stock quantity is required — enter how many units you have.',
                            );
                            return;
                          }
                          final variantStock =
                              int.tryParse(variantStockRaw);
                          if (variantStock == null) {
                            reportVariantSheetError(
                              'variantStock',
                              'Stock quantity must be a whole number.',
                            );
                            return;
                          }
                          if (variantStock < 0) {
                            reportVariantSheetError(
                              'variantStock',
                              'Stock quantity cannot be negative.',
                            );
                            return;
                          }
                          final combo =
                              Map<String, String>.from(selected);
                          if (_variantLines
                              .any((l) => _optionsEqual(l.options, combo))) {
                            Navigator.pop(ctx, false);
                            return;
                          }
                          final base = _sku.text.trim().isEmpty
                              ? 'VAR'
                              : _sku.text.trim();
                          final idx = _variantLines.length + 1;
                          _variantLines.add(_VariantLine(
                            options: combo,
                            initialSku: '$base-V$idx',
                            initialStock: variantStockRaw,
                            initialRegularPrice: regularPriceCtrl.text.trim(),
                            initialSalePrice: salePriceCtrl.text.trim(),
                            initialCostPrice: costPriceCtrl.text.trim(),
                            initialImageUrl: imageUrlCtrl.text.trim(),
                          ));
                          Navigator.pop(ctx, true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Add variant',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700)),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Variant added')));
    } else if (added == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That combination already exists')),
      );
    }
    // Let bottom-sheet closing animations finish before disposal.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    regularPriceCtrl.dispose();
    salePriceCtrl.dispose();
    costPriceCtrl.dispose();
    stockQtyCtrl.dispose();
    imageUrlCtrl.dispose();
  }

  Future<void> _openEditVariantSheet(_VariantLine line) async {
    final sheetRootContext = context;
    final attrs = ref.read(dashboardAttributesProvider).valueOrNull ?? [];
    final selected = Map<String, String>.from(line.options);
    final regularCtrl = TextEditingController(text: line.regularPrice.text);
    final saleCtrl = TextEditingController(text: line.salePrice.text);
    final costCtrl = TextEditingController(text: line.costPrice.text);
    final stockCtrl = TextEditingController(text: line.stock.text);
    final imageCtrl = TextEditingController(text: line.imageUrl.text);
    final editVariantSheetErr = <String?>[null];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModal) {
              void reportEv(String fieldId, String message) {
                editVariantSheetErr[0] = fieldId;
                setModal(() {});
                final cs = Theme.of(sheetRootContext).colorScheme;
                ScaffoldMessenger.of(sheetRootContext)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(message),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: cs.error,
                      duration: const Duration(seconds: 4),
                    ),
                  );
              }

              void clearEv([String? only]) {
                final e = editVariantSheetErr[0];
                if (e == null) return;
                if (only == null || e == only) {
                  editVariantSheetErr[0] = null;
                  setModal(() {});
                }
              }

              void clearEvPricing() {
                final e = editVariantSheetErr[0];
                if (e != 'variantPrice' && e != 'variantSale') return;
                editVariantSheetErr[0] = null;
                setModal(() {});
              }

              return DraggableScrollableSheet(
                initialChildSize: 0.8,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  final theme = Theme.of(context);
                  final usableAttrs =
                      attrs.where((a) => a.values.isNotEmpty).toList();
                  final sheetErr = editVariantSheetErr[0];
                  final attrsInvalid = sheetErr == 'variantAttributes';
                  final priceInvalid = sheetErr == 'variantPrice';
                  final saleInvalid = sheetErr == 'variantSale';
                  final costInvalid = sheetErr == 'variantCost';
                  final stockInvalid = sheetErr == 'variantStock';

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
                      if (usableAttrs.isEmpty)
                        Text(
                          attrs.isEmpty
                              ? 'No attributes available for editing.'
                              : 'Attributes have no option values. Add values under Manage attributes first.',
                          style: theme.textTheme.bodySmall,
                        )
                      else
                        Container(
                          padding: attrsInvalid
                              ? const EdgeInsets.all(10)
                              : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              width: attrsInvalid ? 1.5 : 0,
                              color: attrsInvalid
                                  ? theme.colorScheme.error
                                  : Colors.transparent,
                            ),
                            color: attrsInvalid
                                ? theme.colorScheme.error
                                    .withValues(alpha: 0.05)
                                : null,
                          ),
                          child: Column(
                            children: usableAttrs
                                .map((a) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          children:
                                              a.values.map((raw) {
                                            final label =
                                                _valueLabel(a, raw);
                                            final isSelected =
                                                selected[a.name] == label;
                                            return ChoiceChip(
                                              label: Text(label),
                                              selected: isSelected,
                                              showCheckmark: false,
                                              selectedColor: AppTheme.primary,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .surfaceContainerLow,
                                              labelStyle: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppTheme
                                                        .onSurfaceVariant,
                                              ),
                                              side: BorderSide(
                                                color: isSelected
                                                    ? Colors.transparent
                                                    : theme.colorScheme
                                                        .outlineVariant
                                                        .withValues(
                                                            alpha: 0.5),
                                              ),
                                              onSelected: (_) {
                                                setModal(() {
                                                  if (isSelected) {
                                                    selected.remove(a.name);
                                                  } else {
                                                    selected[a.name] =
                                                        label;
                                                  }
                                                });
                                                clearEv(
                                                    'variantAttributes');
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: regularCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => clearEvPricing(),
                        decoration: _variantPricingInputDecoration(
                          theme,
                          labelText: 'Regular price',
                          prefixText: 'KES ',
                          isInvalid: priceInvalid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: saleCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => clearEvPricing(),
                        decoration: _variantPricingInputDecoration(
                          theme,
                          labelText: 'Sale price (optional)',
                          prefixText: 'KES ',
                          isInvalid: saleInvalid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => clearEv('variantCost'),
                        decoration: _variantPricingInputDecoration(
                          theme,
                          labelText: 'Cost of goods (optional)',
                          helperText: 'Used for profit reporting only.',
                          prefixText: 'KES ',
                          isInvalid: costInvalid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => clearEv('variantStock'),
                        decoration: _variantPricingInputDecoration(
                          theme,
                          labelText: 'Stock quantity',
                          isInvalid: stockInvalid,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.55),
                            width: 1,
                          ),
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
                                      imageCtrl.text
                                          .replaceAll(r'\', '/')
                                          .split('/')
                                          .last,
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
                                    final source =
                                        await _showPhotoSourcePicker();
                                    if (source == null) return;
                                    final path = await _pickImagePath(source);
                                    if (path == null) return;
                                    setModal(() => imageCtrl.text = path);
                                  },
                                  icon: const Icon(Icons.add_a_photo_outlined,
                                      size: 18),
                                  label: const Text('Change image'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryDark,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (imageCtrl.text.trim().isNotEmpty)
                                  TextButton(
                                    onPressed: () =>
                                        setModal(() => imageCtrl.clear()),
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
                          if (usableAttrs.isNotEmpty && selected.isEmpty) {
                            reportEv(
                              'variantAttributes',
                              'Select at least one attribute value.',
                            );
                            return;
                          }
                          final variantRegular =
                              _toDouble(regularCtrl.text);
                          final variantSale = _toDouble(saleCtrl.text);
                          final variantCost = _toDouble(costCtrl.text);
                          final variantPrimaryPrice =
                              variantRegular > 0
                                  ? variantRegular
                                  : variantSale;
                          if (variantPrimaryPrice <= 0) {
                            reportEv(
                              'variantPrice',
                              'Enter a regular or sale price for this variant (KES).',
                            );
                            return;
                          }
                          if (variantRegular > 0 &&
                              variantSale > variantRegular) {
                            reportEv(
                              'variantSale',
                              'Variant sale price cannot be greater than regular price.',
                            );
                            return;
                          }
                          if (costCtrl.text.trim().isNotEmpty &&
                              variantCost <= 0) {
                            reportEv(
                              'variantCost',
                              'Variant cost of goods must be greater than 0 when provided.',
                            );
                            return;
                          }
                          final variantStockRaw =
                              stockCtrl.text.trim();
                          if (variantStockRaw.isEmpty) {
                            reportEv(
                              'variantStock',
                              'Stock quantity is required — enter how many units you have.',
                            );
                            return;
                          }
                          final variantStock =
                              int.tryParse(variantStockRaw);
                          if (variantStock == null) {
                            reportEv(
                              'variantStock',
                              'Stock quantity must be a whole number.',
                            );
                            return;
                          }
                          if (variantStock < 0) {
                            reportEv(
                              'variantStock',
                              'Stock quantity cannot be negative.',
                            );
                            return;
                          }
                          setState(() {
                            if (selected.isNotEmpty) {
                              line.options
                                ..clear()
                                ..addAll(selected);
                            }
                            line.stock.text = variantStockRaw;
                            line.regularPrice.text = regularCtrl.text.trim();
                            line.salePrice.text = saleCtrl.text.trim();
                            line.costPrice.text = costCtrl.text.trim();
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
    costCtrl.dispose();
    stockCtrl.dispose();
    imageCtrl.dispose();
  }

  double _toDouble(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }

  String? _discountLabel() {
    final regular = _toDouble(_regularPrice.text);
    final sale = _toDouble(_salePrice.text);
    if (regular <= 0 || sale <= 0 || sale >= regular) return null;
    final percent = ((regular - sale) / regular) * 100;
    return '-${percent.round()}% off';
  }

  String _publishActionLabel({required bool isNew}) {
    if (_isSaving) return 'Saving...';
    if (isNew) return 'Publish';
    if (_visible) return _initialVisible ? 'Update published' : 'Publish';
    return _initialVisible ? 'Unpublish' : 'Save draft';
  }

  _ProductEditorTab? _nextEditorTab() {
    final tabs = _ProductEditorTab.values;
    final index = tabs.indexOf(_activeEditorTab);
    if (index < 0 || index >= tabs.length - 1) return null;
    return tabs[index + 1];
  }

  String _primaryActionLabel({required bool isNew}) {
    if (_activeEditorTab == _ProductEditorTab.visibility) {
      return _isSaving
          ? 'Saving product...'
          : _publishActionLabel(isNew: isNew);
    }
    final next = _nextEditorTab();
    return next == null ? 'Next' : 'Next: ${next.label}';
  }

  IconData _primaryActionIcon() {
    return _activeEditorTab == _ProductEditorTab.visibility
        ? Icons.save_outlined
        : Icons.arrow_forward_rounded;
  }

  void _handlePrimaryAction() {
    if (_activeEditorTab == _ProductEditorTab.visibility) {
      _saveProduct();
      return;
    }
    final next = _nextEditorTab();
    if (next != null) {
      setState(() => _activeEditorTab = next);
    }
  }

  Future<void> _saveLocalDraft() async {
    final draftKey =
        (widget.initialSku ?? _productApiId ?? 'new_product').trim();
    final draft = <String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'regularPrice': _regularPrice.text.trim(),
      'salePrice': _salePrice.text.trim(),
      'costPrice': _costPrice.text.trim(),
      'sku': _sku.text.trim(),
      'stock': _stock.text.trim(),
      'category': _category,
      'visible': _visible,
      'remoteImageUrls': _remoteImageUrls,
      'localImagePaths': _localImagePaths,
      'variants': _variantLines
          .map((line) => {
                'variantId': line.variantId,
                'options': line.options,
                'sku': line.sku.text.trim(),
                'stock': line.stock.text.trim(),
                'regularPrice': line.regularPrice.text.trim(),
                'salePrice': line.salePrice.text.trim(),
                'costPrice': line.costPrice.text.trim(),
                'imageUrl': line.imageUrl.text.trim(),
              })
          .toList(),
    };
    await ref.read(tokenStorageProvider).saveProductEditorDraft(
        draftKey.isEmpty ? 'new_product' : draftKey, jsonEncode(draft));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Draft saved locally on this device')),
      );
    context.go('/products');
  }

  _ProductEditorTab _tabForField(String fieldId) {
    if (fieldId.startsWith('variant_') || fieldId == 'section_variants') {
      return _ProductEditorTab.variants;
    }
    if (fieldId == 'stock' ||
        fieldId == 'regularPrice' ||
        fieldId == 'salePrice' ||
        fieldId == 'costPrice' ||
        fieldId == 'section_inventory' ||
        fieldId == 'section_pricing') {
      return _ProductEditorTab.pricing;
    }
    if (fieldId == 'section_visibility') {
      return _ProductEditorTab.visibility;
    }
    return _ProductEditorTab.details;
  }

  ({int percent, List<String> missing}) _profileCompletion() {
    final regular = _toDouble(_regularPrice.text);
    final sale = _toDouble(_salePrice.text);
    final checks = <({bool done, String missing})>[
      (done: _name.text.trim().isNotEmpty, missing: 'product name'),
      (done: regular > 0 || sale > 0, missing: 'price'),
    ];

    if (regular > 0 && sale > regular) {
      checks.add((
        done: false,
        missing: 'sale price lower than regular price',
      ));
    }

    final stockRaw = _stock.text.trim();
    if (_variantLines.isEmpty && stockRaw.isNotEmpty) {
      checks.add((
        done: int.tryParse(stockRaw) != null,
        missing: 'valid stock',
      ));
    }

    if (_variantLines.isNotEmpty) {
      checks.add((
        done: _variantLines.every((line) =>
            line.stock.text.trim().isNotEmpty &&
            int.tryParse(line.stock.text.trim()) != null),
        missing: 'variant stock',
      ));
      checks.add((
        done: _variantLines.every((line) {
          final variantRegular = _toDouble(line.regularPrice.text);
          final variantSale = _toDouble(line.salePrice.text);
          return variantRegular > 0 || variantSale > 0;
        }),
        missing: 'variant price',
      ));
    }

    final done = checks.where((c) => c.done).length;
    final percent = ((done / checks.length) * 100).round();
    return (
      percent: percent,
      missing: checks.where((c) => !c.done).map((c) => c.missing).toList(),
    );
  }

  Future<void> _setVisibility(bool next) async {
    if (next || !_visible) {
      setState(() => _visible = next);
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hide this product?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'It will no longer appear in your store. You can make it visible again later.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: const Text('Hide product'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed == true && mounted) {
      setState(() => _visible = false);
    }
  }

  ({String fieldId, String message})? _validateBeforeSave() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      return (fieldId: 'name', message: 'Product name is required.');
    }

    final stockRaw = _stock.text.trim();
    if (stockRaw.isNotEmpty && int.tryParse(stockRaw) == null) {
      return (fieldId: 'stock', message: 'Stock must be a whole number.');
    }

    final regular = _toDouble(_regularPrice.text);
    final sale = _toDouble(_salePrice.text);
    final cost = _toDouble(_costPrice.text);
    final primaryPrice = regular > 0 ? regular : sale;
    if (primaryPrice <= 0) {
      return (
        fieldId: 'regularPrice',
        message: 'Enter a regular price or sale price greater than 0.',
      );
    }
    if (regular > 0 && sale > regular) {
      return (
        fieldId: 'salePrice',
        message: 'Sale price cannot be greater than regular price.',
      );
    }
    if (_costPrice.text.trim().isNotEmpty && cost <= 0) {
      return (
        fieldId: 'costPrice',
        message: 'Cost of goods must be greater than 0 when provided.',
      );
    }

    for (var i = 0; i < _variantLines.length; i++) {
      final line = _variantLines[i];
      final variantLabel = line.optionSummary.trim().isEmpty
          ? 'variant ${i + 1}'
          : '"${line.optionSummary}"';
      if (line.options.isEmpty) {
        return (
          fieldId: 'variant_${i}_price',
          message: 'Variant ${i + 1} is missing selected attributes.',
        );
      }
      final variantStockRaw = line.stock.text.trim();
      if (variantStockRaw.isEmpty) {
        return (
          fieldId: 'variant_${i}_stock',
          message: 'Stock quantity for $variantLabel is required.',
        );
      }
      final variantStock = int.tryParse(variantStockRaw);
      if (variantStock == null) {
        return (
          fieldId: 'variant_${i}_stock',
          message: 'Stock quantity for $variantLabel must be a whole number.',
        );
      }
      if (variantStock < 0) {
        return (
          fieldId: 'variant_${i}_stock',
          message: 'Stock quantity for $variantLabel cannot be negative.',
        );
      }
      final variantRegular = _toDouble(line.regularPrice.text);
      final variantSale = _toDouble(line.salePrice.text);
      final variantCost = _toDouble(line.costPrice.text);
      final variantPrimaryPrice =
          variantRegular > 0 ? variantRegular : variantSale;
      if (variantPrimaryPrice <= 0) {
        return (
          fieldId: 'variant_${i}_price',
          message:
              'Add a price for $variantLabel. Tap the pencil icon to edit.',
        );
      }
      if (variantRegular > 0 && variantSale > variantRegular) {
        return (
          fieldId: 'variant_${i}_price',
          message:
              'Sale price for $variantLabel cannot be greater than regular price.',
        );
      }
      if (line.costPrice.text.trim().isNotEmpty && variantCost <= 0) {
        return (
          fieldId: 'variant_${i}_price',
          message:
              'Cost of goods for $variantLabel must be greater than 0 when provided.',
        );
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
    final inner =
        m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : m;
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
    required double cost,
    required String imageUrl,
  }) {
    final attrs = ref.read(dashboardAttributesProvider).valueOrNull ??
        const <ProductAttribute>[];
    final byName = <String, ProductAttribute>{
      for (final a in attrs) a.name.trim().toLowerCase(): a,
    };
    final attributeArray = <Map<String, dynamic>>[];
    for (final entry in line.options.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      final attr = byName[key.toLowerCase()];
      final attributeId = attr?.id.trim() ?? '';
      final attributeValueId = attr?.valueIdByLabel[value]?.trim() ?? '';
      if (attributeId.isEmpty || attributeValueId.isEmpty) {
        // Skip unresolved options (e.g. placeholder Default: Standard).
        continue;
      }
      attributeArray.add(<String, dynamic>{
        'attribute_id': attributeId,
        'attributeId': attributeId,
        'attribute_value_id': attributeValueId,
        'attributeValueId': attributeValueId,
        'name': key,
        'value': value,
        'attribute_name': key,
        'label': value,
      });
    }

    final payload = <String, dynamic>{
      'sku': line.sku.text.trim(),
      'stock': stock,
      'stockQuantity': stock,
      'stock_quantity': stock,
      'quantity': stock,
      'options': Map<String, String>.from(line.options),
      // Backend expects array-shaped attributes with ids.
      'attributes': attributeArray,
      'attribute_values': attributeArray,
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
    if (cost > 0) {
      payload['costPrice'] = cost;
      payload['cost_price'] = cost;
    } else if (line.costPrice.text.trim().isEmpty) {
      payload['costPrice'] = null;
      payload['cost_price'] = null;
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
      final direct =
          (payload['id'] ?? payload['productId'] ?? '').toString().trim();
      if (direct.isNotEmpty) return direct;
      final nested = payload['product'] ?? payload['item'] ?? payload['data'];
      if (nested is Map) {
        final id =
            (nested['id'] ?? nested['productId'] ?? '').toString().trim();
        if (id.isNotEmpty) return id;
      }
    }
    return fallbackId;
  }

  Future<void> _syncVariantsForProduct(ApiClient api, String productId) async {
    final syncLines = _variantLines
        .where((line) =>
            !(_variantLines.length > 1 && _isPlaceholderVariant(line)))
        .toList();

    final existingLines =
        syncLines.where((v) => (v.variantId ?? '').trim().isNotEmpty).toList();
    final currentIds = existingLines.map((v) => v.variantId!.trim()).toSet();
    final removedIds = _loadedVariantIds.difference(currentIds);

    for (final removedId in removedIds) {
      await api.deleteProductVariant(productId, removedId);
    }

    for (final line in syncLines) {
      final stock = int.tryParse(line.stock.text.trim()) ?? 0;
      final regular = _toDouble(line.regularPrice.text);
      final sale = _toDouble(line.salePrice.text);
      final cost = _toDouble(line.costPrice.text);
      final imageUrl = await _resolveVariantImageUrl(api, line.imageUrl.text);
      final body = _buildVariantPayload(
        line,
        stock: stock,
        regular: regular,
        sale: sale,
        cost: cost,
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
        final fromDetails = _formatApiErrorDetails(data);
        if (fromDetails != null) return fromDetails;
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        final err = data['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
        if (err is String && err.isNotEmpty) return err;
      }
      if (e.message != null && e.message!.isNotEmpty) return e.message!;
    }
    return e.toString();
  }

  /// Pulls a friendly multi-line description out of a structured backend
  /// error response of the shape:
  ///
  /// ```json
  /// {
  ///   "success": false,
  ///   "error": {
  ///     "code": "VALIDATION_ERROR",
  ///     "message": "Validation error",
  ///     "details": [
  ///       {"field": "attributes", "message": "Invalid input: expected array, received object"}
  ///     ]
  ///   }
  /// }
  /// ```
  ///
  /// Returns `null` when no details could be parsed.
  String? _formatApiErrorDetails(Map data) {
    final err = data['error'];
    if (err is! Map) return null;
    final details = err['details'];
    if (details is! List || details.isEmpty) return null;

    final headline =
        (err['message'] is String && (err['message'] as String).isNotEmpty)
            ? err['message'] as String
            : 'Validation error';

    final lines = <String>[];
    for (final entry in details) {
      if (entry is! Map) continue;
      final field = (entry['field'] ?? entry['path'] ?? '').toString().trim();
      final message =
          (entry['message'] ?? entry['error'] ?? '').toString().trim();
      if (field.isEmpty && message.isEmpty) continue;
      if (field.isEmpty) {
        lines.add('• $message');
      } else if (message.isEmpty) {
        lines.add('• $field');
      } else {
        lines.add('• $field — $message');
      }
    }
    if (lines.isEmpty) return null;
    if (lines.length == 1) {
      // Inline form when there's only one issue, e.g.
      // "Validation error: attributes — Invalid input: expected array, received object"
      return '$headline: ${lines.first.replaceFirst('• ', '')}';
    }
    return '$headline:\n${lines.join('\n')}';
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
    required double cost,
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
    if (cost > 0) {
      payload['costPrice'] = cost;
      payload['cost_price'] = cost;
    } else if (_costPrice.text.trim().isEmpty) {
      payload['costPrice'] = null;
      payload['cost_price'] = null;
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
    final validation = _validateBeforeSave();
    if (validation != null) {
      setState(() {
        _errorFieldId = validation.fieldId;
        _activeEditorTab = _tabForField(validation.fieldId);
      });
      _scrollToFieldKey(validation.fieldId);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(validation.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      return;
    }
    setState(() => _errorFieldId = null);
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
      final cost = _toDouble(_costPrice.text);
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
        cost: cost,
        stockVal: stockVal,
        imageUrls: imageUrls,
        variants: const [],
        categoryId: categoryId,
      );

      final isNew = widget.initialSku == null;
      final updateKey = _productApiId ?? widget.initialSku;
      if (!isNew && (updateKey == null || updateKey.isEmpty)) {
        throw StateError(
            'Missing product id for update. Reload the product and try again.');
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
        throw StateError(
            'Product saved, but missing product id for variant sync.');
      }
      await _syncVariantsForProduct(api, persistedProductId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNew ? 'Product created' : 'Product updated')),
      );
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      _showSaveErrorSnack(_formatSaveError(e));
    } catch (e) {
      if (!mounted) return;
      _showSaveErrorSnack(_formatSaveError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSaveErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
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
    final choice = await showModalBottomSheet<String>(
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
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.collections_outlined),
              title: const Text('Choose from media library'),
              onTap: () => Navigator.pop(ctx, 'library'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'library') {
      final url = await MediaLibraryScreen.pick(context);
      if (url == null || url.trim().isEmpty || !mounted) return;
      setState(() {
        if (_totalPhotoSlotsUsed < 5) {
          _remoteImageUrls.add(normalizeStoreMediaUrl(url));
        }
      });
      return;
    }
    await _pickPhoto(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
  }

  @override
  void initState() {
    super.initState();
    _loadRefreshHintPref();
    final isNew = widget.initialSku == null;
    _category = '';
    _name = TextEditingController();
    _description = TextEditingController();
    _regularPrice = TextEditingController();
    _salePrice = TextEditingController();
    _costPrice = TextEditingController();
    _sku = TextEditingController(text: widget.initialSku ?? '');
    _stock = TextEditingController();
    _remoteImageUrls.clear();
    _localImagePaths.clear();
    _productApiId = null;
    _initVariantLines();
    if (!isNew) {
      _loadLiveProductIfEditing();
    }
  }

  List<String> _dropdownCategoryNames(List<CategoryEntry> categories) {
    final names = categories
        .map((c) => c.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final seen = <String>{};
    final unique = <String>[];
    for (final n in names) {
      final key = n.toLowerCase();
      if (seen.add(key)) unique.add(n);
    }
    unique.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    final cur = _category.trim();
    if (cur.isNotEmpty &&
        !unique.any((n) => n.toLowerCase() == cur.toLowerCase())) {
      unique.insert(0, cur);
    }
    return unique;
  }

  void _syncCategoryAfterCategoriesLoad(List<CategoryEntry> list) {
    final names = _dropdownCategoryNames(list);
    if (names.isEmpty) return;
    final desired = _category.trim();
    if (desired.isEmpty) {
      setState(() => _category = names.first);
      return;
    }
    String? match;
    for (final n in names) {
      if (n.toLowerCase() == desired.toLowerCase()) {
        match = n;
        break;
      }
    }
    if (match != null && match != _category) {
      final canonical = match;
      setState(() => _category = canonical);
    }
  }

  Future<void> _loadRefreshHintPref() async {
    final seen =
        await ref.read(tokenStorageProvider).getProductDetailRefreshHintSeen();
    if (!mounted) return;
    setState(() {
      _hasSeenRefreshHint = seen;
      _refreshHintPrefLoaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _regularPrice.dispose();
    _salePrice.dispose();
    _costPrice.dispose();
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
    final categoriesAsync = ref.watch(categoriesListProvider);
    ref.listen(categoriesListProvider, (_, next) {
      next.whenData(_syncCategoryAfterCategoriesLoad);
    });
    final categories = categoriesAsync.valueOrNull ?? const <CategoryEntry>[];
    final categoryNames = _dropdownCategoryNames(categories);
    CategoryEntry? selectedCategory;
    for (final c in categories) {
      if (c.name.trim().toLowerCase() == _category.trim().toLowerCase()) {
        selectedCategory = c;
        break;
      }
    }
    final saleDiscountLabel = _discountLabel();
    final publishLabel = _publishActionLabel(isNew: isNew);
    final primaryActionLabel = _primaryActionLabel(isNew: isNew);
    final completion = _profileCompletion();
    final canPublish = completion.percent == 100;
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
              top: BorderSide(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveLocalDraft,
                  icon: const Icon(Icons.drafts_outlined, size: 18),
                  label: const Text('Save draft'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving ||
                          (_activeEditorTab == _ProductEditorTab.visibility &&
                              !canPublish)
                      ? null
                      : _handlePrimaryAction,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_primaryActionIcon(), size: 18),
                  label: Text(primaryActionLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.primaryDark.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
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
                    onPressed: _isLoadingRemote
                        ? null
                        : () => _loadLiveProductIfEditing(forceRefresh: true),
                    icon: _isLoadingRemote
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                if (_activeEditorTab == _ProductEditorTab.visibility)
                  TextButton(
                    onPressed: _isSaving || !canPublish ? null : _saveProduct,
                    child: Text(
                      publishLabel,
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
                  _ProfileCompletionPanel(
                    percent: completion.percent,
                    missing: completion.missing,
                  ),
                  const SizedBox(height: 14),
                  _EditorTabs(
                    activeTab: _activeEditorTab,
                    onChanged: (tab) => setState(() => _activeEditorTab = tab),
                  ),
                  const SizedBox(height: 14),
                  if (_activeEditorTab == _ProductEditorTab.details) ...[
                    _MediaSectionHeader(
                      key: _keyFor('section_media'),
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
                      if (_refreshHintPrefLoaded && !_hasSeenRefreshHint) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.swipe_down_alt_rounded,
                                  size: 18, color: theme.colorScheme.primary),
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
                                  await ref
                                      .read(tokenStorageProvider)
                                      .saveProductDetailRefreshHintSeen(true);
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
                                    onRemove: () => setState(
                                        () => _remoteImageUrls.removeAt(e.key)),
                                  ),
                                ),
                              ),
                          ..._localImagePaths.asMap().entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: _MediaThumb(
                                    imageUrl: '',
                                    localImagePath: e.value,
                                    onRemove: () => setState(
                                        () => _localImagePaths.removeAt(e.key)),
                                  ),
                                ),
                              ),
                          _AddPhotoButton(onTap: _showAddPhotoSourceSheet),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    KeyedSubtree(
                      key: _keyFor('section_details'),
                      child: _CardShell(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            KeyedSubtree(
                              key: _keyFor('name'),
                              child: _LabeledField(
                                label: 'Product Name',
                                example: _kProductNameExample,
                                child: TextField(
                                  controller: _name,
                                  onChanged: (_) => _clearErrorFor('name'),
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  decoration: _fieldDeco(
                                    theme,
                                    hint: 'e.g. Maize Flour 2kg',
                                    isInvalid: _isInvalid('name'),
                                  ),
                                ),
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
                            const SizedBox(height: 4),
                            Text(
                              'Example: $_kProductDescriptionExample',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                                fontStyle: FontStyle.italic,
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Format',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _FmtIcon(
                                            icon: Icons.format_bold,
                                            tooltip: 'Bold'),
                                        _FmtIcon(
                                            icon: Icons.format_italic,
                                            tooltip: 'Italic'),
                                        _FmtIcon(
                                            icon: Icons.format_list_bulleted,
                                            tooltip: 'Bullet list'),
                                        _FmtIcon(
                                            icon: Icons.link_rounded,
                                            tooltip: 'Insert link'),
                                      ],
                                    ),
                                  ),
                                  TextField(
                                    controller: _description,
                                    maxLines: 5,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(height: 1.45),
                                    decoration: InputDecoration(
                                      hintText:
                                          'e.g. Grade 1 maize flour, 2 kg bag. Milled locally…',
                                      hintStyle: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.75),
                                        height: 1.35,
                                      ),
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
                            if (categoriesAsync.isLoading)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 4,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                            if (categoriesAsync.hasError)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Could not load categories.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => ref.invalidate(
                                              categoriesListProvider),
                                          icon: const Icon(Icons.refresh_rounded,
                                              size: 18),
                                          label: const Text('Retry'),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () async {
                                            await context.push('/categories');
                                            ref.invalidate(
                                                categoriesListProvider);
                                          },
                                          icon: const Icon(
                                              Icons.category_outlined,
                                              size: 18),
                                          label:
                                              const Text('Manage categories'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            if (!categoriesAsync.isLoading &&
                                !categoriesAsync.hasError &&
                                categoryNames.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'No categories yet. Create one to organize products on your storefront.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await context.push('/categories');
                                        ref.invalidate(categoriesListProvider);
                                      },
                                      icon: const Icon(Icons.add_rounded,
                                          size: 20),
                                      label: const Text('Add category'),
                                    ),
                                  ],
                                ),
                              ),
                            if (!categoriesAsync.isLoading &&
                                !categoriesAsync.hasError &&
                                categoryNames.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: () {
                                      final cur = _category.trim();
                                      if (cur.isEmpty) return null;
                                      for (final n in categoryNames) {
                                        if (n.toLowerCase() ==
                                            cur.toLowerCase()) {
                                          return n;
                                        }
                                      }
                                      return null;
                                    }(),
                                    isExpanded: true,
                                    icon: Icon(Icons.expand_more,
                                        color: theme
                                            .colorScheme.onSurfaceVariant),
                                    hint: Text(
                                      categoryNames.isEmpty
                                          ? 'No categories yet'
                                          : 'Select category',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                    items: categoryNames
                                        .map((c) => DropdownMenuItem(
                                            value: c, child: Text(c)))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _category = v ?? _category),
                                  ),
                                ),
                              ),
                            if (!categoriesAsync.isLoading &&
                                !categoriesAsync.hasError &&
                                categoryNames.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await context.push('/categories');
                                    ref.invalidate(categoriesListProvider);
                                  },
                                  icon: Icon(
                                    Icons.category_outlined,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  label: const Text('Manage categories'),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              categoriesAsync.isLoading
                                  ? 'Loading categories…'
                                  : categoriesAsync.hasError
                                      ? 'Fix the load error above or open Categories to continue.'
                                      : categories.isEmpty
                                          ? 'Create categories so shoppers can browse by group.'
                                          : selectedCategory == null
                                              ? '${categories.length} categories available. Choose the closest match for storefront grouping.'
                                              : '${selectedCategory.name} · ${selectedCategory.productCount} products. Subcategories appear nested when available.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_activeEditorTab == _ProductEditorTab.pricing) ...[
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: _keyFor('section_inventory'),
                      child: _CardShell(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Inventory',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                      decoration: _inventoryFieldDeco(theme,
                                          hint: 'Auto if empty'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: KeyedSubtree(
                                    key: _keyFor('stock'),
                                    child: _LabeledField(
                                      label: 'Stock',
                                      child: TextField(
                                        controller: _stock,
                                        keyboardType: TextInputType.number,
                                        enabled: !hasVariants,
                                        onChanged: (_) =>
                                            _clearErrorFor('stock'),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                        decoration: _inventoryFieldDeco(
                                          theme,
                                          hint: hasVariants
                                              ? 'Managed by variants'
                                              : '0',
                                          isInvalid: _isInvalid('stock'),
                                          locked: hasVariants,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (hasVariants) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.lock_outline_rounded,
                                      size: 14,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Stock is read-only here because variant quantities determine total availability.',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      key: _keyFor('section_pricing'),
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
                            key: _keyFor('regularPrice'),
                            label: 'REGULAR PRICE',
                            controller: _regularPrice,
                            accent: theme.colorScheme.onSurfaceVariant,
                            hintText: '0',
                            isInvalid: _isInvalid('regularPrice'),
                            onChanged: (_) {
                              _clearErrorFor('regularPrice');
                              _clearErrorFor('salePrice');
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PriceField(
                                key: _keyFor('salePrice'),
                                label: 'SALE PRICE',
                                controller: _salePrice,
                                accent: AppTheme.primary,
                                hintText: '—',
                                isInvalid: _isInvalid('salePrice'),
                                onChanged: (_) {
                                  _clearErrorFor('regularPrice');
                                  _clearErrorFor('salePrice');
                                  setState(() {});
                                },
                              ),
                              if (saleDiscountLabel != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      saleDiscountLabel,
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PriceField(
                      key: _keyFor('costPrice'),
                      label: 'COST OF GOODS (OPTIONAL)',
                      controller: _costPrice,
                      accent: const Color(0xFF8A4B00),
                      hintText: '0',
                      isInvalid: _isInvalid('costPrice'),
                      onChanged: (_) {
                        _clearErrorFor('costPrice');
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Used for profit and margin reporting. Customers will not see this.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_activeEditorTab == _ProductEditorTab.variants) ...[
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
                              child: Text('$error',
                                  style: theme.textTheme.bodySmall),
                            ),
                          ),
                        ],
                      AsyncData(:final value) => [
                          KeyedSubtree(
                            key: _keyFor('section_variants'),
                            child: _CardShell(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Product options',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
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
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
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
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.layers_outlined,
                                            color: AppTheme.primaryDark,
                                            size: 22),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Text(
                                        'No product options yet. Tap "Add variant" to create one.',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    )
                                  else
                                    ..._variantLines.asMap().entries.map((e) {
                                      final i = e.key;
                                      final line = e.value;
                                      final stockId = 'variant_${i}_stock';
                                      final priceId = 'variant_${i}_price';
                                      final invalidStock = _isInvalid(stockId);
                                      final invalidPrice = _isInvalid(priceId);
                                      String? rowError;
                                      if (invalidStock) {
                                        rowError =
                                            'Stock is required for this variant.';
                                      } else if (invalidPrice) {
                                        rowError =
                                            'Price is required. Tap the pencil icon to edit.';
                                      }
                                      return Padding(
                                        key: _keyFor('variant_$i'),
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _VariantRowTile(
                                          line: line,
                                          onEdit: () {
                                            _clearErrorFor(priceId);
                                            _openEditVariantSheet(line);
                                          },
                                          onRemove: () {
                                            _clearErrorFor(stockId);
                                            _clearErrorFor(priceId);
                                            setState(() {
                                              line.dispose();
                                              _variantLines.removeAt(i);
                                            });
                                          },
                                          invalidStock: invalidStock,
                                          invalidPrice: invalidPrice,
                                          errorMessage: rowError,
                                          onStockChanged: (_) =>
                                              _clearErrorFor(stockId),
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: () {
                                      final async =
                                          ref.read(dashboardAttributesProvider);
                                      final all =
                                          async.valueOrNull ?? [];

                                      if (async.isLoading) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            behavior:
                                                SnackBarBehavior.floating,
                                            content: Text(
                                              'Still loading attributes. Wait a moment, then tap Add variant again.',
                                            ),
                                          ),
                                        );
                                        _scrollVariantsSectionIntoView();
                                        return;
                                      }
                                      if (async.hasError) {
                                        _showVariantSetupRequired(
                                          'Could not load product attributes: ${async.error}',
                                        );
                                        return;
                                      }
                                      if (all.isEmpty) {
                                        _showVariantSetupRequired(
                                          'Add at least one product attribute — for example Size or Color — before you add variants. Open Attributes from the catalog or settings.',
                                        );
                                        return;
                                      }
                                      final usable = all
                                          .where((a) =>
                                              a.values.isNotEmpty)
                                          .toList();
                                      if (usable.isEmpty) {
                                        _showVariantSetupRequired(
                                          'Each attribute needs option values — for example Small, Medium, Large for Size. Open Manage attributes, edit the attribute, and add options.',
                                        );
                                        return;
                                      }
                                      _openAddVariantSheet();
                                    },
                                    icon: const Icon(Icons.add, size: 20),
                                    label: Text(
                                      'Add variant',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primaryDark,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      _ => [
                          _CardShell(child: const SizedBox.shrink()),
                        ],
                    },
                  ],
                  if (_activeEditorTab == _ProductEditorTab.visibility) ...[
                    const SizedBox(height: 16),
                    Container(
                      key: _keyFor('section_visibility'),
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
                            child: Icon(Icons.visibility_outlined,
                                color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Product Visibility',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
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
                            onChanged: _setVisibility,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _variantPricingInputDecoration(
    ThemeData theme, {
    required String labelText,
    String? helperText,
    String? prefixText,
    bool isInvalid = false,
  }) {
    final cs = theme.colorScheme;
    final errorColor = cs.error;
    final idleOutline = cs.outlineVariant.withValues(alpha: 0.55);
    final enabled = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: isInvalid ? errorColor : idleOutline,
        width: isInvalid ? 1.5 : 1,
      ),
    );
    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: isInvalid ? errorColor : cs.primary,
        width: 1.5,
      ),
    );
    return InputDecoration(
      labelText: labelText,
      helperText: helperText,
      prefixText: prefixText,
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : cs.surfaceContainerLow,
      border: enabled,
      enabledBorder: enabled,
      focusedBorder: focused,
      disabledBorder: enabled,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
    );
  }

  InputDecoration _fieldDeco(ThemeData theme,
      {String? hint, bool isInvalid = false}) {
    final errorColor = theme.colorScheme.error;
    final idleOutline = theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: isInvalid
          ? BorderSide(color: errorColor, width: 1.5)
          : BorderSide(color: idleOutline, width: 1),
    );
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainerLow,
      border: enabledBorder,
      enabledBorder: enabledBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  /// Stronger contrast vs `_CardShell` so SKU/stock read as inputs, not bare background.
  InputDecoration _inventoryFieldDeco(
    ThemeData theme, {
    String? hint,
    bool isInvalid = false,
    bool locked = false,
  }) {
    final errorColor = theme.colorScheme.error;
    final idle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: isInvalid
            ? errorColor
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        width: isInvalid ? 1.5 : 1,
      ),
    );
    return InputDecoration(
      hintText: hint,
      suffixIcon: locked
          ? Tooltip(
              message: 'Stock is calculated from variants',
              child: Icon(Icons.lock_outline_rounded,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            )
          : null,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
      ),
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainerHighest,
      border: idle,
      enabledBorder: idle,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _ProfileCompletionPanel extends StatelessWidget {
  const _ProfileCompletionPanel({
    required this.percent,
    required this.missing,
  });

  final int percent;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missingText = missing.isEmpty
        ? 'Product complete — ready to publish'
        : 'Missing: ${missing.take(2).join(', ')}${missing.length > 2 ? ' — add to improve conversions' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Product complete',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 4,
            backgroundColor: AppTheme.surfaceContainerLow,
            color: AppTheme.primary,
          ),
        ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.circle, size: 8, color: Color(0xFFC76A00)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    missingText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A4B00),
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EditorTabs extends StatelessWidget {
  const _EditorTabs({
    required this.activeTab,
    required this.onChanged,
  });

  final _ProductEditorTab activeTab;
  final ValueChanged<_ProductEditorTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit section',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final tab in _ProductEditorTab.values) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _EditorTabButton(
                    tab: tab,
                    selected: activeTab == tab,
                    onTap: () => onChanged(tab),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorTabButton extends StatelessWidget {
  const _EditorTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _ProductEditorTab tab;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    return switch (tab) {
      _ProductEditorTab.details => Icons.edit_note_rounded,
      _ProductEditorTab.pricing => Icons.sell_outlined,
      _ProductEditorTab.variants => Icons.tune_rounded,
      _ProductEditorTab.visibility => Icons.visibility_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppTheme.primaryDark;
    return Material(
      color: selected ? AppTheme.primary : AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minWidth: 104),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : AppTheme.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                tab.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: fg,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: fg.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaSectionHeader extends StatelessWidget {
  const _MediaSectionHeader({super.key, required this.title, this.trailing});

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
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
  const _LabeledField({
    required this.label,
    required this.child,
    this.example,
  });

  final String label;
  final Widget child;
  final String? example;

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
        if (example != null) ...[
          const SizedBox(height: 4),
          Text(
            'Example: $example',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    super.key,
    required this.label,
    required this.controller,
    required this.accent,
    this.hintText,
    this.isInvalid = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Color accent;
  final String? hintText;
  final bool isInvalid;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isInvalid ? errorColor : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isInvalid
                ? errorColor.withValues(alpha: 0.06)
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border:
                isInvalid ? Border.all(color: errorColor, width: 1.5) : null,
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
            onChanged: onChanged,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              prefixText: 'KES ',
              prefixStyle: theme.textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _FmtIcon extends StatelessWidget {
  const _FmtIcon({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      tooltip: tooltip,
      icon: Icon(icon,
          size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
        if (u.host == 'auth.dukanest.com' &&
            u.path.startsWith('/storage/v1/object/public/')) {
          final base = Uri.parse(AppConfig.publicApiBaseUrl);
          return u
              .replace(
                scheme: base.scheme,
                host: base.host,
                port: base.hasPort ? base.port : null,
              )
              .toString();
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              child: const Icon(
                                  Icons.image_not_supported_outlined),
                            ),
                          );
                        }
                        return Container(
                          width: 128,
                          height: 128,
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
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
                  child: Icon(Icons.close,
                      size: 16, color: Theme.of(context).colorScheme.error),
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
    this.invalidStock = false,
    this.invalidPrice = false,
    this.errorMessage,
    this.onStockChanged,
  });

  final _VariantLine line;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final bool invalidStock;
  final bool invalidPrice;
  final String? errorMessage;
  final ValueChanged<String>? onStockChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = invalidStock || invalidPrice;
    final errorColor = theme.colorScheme.error;
    return Container(
      decoration: BoxDecoration(
        color: hasError
            ? errorColor.withValues(alpha: 0.04)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: hasError
            ? Border.all(color: errorColor, width: 1.5)
            : const Border(
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
                    color: hasError ? errorColor : AppTheme.primaryDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon:
                    Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                tooltip: 'Edit variant details',
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded,
                    color: theme.colorScheme.error),
                tooltip: 'Remove variant',
              ),
            ],
          ),
          if (hasError && (errorMessage?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: errorColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (line.regularPrice.text.trim().isNotEmpty)
                _VariantChip(
                    label: 'Price: KES ${line.regularPrice.text.trim()}'),
              if (line.salePrice.text.trim().isNotEmpty)
                _VariantChip(label: 'Sale: KES ${line.salePrice.text.trim()}'),
              if (line.costPrice.text.trim().isNotEmpty)
                _VariantChip(label: 'COG: KES ${line.costPrice.text.trim()}'),
              if (line.imageUrl.text.trim().isNotEmpty)
                _VariantImagePreview(imagePathOrUrl: line.imageUrl.text.trim()),
            ],
          ),
          if (line.regularPrice.text.trim().isNotEmpty ||
              line.salePrice.text.trim().isNotEmpty ||
              line.costPrice.text.trim().isNotEmpty ||
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                        color: invalidStock
                            ? errorColor
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: line.stock,
                      keyboardType: TextInputType.number,
                      onChanged: onStockChanged,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      decoration:
                          _variantFieldDeco(theme, isInvalid: invalidStock),
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

  static InputDecoration _variantFieldDeco(ThemeData theme,
      {bool isInvalid = false}) {
    final errorColor = theme.colorScheme.error;
    final idle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: isInvalid
            ? errorColor
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        width: isInvalid ? 1.5 : 1,
      ),
    );
    return InputDecoration(
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainerHighest,
      border: idle,
      enabledBorder: idle,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : theme.colorScheme.primary,
          width: 1.5,
        ),
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
    final isRemote = imagePathOrUrl.startsWith('http://') ||
        imagePathOrUrl.startsWith('https://');

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
            border:
                Border.all(color: theme.colorScheme.outlineVariant, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                  color: AppTheme.primary, size: 28),
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
