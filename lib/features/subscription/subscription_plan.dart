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

  final monthly = price([
    'monthlyPrice',
    'price_monthly',
    'monthly_price',
    'priceMonthly',
    'price'
  ]);
  final yearly =
      price(['yearlyPrice', 'price_yearly', 'yearly_price', 'annualPrice']);
  // Only treat as free when at least one price was found and all found are 0.
  final found = [monthly, yearly].where((e) => e >= 0).toList();
  if (found.isEmpty) return false;
  return found.every((e) => e == 0);
}

double? _readPrice(Map<String, dynamic> p, List<String> keys) {
  for (final k in keys) {
    final v = p[k];
    if (v == null) continue;
    if (v is num) return v.toDouble();
    final parsed = double.tryParse(v.toString().trim());
    if (parsed != null) return parsed;
  }
  return null;
}

/// Monthly (or generic) plan price from API maps (`price`, `priceKes`, …).
double? planMonthlyPriceAmount(Map<String, dynamic> p) {
  final direct = _readPrice(p, const [
    'monthlyPrice',
    'priceMonthly',
    'price_monthly',
    'monthly_price',
    'monthly',
    'price',
    'priceKes',
    'price_kes',
    'priceUsd',
    'price_usd',
    'amount',
    'cost',
  ]);
  if (direct != null) return direct;

  final pricing = p['pricing'];
  if (pricing is Map) {
    final pm = Map<String, dynamic>.from(pricing);
    return _readPrice(pm, const [
      'monthly',
      'month',
      'monthlyPrice',
      'price',
      'priceKes',
      'price_kes',
    ]);
  }
  return null;
}

/// Yearly plan price from API maps.
double? planYearlyPriceAmount(Map<String, dynamic> p) {
  final direct = _readPrice(p, const [
    'yearlyPrice',
    'yearly_price',
    'price_yearly',
    'annualPrice',
    'annual_price',
    'yearlyPriceKes',
    'yearly_price_kes',
    'yearlyPriceUsd',
    'yearly_price_usd',
    'yearly',
    'year',
  ]);
  if (direct != null) return direct;

  final pricing = p['pricing'];
  if (pricing is Map) {
    final pm = Map<String, dynamic>.from(pricing);
    return _readPrice(pm, const [
      'yearly',
      'year',
      'yearlyPrice',
      'annual',
      'annualPrice',
    ]);
  }
  return null;
}

String? _planCurrencySymbol(Map<String, dynamic> p) {
  for (final k in const [
    'currencySymbol',
    'currency_symbol',
    'symbol',
  ]) {
    final v = p[k];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
    }
  }
  final code = p['currencyCode'] ?? p['currency_code'] ?? p['currency'];
  if (code == 'USD' || code == 'usd') return '\$';
  if (code == 'KES' || code == 'kes') return 'KSh';
  return 'KSh';
}

String formatPlanPriceAmount(double amount, {String? currencySymbol}) {
  final symbol = currencySymbol ?? 'KSh';
  final rounded = amount == amount.roundToDouble();
  return '$symbol ${amount.toStringAsFixed(rounded ? 0 : 2)}';
}

/// Human-readable monthly/yearly price lines for plan cards.
({String? monthly, String? yearly}) formatPlanPriceLines(
  Map<String, dynamic> p,
) {
  final symbol = _planCurrencySymbol(p);
  final monthlyAmount = planMonthlyPriceAmount(p);
  final yearlyAmount = planYearlyPriceAmount(p);
  return (
    monthly: monthlyAmount == null
        ? null
        : formatPlanPriceAmount(monthlyAmount, currencySymbol: symbol),
    yearly: yearlyAmount == null
        ? null
        : formatPlanPriceAmount(yearlyAmount, currencySymbol: symbol),
  );
}
