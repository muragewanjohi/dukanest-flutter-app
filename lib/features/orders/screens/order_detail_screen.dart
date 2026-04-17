import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/pending_orders_count_provider.dart';

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
    Map<String, dynamic>? parseDetailPayload(dynamic data) {
      if (data is! Map<String, dynamic>) return null;
      final raw = data['order'] ?? data['item'] ?? data;
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    }

    bool looksLikeOrderCode(String value) =>
        RegExp(r'^[A-Za-z]{2,}-\d{6,}(-\d+)?$').hasMatch(value.trim());

    Future<String?> resolveOrderIdFromList(String key) async {
      final lookupResponse = await api.getOrders(
        page: 1,
        // use a broader window since some backends use contains/fuzzy search
        // and may not return the exact code as the first item.
        limit: 50,
        search: key,
      );
      if (!lookupResponse.success || lookupResponse.data == null) return null;
      final lookupPayload = lookupResponse.data;
      final list = lookupPayload is Map<String, dynamic>
          ? (lookupPayload['items'] ?? lookupPayload['orders'] ?? lookupPayload['data'])
          : lookupPayload;
      if (list is! List || list.isEmpty) return null;

      for (final raw in list.whereType<Map>()) {
        final map = Map<String, dynamic>.from(raw);
        final code = (map['code'] ?? map['orderNumber'] ?? map['order_number'] ?? '')
            .toString()
            .trim();
        final id = (map['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        if (code == key || key == id) return id;
      }

      // Fallback to first valid ID if exact code match wasn't found.
      for (final raw in list.whereType<Map>()) {
        final id = (raw['id'] ?? '').toString().trim();
        if (id.isNotEmpty) return id;
      }
      return null;
    }

    final key = orderKey.trim();
    if (key.isEmpty) return null;

    // If routed with an order code (e.g. ORD-20260414-799953), resolve to ID first.
    if (looksLikeOrderCode(key)) {
      final resolvedId = await resolveOrderIdFromList(key);
      if (resolvedId != null) {
        final resolvedResponse = await api.getOrderDetail(resolvedId);
        if (resolvedResponse.success && resolvedResponse.data != null) {
          return parseDetailPayload(resolvedResponse.data);
        }
      }
    }

    // Attempt direct fetch (works when orderKey is already an API ID).
    try {
      final directResponse = await api.getOrderDetail(key);
      if (directResponse.success && directResponse.data != null) {
        final direct = parseDetailPayload(directResponse.data);
        if (direct != null) return direct;
      }
    } on DioException {
      // Fall through to lookup fallback below.
    }

    // Fallback: resolve by order code through list search, then fetch detail by id.
    final resolvedId = await resolveOrderIdFromList(key);
    if (resolvedId == null || resolvedId.isEmpty) return null;

    final resolvedResponse = await api.getOrderDetail(resolvedId);
    if (!resolvedResponse.success || resolvedResponse.data == null) return null;
    return parseDetailPayload(resolvedResponse.data);
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

  static String _pickString(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value;
      if (value is num) return value.toString();
    }
    return fallback;
  }

  /// Walks a dot-path like `product.images.0` through nested maps/lists and
  /// returns the first non-empty string found, or '' if missing.
  static String _pickPath(Map<String, dynamic> root, String path) {
    dynamic cursor = root;
    for (final seg in path.split('.')) {
      if (cursor is Map) {
        cursor = cursor[seg];
      } else if (cursor is List) {
        final idx = int.tryParse(seg);
        if (idx == null || idx < 0 || idx >= cursor.length) return '';
        cursor = cursor[idx];
      } else {
        return '';
      }
      if (cursor == null) return '';
    }
    if (cursor is String) return cursor.trim();
    if (cursor is num) return cursor.toString();
    return '';
  }

  static String _pickFirstPath(Map<String, dynamic> root, List<String> paths) {
    for (final p in paths) {
      final value = _pickPath(root, p);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static num? _pickNum(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final raw = map[key];
      if (raw is num) return raw;
      if (raw is String) {
        final parsed = num.tryParse(raw.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String _formatMoney(dynamic value, {String currency = 'KES'}) {
    num? numeric;
    if (value is num) {
      numeric = value;
    } else if (value is String) {
      numeric = num.tryParse(value.trim());
      if (numeric == null && value.trim().isNotEmpty) return value;
    }
    if (numeric != null) return '$currency ${numeric.toStringAsFixed(2)}';
    return '$currency 0.00';
  }

  static _OrderDetailData _mapApiOrderToDetail(Map<String, dynamic> raw, String fallbackCode) {
    final customerRaw = raw['customer'] ?? raw['buyer'] ?? raw['user'];
    final customer = customerRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(customerRaw)
        : <String, dynamic>{};
    final shippingRaw = raw['shippingAddress'] ??
        raw['shipping_address'] ??
        raw['shipping'] ??
        raw['shippingDetails'];
    final shipping = shippingRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(shippingRaw)
        : <String, dynamic>{};
    final currency = _pickString(raw, ['currencyCode', 'currency_code', 'currency'], fallback: 'KES');
    final code = _pickString(
      raw,
      ['code', 'orderNumber', 'order_number', 'orderCode', 'id'],
      fallback: fallbackCode,
    );
    final apiId = _pickString(raw, ['id', 'orderId', 'order_id', '_id'], fallback: '');

    final itemsRaw = raw['items'] ??
        raw['lineItems'] ??
        raw['line_items'] ??
        raw['orderItems'] ??
        raw['order_items'] ??
        const [];
    final itemList = itemsRaw is List ? itemsRaw : const [];
    final lineItems = itemList.whereType<Map>().map((entry) {
      final item = Map<String, dynamic>.from(entry);
      final qty = item['quantity'] ?? item['qty'] ?? 1;
      final variant = _pickString(
        item,
        ['variant', 'variantName', 'variant_name', 'option', 'sku'],
        fallback: 'Standard',
      );
      final priceValue = item['total'] ??
          item['totalPrice'] ??
          item['total_price'] ??
          item['price'] ??
          item['unitPrice'] ??
          item['unit_price'] ??
          0;
      final image = _pickFirstPath(item, [
        'image',
        'imageUrl',
        'image_url',
        'thumbnail',
        'thumbnailUrl',
        'thumbnail_url',
        'productImage',
        'product_image',
        'product.image',
        'product.imageUrl',
        'product.image_url',
        'product.thumbnail',
        'product.thumbnailUrl',
        'product.thumbnail_url',
        'product.images.0',
        'product.images.0.url',
        'images.0',
        'images.0.url',
        'variant.image',
        'variant.imageUrl',
        'variant.image_url',
      ]);
      final flatName = _pickString(
        item,
        ['name', 'title', 'productName', 'product_name'],
        fallback: '',
      );
      final nestedName = flatName.isEmpty
          ? _pickFirstPath(item, ['product.name', 'product.title', 'variant.name'])
          : flatName;
      return _LineItem(
        name: nestedName.isEmpty ? 'Item' : nestedName,
        variantQty: '$variant • Qty: $qty',
        price: _formatMoney(priceValue, currency: currency),
        thumbColor: const Color(0xFF718096),
        imageUrl: image.isEmpty ? null : image,
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

    // Totals — support snake_case, grand/amount aliases, and nested totals object.
    final totalsRaw = raw['totals'] ?? raw['summary'];
    final totals = totalsRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(totalsRaw)
        : <String, dynamic>{};
    final subtotal = _pickNum(raw, ['subtotal', 'subTotal', 'sub_total', 'totalBeforeTax', 'total_before_tax']) ??
        _pickNum(totals, ['subtotal', 'subTotal', 'sub_total']) ??
        0;
    final shippingAmount = _pickNum(raw, [
          'shippingAmount',
          'shipping_amount',
          'shipping_total',
          'shippingTotal',
          'deliveryFee',
          'delivery_fee',
        ]) ??
        _pickNum(shipping, ['amount', 'fee', 'cost']) ??
        _pickNum(totals, ['shipping', 'shippingAmount']) ??
        // Only treat a bare `shipping` key as an amount when it isn't the
        // nested address object above.
        (raw['shipping'] is num ? raw['shipping'] as num : 0);
    final tax = _pickNum(raw, ['tax', 'taxAmount', 'tax_amount', 'totalTax', 'total_tax']) ??
        _pickNum(totals, ['tax', 'taxAmount']) ??
        0;
    final total = _pickNum(raw, [
          'total',
          'grandTotal',
          'grand_total',
          'totalAmount',
          'total_amount',
          'amountTotal',
          'amount_total',
          'amount',
          'orderTotal',
          'order_total',
        ]) ??
        _pickNum(totals, ['total', 'grandTotal', 'grand_total']) ??
        subtotal;

    // Customer — fall back to top-level order-scoped fields that the list
    // endpoint already exposes (`customerName`, `customer_name`, `email`, ...).
    final customerName = _pickString(
      customer,
      ['name', 'fullName', 'full_name', 'displayName', 'display_name'],
      fallback: _pickString(
        raw,
        ['customerName', 'customer_name', 'buyerName', 'buyer_name', 'billingName', 'billing_name'],
        fallback: _pickFirstPath(raw, ['billingAddress.name', 'shippingAddress.name']).isNotEmpty
            ? _pickFirstPath(raw, ['billingAddress.name', 'shippingAddress.name'])
            : 'Customer',
      ),
    );
    final customerEmail = _pickString(
      customer,
      ['email', 'emailAddress', 'email_address'],
      fallback: _pickString(raw, ['customerEmail', 'customer_email', 'email'], fallback: '—'),
    );
    final customerPhone = _pickString(
      customer,
      ['phone', 'phoneNumber', 'phone_number', 'mobile', 'mobileNumber', 'mobile_number'],
      fallback: _pickString(
        raw,
        ['customerPhone', 'customer_phone', 'phone', 'phoneNumber', 'phone_number', 'contactPhone', 'contact_phone'],
        fallback: '—',
      ),
    );

    final address = [
      _pickString(shipping, ['name', 'fullName', 'full_name'], fallback: customerName),
      _pickString(shipping, ['line1', 'address1', 'address_1', 'address', 'street', 'streetAddress', 'street_address'], fallback: ''),
      _pickString(shipping, ['line2', 'address2', 'address_2'], fallback: ''),
      [
        _pickString(shipping, ['city', 'town'], fallback: ''),
        _pickString(shipping, ['state', 'region', 'province'], fallback: ''),
        _pickString(shipping, ['postalCode', 'postal_code', 'zip', 'zipCode', 'zip_code'], fallback: ''),
      ].where((e) => e.isNotEmpty).join(', '),
      _pickString(shipping, ['country', 'countryCode', 'country_code'], fallback: ''),
    ].where((e) => e.isNotEmpty).join('\n');

    return _OrderDetailData(
      apiId: apiId.isEmpty ? code : apiId,
      code: code,
      itemsCategorySubtitle: '${lineItems.length} items',
      premiumCustomer: false,
      lineItems: lineItems,
      subtotal: _formatMoney(subtotal, currency: currency),
      shipping: _formatMoney(shippingAmount, currency: currency),
      tax: _formatMoney(tax, currency: currency),
      total: _formatMoney(total, currency: currency),
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      shippingAddress: address.isEmpty ? '—' : address,
      timeline: timeline,
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _patchOrderStatus(
    BuildContext context,
    WidgetRef ref,
    String status, {
    required String apiId,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.patchOrder(apiId, {'status': status});
      if (!r.success) {
        throw StateError(r.error?.message ?? 'Update failed');
      }
      ref.invalidate(orderDetailProvider(orderKey));
      if (context.mounted) {
        _toast(context, 'Order updated');
      }
    } catch (e) {
      if (context.mounted) {
        _toast(context, 'Update failed: $e');
      }
    }
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
    final liveOrder = ref.watch(orderDetailProvider(orderKey));
    final pendingOrdersCount = ref.watch(pendingOrdersCountProvider).maybeWhen(
          data: (count) => count,
          orElse: () => 0,
        );
    final badgeLabel = pendingOrdersCount > 99 ? '99+' : '$pendingOrdersCount';

    return liveOrder.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: const DashboardAppBar(title: 'Orders'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: const DashboardAppBar(title: 'Orders'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(orderDetailProvider(orderKey)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (raw) {
        if (raw == null) {
          return Scaffold(
            backgroundColor: AppTheme.surface,
            appBar: const DashboardAppBar(title: 'Orders'),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Order could not be loaded.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(orderDetailProvider(orderKey)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final data = _mapApiOrderToDetail(raw, orderKey);
        return _buildOrderScaffold(
          context,
          ref,
          theme,
          data,
          true,
          pendingOrdersCount,
          badgeLabel,
        );
      },
    );
  }

  Widget _buildOrderScaffold(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    _OrderDetailData data,
    bool isLiveData,
    int pendingOrdersCount,
    String badgeLabel,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Orders',
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: pendingOrdersCount > 0,
              label: Text(badgeLabel),
              child: Icon(
                Icons.notifications_none_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                _OrderCodeHeader(code: data.code),
                const SizedBox(height: 12),
                _DataSourceBadge(isLiveData: isLiveData),
                const SizedBox(height: 12),
                _itemsCard(context, data),
                const SizedBox(height: 16),
                _timelineCard(context, data),
                const SizedBox(height: 16),
                _quickActionsCard(context, ref, data),
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
      bottomNavigationBar: _mobileBottomBar(context, ref, data),
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

  Widget _quickActionsCard(BuildContext context, WidgetRef ref, _OrderDetailData data) {
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
                onTap: () => _patchOrderStatus(context, ref, 'shipped', apiId: data.apiId),
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
              onTap: () => _patchOrderStatus(context, ref, 'cancelled', apiId: data.apiId),
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

  Widget? _mobileBottomBar(BuildContext context, WidgetRef ref, _OrderDetailData data) {
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
                    onPressed: () => _patchOrderStatus(context, ref, 'processing', apiId: data.apiId),
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

/// Compact, scannable header that pushes the order code into the page body
/// so the app bar can stay a stable "Orders" section title.
class _OrderCodeHeader extends StatelessWidget {
  const _OrderCodeHeader({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORDER',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '#$code',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.2,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
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
    required this.apiId,
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

  /// The backend-canonical ID used for PATCH/cancel endpoints. Falls back to
  /// [code] when the API didn't return a separate `id` field.
  final String apiId;
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
