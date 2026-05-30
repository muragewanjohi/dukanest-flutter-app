import 'package:intl/intl.dart';

/// View-model for rendering an arbitrary analytics segment payload as charts,
/// metric cards, breakdown bars and tables — without hardcoding every segment
/// schema. Robust to the varied shapes returned by
/// `GET /dashboard/analytics/:segment`.
class SegmentView {
  SegmentView({
    required this.metrics,
    required this.series,
    required this.breakdowns,
    required this.tables,
  });

  final List<SegmentMetric> metrics;
  final List<SegmentSeries> series;
  final List<SegmentBreakdown> breakdowns;
  final List<SegmentTable> tables;

  bool get isEmpty =>
      metrics.isEmpty && series.isEmpty && breakdowns.isEmpty && tables.isEmpty;
}

class SegmentMetric {
  SegmentMetric(this.label, this.value, {this.positive});
  final String label;
  final String value;
  final bool? positive;
}

class SegmentSeries {
  SegmentSeries(this.title, this.values, this.labels);
  final String title;
  final List<double> values;
  final List<String> labels;
}

class SegmentBreakdown {
  SegmentBreakdown(this.title, this.rows);
  final String title;
  final List<({String label, double value})> rows;
}

class SegmentTable {
  SegmentTable(this.title, this.columns, this.rows);
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
}

const _labelKeys = [
  'name',
  'label',
  'title',
  'date',
  'day',
  'period',
  'month',
  'week',
  'country',
  'region',
  'city',
  'location',
  'source',
  'channel',
  'product',
  'productName',
  'category',
  'sku',
  'status',
  'key',
  'id',
];

const _valueKeys = [
  'revenue',
  'amount',
  'total',
  'value',
  'count',
  'quantity',
  'qty',
  'sales',
  'orders',
  'views',
  'visits',
  'sessions',
  'users',
  'refunds',
];

const _moneyHints = [
  'revenue',
  'amount',
  'sales',
  'total',
  'profit',
  'cogs',
  'spend',
  'value'
];
const _percentHints = ['percent', 'rate', 'margin', 'share', 'ratio', 'pct'];

String _humanize(String key) {
  final spaced = key
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

bool _keyHints(String key, List<String> hints) {
  final k = key.toLowerCase();
  return hints.any(k.contains);
}

String _formatMetric(String key, num n, String currency) {
  if (_keyHints(key, _percentHints)) {
    final pct = (n > 0 && n <= 1) ? n * 100 : n;
    return '${pct.toStringAsFixed(pct.abs() >= 10 ? 0 : 1)}%';
  }
  if (_keyHints(key, _moneyHints)) {
    return '$currency ${NumberFormat('#,##0').format(n)}';
  }
  return NumberFormat('#,##0.##').format(n);
}

num? _asNum(dynamic v) {
  if (v is num) return v;
  if (v is String) {
    final p = num.tryParse(v.replaceAll(RegExp(r'[^0-9.-]'), ''));
    return p;
  }
  return null;
}

String _findString(Map m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
  }
  return '';
}

({String? key, num value})? _findNumeric(Map m) {
  for (final k in _valueKeys) {
    final n = _asNum(m[k]);
    if (n != null) return (key: k, value: n);
  }
  // Fallback: first numeric field.
  for (final entry in m.entries) {
    final n = _asNum(entry.value);
    if (n != null) return (key: entry.key.toString(), value: n);
  }
  return null;
}

String _currencyOf(Map<String, dynamic> root) {
  for (final m in [root, root['metrics'], root['revenue']]) {
    if (m is Map) {
      final c = m['currencyCode'] ?? m['currency_code'] ?? m['currency'];
      if (c != null && c.toString().trim().isNotEmpty) return c.toString();
    }
  }
  return 'KES';
}

String _shorten(String label) =>
    label.length <= 10 ? label : '${label.substring(0, 9)}…';

void _consume(
  Map<String, dynamic> map,
  String prefix,
  String currency,
  SegmentView out,
  int depth,
) {
  map.forEach((rawKey, value) {
    final key = rawKey.toString();
    if (key == 'currencyCode' || key == 'currency_code' || key == 'currency') {
      return;
    }
    final label =
        prefix.isEmpty ? _humanize(key) : '$prefix · ${_humanize(key)}';

    final n = value is num ? value : (value is String ? null : null);
    if (n != null) {
      out.metrics.add(SegmentMetric(label, _formatMetric(key, n, currency)));
      return;
    }
    if (value is bool) {
      out.metrics
          .add(SegmentMetric(label, value ? 'Yes' : 'No', positive: value));
      return;
    }
    if (value is String) {
      if (value.length <= 24) {
        out.metrics.add(SegmentMetric(label, value));
      }
      return;
    }

    if (value is List) {
      _consumeList(label, value, currency, out);
      return;
    }

    if (value is Map && depth < 2) {
      final m = Map<String, dynamic>.from(value);
      final allNum = m.isNotEmpty && m.values.every((v) => _asNum(v) != null);
      if (allNum && m.length >= 2 && m.length <= 12) {
        out.breakdowns.add(SegmentBreakdown(
          label,
          m.entries
              .map((e) =>
                  (label: _humanize(e.key), value: _asNum(e.value)!.toDouble()))
              .toList(),
        ));
      } else {
        _consume(m, label, currency, out, depth + 1);
      }
    }
  });
}

void _consumeList(
  String label,
  List value,
  String currency,
  SegmentView out,
) {
  if (value.isEmpty) return;

  // All numbers -> time series.
  if (value.every((e) => _asNum(e) != null)) {
    final values = value.map((e) => _asNum(e)!.toDouble()).toList();
    out.series.add(SegmentSeries(label, values, _autoLabels(values.length)));
    return;
  }

  // List of maps.
  final maps =
      value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (maps.isEmpty) return;

  final sample = maps.first;
  final numeric = _findNumeric(sample);

  if (numeric != null && numeric.key != null) {
    final rows = <({String label, double value})>[];
    for (final m in maps) {
      final lbl = _findString(m, _labelKeys);
      final v = _asNum(m[numeric.key]);
      if (v == null) continue;
      rows.add((label: lbl.isEmpty ? '—' : lbl, value: v.toDouble()));
    }
    if (rows.isNotEmpty) {
      // If the label looks like a date sequence, render as a line series;
      // otherwise as a ranked breakdown.
      final looksTemporal = _keyHints(_findStringKey(sample, _labelKeys),
          ['date', 'day', 'month', 'week', 'period']);
      if (looksTemporal) {
        out.series.add(SegmentSeries(
          '$label (${_humanize(numeric.key!)})',
          rows.map((r) => r.value).toList(),
          rows.map((r) => _shorten(r.label)).toList(),
        ));
      } else {
        rows.sort((a, b) => b.value.compareTo(a.value));
        out.breakdowns.add(SegmentBreakdown(
          '$label (${_humanize(numeric.key!)})',
          rows.take(8).toList(),
        ));
      }
      return;
    }
  }

  // Fallback: tabular view.
  final columns = <String>[];
  for (final k in [
    ...(_labelKeys),
    ..._valueKeys,
    ...sample.keys.map((e) => e.toString())
  ]) {
    if (sample.containsKey(k) && !columns.contains(k) && columns.length < 4) {
      columns.add(k);
    }
  }
  if (columns.isEmpty) return;
  final tableRows = maps.take(12).map((m) {
    return columns.map((c) => (m[c] ?? '').toString()).toList();
  }).toList();
  out.tables.add(SegmentTable(
    label,
    columns.map(_humanize).toList(),
    tableRows,
  ));
}

String _findStringKey(Map m, List<String> keys) {
  for (final k in keys) {
    if (m[k] != null && m[k].toString().trim().isNotEmpty) return k;
  }
  return '';
}

List<String> _autoLabels(int n) {
  if (n <= 0) return [];
  final now = DateTime.now();
  final df = n <= 14 ? DateFormat('E') : DateFormat.Md();
  return List<String>.generate(
      n, (i) => df.format(now.subtract(Duration(days: n - 1 - i))));
}

/// Parses an arbitrary analytics segment payload into a renderable [SegmentView].
SegmentView parseSegmentView(Map<String, dynamic> data) {
  final currency = _currencyOf(data);
  final out = SegmentView(metrics: [], series: [], breakdowns: [], tables: []);
  // Many segments wrap the useful payload in `data` or `metrics`.
  final root = (data['data'] is Map)
      ? Map<String, dynamic>.from(data['data'] as Map)
      : data;
  _consume(root, '', currency, out, 0);
  // Cap to keep the pane focused.
  return SegmentView(
    metrics: out.metrics.take(8).toList(),
    series: out.series.take(4).toList(),
    breakdowns: out.breakdowns.take(4).toList(),
    tables: out.tables.take(3).toList(),
  );
}
