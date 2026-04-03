import 'package:intl/intl.dart';

/// Parsed view-model for [AnalyticsScreen] from `GET /dashboard/analytics` `data`.
class AnalyticsViewData {
  const AnalyticsViewData({
    required this.periodDays,
    required this.currencyCode,
    required this.totalRevenueFormatted,
    required this.revenueSubtitle,
    required this.lineNormalized,
    required this.xLabels,
    this.changePercent,
    this.conversionPercent,
    required this.conversionFootnote,
    required this.topProducts,
    this.returningShare,
    required this.trafficSources,
  });

  final int periodDays;
  final String currencyCode;
  final String totalRevenueFormatted;
  final String revenueSubtitle;
  final List<double> lineNormalized;
  final List<String> xLabels;
  final double? changePercent;
  final double? conversionPercent;
  final String conversionFootnote;
  final List<({String name, String sub, String amount})> topProducts;
  final double? returningShare;
  final List<({String label, double fraction})> trafficSources;
}

Map<String, dynamic>? _metricsMap(Map<String, dynamic> root) {
  final m = root['metrics'];
  return m is Map ? Map<String, dynamic>.from(m) : null;
}

Map<String, dynamic>? _revenueNested(Map<String, dynamic> root) {
  final r = root['revenue'];
  return r is Map ? Map<String, dynamic>.from(r) : null;
}

String _currencyFrom(Map<String, dynamic> root) {
  final candidates = [root, _metricsMap(root), _revenueNested(root)];
  for (final m in candidates) {
    if (m == null) continue;
    final c = m['currencyCode'] ?? m['currency_code'];
    if (c != null && c.toString().trim().isNotEmpty) return c.toString();
  }
  return 'KES';
}

String _fmtMoney(num amount, String currency) => '$currency ${amount.toStringAsFixed(2)}';

List<num> _seriesFromList(List<dynamic>? list) {
  if (list == null || list.isEmpty) return [];
  final out = <num>[];
  for (final e in list) {
    if (e is num) {
      out.add(e);
    } else if (e is Map) {
      final n = e['amount'] ?? e['value'] ?? e['revenue'] ?? e['total'] ?? e['y'];
      out.add(n is num ? n : 0);
    } else {
      out.add(0);
    }
  }
  return out;
}

List<num> _extractSeries(Map<String, dynamic> root) {
  List<num>? fromKey(String key) {
    final v = root[key];
    if (v is! List) return null;
    final s = _seriesFromList(v);
    return s.isEmpty ? null : s;
  }

  for (final key in ['dailySeries', 'revenueSeries', 'series', 'revenueByDay', 'chartData', 'trend']) {
    final r = fromKey(key);
    if (r != null) return r;
  }

  final rev = _revenueNested(root);
  if (rev != null) {
    for (final key in ['dailySeries', 'weeklySeries', 'series', 'byDay', 'periodSeries']) {
      final v = rev[key];
      if (v is List) {
        final s = _seriesFromList(v);
        if (s.isNotEmpty) return s;
      }
    }
  }

  final metrics = _metricsMap(root);
  if (metrics != null) {
    final rm = metrics['revenue'];
    if (rm is Map) {
      final rmap = Map<String, dynamic>.from(rm);
      for (final key in ['dailySeries', 'weeklySeries', 'series', 'periodSeries', 'last7Days']) {
        final v = rmap[key];
        if (v is List) {
          final s = _seriesFromList(v);
          if (s.isNotEmpty) return s;
        }
      }
    }
  }

  return [];
}

num _extractTotalRevenue(Map<String, dynamic> root, List<num> series) {
  num? pick(dynamic v) => v is num ? v : null;

  final direct = pick(root['totalRevenue']) ??
      pick(root['revenueTotal']) ??
      pick(root['total_revenue']);
  if (direct != null) return direct;

  final summary = root['summary'];
  if (summary is Map) {
    final s = pick(Map<String, dynamic>.from(summary)['revenue'] ??
        Map<String, dynamic>.from(summary)['totalRevenue']);
    if (s != null) return s;
  }

  final revRaw = root['revenue'];
  if (revRaw is num) return revRaw;

  final rev = _revenueNested(root);
  if (rev != null) {
    for (final k in ['periodTotal', 'total', 'paid', 'amount', 'monthlyPaid', 'weeklyPaid']) {
      final v = pick(rev[k]);
      if (v != null) return v;
    }
  }

  final metrics = _metricsMap(root);
  if (metrics != null) {
    final rm = metrics['revenue'];
    if (rm is Map) {
      final rmap = Map<String, dynamic>.from(rm);
      for (final k in ['periodTotal', 'monthlyPaid', 'weeklyPaid', 'total', 'amount']) {
        final v = pick(rmap[k]);
        if (v != null) return v;
      }
    }
  }

  if (series.isNotEmpty) return series.fold<num>(0, (a, b) => a + b);
  return 0;
}

List<double> _normalizeLinePoints(List<num> values) {
  if (values.isEmpty) return [];
  final doubles = values.map((e) => e.toDouble()).toList();
  var max = 0.0;
  for (final n in doubles) {
    if (n > max) max = n;
  }
  if (max <= 0) {
    return List<double>.filled(doubles.length, 0.08);
  }
  return doubles.map((v) => 0.12 + 0.88 * (v / max).clamp(0.0, 1.0)).toList();
}

List<String> _labelsForSeries(int length, int periodDays) {
  if (length <= 0) return [];
  final now = DateTime.now();
  final weekday = DateFormat('E');
  final md = DateFormat.Md();
  if (length <= 14) {
    return List<String>.generate(length, (i) {
      final d = now.subtract(Duration(days: length - 1 - i));
      return weekday.format(d);
    });
  }
  return List<String>.generate(length, (i) {
    final d = now.subtract(Duration(days: length - 1 - i));
    return md.format(d);
  });
}

double? _extractChangePercent(Map<String, dynamic> root) {
  double? fromNum(dynamic v) {
    if (v is num) return v.toDouble();
    return null;
  }

  for (final k in [
    'revenueChangePercent',
    'revenue_change_percent',
    'growthPercent',
    'periodChangePercent',
  ]) {
    final p = fromNum(root[k]);
    if (p != null) return p;
  }

  Map<String, dynamic>? rev = _revenueNested(root);
  final metrics = _metricsMap(root);
  if (rev == null && metrics != null && metrics['revenue'] is Map) {
    rev = Map<String, dynamic>.from(metrics['revenue'] as Map);
  }

  if (rev != null) {
    for (final k in [
      'weekOverWeekChangePercent',
      'weekOverWeekPercent',
      'wowPercent',
      'monthOverMonthChangePercent',
      'momPercent',
      'periodOverPeriodChangePercent',
      'changePercent',
    ]) {
      final p = fromNum(rev[k]);
      if (p != null) return p;
    }
  }

  return null;
}

double? _extractConversionPercent(Map<String, dynamic> root) {
  double? normalize(dynamic v) {
    if (v is! num) return null;
    final d = v.toDouble();
    if (d > 0 && d <= 1) return d * 100;
    return d;
  }

  for (final k in ['conversionRate', 'conversion_rate']) {
    final p = normalize(root[k]);
    if (p != null) return p;
  }

  final c = root['conversion'];
  if (c is Map) {
    final m = Map<String, dynamic>.from(c);
    final p = normalize(m['rate'] ?? m['percent'] ?? m['value']);
    if (p != null) return p;
  }

  final metrics = _metricsMap(root);
  if (metrics != null) {
    final conv = metrics['conversion'];
    if (conv is Map) {
      final p = normalize(Map<String, dynamic>.from(conv)['rate'] ??
          Map<String, dynamic>.from(conv)['percent']);
      if (p != null) return p;
    }
  }

  return null;
}

String _conversionFootnote(Map<String, dynamic> root) {
  final peer = root['conversionPeerPercentile'] ??
      root['conversion_benchmark_percentile'] ??
      (root['conversion'] is Map
          ? (root['conversion'] as Map)['peerPercentile']
          : null);
  if (peer is num) {
    return 'Higher than ${peer.round()}% of similar stores in your category.';
  }
  return 'Improve checkout, trust signals, and product pages to lift conversions.';
}

List<({String name, String sub, String amount})> _topProducts(
  Map<String, dynamic> root,
  String currency,
) {
  final raw = root['topProducts'] ??
      root['top_products'] ??
      root['bestSellers'] ??
      root['best_sellers'] ??
      root['products'];
  if (raw is! List) return [];

  final out = <({String name, String sub, String amount})>[];
  for (final e in raw.take(5)) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final name = (m['name'] ?? m['title'] ?? m['productName'] ?? 'Product').toString();
    final sold = m['quantitySold'] ?? m['sold'] ?? m['units'] ?? m['count'];
    final rev = m['revenue'] ?? m['total'] ?? m['amount'];
    final soldN = sold is num ? sold.toInt() : int.tryParse('$sold') ?? 0;
    final sub = soldN > 0 ? '$soldN sold in period' : 'Sales in selected period';
    final amount = rev is num ? _fmtMoney(rev.toDouble(), currency) : '—';
    out.add((name: name, sub: sub, amount: amount));
  }
  return out;
}

double? _returningShare(Map<String, dynamic> root) {
  dynamic v = root['returningCustomerShare'] ??
      root['returning_customer_share'] ??
      root['returningShare'];
  if (v == null && root['customers'] is Map) {
    v = Map<String, dynamic>.from(root['customers'] as Map)['returningPercent'] ??
        (root['customers'] as Map)['returning'];
  }
  if (v is! num) return null;
  final d = v.toDouble();
  return d > 1 ? d / 100 : d;
}

List<({String label, double fraction})> _trafficSources(Map<String, dynamic> root) {
  final raw = root['trafficSources'] ?? root['traffic_sources'] ?? root['traffic'] ?? root['channels'];
  if (raw is Map) {
    final rows = <({String label, double fraction})>[];
    raw.forEach((key, value) {
      if (value is! num) return;
      var f = value.toDouble();
      if (f > 1) f = f / 100;
      rows.add((label: key.toString().toUpperCase(), fraction: f));
    });
    final sum = rows.fold<double>(0, (a, t) => a + t.fraction);
    if (sum <= 0) return [];
    return rows.map((t) => (label: t.label, fraction: t.fraction / sum)).toList();
  }
  if (raw is! List) return [];

  final rows = <({String label, double fraction})>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final label = (m['label'] ?? m['source'] ?? m['name'] ?? 'Channel').toString();
    final frac = m['fraction'] ?? m['percent'] ?? m['share'] ?? m['value'];
    if (frac is! num) continue;
    var f = frac.toDouble();
    if (f > 1) f = f / 100;
    rows.add((label: label.toUpperCase(), fraction: f));
  }
  final sum = rows.fold<double>(0, (a, t) => a + t.fraction);
  if (sum <= 0) return [];
  return rows.map((t) => (label: t.label, fraction: t.fraction / sum)).toList();
}

/// Builds UI data from API root map; [periodDays] drives copy (7/30/90).
AnalyticsViewData parseAnalyticsViewData(Map<String, dynamic>? root, int periodDays) {
  final data = root ?? <String, dynamic>{};
  final currency = _currencyFrom(data);
  final series = _extractSeries(data);
  final total = _extractTotalRevenue(data, series);
  final normalized = _normalizeLinePoints(series);
  final labels = _labelsForSeries(normalized.length, periodDays);

  return AnalyticsViewData(
    periodDays: periodDays,
    currencyCode: currency,
    totalRevenueFormatted: _fmtMoney(total.toDouble(), currency),
    revenueSubtitle: 'Revenue trend over the last $periodDays days',
    lineNormalized: normalized,
    xLabels: labels,
    changePercent: _extractChangePercent(data),
    conversionPercent: _extractConversionPercent(data),
    conversionFootnote: _conversionFootnote(data),
    topProducts: _topProducts(data, currency),
    returningShare: _returningShare(data),
    trafficSources: _trafficSources(data),
  );
}
