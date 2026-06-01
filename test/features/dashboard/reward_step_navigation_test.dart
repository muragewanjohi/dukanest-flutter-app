import 'package:dukanest_app/features/dashboard/reward_checklist_data.dart';
import 'package:dukanest_app/features/dashboard/reward_step_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

RewardStep _step({
  required String stepId,
  String href = '',
  bool done = false,
  String actionLabel = 'Continue',
}) {
  return (
    title: stepId,
    subtitle: '',
    done: done,
    stepId: stepId,
    href: href,
    actionLabel: actionLabel,
  );
}

void main() {
  group('rewardStepRoute', () {
    test('maps canonical reward step ids', () {
      expect(
          rewardStepRoute(_step(stepId: 'hero_image')), '/hero-section/edit');
      expect(rewardStepRoute(_step(stepId: 'products_five')), '/products');
      expect(rewardStepRoute(_step(stepId: 'categories_two')), '/categories');
      expect(rewardStepRoute(_step(stepId: 'sale_active')), '/sales');
      expect(
        rewardStepRoute(_step(stepId: 'split_layout_image')),
        '/page-editor/home',
      );
    });

    test('prefers href when it resolves to a mobile route', () {
      expect(
        rewardStepRoute(_step(
          stepId: 'unknown',
          href: '/hero-section/edit',
        )),
        '/hero-section/edit',
      );
    });

    test('maps web page editor href to home page editor', () {
      expect(
        rewardStepRoute(_step(
          stepId: 'banner_updated',
          href: '/dashboard/pages/abc123/edit',
        )),
        '/page-editor/home',
      );
    });
  });
}
