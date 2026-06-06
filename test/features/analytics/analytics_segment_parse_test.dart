import 'package:dukanest_app/features/analytics/analytics_segment_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSegmentView', () {
    test('formats period start and end without time', () {
      final view = parseSegmentView({
        'periodStart': '2026-05-01T00:00:00.000Z',
        'periodEnd': '2026-06-06T23:59:59.999Z',
      });

      expect(view.metrics, hasLength(2));
      expect(view.metrics[0].label, 'Period Start');
      expect(view.metrics[0].value, isNot(contains('T')));
      expect(view.metrics[0].value, isNot(contains(':')));
      expect(view.metrics[1].label, 'Period End');
      expect(view.metrics[1].value, isNot(contains('T')));
    });

    test('leaves non-date strings unchanged', () {
      final view = parseSegmentView({'status': 'active'});

      expect(view.metrics, hasLength(1));
      expect(view.metrics.first.value, 'active');
    });
  });
}
