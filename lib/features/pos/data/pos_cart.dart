import 'pos_models.dart';

/// One line in the POS cart. [lineKey] is a local id so the same product can
/// appear on multiple lines (e.g. two different discounts).
class PosCartLine {
  const PosCartLine({
    required this.lineKey,
    required this.product,
    this.variant,
    this.quantity = 1,
    this.discountAmount = 0,
  });

  final String lineKey;
  final PosCatalogProduct product;
  final PosCatalogVariant? variant;
  final int quantity;
  final double discountAmount;

  double get unitPrice => variant?.price ?? product.price;

  int? get availableStock => variant?.stockQuantity ?? product.stockQuantity;

  bool get isOversold {
    final s = availableStock;
    return s != null && quantity > s;
  }

  String get displayName =>
      variant != null && variant!.label.isNotEmpty
          ? '${product.name} — ${variant!.label}'
          : product.name;

  double get lineGross => round2(unitPrice * quantity);

  double get lineTotal {
    final d = discountAmount.clamp(0, lineGross).toDouble();
    return round2(lineGross - d);
  }

  PosCartLine copyWith({int? quantity, double? discountAmount}) => PosCartLine(
        lineKey: lineKey,
        product: product,
        variant: variant,
        quantity: quantity ?? this.quantity,
        discountAmount: discountAmount ?? this.discountAmount,
      );

  Map<String, dynamic> toApiItem() => {
        'product_id': product.id,
        'variant_id': variant?.id,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_amount': discountAmount,
      };
}

class PosCart {
  const PosCart({
    this.lines = const [],
    this.orderDiscount = 0,
    this.customerName = '',
    this.customerPhone = '',
    this.notes = '',
  });

  final List<PosCartLine> lines;
  final double orderDiscount;
  final String customerName;
  final String customerPhone;
  final String notes;

  bool get isEmpty => lines.isEmpty;

  int get itemCount =>
      lines.fold<int>(0, (sum, l) => sum + l.quantity);

  bool get hasOversoldLine => lines.any((l) => l.isOversold);

  PosCart copyWith({
    List<PosCartLine>? lines,
    double? orderDiscount,
    String? customerName,
    String? customerPhone,
    String? notes,
  }) =>
      PosCart(
        lines: lines ?? this.lines,
        orderDiscount: orderDiscount ?? this.orderDiscount,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        notes: notes ?? this.notes,
      );
}
