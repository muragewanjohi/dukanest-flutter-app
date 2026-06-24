import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/subscription_provider.dart';
import '../subscription_plan_actions.dart';
import '../subscription_snapshot_helpers.dart';
import '../widgets/subscription_plan_card.dart';

class ChangePlanScreen extends ConsumerStatefulWidget {
  const ChangePlanScreen({super.key});

  @override
  ConsumerState<ChangePlanScreen> createState() => _ChangePlanScreenState();
}

class _ChangePlanScreenState extends ConsumerState<ChangePlanScreen> {
  String _billingCycle = 'monthly';

  Future<void> _refreshAll() async {
    ref.invalidate(subscriptionProvider);
    ref.invalidate(subscriptionPesapalConfigProvider);
    await ref.read(subscriptionProvider.future);
    await ref.read(subscriptionPesapalConfigProvider.future);
  }

  SubscriptionPlanActions get _actions => SubscriptionPlanActions(
        ref: ref,
        context: context,
        billingCycle: _billingCycle,
        onRefresh: _refreshAll,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(subscriptionProvider);
    final pesapalSnap = ref.watch(subscriptionPesapalConfigProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Change plan',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(subscriptionPesapalConfigProvider);
          await Future.wait([
            ref.refresh(subscriptionProvider.future),
            ref.refresh(subscriptionPesapalConfigProvider.future),
          ]);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ApiErrorView(
                error: e,
                title: 'Could not load plans',
                onRetry: _refreshAll,
              ),
            ],
          ),
          data: (data) {
            final plans = parseAvailablePlans(data);
            final currentId = resolveCurrentPlanId(data, plans);

            num? yearlyDiscount = pickYearlyDiscountPercent(data);
            final extra = pesapalSnap.asData?.value;
            if (yearlyDiscount == null && extra != null) {
              yearlyDiscount = pickYearlyDiscountPercent(extra);
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Choose a plan to upgrade, downgrade, or activate.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ...plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SubscriptionPlanCard(
                      plan: plan,
                      theme: theme,
                      billingCycle: _billingCycle,
                      onBillingCycleChanged: (v) =>
                          setState(() => _billingCycle = v),
                      yearlyDiscountPercent: yearlyDiscount,
                      isCurrent:
                          currentId != null && planId(plan) == currentId,
                      changeType: planChangeType(plan),
                      showPlanActions: true,
                      onTumizi: () => _actions.payWithTumizi(plan),
                      onPesapal: () => _actions.payWithPesapal(data, plan),
                      onActivateFree: () => _actions.activateFree(plan),
                      onDowngrade: () => _actions.confirmDowngrade(
                        plans: plans,
                        activeId: currentId ?? '',
                        targetPlan: plan,
                      ),
                    ),
                  ),
                ),
                if (plans.isEmpty)
                  Text(
                    'No plan catalog returned.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
