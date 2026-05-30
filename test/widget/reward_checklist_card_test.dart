import 'package:dukanest_app/features/dashboard/providers/dashboard_reward_checklist_provider.dart';
import 'package:dukanest_app/features/dashboard/widgets/reward_checklist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required Map<String, dynamic>? data}) {
  return ProviderScope(
    overrides: [
      dashboardRewardChecklistProvider.overrideWith((ref) async => data),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: RewardChecklistCard()),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing when the reward program is disabled',
      (tester) async {
    await tester.pumpWidget(_host(data: {
      'reward': {'enabled': false, 'eligible': true},
    }));
    await tester.pumpAndSettle();

    expect(find.text('Onboarding reward'), findsNothing);
  });

  testWidgets('renders headline, progress and step rows when eligible',
      (tester) async {
    await tester.pumpWidget(_host(data: {
      'reward': {
        'enabled': true,
        'eligible': true,
        'bonusDays': 30,
        'daysRemainingInWindow': 5,
      },
      'progressPercent': 50,
      'completedCount': 1,
      'totalCount': 2,
      'items': [
        {'key': 'heroImage', 'completed': true},
        {'key': 'addLogo', 'completed': false},
      ],
    }));
    await tester.pumpAndSettle();

    expect(find.text('Onboarding reward'), findsOneWidget);
    expect(find.text('Earn up to 30 bonus days'), findsOneWidget);
    expect(find.text('1 of 2 steps done'), findsOneWidget);
    // Humanized step titles from the items array.
    expect(find.text('Hero Image'), findsOneWidget);
    expect(find.text('Add Logo'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the granted state copy once the reward is unlocked',
      (tester) async {
    await tester.pumpWidget(_host(data: {
      'reward': {'enabled': true, 'granted': true},
    }));
    await tester.pumpAndSettle();

    expect(find.text('Reward unlocked'), findsOneWidget);
  });
}
