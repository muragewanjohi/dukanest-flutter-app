import 'package:dukanest_app/core/widgets/dashboard_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('DashboardPageHeader — showStoreRow: false', () {
    testWidgets('drops the store name and keeps back button beside the title',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const DashboardPageHeader(
          title: 'Customers',
          showStoreRow: false,
          leading: BackButton(),
          actions: [Icon(Icons.refresh)],
        ),
      ));

      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('DukaNest'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // The back button and the title share the same horizontal band.
      final backCentre = tester.getCenter(find.byType(BackButton));
      final titleCentre = tester.getCenter(find.text('Customers'));
      expect((backCentre.dy - titleCentre.dy).abs(), lessThan(24));
    });

    testWidgets('still renders the subtitle when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const DashboardPageHeader(
          title: 'Inventory',
          subtitle: 'Stock counts, alerts, thresholds.',
          showStoreRow: false,
          leading: BackButton(),
        ),
      ));

      expect(find.text('Stock counts, alerts, thresholds.'), findsOneWidget);
    });
  });
}
