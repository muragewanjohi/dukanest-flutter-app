import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../../../core/widgets/illustrated_empty_state.dart';
import '../../../core/widgets/shimmer_list_loader.dart';
import '../data/attributes_repository.dart';
import '../data/categories_repository.dart';
import '../providers/attributes_list_provider.dart';
import '../providers/categories_list_provider.dart';

/// Product catalog — Stitch: "Product Catalog (with Quick Actions)"
/// Project DukaNest Tenant App Plan, screen 62433aa938834d55bc36fd5d1a134124.
typedef ProductListItem = ({
  String? id,
  String name,
  String meta,
  String status,
  bool active,
  bool isDemo,
  String stock,
  bool stockWarn,
  String price,
  String sku,
  String imageUrl,
  bool accentBar,
});

enum _ProductsSortOption {
  newest('Newest'),
  lowStock('Low Stock'),
  highestPrice('Highest Price'),
  lowestPrice('Lowest Price');

  const _ProductsSortOption(this.label);

  final String label;
}

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  static const Duration _productsCacheTtl = Duration(minutes: 5);
  static final Map<
      String,
      ({
        List<ProductListItem> products,
        int page,
        int pageSize,
        int totalPages,
        int totalItems,
        DateTime savedAt,
      })> _productsCache = {};

  static const _kIconFacebook =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCu39UMZ478Jp3AgkDfI97OE621gJthMTC3sW2JhVIOk2NdvshMKWOfMbess2O_geyGWG6uv9RDAqGd91aP_o68_XsPW_glXY_KoTYW52hpwIR6Ggx1FGOBY1GqLoqB0PwrihlUel4Cl8b7dPWftTTAvXLBUIxcswkyk6L_0gWHxoeeqjubEXBgC5YRnpXN8KhazuiarZ3uFPBARCsaqyOWZqZYm3rsQ3y_U4YcIBvpsIWgyRFPfM--LQTSYu7GsG8EfLS0ARIsIsVQ';
  static const _kIconWhatsApp =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDR8_J2lm2Hd76_zE0gIVafee45tK1stTJq3ZJs-peKpz6Ygn4q7pvHLmpL_NMC-d71kg_f6J7qjLkYEJ_eHRccmRuKRRiaijw8ZVnsSnlYGwI_64LDzEZ589ov47okTh9PkSvBhlkCq-NhBSLQaei4KXwTyRifnu8EwDGnzOQGIJbXDurz7TvbJGQ7nLJCw_K4pMctXB0q8AL33XVkUog5KKrbB81Xam-6z-Xd-D608wnwF9EWz2wNxlZ21USniP_WzrpVwSd2dmGE';
  static const _kIconInstagram =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDh9zDpcWzuavgdI-XcRnz3k0la38sFTcPOJaWBgLpx7NKvZL74-mScPC8LFTF0NdpvJOSoD0NVW7APAtoCsf19QfAjrET99VG71XS2EFa-zTgZtM0gQaGFTpbgqfbsfQmTTIAFTUQrAthLICUd2kT-bagJ19ztBvK79N5q5J9Poyiy245iBOR2fsNG1a2Bri5dJ_BmFL2kHCmdWz9kndX8_fqhO9AlTrs8k6vPB_nws3jdrkFxJz0XU-7wU7UzgPfpyJ9qBCPA1bLh';

  static String _shareUrlFor(String sku) =>
      'https://dukanest.app/p/${Uri.encodeComponent(sku)}';

  bool _isLoading = true;
  bool _isLiveData = false;
  String? _errorMessage;
  List<ProductListItem> _products = const [];
  List<ProductListItem> _allProducts = const [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalPages = 1;
  int _totalItems = 0;
  DateTime? _lastSyncedAt;
  bool _hasSeenRefreshHint = false;
  bool _storeStructureExpanded = false;
  bool _hideDemoProducts = false;
  _ProductsSortOption _sortOption = _ProductsSortOption.newest;
  Set<String> _selectedCategoryNames = {};
  Map<String, Set<String>> _selectedAttributeValuesById = {};

  String _cacheKeyFor({required int page}) {
    final q = _searchController.text.trim().toLowerCase();
    return '$page|$_pageSize|$q';
  }

  void _invalidateProductsCache() {
    _productsCache.clear();
  }

  String _lastUpdatedLabel() {
    final at = _lastSyncedAt;
    if (at == null) return 'Not synced yet';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated ${diff.inDays}d ago';
  }

  @override
  void initState() {
    super.initState();
    _loadRefreshHintPref();
    _loadProducts();
  }

  Future<void> _loadRefreshHintPref() async {
    final seen =
        await ref.read(tokenStorageProvider).getProductsListRefreshHintSeen();
    if (!mounted) return;
    setState(() => _hasSeenRefreshHint = seen);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(dynamic value, String? currencyCode) {
    if (value is num) {
      final code =
          (currencyCode == null || currencyCode.isEmpty) ? 'KES' : currencyCode;
      return '$code ${value.toStringAsFixed(2)}';
    }
    if (value is String && value.trim().isNotEmpty) return value;
    return 'KES 0.00';
  }

  String _pickImageUrl(Map<String, dynamic> p) {
    String normalize(dynamic raw) {
      if (raw is! String) return '';
      final s = raw.trim();
      if (s.isEmpty) return '';
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
      if (s.startsWith('//')) return 'https:$s';
      final base = AppConfig.publicApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
      if (s.startsWith('/')) return '$base$s';
      return '$base/$s';
    }

    String fromMap(Map<String, dynamic> m) {
      final cands = [
        m['url'],
        m['src'],
        m['imageUrl'],
        m['image_url'],
        m['thumbnail'],
        m['thumbnail_url'],
        m['publicUrl'],
        m['public_url'],
      ];
      for (final c in cands) {
        final n = normalize(c);
        if (n.isNotEmpty) return n;
      }
      return '';
    }

    final direct = [
      p['image'],
      p['imageUrl'],
      p['image_url'],
      p['thumbnail'],
      p['thumbnailUrl'],
      p['thumbnail_url'],
      p['featuredImage'],
      p['featured_image'],
    ];
    for (final v in direct) {
      if (v is Map) {
        final nested = fromMap(Map<String, dynamic>.from(v));
        if (nested.isNotEmpty) return nested;
      }
      final n = normalize(v);
      if (n.isNotEmpty) return n;
    }
    final imgs = p['images'] ?? p['media'] ?? p['gallery'];
    if (imgs is List) {
      for (final e in imgs) {
        final n = normalize(e);
        if (n.isNotEmpty) return n;
        if (e is Map) {
          final nested = fromMap(Map<String, dynamic>.from(e));
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return '';
  }

  Future<void> _loadProducts(
      {int? pageOverride, bool forceRefresh = false}) async {
    final pageToLoad = pageOverride ?? _currentPage;
    final cacheKey = _cacheKeyFor(page: pageToLoad);
    if (!forceRefresh) {
      final cached = _productsCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.savedAt) < _productsCacheTtl) {
        final filtered = _applyLocalFilters(cached.products);
        setState(() {
          _allProducts = cached.products;
          _products = filtered;
          _currentPage = cached.page;
          _pageSize = cached.pageSize;
          _totalPages = cached.totalPages;
          _totalItems = cached.totalItems;
          _isLiveData = true;
          _isLoading = false;
          _errorMessage = null;
          _lastSyncedAt = cached.savedAt;
        });
        return;
      }
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.getProducts(
        page: pageToLoad,
        limit: _pageSize,
        search: _searchController.text.trim(),
      );
      if (!response.success || response.data == null) {
        throw StateError(response.error?.message ?? 'Failed to load products');
      }
      final payload = response.data;
      final items = payload is Map<String, dynamic>
          ? payload['items'] ?? payload['products'] ?? payload['data']
          : payload;
      if (items is! List) {
        throw const FormatException('Invalid products response');
      }
      final mapped = items.whereType<Map>().map((raw) {
        final p = Map<String, dynamic>.from(raw);
        final apiId = p['id']?.toString();
        final sku = (p['sku'] ?? p['code'] ?? p['id'] ?? 'UNKNOWN').toString();
        final name = (p['name'] ?? p['title'] ?? 'Product').toString();
        final category =
            (p['categoryName'] ?? p['category'] ?? 'General').toString();
        final stockValue =
            p['stock'] ?? p['stockQuantity'] ?? p['quantity'] ?? 0;
        final stockNum = stockValue is num
            ? stockValue.toInt()
            : int.tryParse(stockValue.toString()) ?? 0;
        final stockWarn = stockNum > 0 && stockNum <= 5;
        final statusRaw = (p['status'] ?? '').toString().toLowerCase();
        final active = statusRaw.isEmpty
            ? (p['isActive'] == true || p['active'] == true)
            : statusRaw == 'active' || statusRaw == 'enabled';
        final isDemo = p['isDemo'] == true ||
            p['demo'] == true ||
            (p['source']?.toString().toLowerCase() == 'demo');
        final status = active ? 'Active' : 'Inactive';
        final currencyCode =
            (p['currencyCode'] ?? p['currency_code'])?.toString();
        final price = _formatCurrency(
          p['salePrice'] ?? p['price'] ?? p['regularPrice'] ?? p['amount'],
          currencyCode,
        );
        final imageUrl = _pickImageUrl(p);
        return (
          id: apiId,
          name: name,
          meta: '$category • SKU: $sku',
          status: status,
          active: active,
          isDemo: isDemo,
          stock: stockWarn ? 'Low ($stockNum)' : '$stockNum units',
          stockWarn: stockWarn,
          price: price,
          sku: sku,
          imageUrl: imageUrl,
          accentBar: false,
        );
      }).toList();

      _productsCache[cacheKey] = (
        products: mapped,
        page: response.pagination?.page ?? pageToLoad,
        pageSize: response.pagination?.limit ?? _pageSize,
        totalPages: response.pagination?.totalPages ?? 1,
        totalItems: response.pagination?.total ?? mapped.length,
        savedAt: DateTime.now(),
      );

      setState(() {
        _allProducts = mapped;
        _products = _applyLocalFilters(mapped);
        _currentPage = response.pagination?.page ?? pageToLoad;
        _pageSize = response.pagination?.limit ?? _pageSize;
        _totalPages = response.pagination?.totalPages ?? 1;
        _totalItems = response.pagination?.total ?? mapped.length;
        _isLiveData = true;
        _isLoading = false;
        _lastSyncedAt = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _allProducts = const [];
        _products = _applyLocalFilters(_allProducts);
        _currentPage = 1;
        _totalPages = 1;
        _totalItems = _products.length;
        _isLiveData = false;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _goPrevPage() {
    if (_isLoading || _currentPage <= 1) return;
    _loadProducts(pageOverride: _currentPage - 1);
  }

  void _goNextPage() {
    if (_isLoading || _currentPage >= _totalPages) return;
    _loadProducts(pageOverride: _currentPage + 1);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadProducts(pageOverride: 1),
    );
  }

  String _categoryFor(ProductListItem product) =>
      product.meta.split('•').first.trim();

  int _stockNumber(ProductListItem product) {
    final match = RegExp(r'\d+').firstMatch(product.stock);
    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  }

  double _priceNumber(ProductListItem product) {
    final normalized = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? 0;
  }

  List<ProductListItem> _applyLocalFilters(List<ProductListItem> items) {
    final filtered = items.where((product) {
      if (_hideDemoProducts && product.isDemo) {
        return false;
      }
      if (_selectedCategoryNames.isNotEmpty) {
        final category = _categoryFor(product);
        if (!_selectedCategoryNames.contains(category)) return false;
      }
      if (_selectedAttributeValuesById.isNotEmpty) {
        final searchable =
            '${product.name} ${product.meta} ${product.sku}'.toLowerCase();
        for (final selectedValues in _selectedAttributeValuesById.values) {
          if (selectedValues.isEmpty) continue;
          final hasAny = selectedValues
              .any((value) => searchable.contains(value.toLowerCase()));
          if (!hasAny) return false;
        }
      }
      return true;
    }).toList();

    switch (_sortOption) {
      case _ProductsSortOption.newest:
        return filtered;
      case _ProductsSortOption.lowStock:
        filtered.sort((a, b) {
          final warnCompare =
              (b.stockWarn ? 1 : 0).compareTo(a.stockWarn ? 1 : 0);
          if (warnCompare != 0) return warnCompare;
          return _stockNumber(a).compareTo(_stockNumber(b));
        });
        return filtered;
      case _ProductsSortOption.highestPrice:
        filtered.sort((a, b) => _priceNumber(b).compareTo(_priceNumber(a)));
        return filtered;
      case _ProductsSortOption.lowestPrice:
        filtered.sort((a, b) => _priceNumber(a).compareTo(_priceNumber(b)));
        return filtered;
    }
  }

  int _activeFilterCount() {
    final attrCount = _selectedAttributeValuesById.values.fold<int>(
      0,
      (total, values) => total + values.length,
    );
    return _selectedCategoryNames.length + attrCount;
  }

  void _applyAndSetFilters({
    required Set<String> categoryNames,
    required Map<String, Set<String>> attributeValuesById,
  }) {
    setState(() {
      _selectedCategoryNames = categoryNames;
      _selectedAttributeValuesById = attributeValuesById;
      _products = _applyLocalFilters(_allProducts);
    });
  }

  void _selectCategoryChip(String? categoryName) {
    setState(() {
      _selectedCategoryNames =
          categoryName == null ? <String>{} : {categoryName};
      _products = _applyLocalFilters(_allProducts);
    });
  }

  void _selectSortOption(_ProductsSortOption option) {
    setState(() {
      _sortOption = option;
      _products = _applyLocalFilters(_allProducts);
    });
  }

  void _toggleHideDemoProducts(bool hideDemoProducts) {
    setState(() {
      _hideDemoProducts = hideDemoProducts;
      _products = _applyLocalFilters(_allProducts);
    });
  }

  Future<void> _openFiltersSheet({
    required List<CategoryEntry> categories,
    required List<ProductAttribute> attributes,
  }) async {
    final hydratedAttributes = await _loadAttributesWithValues(attributes);
    if (!mounted) return;
    final initialCategories = Set<String>.from(_selectedCategoryNames);
    final initialAttrs = <String, Set<String>>{
      for (final entry in _selectedAttributeValuesById.entries)
        entry.key: Set<String>.from(entry.value),
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ProductsFilterSheet(
          categories: categories,
          attributes: hydratedAttributes,
          selectedCategoryNames: initialCategories,
          selectedAttributeValuesById: initialAttrs,
          onApply: _applyAndSetFilters,
        );
      },
    );
  }

  List<String> _extractAttributeValuesFromDetail(Map<String, dynamic> detail) {
    final rawValues = detail['values'] ??
        detail['attributeValues'] ??
        detail['attribute_values'] ??
        detail['items'] ??
        detail['options'];
    if (rawValues is! List) return const [];
    final values = <String>[];
    for (final raw in rawValues) {
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final label = (m['value'] ?? m['name'] ?? '').toString().trim();
        if (label.isEmpty) continue;
        final cc = (m['colorCode'] ?? m['color_code'] ?? '').toString().trim();
        values.add(cc.isNotEmpty
            ? '$label|${cc.startsWith('#') ? cc : '#$cc'}'
            : label);
      } else if (raw != null) {
        final s = raw.toString().trim();
        if (s.isNotEmpty) values.add(s);
      }
    }
    return values;
  }

  Future<List<ProductAttribute>> _loadAttributesWithValues(
    List<ProductAttribute> attributes,
  ) async {
    final api = ref.read(apiClientProvider);
    final hydrated = <ProductAttribute>[];
    for (final attr in attributes) {
      if (attr.values.isNotEmpty) {
        hydrated.add(attr);
        continue;
      }
      try {
        final r = await api.getDashboardAttribute(attr.id);
        final data = r.data;
        if (r.success && data is Map<String, dynamic>) {
          final detail = (data['attribute'] ?? data['item'] ?? data);
          if (detail is Map<String, dynamic>) {
            final values = _extractAttributeValuesFromDetail(detail);
            hydrated.add(
              ProductAttribute(
                id: attr.id,
                name: attr.name,
                description: attr.description,
                values: values,
                displayType: attr.displayType,
              ),
            );
            continue;
          }
        }
      } catch (_) {
        // Keep the attribute even if detail lookup fails.
      }
      hydrated.add(attr);
    }
    return hydrated;
  }

  static Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showQuickActionsModal(ProductListItem product) {
    final rootContext = context;
    final shareUrl = _shareUrlFor(product.sku);
    final encodedUrl = Uri.encodeComponent(shareUrl);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).padding.bottom;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(12, 5, 40, 0.08),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(8, 12, 8, 16 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    product.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _SheetActionRow(
                  icon: Icons.visibility_outlined,
                  label: 'View',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showDialog<void>(
                      context: rootContext,
                      builder: (ctx) => AlertDialog(
                        title: Text(product.name),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(product.meta),
                              const SizedBox(height: 8),
                              Text('Stock: ${product.stock}'),
                              Text('Price: ${product.price}'),
                              Text('Status: ${product.status}'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _SheetActionRow(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    HapticFeedback.lightImpact();
                    final key = (product.id != null && product.id!.isNotEmpty)
                        ? product.id!
                        : product.sku;
                    () async {
                      await rootContext
                          .push('/products/edit/${Uri.encodeComponent(key)}');
                      if (!mounted) return;
                      _invalidateProductsCache();
                      await _loadProducts(
                          pageOverride: _currentPage, forceRefresh: true);
                    }();
                  },
                ),
                _SheetActionRow(
                  icon: Icons.block_rounded,
                  label: product.active ? 'Deactivate' : 'Activate',
                  showDividerBelow: true,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    HapticFeedback.lightImpact();
                    final id = product.id;
                    if (id == null || id.isEmpty) {
                      if (rootContext.mounted) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Missing product id — refresh the list.')),
                        );
                      }
                      return;
                    }

                    final nextActive = !product.active;
                    final nextStatus = nextActive ? 'Active' : 'Inactive';

                    setState(() {
                      final idx = _allProducts.indexWhere((p) => p.id == id);
                      if (idx >= 0) {
                        final old = _allProducts[idx];
                        _allProducts[idx] = (
                          id: old.id,
                          name: old.name,
                          meta: old.meta,
                          status: nextStatus,
                          active: nextActive,
                          isDemo: old.isDemo,
                          stock: old.stock,
                          stockWarn: old.stockWarn,
                          price: old.price,
                          sku: old.sku,
                          imageUrl: old.imageUrl,
                          accentBar: old.accentBar
                        );
                        _products = _applyLocalFilters(_allProducts);
                      }
                    });

                    try {
                      final api = ref.read(apiClientProvider);
                      final next = product.active ? 'inactive' : 'active';
                      final r = await api.updateProduct(id, {'status': next});
                      if (!r.success) {
                        throw StateError(r.error?.message ?? 'Update failed');
                      }
                      if (rootContext.mounted) {
                        _invalidateProductsCache();
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${nextActive ? 'Activated' : 'Deactivated'} ${product.name}')),
                        );
                      }
                    } catch (e) {
                      if (rootContext.mounted) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(content: Text('Status update failed: $e')),
                        );
                      }
                    }
                  },
                ),
                _SheetShareRow(
                  imageUrl: _kIconFacebook,
                  label: 'Share on Facebook',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    HapticFeedback.lightImpact();
                    _launchExternal(
                      'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl',
                    );
                  },
                ),
                _SheetShareRow(
                  iconWidget: const Icon(Icons.close, size: 20),
                  label: 'Share on X',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    HapticFeedback.lightImpact();
                    _launchExternal(
                      'https://twitter.com/intent/tweet?url=$encodedUrl&text=${Uri.encodeComponent('Check out ${product.name}')}',
                    );
                  },
                ),
                _SheetShareRow(
                  imageUrl: _kIconWhatsApp,
                  label: 'Share on WhatsApp',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    HapticFeedback.lightImpact();
                    _launchExternal(
                      'https://wa.me/?text=${Uri.encodeComponent('${product.name} — $shareUrl')}',
                    );
                  },
                ),
                _SheetShareRow(
                  imageUrl: _kIconInstagram,
                  label: 'Share on Instagram',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    HapticFeedback.lightImpact();
                    SharePlus.instance.share(
                      ShareParams(text: '${product.name}\n$shareUrl'),
                    );
                  },
                ),
                _SheetActionRow(
                  icon: Icons.link,
                  label: 'Copy Link',
                  showDividerBelow: true,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    HapticFeedback.lightImpact();
                    await Clipboard.setData(ClipboardData(text: shareUrl));
                    if (rootContext.mounted) {
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    }
                  },
                ),
                _SheetActionRow(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  destructive: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    HapticFeedback.heavyImpact();
                    showDialog<void>(
                      context: rootContext,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete product?'),
                        content:
                            Text('Remove ${product.name} from your catalog?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final delId = product.id ?? product.sku;
                              try {
                                final api = ref.read(apiClientProvider);
                                final r = await api.deleteProduct(delId);
                                if (!r.success) {
                                  throw StateError(
                                      r.error?.message ?? 'Delete failed');
                                }
                                if (rootContext.mounted) {
                                  _invalidateProductsCache();
                                  ScaffoldMessenger.of(rootContext)
                                      .showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Deleted ${product.name}')),
                                  );
                                  await _loadProducts(forceRefresh: true);
                                }
                              } catch (e) {
                                if (rootContext.mounted) {
                                  ScaffoldMessenger.of(rootContext)
                                      .showSnackBar(
                                    SnackBar(
                                        content: Text('Delete failed: $e')),
                                  );
                                }
                              }
                            },
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                  color:
                                      Theme.of(rootContext).colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final products = _products;
    final categoriesAsync = ref.watch(categoriesListProvider);
    final attributesAsync = ref.watch(dashboardAttributesProvider);
    final categories = categoriesAsync.valueOrNull ?? const <CategoryEntry>[];
    final attributes =
        attributesAsync.valueOrNull ?? const <ProductAttribute>[];
    final fabBottom = MediaQuery.of(context).padding.bottom + 8;
    final totalProducts = _totalItems > 0 ? _totalItems : _allProducts.length;
    final activeProducts = _allProducts.where((p) => p.active).length;
    final totalStock =
        _allProducts.fold<int>(0, (sum, p) => sum + _stockNumber(p));
    final lowStockCount = _allProducts.where((p) => p.stockWarn).length;
    final productCategoryNames =
        _allProducts.map(_categoryFor).where((c) => c.isNotEmpty).toSet();
    final categoryNames = <String>{
      ...categories.map((c) => c.name).where((name) => name.trim().isNotEmpty),
      ...productCategoryNames,
    }.toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottom),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryDark, AppTheme.primary],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                await context.push('/products/new');
                if (!mounted) return;
                _invalidateProductsCache();
                await _loadProducts(
                    pageOverride: _currentPage, forceRefresh: true);
              },
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: () => _loadProducts(forceRefresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                  24, 8 + MediaQuery.of(context).padding.top, 24, 120),
              children: [
                DashboardPageHeader(
                  title: 'Products',
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Center(
                        child: Text(
                          '$activeProducts active',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppTheme.primaryDark,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh products',
                      onPressed: _isLoading
                          ? null
                          : () => _loadProducts(
                              pageOverride: _currentPage, forceRefresh: true),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppTheme.primaryDark,
                      ),
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => context.push('/notifications'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProductsSummaryCards(
                  totalProducts: totalProducts,
                  totalStock: totalStock,
                  lowStockCount: lowStockCount,
                ),
                const SizedBox(height: 14),
                _StoreStructureSection(
                  expanded: _storeStructureExpanded,
                  onToggle: () => setState(
                      () => _storeStructureExpanded = !_storeStructureExpanded),
                ),
                const SizedBox(height: 14),
                _CategoryAndSortRow(
                  categories: categoryNames,
                  selectedCategoryNames: _selectedCategoryNames,
                  selectedSortOption: _sortOption,
                  visibleProductCount: products.length,
                  hideDemoProducts: _hideDemoProducts,
                  onSelectCategory: _selectCategoryChip,
                  onSelectSort: _selectSortOption,
                  onToggleHideDemoProducts: _toggleHideDemoProducts,
                ),
                const SizedBox(height: 14),
                if (!wide)
                  _FiltersRow(
                    theme: theme,
                    controller: _searchController,
                    onSearchChanged: _onSearchChanged,
                    isLoading: _isLoading,
                    activeFiltersCount: _activeFilterCount(),
                    onOpenFilters: () => _openFiltersSheet(
                      categories: categories,
                      attributes: attributes,
                    ),
                  ),
                if (wide)
                  _FiltersRowWide(
                    theme: theme,
                    controller: _searchController,
                    onSearchChanged: _onSearchChanged,
                    isLoading: _isLoading,
                    activeFiltersCount: _activeFilterCount(),
                    onOpenFilters: () => _openFiltersSheet(
                      categories: categories,
                      attributes: attributes,
                    ),
                  ),
                const SizedBox(height: 18),
                _ProductsDataSourceBadge(isLiveData: _isLiveData),
                const SizedBox(height: 6),
                Text(
                  '${_lastUpdatedLabel()} • Pull down to refresh',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!_hasSeenRefreshHint) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.swipe_down_alt_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: swipe down anywhere on this page to refresh products.',
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
                                .saveProductsListRefreshHintSeen(true);
                          },
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: ShimmerListLoader(itemCount: 8, height: 100),
                  )
                else if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Using fallback product data. ${_errorMessage!}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  )
                else if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: IllustratedEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products found',
                      subtitle:
                          'Adjust your search filters or add a new product.',
                    ),
                  )
                else
                  ...products.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _CatalogProductCard(
                        product: p,
                        wide: wide,
                        onOpenMenu: () => _showQuickActionsModal(p),
                        onOpenProduct: () {
                          final key = (p.id != null && p.id!.isNotEmpty)
                              ? p.id!
                              : p.sku;
                          context.push(
                              '/products/edit/${Uri.encodeComponent(key)}');
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Divider(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.2),
                    height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Page $_currentPage of $_totalPages • $_totalItems total',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PageBtn(
                            icon: Icons.chevron_left,
                            onPressed: _goPrevPage,
                            enabled: _currentPage > 1),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_currentPage',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PageBtn(
                          label: _currentPage < _totalPages
                              ? '${_currentPage + 1}'
                              : '-',
                          onPressed: _goNextPage,
                          enabled: _currentPage < _totalPages,
                        ),
                        const SizedBox(width: 8),
                        _PageBtn(
                            icon: Icons.chevron_right,
                            onPressed: _goNextPage,
                            enabled: _currentPage < _totalPages),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'Showing ${products.length} of $totalProducts products',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.theme,
    required this.controller,
    required this.onSearchChanged,
    required this.isLoading,
    required this.activeFiltersCount,
    required this.onOpenFilters,
  });

  final ThemeData theme;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final bool isLoading;
  final int activeFiltersCount;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
              ),
              decoration: InputDecoration(
                hintText: 'Search products by name, SKU or category...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.outline,
                ),
                suffixIcon: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _FilterButton(
          count: activeFiltersCount,
          onTap: onOpenFilters,
        ),
      ],
    );
  }
}

class _FiltersRowWide extends StatelessWidget {
  const _FiltersRowWide({
    required this.theme,
    required this.controller,
    required this.onSearchChanged,
    required this.isLoading,
    required this.activeFiltersCount,
    required this.onOpenFilters,
  });

  final ThemeData theme;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final bool isLoading;
  final int activeFiltersCount;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.onSurfaceVariant),
              decoration: InputDecoration(
                hintText: 'Search products by name, SKU or category...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: theme.colorScheme.outline),
                suffixIcon: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _FilterButton(
          count: activeFiltersCount,
          onTap: onOpenFilters,
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  Icons.filter_list_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductsFilterSheet extends StatefulWidget {
  const _ProductsFilterSheet({
    required this.categories,
    required this.attributes,
    required this.selectedCategoryNames,
    required this.selectedAttributeValuesById,
    required this.onApply,
  });

  final List<CategoryEntry> categories;
  final List<ProductAttribute> attributes;
  final Set<String> selectedCategoryNames;
  final Map<String, Set<String>> selectedAttributeValuesById;
  final void Function({
    required Set<String> categoryNames,
    required Map<String, Set<String>> attributeValuesById,
  }) onApply;

  @override
  State<_ProductsFilterSheet> createState() => _ProductsFilterSheetState();
}

class _ProductsFilterSheetState extends State<_ProductsFilterSheet> {
  late Set<String> _selectedCategories;
  late Map<String, Set<String>> _selectedAttributeValuesById;

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set<String>.from(widget.selectedCategoryNames);
    _selectedAttributeValuesById = {
      for (final entry in widget.selectedAttributeValuesById.entries)
        entry.key: Set<String>.from(entry.value),
    };
  }

  void _toggleCategory(String categoryName) {
    setState(() {
      if (_selectedCategories.contains(categoryName)) {
        _selectedCategories.remove(categoryName);
      } else {
        _selectedCategories.add(categoryName);
      }
    });
  }

  void _toggleAttributeValue(String attributeId, String value) {
    setState(() {
      final current = _selectedAttributeValuesById[attributeId] ?? <String>{};
      if (current.contains(value)) {
        current.remove(value);
      } else {
        current.add(value);
      }
      if (current.isEmpty) {
        _selectedAttributeValuesById.remove(attributeId);
      } else {
        _selectedAttributeValuesById[attributeId] = current;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.78;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'CATEGORIES',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppTheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: widget.categories.map((category) {
                            final selected =
                                _selectedCategories.contains(category.name);
                            return ChoiceChip(
                              label: Text(category.name),
                              selected: selected,
                              onSelected: (_) => _toggleCategory(category.name),
                              showCheckmark: false,
                              selectedColor: AppTheme.primary,
                              backgroundColor: AppTheme.surfaceContainerLow,
                              labelStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.onSurfaceVariant,
                              ),
                              side: BorderSide(
                                color: selected
                                    ? Colors.transparent
                                    : theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        ...widget.attributes.map((attribute) {
                          final selectedValues =
                              _selectedAttributeValuesById[attribute.id] ??
                                  const <String>{};
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                attribute.name.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: attribute.values.map((raw) {
                                  final value = raw.split('|').first.trim();
                                  final selected =
                                      selectedValues.contains(value);
                                  return ChoiceChip(
                                    label: Text(value),
                                    selected: selected,
                                    onSelected: (_) => _toggleAttributeValue(
                                        attribute.id, value),
                                    showCheckmark: false,
                                    selectedColor: AppTheme.primary,
                                    backgroundColor:
                                        AppTheme.surfaceContainerLow,
                                    labelStyle: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : AppTheme.onSurfaceVariant,
                                    ),
                                    side: BorderSide(
                                      color: selected
                                          ? Colors.transparent
                                          : theme.colorScheme.outlineVariant
                                              .withValues(alpha: 0.5),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        widget.onApply(
                          categoryNames: <String>{},
                          attributeValuesById: <String, Set<String>>{},
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onApply(
                            categoryNames: _selectedCategories,
                            attributeValuesById: _selectedAttributeValuesById,
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsSummaryCards extends StatelessWidget {
  const _ProductsSummaryCards({
    required this.totalProducts,
    required this.totalStock,
    required this.lowStockCount,
  });

  final int totalProducts;
  final int totalStock;
  final int lowStockCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProductsSummaryCard(
            label: 'Total\nProducts',
            value: '$totalProducts',
            caption: 'Active',
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ProductsSummaryCard(
            label: 'Total\nStock',
            value: '$totalStock',
            caption: 'Units',
            icon: Icons.show_chart_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ProductsSummaryCard(
            label: 'Low Stock\nAlerts',
            value: '$lowStockCount',
            caption: lowStockCount == 0 ? 'All stocked' : 'Need restock',
            icon: Icons.warning_amber_rounded,
            alert: lowStockCount > 0,
          ),
        ),
      ],
    );
  }
}

class _ProductsSummaryCard extends StatelessWidget {
  const _ProductsSummaryCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.alert = false,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        alert ? const Color(0xFFE68600) : theme.colorScheme.onSurfaceVariant;
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            alert ? const Color(0xFFFFFBEB) : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert
              ? const Color(0xFFFBBF24)
              : AppTheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: alert
                        ? const Color(0xFFB45309)
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: alert ? const Color(0xFFE68600) : AppTheme.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: alert
                  ? const Color(0xFFE68600)
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreStructureSection extends StatelessWidget {
  const _StoreStructureSection({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: _StoreStructureCollapsed(onTap: onToggle),
      secondChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BackSquareButton(onTap: onToggle),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Manage store structure',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StoreStructureAction(
            title: 'Manage Categories',
            subtitle: 'Organise your shop structure and group related products',
            icon: Icons.grid_view_rounded,
            iconColor: AppTheme.primary,
            iconBackground: const Color(0xFFE8EAFF),
            onTap: () => context.push('/categories'),
          ),
          const SizedBox(height: 10),
          _StoreStructureAction(
            title: 'Manage Attributes',
            subtitle: 'Define sizes, colours, materials & other variants',
            icon: Icons.format_align_left_rounded,
            iconColor: const Color(0xFF22C55E),
            iconBackground: const Color(0xFFE8FDF1),
            onTap: () => context.push('/attributes'),
          ),
        ],
      ),
      crossFadeState:
          expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 180),
      sizeCurve: Curves.easeOutCubic,
    );
  }
}

class _StoreStructureCollapsed extends StatelessWidget {
  const _StoreStructureCollapsed({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.grid_view_rounded,
                    color: Theme.of(context).colorScheme.outline, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage store structure',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    Text(
                      'Categories & Attributes',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackSquareButton extends StatelessWidget {
  const _BackSquareButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.chevron_left_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _StoreStructureAction extends StatelessWidget {
  const _StoreStructureAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryAndSortRow extends StatelessWidget {
  const _CategoryAndSortRow({
    required this.categories,
    required this.selectedCategoryNames,
    required this.selectedSortOption,
    required this.visibleProductCount,
    required this.hideDemoProducts,
    required this.onSelectCategory,
    required this.onSelectSort,
    required this.onToggleHideDemoProducts,
  });

  final List<String> categories;
  final Set<String> selectedCategoryNames;
  final _ProductsSortOption selectedSortOption;
  final int visibleProductCount;
  final bool hideDemoProducts;
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<_ProductsSortOption> onSelectSort;
  final ValueChanged<bool> onToggleHideDemoProducts;

  @override
  Widget build(BuildContext context) {
    final selectedCategory =
        selectedCategoryNames.length == 1 ? selectedCategoryNames.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _CategoryChip(
                label: 'All',
                selected: selectedCategoryNames.isEmpty,
                onTap: () => onSelectCategory(null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                _CategoryChip(
                  label: category,
                  selected: selectedCategory == category,
                  onTap: () => onSelectCategory(category),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing $visibleProductCount products',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hide demo',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Switch.adaptive(
                  value: hideDemoProducts,
                  onChanged: onToggleHideDemoProducts,
                ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_ProductsSortOption>(
              initialValue: selectedSortOption,
              onSelected: onSelectSort,
              itemBuilder: (context) => _ProductsSortOption.values
                  .map(
                    (option) => PopupMenuItem<_ProductsSortOption>(
                      value: option,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded,
                      color: AppTheme.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Sort: ${selectedSortOption.label}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceContainerLowest,
      side: BorderSide(
        color: selected
            ? AppTheme.primary
            : AppTheme.outlineVariant.withValues(alpha: 0.65),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : AppTheme.primaryDark,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({
    required this.product,
    required this.wide,
    required this.onOpenMenu,
    required this.onOpenProduct,
  });

  final ProductListItem product;
  final bool wide;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactive = !product.active;
    final titleStyle = GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: AppTheme.primaryDark.withValues(alpha: inactive ? 0.55 : 1),
    );

    return Opacity(
      opacity: inactive ? 0.82 : 1,
      child: Material(
        color: inactive
            ? AppTheme.surfaceContainerLowest.withValues(alpha: 0.65)
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpenProduct,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _thumb(theme, inactive, product.isDemo),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name,
                                style: titleStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(
                              product.meta,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(
                          active: product.active, status: product.status),
                      const SizedBox(width: 24),
                      _MetricColumn(
                          label: 'STOCK',
                          value: product.stock,
                          warn: product.stockWarn,
                          theme: theme),
                      const SizedBox(width: 32),
                      _MetricColumn(
                        label: 'PRICE',
                        value: product.price,
                        warn: false,
                        theme: theme,
                        emphasize: true,
                      ),
                      const SizedBox(width: 8),
                      _MenuButton(onPressed: onOpenMenu),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _thumb(theme, inactive, product.isDemo),
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
                                        product.name,
                                        style: titleStyle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _StatusChip(
                                        active: product.active,
                                        status: product.status),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.meta,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricColumn(
                              label: 'STOCK',
                              value: product.stock,
                              warn: product.stockWarn,
                              theme: theme,
                            ),
                          ),
                          Expanded(
                            child: _MetricColumn(
                              label: 'PRICE',
                              value: product.price,
                              warn: false,
                              theme: theme,
                              emphasize: true,
                            ),
                          ),
                          _MenuButton(onPressed: onOpenMenu),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(ThemeData theme, bool inactive, bool isDemo) {
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
                  port: base.hasPort ? base.port : null)
              .toString();
        }
      } catch (_) {}
      return raw;
    }

    Widget placeholder({bool loading = false}) {
      return Container(
        width: 96,
        height: 96,
        color: theme.colorScheme.surfaceContainerLow,
        child: loading
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            : Icon(Icons.image_outlined, color: theme.colorScheme.outline),
      );
    }

    if (product.imageUrl.trim().isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder(loading: true),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          ColorFiltered(
            colorFilter: inactive
                ? const ColorFilter.matrix(<double>[
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: Image.network(
              product.imageUrl,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return placeholder(loading: true);
              },
              errorBuilder: (_, __, ___) {
                final alt = fallbackUrl(product.imageUrl);
                if (alt != product.imageUrl) {
                  return Image.network(
                    alt,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return placeholder(loading: true);
                    },
                    errorBuilder: (_, __, ___) => placeholder(),
                  );
                }
                return placeholder();
              },
            ),
          ),
          if (product.accentBar)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          if (isDemo)
            const Positioned(
              top: 8,
              right: 8,
              child: _DemoImageBadge(),
            ),
        ],
      ),
    );
  }
}

class _DemoImageBadge extends StatelessWidget {
  const _DemoImageBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Demo product',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xCC111827),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'DEMO',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _ProductsDataSourceBadge extends StatelessWidget {
  const _ProductsDataSourceBadge({required this.isLiveData});

  final bool isLiveData;

  @override
  Widget build(BuildContext context) {
    final bg = isLiveData ? const Color(0xFFD1FAE5) : const Color(0xFFFFF4E5);
    final fg = isLiveData ? const Color(0xFF065F46) : const Color(0xFF9A3412);
    final label = isLiveData ? 'LIVE PRODUCTS DATA' : 'FALLBACK PRODUCTS DATA';
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
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.warn,
    required this.theme,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool warn;
  final ThemeData theme;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.outline,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize
                ? AppTheme.primaryDark
                : (warn
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLow,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.more_vert, color: AppTheme.primaryDark, size: 22),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active, required this.status});

  final bool active;
  final String status;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9);
    final fg = active ? const Color(0xFF047857) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDividerBelow = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDividerBelow;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFBA1A1A)
        : Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          destructive ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDividerBelow)
          Divider(
              height: 1, color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
      ],
    );
  }
}

class _SheetShareRow extends StatelessWidget {
  const _SheetShareRow({
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.iconWidget,
  });

  final String label;
  final VoidCallback onTap;
  final String? imageUrl;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: imageUrl != null
                  ? Image.network(imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.share, size: 20))
                  : iconWidget ?? const Icon(Icons.share, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  const _PageBtn({
    this.icon,
    this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: icon != null
              ? Icon(icon,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)
              : Center(
                  child: Text(
                    label!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
