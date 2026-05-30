import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Minimal end-to-end smoke scaffold. Run on a device/emulator with:
///   flutter test integration_test/app_smoke_test.dart
///
/// Expand this to drive real flows (launch -> login against a staging tenant
/// or a mocked Dio override -> land on the dashboard). Kept tiny on purpose so
/// the suite stays fast and reliable; heavy flows belong here, not in unit
/// tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app harness renders a frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('smoke'))),
      ),
    );
    expect(find.text('smoke'), findsOneWidget);
  });
}
