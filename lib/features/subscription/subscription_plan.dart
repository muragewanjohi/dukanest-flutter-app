/// Pure helpers for reasoning about subscription plan maps coming from the API.
///
/// Kept free of any widget/Flutter imports so the rules can be unit-tested in
/// isolation.
library;

/// A plan can be activated without payment when it is explicitly free / no
/// payment is required, or all of its discoverable prices are zero.
bool isPlanFreeActivatable(Map<String, dynamic> p) {
  for (final k in ['isFree', 'free', 'allowDirectActivation', 'noPayment']) {
    if (p[k] == true) return true;
  }
  for (final k in ['requiresPayment', 'requires_payment', 'paymentRequired']) {
    if (p[k] == false) return true;
  }

  double price(List<String> keys) {
    for (final k in keys) {
      final v = p[k];
      final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      if (n != null) return n;
    }
    return -1;
  }

  final monthly = price(
      ['monthlyPrice', 'price_monthly', 'monthly_price', 'priceMonthly', 'price']);
  final yearly =
      price(['yearlyPrice', 'price_yearly', 'yearly_price', 'annualPrice']);
  // Only treat as free when at least one price was found and all found are 0.
  final found = [monthly, yearly].where((e) => e >= 0).toList();
  if (found.isEmpty) return false;
  return found.every((e) => e == 0);
}
