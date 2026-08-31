import 'dart:math';

/// POS domain models. Hand-written `fromJson` to match the rest of the app
/// (see analytics/models/expense_category.dart). Mirrors the payload of
/// GET /api/v1/mobile/pos/bootstrap and POST /api/v1/mobile/pos/sales.

String? _optString(dynamic v) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

double _toDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int? _toIntOrNull(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Round to 2 decimals the same way the server does (see create-sale.ts round2).
double round2(num n) => (n * 100).roundToDouble() / 100;

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class PosCurrency {
  const PosCurrency({
    required this.code,
    required this.symbol,
    required this.symbolPosition,
    required this.decimalPlaces,
  });

  final String code;
  final String symbol;
  final String symbolPosition; // 'before' | 'after'
  final int decimalPlaces;

  static const fallback = PosCurrency(
    code: 'KES',
    symbol: 'KSh',
    symbolPosition: 'before',
    decimalPlaces: 2,
  );

  factory PosCurrency.fromJson(Map<String, dynamic> j) => PosCurrency(
        code: _optString(j['code']) ?? 'KES',
        symbol: _optString(j['symbol']) ?? 'KSh',
        symbolPosition: _optString(j['symbol_position']) ?? 'before',
        decimalPlaces: _toIntOrNull(j['decimal_places']) ?? 2,
      );

  String format(num amount) {
    final s = amount.toStringAsFixed(decimalPlaces);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final body = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    return symbolPosition == 'after' ? '$body $symbol' : '$symbol $body';
  }
}

class PosTaxConfig {
  const PosTaxConfig({
    required this.enabled,
    required this.rate,
    required this.pricingType,
  });

  final bool enabled;
  final double? rate; // percent
  final String pricingType; // 'inclusive' | 'exclusive'

  static const none =
      PosTaxConfig(enabled: false, rate: null, pricingType: 'exclusive');

  factory PosTaxConfig.fromJson(Map<String, dynamic> j) => PosTaxConfig(
        enabled: j['enabled'] == true,
        rate: j['rate'] == null ? null : _toDouble(j['rate']),
        pricingType: _optString(j['pricing_type']) ?? 'exclusive',
      );
}

class PosPaymentConfig {
  const PosPaymentConfig({
    required this.cashEnabled,
    required this.mpesaEnabled,
    this.mpesaStkEnabled = false,
  });

  final bool cashEnabled;
  final bool mpesaEnabled;

  /// Tumizi customer STK push is live — the POS can charge M-Pesa directly.
  final bool mpesaStkEnabled;

  static const cashOnly =
      PosPaymentConfig(cashEnabled: true, mpesaEnabled: false);

  factory PosPaymentConfig.fromJson(Map<String, dynamic> j) => PosPaymentConfig(
        cashEnabled: j['cash_enabled'] == true,
        mpesaEnabled: j['mpesa_enabled'] == true,
        mpesaStkEnabled: j['mpesa_stk_enabled'] == true,
      );
}

class PosStoreInfo {
  const PosStoreInfo({required this.name, this.phone, this.address});

  final String name;
  final String? phone;
  final String? address;

  factory PosStoreInfo.fromJson(Map<String, dynamic> j) => PosStoreInfo(
        name: _optString(j['name']) ?? 'Store',
        phone: _optString(j['phone']),
        address: _optString(j['address']),
      );
}

class PosSettings {
  const PosSettings({
    required this.currency,
    required this.tax,
    required this.payments,
    required this.store,
  });

  final PosCurrency currency;
  final PosTaxConfig tax;
  final PosPaymentConfig payments;
  final PosStoreInfo store;

  static const empty = PosSettings(
    currency: PosCurrency.fallback,
    tax: PosTaxConfig.none,
    payments: PosPaymentConfig.cashOnly,
    store: PosStoreInfo(name: 'Store'),
  );

  factory PosSettings.fromJson(Map<String, dynamic> j) => PosSettings(
        currency: PosCurrency.fromJson(_asMap(j['currency'])),
        tax: PosTaxConfig.fromJson(_asMap(j['tax'])),
        payments: PosPaymentConfig.fromJson(_asMap(j['payments'])),
        store: PosStoreInfo.fromJson(_asMap(j['store'])),
      );
}

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

class PosCatalogVariant {
  const PosCatalogVariant({
    required this.id,
    required this.productId,
    required this.price,
    this.sku,
    this.barcode,
    this.stockQuantity,
    this.label = '',
  });

  final String id;
  final String productId;
  final double price;
  final String? sku;
  final String? barcode;
  final int? stockQuantity;
  final String label; // e.g. "Red / L"

  factory PosCatalogVariant.fromJson(Map<String, dynamic> j, double productPrice) {
    final attrs = (j['attributes'] is List)
        ? (j['attributes'] as List)
            .whereType<Map>()
            .map((a) => _optString(a['value']) ?? '')
            .where((v) => v.isNotEmpty)
            .toList()
        : const <String>[];
    return PosCatalogVariant(
      id: _optString(j['id']) ?? '',
      productId: _optString(j['product_id']) ?? '',
      price: j['price'] == null ? productPrice : _toDouble(j['price'], productPrice),
      sku: _optString(j['sku']),
      barcode: _optString(j['barcode']),
      stockQuantity: _toIntOrNull(j['stock_quantity']),
      label: attrs.join(' / '),
    );
  }

  bool matches(String q) {
    final n = q.toLowerCase();
    return label.toLowerCase().contains(n) ||
        (sku?.toLowerCase().contains(n) ?? false) ||
        (barcode?.toLowerCase().contains(n) ?? false);
  }
}

class PosCatalogProduct {
  const PosCatalogProduct({
    required this.id,
    required this.name,
    required this.price,
    this.sku,
    this.barcode,
    this.image,
    this.stockQuantity,
    this.hasVariants = false,
    this.variants = const [],
  });

  final String id;
  final String name;

  /// Effective sell price (sale_price when present, else price).
  final double price;
  final String? sku;
  final String? barcode;
  final String? image;
  final int? stockQuantity;
  final bool hasVariants;
  final List<PosCatalogVariant> variants;

  factory PosCatalogProduct.fromJson(Map<String, dynamic> j) {
    final base = _toDouble(j['price']);
    final sale = j['sale_price'] == null ? null : _toDouble(j['sale_price']);
    final effective = (sale != null && sale > 0) ? sale : base;
    final rawVariants = (j['variants'] is List) ? j['variants'] as List : const [];
    return PosCatalogProduct(
      id: _optString(j['id']) ?? '',
      name: _optString(j['name']) ?? 'Product',
      price: effective,
      sku: _optString(j['sku']),
      barcode: _optString(j['barcode']),
      image: _optString(j['image']),
      stockQuantity: _toIntOrNull(j['stock_quantity']),
      hasVariants: j['has_variants'] == true || rawVariants.isNotEmpty,
      variants: rawVariants
          .whereType<Map>()
          .map((v) => PosCatalogVariant.fromJson(
              Map<String, dynamic>.from(v), effective))
          .where((v) => v.id.isNotEmpty)
          .toList(),
    );
  }

  bool matches(String q) {
    if (q.trim().isEmpty) return true;
    final n = q.toLowerCase();
    return name.toLowerCase().contains(n) ||
        (sku?.toLowerCase().contains(n) ?? false) ||
        (barcode?.toLowerCase().contains(n) ?? false) ||
        variants.any((v) => v.matches(n));
  }
}

class PosBootstrap {
  const PosBootstrap({
    required this.settings,
    required this.products,
    this.capturedAt,
  });

  final PosSettings settings;
  final List<PosCatalogProduct> products;
  final DateTime? capturedAt;

  factory PosBootstrap.fromData(Map<String, dynamic> data) {
    final rawProducts =
        (data['products'] is List) ? data['products'] as List : const [];
    return PosBootstrap(
      settings: PosSettings.fromJson(_asMap(data['settings'])),
      products: rawProducts
          .whereType<Map>()
          .map((p) => PosCatalogProduct.fromJson(Map<String, dynamic>.from(p)))
          .where((p) => p.id.isNotEmpty)
          .toList(),
      capturedAt: DateTime.tryParse(_optString(data['captured_at']) ?? ''),
    );
  }
}

// ---------------------------------------------------------------------------
// Sale result (POST /pos/sales response)
// ---------------------------------------------------------------------------

class PosOversoldLine {
  const PosOversoldLine({
    required this.name,
    required this.available,
    required this.sold,
  });

  final String name;
  final int available;
  final int sold;

  factory PosOversoldLine.fromJson(Map<String, dynamic> j) => PosOversoldLine(
        name: _optString(j['name']) ?? 'Item',
        available: _toIntOrNull(j['available']) ?? 0,
        sold: _toIntOrNull(j['sold']) ?? 0,
      );
}

class PosSaleResult {
  const PosSaleResult({
    required this.id,
    required this.orderNumber,
    required this.receiptNumber,
    required this.total,
    this.invoiceNumber,
    this.subtotal = 0,
    this.discountTotal = 0,
    this.taxAmount = 0,
    this.amountTendered,
    this.changeDue,
    this.paymentStatus = 'paid',
    this.status = 'completed',
    this.oversold = const [],
    this.overLimit = false,
    this.deduplicated = false,
    this.requiresPaymentConfirmation = false,
    this.tumiziExternalReference,
    this.createdAt,
  });

  final String id;
  final String orderNumber;
  final String receiptNumber;
  final double total;
  final String? invoiceNumber;
  final double subtotal;
  final double discountTotal;
  final double taxAmount;
  final double? amountTendered;
  final double? changeDue;
  final String paymentStatus;
  final String status;
  final List<PosOversoldLine> oversold;
  final bool overLimit;
  final bool deduplicated;

  /// M-Pesa sale: the STK push was sent and payment is still `pending`.
  final bool requiresPaymentConfirmation;
  final String? tumiziExternalReference;
  final DateTime? createdAt;

  bool get isPaid => paymentStatus == 'paid';

  PosSaleResult copyWith({String? paymentStatus}) => PosSaleResult(
        id: id,
        orderNumber: orderNumber,
        receiptNumber: receiptNumber,
        total: total,
        invoiceNumber: invoiceNumber,
        subtotal: subtotal,
        discountTotal: discountTotal,
        taxAmount: taxAmount,
        amountTendered: amountTendered,
        changeDue: changeDue,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        status: status,
        oversold: oversold,
        overLimit: overLimit,
        deduplicated: deduplicated,
        requiresPaymentConfirmation: requiresPaymentConfirmation,
        tumiziExternalReference: tumiziExternalReference,
        createdAt: createdAt,
      );

  factory PosSaleResult.fromJson(Map<String, dynamic> j) {
    final rawOversold =
        (j['oversold'] is List) ? j['oversold'] as List : const [];
    return PosSaleResult(
      id: _optString(j['id']) ?? '',
      orderNumber: _optString(j['order_number']) ?? '',
      receiptNumber: _optString(j['receipt_number']) ?? '',
      total: _toDouble(j['total']),
      invoiceNumber: _optString(j['invoice_number']),
      subtotal: _toDouble(j['subtotal']),
      discountTotal: _toDouble(j['discount_total']),
      taxAmount: _toDouble(j['tax_amount']),
      amountTendered:
          j['amount_tendered'] == null ? null : _toDouble(j['amount_tendered']),
      changeDue: j['change_due'] == null ? null : _toDouble(j['change_due']),
      paymentStatus: _optString(j['payment_status']) ?? 'paid',
      status: _optString(j['status']) ?? 'completed',
      oversold: rawOversold
          .whereType<Map>()
          .map((o) => PosOversoldLine.fromJson(Map<String, dynamic>.from(o)))
          .toList(),
      overLimit: j['over_limit'] == true,
      deduplicated: j['deduplicated'] == true,
      requiresPaymentConfirmation: j['requires_payment_confirmation'] == true,
      tumiziExternalReference: _optString(j['tumizi_external_reference']),
      createdAt: DateTime.tryParse(_optString(j['created_at']) ?? ''),
    );
  }
}

// ---------------------------------------------------------------------------
// Local identifiers
// ---------------------------------------------------------------------------

/// RFC-4122 v4 UUID without a package dependency. The server validates
/// `client_sale_id` with Zod v4's strict UUID (version + variant nibbles), so
/// the version (0x40) and variant (0x80) bits must be set correctly.
String posUuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}
