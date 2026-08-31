import 'pos_cart.dart';
import 'pos_models.dart';

/// Totals for a POS cart. This is a faithful port of the server-side math in
/// `storeflow/src/lib/pos/create-sale.ts` (steps 3–4) so the amount shown at
/// the counter matches what the order is recorded as.
class PosTotals {
  const PosTotals({
    required this.grossSubtotal,
    required this.discountTotal,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
  });

  final double grossSubtotal;
  final double discountTotal;
  final double subtotal;
  final double taxAmount;
  final double total;

  static const zero = PosTotals(
    grossSubtotal: 0,
    discountTotal: 0,
    subtotal: 0,
    taxAmount: 0,
    total: 0,
  );

  static PosTotals compute({
    required List<PosCartLine> lines,
    required double orderDiscount,
    required PosTaxConfig tax,
  }) {
    double gross = 0;
    double lineDiscount = 0;
    for (final l in lines) {
      final g = round2(l.unitPrice * l.quantity);
      final d = l.discountAmount.clamp(0, g).toDouble();
      gross += g;
      lineDiscount += d;
    }
    gross = round2(gross);
    lineDiscount = round2(lineDiscount);

    final orderDisc =
        orderDiscount.clamp(0, round2(gross - lineDiscount)).toDouble();
    final discountTotal = round2(lineDiscount + orderDisc);
    final subtotal = round2(gross - discountTotal);

    double taxAmount = 0;
    if (tax.enabled && tax.rate != null && tax.rate! > 0) {
      final r = tax.rate! / 100;
      taxAmount = round2(
        tax.pricingType == 'inclusive'
            ? subtotal - subtotal / (1 + r)
            : subtotal * r,
      );
    }

    double total = subtotal;
    if (tax.enabled && tax.rate != null && tax.pricingType == 'exclusive') {
      total = round2(total + taxAmount);
    }

    return PosTotals(
      grossSubtotal: gross,
      discountTotal: discountTotal,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
    );
  }
}
