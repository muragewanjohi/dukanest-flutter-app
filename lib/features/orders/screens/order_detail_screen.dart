import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';

/// Order detail — Stitch: "Order Details (Optimized Actions)"
/// & local export `02-order-details/screen.html` (Quick Actions + Customer + Shipping + Notes + bottom bar).
///
/// Note: Stitch project may show a newer screen id; layout follows the DukaNest Tenant App Plan export.
final orderDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  orderKey,
) async {
  try {
    final api = ref.read(apiClientProvider);
    final response = await api.getOrderDetail(orderKey);
    if (!response.success || response.data == null) return null;
    final payload = response.data;
    if (payload is! Map<String, dynamic>) return null;
    final raw = payload['order'] ?? payload['item'] ?? payload;
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  } catch (_) {
    return null;
  }
});

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderKey,
  });

  final String orderKey;

  static const Color _navyTitle = Color(0xFF001790);
  static const Color _itemTileBg = Color(0xFFF4F3F3);
  static const Color _premiumBadgeBg = Color(0xFFDFE0FF);
  static const Color _surfaceContainerHigh = Color(0xFFE9E8E8);

  static const _imgHeadphones =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAWjGc1hlvrvqIYLxM-3WNXMY7Zq7TqvAde4K7gacZMDAeXITtnj4MWSGBm1KFfjxAJwmGVVeFHm2VXNbANZXSY-Sb4jxmqWIVdrn5MqnA8TyHdffh2bPcD8fijxveCaByWeJpsUzVAwCtTMr_lSDYjQPEfUIygYmL4Z6frHzoGYdNqTyGUKKfQHEoks0A4hKvfW8q5GHDVbxbQZkJfU0Obei8Z7DGRAFDJNz0jCGhORwzauZ_D1O6bXUtTzuuw40nkDJRt1y4CZ_ew';
  static const _imgAdapter =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCLcm_TCAM1RGqqFuJYS9Lo09Hsz6K_QtMGCCxkjx6gTmzqZvBy2kFHrmPEwSFuuKMd2hL6O4M0DP34f5IGuq2fpVuzUmhdJlShLhcsTe2g7mkFuK0UlEVc_9cOznWI1Aa_qVnluY-GPX3_8tLINesvRYMXHke4hc_KSRjg4ET87zmwrC7VmVIgpZV1jh-t0O8oE_Ppdeskrv_EjV6jiRYoeD4hbJiKtOgEfsQvXOFliEhMTr_cbpvoJ54hRa_F2F7rYjzchlgy650j';
  static const _imgCable =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBQfD813MMZVHTnns8Rq2PpP0G-LqUG-JYb_b0AFgU5LhhPpvKEY_WjE0d6HwIa9DmrFJUOf-YiLBDf56UHX8OR7V5nmE8s6oPx_5xN3I4Rlfvf6KNrLHoa5E4EzAatLNKh8qlsBWwZuVhwexonPv5tgHtCuJ2qaRPIbhMz_Kvw0IVgmfBqtTJjqdcMVZpdJhkTbmJAW5mv-xhaHAN-jpA6wttPMo6MJEvF27JMcSbagepP5bRZx8dEiedqwVkdu2dCAVbwLZdL-alI';

  static final Map<String, _OrderDetailData> _demo = {
    'DK-9821': _stitchDefaultDetail,
    'DK-9819': _OrderDetailData(
      code: 'DK-9819',
      itemsCategorySubtitle: '1 item from Watches',
      premiumCustomer: false,
      lineItems: const [
        _LineItem(
          name: 'Minimalist Slate Watch',
          variantQty: 'Graphite • Qty: 1',
          price: '\$89.50',
          thumbColor: Color(0xFF4A5568),
        ),
      ],
      subtotal: '\$89.50',
      shipping: '\$8.00',
      tax: '\$7.80',
      total: '\$105.30',
      customerName: 'Alex Rivera',
      customerEmail: 'a.rivera@example.com',
      customerPhone: '+1 (555) 334-2201',
      shippingAddress:
          'Alex Rivera\n88 Cedar Lane\nPortland, OR 97201\nUnited States',
      timeline: [
        const _TimelineStep(
          title: 'Order Received',
          subtitleLines: ['Oct 24, 2025 • 9:05 AM'],
          state: _StepState.done,
        ),
        const _TimelineStep(
          title: 'Payment Confirmed',
          subtitleLines: ['Oct 24, 2025 • 9:06 AM', 'via Stripe'],
          state: _StepState.done,
        ),
        const _TimelineStep(
          title: 'Processing Order',
          subtitleLines: ['Oct 24, 2025 • 9:10 AM'],
          state: _StepState.current,
        ),
        const _TimelineStep(
          title: 'Shipped',
          subtitleLines: ['Pending action'],
          state: _StepState.upcoming,
        ),
      ],
    ),
    'DK-9815': _OrderDetailData(
      code: 'DK-9815',
      itemsCategorySubtitle: '2 items from Audio',
      premiumCustomer: true,
      lineItems: const [
        _LineItem(
          name: 'Studio Pro Wireless',
          variantQty: 'Matte Black • Qty: 2',
          price: '\$398.00',
          thumbColor: Color(0xFF2D3748),
        ),
      ],
      subtotal: '\$398.00',
      shipping: '\$0.00',
      tax: '\$31.84',
      total: '\$429.84',
      customerName: 'Priya Shah',
      customerEmail: 'priya.shah@example.com',
      customerPhone: '+1 (555) 771-0092',
      shippingAddress: 'Priya Shah\n221B Baker Ave\nSeattle, WA 98101\nUnited States',
      timeline: [
        const _TimelineStep(
          title: 'Order Received',
          subtitleLines: ['Oct 23, 2025 • 4:28 PM'],
          state: _StepState.done,
        ),
        const _TimelineStep(
          title: 'Payment Confirmed',
          subtitleLines: ['Oct 23, 2025 • 4:29 PM', 'via Stripe'],
          state: _StepState.done,
        ),
        const _TimelineStep(
          title: 'Processing Order',
          subtitleLines: ['Oct 23, 2025 • 4:35 PM'],
          state: _StepState.done,
        ),
        const _TimelineStep(
          title: 'Shipped',
          subtitleLines: ['Oct 23, 2025 • 6:12 PM', 'FedEx • Tracking sent'],
          state: _StepState.done,
        ),
      ],
    ),
    'DK-9810': _OrderDetailData(
      code: 'DK-9810',
      itemsCategorySubtitle: '1 item from Accessories',
      premiumCustomer: false,
      lineItems: const [
        _LineItem(
          name: 'Golden Aviators',
          variantQty: 'Amber • Qty: 2',
          price: '\$45.00',
          thumbColor: Color(0xFFB7791F),
        ),
      ],
      subtotal: '\$45.00',
      shipping: '\$5.99',
      tax: '\$4.08',
      total: '\$55.07',
      customerName: 'Chris Ortiz',
      customerEmail: 'c.ortiz@example.com',
      customerPhone: '+1 (555) 448-7712',
      shippingAddress:
          'Chris Ortiz\n400 Market St\nSan Francisco, CA 94105\nUnited States',
      timeline: [
        const _TimelineStep(
          title: 'Order Received',
          subtitleLines: ['Oct 23, 2025 • 11:12 AM'],
          state: _StepState.done,
        ),
        const _TimelineStep(
          title: 'Payment Confirmed',
          subtitleLines: ['Pending'],
          state: _StepState.current,
        ),
        const _TimelineStep(
          title: 'Processing Order',
          subtitleLines: ['Pending action'],
          state: _StepState.upcoming,
        ),
        const _TimelineStep(
          title: 'Shipped',
          subtitleLines: ['Pending action'],
          state: _StepState.upcoming,
        ),
      ],
    ),
  };

  static const _OrderDetailData _stitchDefaultDetail = _OrderDetailData(
    code: 'DK-9821',
    itemsCategorySubtitle: '3 items from Electronics & Accessories',
    premiumCustomer: true,
    lineItems: [
      _LineItem(
        name: 'Pro Wireless Headphones',
        variantQty: 'Midnight Blue • Qty: 1',
        price: '\$299.00',
        imageUrl: _imgHeadphones,
        thumbColor: Color(0xFF2B4C7E),
      ),
      _LineItem(
        name: 'Fast Charge 45W Adapter',
        variantQty: 'USB-C • Qty: 2',
        price: '\$78.00',
        imageUrl: _imgAdapter,
        thumbColor: Color(0xFF718096),
      ),
      _LineItem(
        name: 'Braided Cable 2.0m',
        variantQty: 'Space Grey • Qty: 1',
        price: '\$19.00',
        imageUrl: _imgCable,
        thumbColor: Color(0xFFE2E8F0),
      ),
    ],
    subtotal: '\$396.00',
    shipping: '\$12.00',
    tax: '\$31.68',
    total: '\$439.68',
    customerName: 'Sarah Jenkins',
    customerEmail: 's.jenkins@example.com',
    customerPhone: '+1 (555) 902-4412',
    shippingAddress:
        'Sarah Jenkins\n4820 North Parkway Blvd\nSuite 1204\nAustin, TX 78701\nUnited States',
    timeline: [
      _TimelineStep(
        title: 'Order Received',
        subtitleLines: ['Oct 24, 2025 • 9:41 AM'],
        state: _StepState.done,
      ),
      _TimelineStep(
        title: 'Payment Confirmed',
        subtitleLines: ['Oct 24, 2025 • 9:45 AM', 'via Stripe'],
        state: _StepState.done,
      ),
      _TimelineStep(
        title: 'Processing Order',
        subtitleLines: ['Started Oct 24, 2025 • 11:20 AM'],
        state: _StepState.current,
      ),
      _TimelineStep(
        title: 'Shipped',
        subtitleLines: ['Pending action'],
        state: _StepState.upcoming,
      ),
    ],
  );

  static String _pickString(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value;
      if (value is num) return value.toString();
    }
    return fallback;
  }

  static String _formatMoney(dynamic value, {String currency = 'KES'}) {
    if (value is num) return '$currency ${value.toStringAsFixed(2)}';
    if (value is String && value.trim().isNotEmpty) return value;
    return '$currency 0.00';
  }

  static _OrderDetailData _mapApiOrderToDetail(Map<String, dynamic> raw, String fallbackCode) {
    final customerRaw = raw['customer'];
    final customer = customerRaw is Map<String, dynamic> ? customerRaw : <String, dynamic>{};
    final shippingRaw = raw['shippingAddress'] ?? raw['shipping_address'] ?? raw['shipping'];
    final shipping = shippingRaw is Map<String, dynamic> ? shippingRaw : <String, dynamic>{};
    final currency = _pickString(raw, ['currencyCode', 'currency_code'], fallback: 'KES');
    final code = _pickString(raw, ['code', 'orderNumber', 'order_number', 'id'], fallback: fallbackCode);
    final itemsRaw = raw['items'] ?? raw['lineItems'] ?? raw['orderItems'] ?? const [];
    final itemList = itemsRaw is List ? itemsRaw : const [];
    final lineItems = itemList.whereType<Map>().map((entry) {
      final item = Map<String, dynamic>.from(entry);
      final qty = item['quantity'] ?? item['qty'] ?? 1;
      final variant = _pickString(item, ['variant', 'option', 'sku'], fallback: 'Standard');
      final priceValue = item['total'] ?? item['price'] ?? item['unitPrice'] ?? 0;
      return _LineItem(
        name: _pickString(item, ['name', 'title'], fallback: 'Item'),
        variantQty: '$variant • Qty: $qty',
        price: _formatMoney(priceValue, currency: currency),
        imageUrl: _pickString(item, ['image', 'imageUrl', 'thumbnail'], fallback: '').isEmpty
            ? null
            : _pickString(item, ['image', 'imageUrl', 'thumbnail']),
      );
    }).toList();

    final status = _pickString(raw, ['status'], fallback: 'pending').toLowerCase();
    final timeline = <_TimelineStep>[
      const _TimelineStep(
        title: 'Order Received',
        subtitleLines: ['Order created'],
        state: _StepState.done,
      ),
      _TimelineStep(
        title: 'Payment Confirmed',
        subtitleLines: ['Awaiting confirmation'],
        state: status.contains('paid') || status.contains('processing')
            ? _StepState.done
            : _StepState.current,
      ),
      _TimelineStep(
        title: 'Processing Order',
        subtitleLines: ['Preparing shipment'],
        state: status.contains('ship') || status.contains('deliver')
            ? _StepState.done
            : status.contains('processing')
                ? _StepState.current
                : _StepState.upcoming,
      ),
      _TimelineStep(
        title: 'Shipped',
        subtitleLines: ['Pending action'],
        state: status.contains('ship') || status.contains('deliver')
            ? _StepState.done
            : _StepState.upcoming,
      ),
    ];

    final subtotal = raw['subtotal'] ?? raw['subTotal'] ?? raw['totalBeforeTax'] ?? 0;
    final shippingAmount = raw['shipping'] ?? raw['shippingAmount'] ?? 0;
    final tax = raw['tax'] ?? raw['taxAmount'] ?? 0;
    final total = raw['total'] ?? raw['grandTotal'] ?? subtotal;

    final address = [
      _pickString(shipping, ['name'], fallback: _pickString(customer, ['name'], fallback: 'Customer')),
      _pickString(shipping, ['line1', 'address1', 'address'], fallback: ''),
      _pickString(shipping, ['line2', 'address2'], fallback: ''),
      [
        _pickString(shipping, ['city'], fallback: ''),
        _pickString(shipping, ['state'], fallback: ''),
        _pickString(shipping, ['postalCode', 'zip'], fallback: ''),
      ].where((e) => e.isNotEmpty).join(', '),
      _pickString(shipping, ['country'], fallback: ''),
    ].where((e) => e.isNotEmpty).join('\n');

    return _OrderDetailData(
      code: code,
      itemsCategorySubtitle: '${lineItems.length} items',
      premiumCustomer: false,
      lineItems: lineItems,
      subtotal: _formatMoney(subtotal, currency: currency),
      shipping: _formatMoney(shippingAmount, currency: currency),
      tax: _formatMoney(tax, currency: currency),
      total: _formatMoney(total, currency: currency),
      customerName: _pickString(customer, ['name', 'fullName'], fallback: 'Customer'),
      customerEmail: _pickString(customer, ['email'], fallback: '—'),
      customerPhone: _pickString(customer, ['phone', 'phoneNumber'], fallback: '—'),
      shippingAddress: address.isEmpty ? '—' : address,
      timeline: timeline,
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openMap(BuildContext context, String address) async {
    final q = Uri.encodeComponent(address.replaceAll('\n', ' '));
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        _toast(context, 'Could not open maps');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fallbackData = _demo[orderKey] ??
        _OrderDetailData(
          code: orderKey,
          itemsCategorySubtitle: 'Items',
          premiumCustomer: false,
          lineItems: const [],
          subtotal: '\$0.00',
          shipping: '\$0.00',
          tax: '\$0.00',
          total: '\$0.00',
          customerName: '—',
          customerEmail: '—',
          customerPhone: '—',
          shippingAddress: '—',
          timeline: const [],
        );
    final liveOrder = ref.watch(orderDetailProvider(orderKey));
    final isLiveData = liveOrder.asData?.value != null;
    final data = liveOrder.when(
      data: (raw) => raw == null ? fallbackData : _mapApiOrderToDetail(raw, orderKey),
      loading: () => fallbackData,
      error: (_, __) => fallbackData,
    );

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => context.pop(),
                    color: _navyTitle,
                  ),
                  Expanded(
                    child: Text(
                      'Order #${data.code}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: _navyTitle,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  ClipOval(
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuBYNcARSFNN-b8ct1FSGr2g6zoPRV3QUjw5sb16F4jJlamo225muiun234Zz8Upd_RN5cmauNcUJtDBBdX5JMGivANpvGVeZZYdSSFaqriBfrlNSynd6QlbhN0SOE_lLUAESXrz3vaAdPyAtlgZX8vSM9uY0dOw7L6EDgNwOATYzmyZvhXuRcGu9wCqN9Bwbuc2PsIRrfa3XiWPRHzbiLTIROU0MjrVwVfgAe5dNg8kYJttC_aSM6XSPRvXNSlxPeb2UwMU83Kmkp78',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: AppTheme.surfaceContainerLow,
                        alignment: Alignment.center,
                        child: Icon(Icons.person_rounded,
                            color: AppTheme.primary.withValues(alpha: 0.8), size: 22),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_none_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                _DataSourceBadge(isLiveData: isLiveData),
                const SizedBox(height: 12),
                _itemsCard(context, data),
                const SizedBox(height: 16),
                _timelineCard(context, data),
                const SizedBox(height: 16),
                _quickActionsCard(context, data),
                const SizedBox(height: 16),
                _customerCard(context, data),
                const SizedBox(height: 16),
                _shippingCard(context, data),
                const SizedBox(height: 16),
                _OrderNotesCard(orderCode: data.code),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _mobileBottomBar(context, data),
    );
  }

  Widget _itemsCard(BuildContext context, _OrderDetailData data) {
    final theme = Theme.of(context);
    final onCard = theme.colorScheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items Ordered',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.itemsCategorySubtitle,
                      style: GoogleFonts.inter(
                        color: onCard,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.premiumCustomer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _premiumBadgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PREMIUM CUSTOMER',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A2ACF),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ...data.lineItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _itemRow(theme, item),
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _priceRow(theme, 'Subtotal', data.subtotal, isTotal: false, onCard: onCard),
                const SizedBox(height: 10),
                _priceRow(theme, 'Shipping (Standard)', data.shipping, isTotal: false, onCard: onCard),
                const SizedBox(height: 10),
                _priceRow(theme, 'Estimated Tax', data.tax, isTotal: false, onCard: onCard),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                _priceRow(theme, 'Total', data.total, isTotal: true, onCard: onCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _itemRow(ThemeData theme, _LineItem item) {
    Widget thumb;
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          height: 64,
          child: CachedNetworkImage(
            imageUrl: item.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => ColoredBox(
              color: _itemTileBg,
              child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            errorWidget: (_, __, ___) => ColoredBox(
              color: item.thumbColor,
              child: Icon(Icons.image_not_supported_outlined, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ),
      );
    } else {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.thumbColor,
                Color.lerp(item.thumbColor, Colors.black, 0.15)!,
              ],
            ),
          ),
          child: Icon(Icons.inventory_2_outlined, color: Colors.white.withValues(alpha: 0.9), size: 26),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _itemTileBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          thumb,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.variantQty,
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.price,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _priceRow(
    ThemeData theme,
    String label,
    String value, {
    required bool isTotal,
    required Color onCard,
  }) {
    if (isTotal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: _navyTitle,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: onCard, fontSize: 14),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _timelineCard(BuildContext context, _OrderDetailData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Processing Timeline',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          _Timeline(steps: data.timeline),
        ],
      ),
    );
  }

  Widget _quickActionsCard(BuildContext context, _OrderDetailData data) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C0528).withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryDark, AppTheme.primary],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _toast(context, 'Mark as Shipped (demo)'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Mark as Shipped',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: _surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toast(context, 'Print packing slip (demo)'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.print_outlined, color: theme.colorScheme.onSurface, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Print Packing Slip',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toast(context, 'Cancel order (demo)'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Cancel Order',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
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

  Widget _customerCard(BuildContext context, _OrderDetailData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _premiumBadgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline_rounded, color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Customer Info',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _labeledBlock(context, 'Contact Name', data.customerName, primaryValue: false),
          const SizedBox(height: 14),
          _labeledBlock(context, 'Email Address', data.customerEmail, primaryValue: true),
          const SizedBox(height: 14),
          _labeledBlock(context, 'Phone', data.customerPhone, primaryValue: false),
        ],
      ),
    );
  }

  Widget _labeledBlock(
    BuildContext context,
    String label,
    String value, {
    required bool primaryValue,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: primaryValue ? AppTheme.primary : scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _shippingCard(BuildContext context, _OrderDetailData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _premiumBadgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.location_on_outlined, color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Shipping Address',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _itemTileBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.shippingAddress,
                  style: GoogleFonts.inter(
                    height: 1.45,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _openMap(context, data.shippingAddress),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('View on Map'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _mobileBottomBar(BuildContext context, _OrderDetailData data) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 840) return null;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.06)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TOTAL ORDER',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.total,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => _toast(context, 'Process Order (demo)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: AppTheme.primaryDark.withValues(alpha: 0.35),
                    ),
                    child: Text(
                      'Process Order',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DataSourceBadge extends StatelessWidget {
  const _DataSourceBadge({required this.isLiveData});

  final bool isLiveData;

  @override
  Widget build(BuildContext context) {
    final bg = isLiveData ? const Color(0xFFD1FAE5) : const Color(0xFFFFF4E5);
    final fg = isLiveData ? const Color(0xFF065F46) : const Color(0xFF9A3412);
    final label = isLiveData ? 'LIVE ORDER DATA' : 'FALLBACK ORDER DATA';

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
              style: GoogleFonts.inter(
                color: fg,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderNotesCard extends StatefulWidget {
  const _OrderNotesCard({required this.orderCode});

  final String orderCode;

  @override
  State<_OrderNotesCard> createState() => _OrderNotesCardState();
}

class _OrderNotesCardState extends State<_OrderNotesCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Internal Notes',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add a private note about this order...',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.neutral,
              ),
              filled: true,
              fillColor: AppTheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              final t = _controller.text.trim();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t.isEmpty
                        ? 'Nothing to save'
                        : 'Note saved for ${widget.orderCode} (demo)',
                  ),
                ),
              );
            },
            child: Text(
              'SAVE NOTE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, upcoming }

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.subtitleLines,
    required this.state,
  });

  final String title;
  final List<String> subtitleLines;
  final _StepState state;
}

class _LineItem {
  const _LineItem({
    required this.name,
    required this.variantQty,
    required this.price,
    this.imageUrl,
    this.thumbColor = const Color(0xFF718096),
  });

  final String name;
  final String variantQty;
  final String price;
  final String? imageUrl;
  final Color thumbColor;
}

class _OrderDetailData {
  const _OrderDetailData({
    required this.code,
    required this.itemsCategorySubtitle,
    required this.premiumCustomer,
    required this.lineItems,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.shippingAddress,
    required this.timeline,
  });

  final String code;
  final String itemsCategorySubtitle;
  final bool premiumCustomer;
  final List<_LineItem> lineItems;
  final String subtotal;
  final String shipping;
  final String tax;
  final String total;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String shippingAddress;
  final List<_TimelineStep> timeline;
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});

  final List<_TimelineStep> steps;

  static const Color _lineBlue = Color(0xFF0025CC);
  static const Color _lineMuted = Color(0xFFEFEDED);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;
        final showLine = !isLast;
        final lineActive = step.state == _StepState.done;

        Widget row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Column(
                children: [
                  _StepDot(state: step.state),
                  if (showLine)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 2,
                      height: 40,
                      color: lineActive ? _lineBlue : _lineMuted,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: step.state == _StepState.upcoming
                            ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                            : step.state == _StepState.current
                                ? AppTheme.primary
                                : OrderDetailScreen._navyTitle,
                      ),
                    ),
                    ...step.subtitleLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          line,
                          style: GoogleFonts.inter(
                            color: step.state == _StepState.upcoming
                                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        if (step.state == _StepState.upcoming) {
          row = Opacity(opacity: 0.4, child: row);
        }
        return row;
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.state});

  final _StepState state;

  static const Color _blue = Color(0xFF0025CC);

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: _blue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: 0.35),
                blurRadius: 0,
                spreadRadius: 2,
              ),
            ],
            color: Colors.white,
          ),
          child: Center(
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
            ),
          ),
        );
      case _StepState.upcoming:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.shade400,
              width: 2,
            ),
            color: Colors.white,
          ),
        );
    }
  }
}
