import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';

/// Product catalog — Stitch: "Product Catalog (with Quick Actions)"
/// Project DukaNest Tenant App Plan, screen 62433aa938834d55bc36fd5d1a134124.
typedef ProductListItem = ({
  String? id,
  String name,
  String meta,
  String status,
  bool active,
  String stock,
  bool stockWarn,
  String price,
  String sku,
  String imageUrl,
  bool accentBar,
});

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {

  static const _kProfileAvatar =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC2_SJewaxT7aw4FFdp0d1msPDYEEeyZUPnzN20SAQVeXaMlmd9eM6R_dGaWWv6k4bTrdJNt3_lq3ybiwxjYxYTJVLrc2QjgWxGJ8mSqeO_EGOdsbVT5FwHySJ7nbDkz8K9JE-KqAkQbaTLoXTbcAijYaSYgnRYB3iZatmB19nP2XojVuVKIL2I2GWucM49O2JoV3LXDGruR-DzJWcAJGeGV8MFHW1fmr8IovzY-dQLZuyr9fuEVhlLNz54RENBGIVvGDbF0oQThfpo';

  static const _kSneaker =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBItpyh7rifhulInTnFVxDIGg-AgrcC3dNLPMXbdw1QqOBNP-rF6vjac2o8a4ZxGE5iuht_h7q0yXNKub5Rm-TNJ_PSiFKpMdA54Wxnfa1i6ASERO_Hdung32CBZZVqy-kINY0JOsfm1fsgaM42KaOeFldn7sPtE0UIivsZMyG1_B9eD2q7R4ytB8bAmQ3hXU7wEEXbTza-mIpaY1YIiEOARaf61fVunRr4wtJNDHF096AEFOjVZGl4VXJunIdlDvTFIaPahiBAc9GG';
  static const _kWatch =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC0ei8XqCEmV8Zsq5Lv3E9w-dqx_f9FBaGX_NtmPyGDvsbqMO5w26wmb4DwQKtMNn8G7BAdrz1q74g1Kto-2e7h5rUwiAWhFrIZcQtztnqm9iI6X3D0Iv6TyjU_zPNWQxpotj7e5bndssIZsXOago1HETIinyDA3QAA2YT4O4P-6tBHmdeFPgrls1GNhErRK4XHE_KME8qkXjv4FsJCm7onxa0xF2uWrybLUks7O1yBZOFXePKNpP7frYkKFTZVtFXiFBKQ9rJ1NGiK';
  static const _kHeadphones =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD9cWmwiE-_lsX7IB3rEswMD2xUB-QYYIvTSR8jPsKAnxUdlperQpbtwgC2fzrRrSLFT6gHVTY4d1mKcgcsfMWE68jvOEQLbhz-19GYfd3EygJ5wHRMf0x0TqfrkpCFQNEA2dGov2KgaKcVcyc8Zr-JRBVwidom5CIfH_w3DSg3R4xmMKL3z0L7TSgqzaGh8eP-xIHOLjc-bPvG_iKrshB9CCskI8ZZQlUzsVUJ5KYYi46dmmWgtiTjLnyy3SP4GUEf4SjCq2-XY0eT';
  static const _kAviators =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDuRZSDgVO8zLQfz9qgW7UgcfYppVXgR1YjV6lvUHp6lEtQrB3shE4GKMQecGWG-TG1t5CHFNEHhdR3eMTlqzXO0omYY2-4s4UZjJU2xjXJWud6xyyq7A41Q9jwgeYb2uiF27phDBDx1n2ZyoKax62T3Orl3-Ih5LuM4thz5K9QYR7AcQx84RnXhloSoWU8J3eJyGooJwggfD81exp9XUtokbVsipUDp8fHK9P5eqhCYjIYpjQqcfuBAnJBbtnD5CbXSn2hivnU3oT3';

  static const _kIconFacebook =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCu39UMZ478Jp3AgkDfI97OE621gJthMTC3sW2JhVIOk2NdvshMKWOfMbess2O_geyGWG6uv9RDAqGd91aP_o68_XsPW_glXY_KoTYW52hpwIR6Ggx1FGOBY1GqLoqB0PwrihlUel4Cl8b7dPWftTTAvXLBUIxcswkyk6L_0gWHxoeeqjubEXBgC5YRnpXN8KhazuiarZ3uFPBARCsaqyOWZqZYm3rsQ3y_U4YcIBvpsIWgyRFPfM--LQTSYu7GsG8EfLS0ARIsIsVQ';
  static const _kIconWhatsApp =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDR8_J2lm2Hd76_zE0gIVafee45tK1stTJq3ZJs-peKpz6Ygn4q7pvHLmpL_NMC-d71kg_f6J7qjLkYEJ_eHRccmRuKRRiaijw8ZVnsSnlYGwI_64LDzEZ589ov47okTh9PkSvBhlkCq-NhBSLQaei4KXwTyRifnu8EwDGnzOQGIJbXDurz7TvbJGQ7nLJCw_K4pMctXB0q8AL33XVkUog5KKrbB81Xam-6z-Xd-D608wnwF9EWz2wNxlZ21USniP_WzrpVwSd2dmGE';
  static const _kIconInstagram =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDh9zDpcWzuavgdI-XcRnz3k0la38sFTcPOJaWBgLpx7NKvZL74-mScPC8LFTF0NdpvJOSoD0NVW7APAtoCsf19QfAjrET99VG71XS2EFa-zTgZtM0gQaGFTpbgqfbsfQmTTIAFTUQrAthLICUd2kT-bagJ19ztBvK79N5q5J9Poyiy245iBOR2fsNG1a2Bri5dJ_BmFL2kHCmdWz9kndX8_fqhO9AlTrs8k6vPB_nws3jdrkFxJz0XU-7wU7UzgPfpyJ9qBCPA1bLh';

  static String _shareUrlFor(String sku) =>
      'https://dukanest.app/p/${Uri.encodeComponent(sku)}';

  static List<ProductListItem> _fallbackProducts() => [
        (
          id: null,
          name: 'Velocity Nitro Runner',
          meta: 'Footwear • SKU: VN-2024-RD',
          status: 'Active',
          active: true,
          stock: '124 units',
          stockWarn: false,
          price: '\$129.00',
          sku: 'VN-2024-RD',
          imageUrl: _kSneaker,
          accentBar: true,
        ),
        (
          id: null,
          name: 'Minimalist Slate Watch',
          meta: 'Accessories • SKU: MW-SL-01',
          status: 'Active',
          active: true,
          stock: '42 units',
          stockWarn: false,
          price: '\$85.50',
          sku: 'MW-SL-01',
          imageUrl: _kWatch,
          accentBar: false,
        ),
        (
          id: null,
          name: 'Studio Pro Wireless',
          meta: 'Electronics • SKU: SPW-BLK-99',
          status: 'Inactive',
          active: false,
          stock: '0 units',
          stockWarn: false,
          price: '\$199.00',
          sku: 'SPW-BLK-99',
          imageUrl: _kHeadphones,
          accentBar: false,
        ),
        (
          id: null,
          name: 'Golden Aviators',
          meta: 'Accessories • SKU: GA-GLD-45',
          status: 'Active',
          active: true,
          stock: 'Low (5)',
          stockWarn: true,
          price: '\$45.00',
          sku: 'GA-GLD-45',
          imageUrl: _kAviators,
          accentBar: false,
        ),
      ];

  bool _isLoading = true;
  bool _isLiveData = false;
  String? _errorMessage;
  List<ProductListItem> _products = const [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalPages = 1;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(dynamic value, String? currencyCode) {
    if (value is num) {
      final code = (currencyCode == null || currencyCode.isEmpty) ? 'KES' : currencyCode;
      return '$code ${value.toStringAsFixed(2)}';
    }
    if (value is String && value.trim().isNotEmpty) return value;
    return 'KES 0.00';
  }

  Future<void> _loadProducts({int? pageOverride}) async {
    final pageToLoad = pageOverride ?? _currentPage;
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
        final category = (p['categoryName'] ?? p['category'] ?? 'General').toString();
        final stockValue = p['stock'] ?? p['stockQuantity'] ?? p['quantity'] ?? 0;
        final stockNum = stockValue is num ? stockValue.toInt() : int.tryParse(stockValue.toString()) ?? 0;
        final stockWarn = stockNum > 0 && stockNum <= 5;
        final statusRaw = (p['status'] ?? '').toString().toLowerCase();
        final active = statusRaw.isEmpty
            ? (p['isActive'] == true || p['active'] == true)
            : statusRaw == 'active' || statusRaw == 'enabled';
        final status = active ? 'Active' : 'Inactive';
        final currencyCode = (p['currencyCode'] ?? p['currency_code'])?.toString();
        final price = _formatCurrency(
          p['salePrice'] ?? p['price'] ?? p['regularPrice'] ?? p['amount'],
          currencyCode,
        );
        final imageUrl = (p['image'] ?? p['imageUrl'] ?? p['thumbnail'] ?? _kSneaker).toString();
        return (
          id: apiId,
          name: name,
          meta: '$category • SKU: $sku',
          status: status,
          active: active,
          stock: stockWarn ? 'Low ($stockNum)' : '$stockNum units',
          stockWarn: stockWarn,
          price: price,
          sku: sku,
          imageUrl: imageUrl,
          accentBar: false,
        );
      }).toList();

      setState(() {
        _products = mapped;
        _currentPage = response.pagination?.page ?? pageToLoad;
        _pageSize = response.pagination?.limit ?? _pageSize;
        _totalPages = response.pagination?.totalPages ?? 1;
        _totalItems = response.pagination?.total ?? mapped.length;
        _isLiveData = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _products = _fallbackProducts();
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    rootContext.push(
                      '/products/edit/${Uri.encodeComponent(product.sku)}',
                    );
                  },
                ),
                _SheetActionRow(
                  icon: Icons.block_rounded,
                  label: product.active ? 'Deactivate' : 'Activate',
                  showDividerBelow: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          product.active
                              ? 'Deactivate (demo) — ${product.name}'
                              : 'Activate (demo) — ${product.name}',
                        ),
                      ),
                    );
                  },
                ),
                _SheetShareRow(
                  imageUrl: _kIconFacebook,
                  label: 'Share on Facebook',
                  onTap: () {
                    Navigator.pop(sheetContext);
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
                    await Clipboard.setData(ClipboardData(text: shareUrl));
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
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
                    showDialog<void>(
                      context: rootContext,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete product?'),
                        content: Text('Remove ${product.name} from your catalog?'),
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
                                  throw StateError(r.error?.message ?? 'Delete failed');
                                }
                                if (rootContext.mounted) {
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(content: Text('Deleted ${product.name}')),
                                  );
                                  await _loadProducts();
                                }
                              } catch (e) {
                                if (rootContext.mounted) {
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(content: Text('Delete failed: $e')),
                                  );
                                }
                              }
                            },
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Theme.of(rootContext).colorScheme.error),
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
    final colorScheme = theme.colorScheme;
    final products = _products;
    final fabBottom = MediaQuery.of(context).padding.bottom + 80;

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
              onTap: () => context.push('/products/new'),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: LayoutBuilder(
          builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          return ListView(
            padding: EdgeInsets.fromLTRB(24, 8 + MediaQuery.of(context).padding.top, 24, 120),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    backgroundImage: const NetworkImage(_kProfileAvatar),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'DukaNest',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const Spacer(),
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
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INVENTORY MANAGEMENT',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Product Catalog',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wide)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryDark, AppTheme.primary],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(12, 5, 40, 0.06),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push('/products/new'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, color: Colors.white, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Add New Product',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!wide) const SizedBox(height: 24),
              if (!wide)
                _FiltersRow(
                  theme: theme,
                  controller: _searchController,
                  onSearchChanged: _onSearchChanged,
                  isLoading: _isLoading,
                ),
              if (wide) const SizedBox(height: 24),
              if (wide)
                _FiltersRowWide(
                  theme: theme,
                  controller: _searchController,
                  onSearchChanged: _onSearchChanged,
                  isLoading: _isLoading,
                ),
              const SizedBox(height: 24),
              _ProductsDataSourceBadge(isLiveData: _isLiveData),
              const SizedBox(height: 12),
              _QuickActionCards(theme: theme),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No products found.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
                    onOpenProduct: () => context.push(
                      '/products/edit/${Uri.encodeComponent(p.sku)}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: AppTheme.outlineVariant.withValues(alpha: 0.2), height: 32),
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
                      _PageBtn(icon: Icons.chevron_left, onPressed: _goPrevPage, enabled: _currentPage > 1),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PageBtn(
                        label: _currentPage < _totalPages ? '${_currentPage + 1}' : '-',
                        onPressed: _goNextPage,
                        enabled: _currentPage < _totalPages,
                      ),
                      const SizedBox(width: 8),
                      _PageBtn(icon: Icons.chevron_right, onPressed: _goNextPage, enabled: _currentPage < _totalPages),
                    ],
                  ),
                ],
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
  });

  final ThemeData theme;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.search, color: theme.colorScheme.outline, size: 22),
              ),
              Expanded(
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All Categories',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more, color: theme.colorScheme.outline),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.filter_list, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
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
  });

  final ThemeData theme;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 8,
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
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.search, color: theme.colorScheme.outline, size: 22),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onSearchChanged,
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceVariant),
                    decoration: InputDecoration(
                      hintText: 'Search products by name, SKU or category...',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.outline),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'All Categories',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(Icons.expand_more, color: theme.colorScheme.outline),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.filter_list, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionCards extends StatelessWidget {
  const _QuickActionCards({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/categories'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFE0FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.folder_open_rounded, color: AppTheme.primaryDark),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Manage Categories',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organize your shop structure',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/attributes'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.format_list_bulleted_rounded, color: theme.colorScheme.secondary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Manage Attributes',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Define sizes, colors & more',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
                      _thumb(theme, inactive),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                      _StatusChip(active: product.active, status: product.status),
                      const SizedBox(width: 24),
                      _MetricColumn(label: 'STOCK', value: product.stock, warn: product.stockWarn, theme: theme),
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
                          _thumb(theme, inactive),
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
                                    _StatusChip(active: product.active, status: product.status),
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

  Widget _thumb(ThemeData theme, bool inactive) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          ColorFiltered(
            colorFilter: inactive
                ? const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0, 0, 0, 1, 0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: Image.network(
              product.imageUrl,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 96,
                color: theme.colorScheme.surfaceContainerLow,
                child: Icon(Icons.image_outlined, color: theme.colorScheme.outline),
              ),
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
        ],
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
                : (warn ? theme.colorScheme.error : theme.colorScheme.onSurface),
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
                      fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDividerBelow)
          Divider(height: 1, color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
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
                  ? Image.network(imageUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.share, size: 20))
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
              ? Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant)
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
