import 'package:dukanest_app/features/dashboard/providers/dashboard_reward_checklist_provider.dart';
import 'package:dukanest_app/features/dashboard/widgets/reward_checklist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _host({required Map<String, dynamic>? data}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: SingleChildScrollView(child: RewardChecklistCard()),
        ),
      ),
      GoRoute(
        path: '/hero-section/edit',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Hero editor'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      dashboardRewardChecklistProvider.overrideWith((ref) async => data),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _expandRewardCard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('reward_checklist_header')));
  await tester.pumpAndSettle();
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

  testWidgets(
      'shows header progress and matches getting-started carousel chrome',
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
        {'id': 'hero_image', 'label': 'Hero image', 'completed': true},
        {'id': 'add_logo', 'label': 'Add logo', 'completed': false},
      ],
    }));
    await tester.pumpAndSettle();

    expect(find.text('Onboarding reward'), findsOneWidget);
    expect(find.text('1/2 done'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('View subscription & plan'), findsNothing);
  });

  testWidgets('step CTA navigates to the target screen', (tester) async {
    await tester.pumpWidget(_host(data: {
      'reward': {'enabled': true, 'eligible': true, 'bonusDays': 30},
      'items': [
        {
          'id': 'hero_image',
          'label': 'Hero image',
          'completed': false,
          'cta': 'Edit hero',
        },
      ],
    }));
    await tester.pumpAndSettle();
    await _expandRewardCard(tester);

    await tester.tap(find.text('Edit hero'));
    await tester.pumpAndSettle();

    expect(find.text('Hero editor'), findsOneWidget);
  });

  testWidgets('expands to show step pager controls', (tester) async {
    await tester.pumpWidget(_host(data: {
      'reward': {'enabled': true, 'eligible': true},
      'items': [
        {'id': 'hero_image', 'label': 'Hero image', 'completed': false},
      ],
    }));
    await tester.pumpAndSettle();
    await _expandRewardCard(tester);

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Step 1 of 1'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('shows the granted state copy once the reward is unlocked',
      (tester) async {
    await tester.pumpWidget(_host(data: {
      'reward': {'enabled': true, 'granted': true},
      'items': [
        {'id': 'hero_image', 'label': 'Hero image', 'completed': true},
      ],
    }));
    await tester.pumpAndSettle();
    await _expandRewardCard(tester);

    expect(
      find.textContaining('subscription was extended'),
      findsOneWidget,
    );
  });
}
