import 'package:dukanest_app/features/analytics/analytics_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAnalyticsViewData', () {
    test('defaults currency to KES and produces empty series when no data', () {
      final v = parseAnalyticsViewData(null, 7);
      expect(v.currencyCode, 'KES');
      expect(v.periodDays, 7);
      expect(v.lineNormalized, isEmpty);
      expect(v.totalRevenueFormatted, 'KES 0.00');
    });

    test('reads explicit currency and total revenue', () {
      final v = parseAnalyticsViewData({
        'currencyCode': 'USD',
        'totalRevenue': 1234.5,
      }, 30);
      expect(v.currencyCode, 'USD');
      expect(v.totalRevenueFormatted, 'USD 1234.50');
    });

    test('sums a numeric series when no explicit total is given', () {
      final v = parseAnalyticsViewData({
        'series': [10, 20, 30],
      }, 7);
      expect(v.totalRevenueFormatted, 'KES 60.00');
      // Normalized points are produced for each series entry.
      expect(v.lineNormalized.length, 3);
      // The max value normalizes to the top of the 0.12..1.0 band.
      expect(v.lineNormalized.last, closeTo(1.0, 1e-9));
    });

    test('extracts series from list of maps with amount/value keys', () {
      final v = parseAnalyticsViewData({
        'revenueSeries': [
          {'amount': 5},
          {'value': 15},
        ],
      }, 7);
      expect(v.totalRevenueFormatted, 'KES 20.00');
    });

    test('normalizes traffic source fractions to sum to 1', () {
      final v = parseAnalyticsViewData({
        'trafficSources': {'direct': 30, 'search': 70},
      }, 7);
      final total = v.trafficSources.fold<double>(0, (a, t) => a + t.fraction);
      expect(total, closeTo(1.0, 1e-9));
      expect(v.trafficSources.map((e) => e.label),
          containsAll(['DIRECT', 'SEARCH']));
    });
  });

  group('parsePnlViewData', () {
    test('derives net revenue, profit and margins when only inputs given', () {
      final p = parsePnlViewData({
        'grossRevenue': 1000,
        'refundsDiscounts': 100,
        'cogs': 400,
        'operatingExpenses': 200,
      });
      expect(p.netRevenue, 900); // 1000 - 100
      expect(p.grossProfit, 500); // 900 - 400
      expect(p.netProfit, 300); // 500 - 200
      expect(p.grossMarginPercent, closeTo(500 / 900 * 100, 1e-9));
      expect(p.netMarginPercent, closeTo(300 / 900 * 100, 1e-9));
    });

    test('prefers explicit net values when provided', () {
      final p = parsePnlViewData({
        'grossRevenue': 1000,
        'netRevenue': 800,
        'netProfit': 250,
      });
      expect(p.netRevenue, 800);
      expect(p.netProfit, 250);
    });

    test('null margins when net revenue is zero (avoids divide-by-zero)', () {
      final p = parsePnlViewData(<String, dynamic>{});
      expect(p.netRevenue, 0);
      expect(p.grossMarginPercent, isNull);
      expect(p.netMarginPercent, isNull);
    });
  });
}
