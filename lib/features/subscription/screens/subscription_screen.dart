import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/subscription_provider.dart';
import '../subscription_plan.dart';
import '../subscription_plan_actions.dart';
import '../subscription_snapshot_helpers.dart';
import '../widgets/subscription_payment_options.dart';
import '../widgets/subscription_plan_card.dart';
import '../widgets/subscription_status_banners.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
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
        title: 'Subscription',
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
                title: 'Could not load subscription',
                onRetry: _refreshAll,
              ),
            ],
          ),
          data: (data) {
            final plans = parseAvailablePlans(data);
            final currentPlan = resolveCurrentPlan(data: data, plans: plans);

            num? yearlyDiscount = pickYearlyDiscountPercent(data);
            final extra = pesapalSnap.asData?.value;
            if (yearlyDiscount == null && extra != null) {
              yearlyDiscount = pickYearlyDiscountPercent(extra);
            }

            final showPayment =
                currentPlan != null && !isPlanFreeActivatable(currentPlan);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _TrialBanner(data: data, theme: theme),
                SubscriptionRenewalBanner(
                  data: data,
                  onRenew: () {
                    if (currentPlan != null) {
                      if (isPlanFreeActivatable(currentPlan)) {
                        _actions.activateFree(currentPlan);
                      } else {
                        _actions.payWithTumizi(currentPlan);
                      }
                    }
                  },
                ),
                ScheduledDowngradeChip(data: data),
                const SizedBox(height: 12),
                _SectionTitle(text: 'Current plan', theme: theme),
                const SizedBox(height: 8),
                if (currentPlan != null)
                  SubscriptionPlanCard(
                    plan: currentPlan,
                    theme: theme,
                    billingCycle: _billingCycle,
                    onBillingCycleChanged: (v) =>
                        setState(() => _billingCycle = v),
                    yearlyDiscountPercent: yearlyDiscount,
                    isCurrent: true,
                  )
                else
                  _EmptyCurrentPlanCard(theme: theme),
                _PesapalConfigStrip(
                  data: data,
                  yearlyDiscount: yearlyDiscount,
                ),
                if (showPayment) ...[
                  const SizedBox(height: 20),
                  SubscriptionPaymentOptions(
                    billingCycle: _billingCycle,
                    onMpesa: () => _actions.payWithTumizi(currentPlan),
                    onPesapal: () =>
                        _actions.payWithPesapal(data, currentPlan),
                    mpesaEnabled: true,
                  ),
                ],
                const SizedBox(height: 24),
                _SubscriptionLinksRow(
                  onBillingHistory: () => context.push('/billing-history'),
                  onChangePlan: () => context.push('/change-plan'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.data, required this.theme});

  final Map<String, dynamic> data;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final text = _trialMessage(data);
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.92),
            AppTheme.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCurrentPlanCard extends StatelessWidget {
  const _EmptyCurrentPlanCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'No active plan on file. Use Change plan to pick one.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PesapalConfigStrip extends StatelessWidget {
  const _PesapalConfigStrip({
    required this.data,
    required this.yearlyDiscount,
  });

  final Map<String, dynamic> data;
  final num? yearlyDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = yearlyDiscount;

    if (pct == null || pct <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Save about ${pct.toStringAsFixed(0)}% on yearly billing with PesaPal when your plan supports it.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        color: AppTheme.primaryDark,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SubscriptionLinksRow extends StatelessWidget {
  const _SubscriptionLinksRow({
    required this.onBillingHistory,
    required this.onChangePlan,
  });

  final VoidCallback onBillingHistory;
  final VoidCallback onChangePlan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBillingHistory,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Billing history'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onChangePlan,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Change plan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String? _trialMessage(Map<String, dynamic> data) {
  final merged = {...data};
  final sub = data['subscription'];
  final current = data['currentSubscription'];
  if (sub is Map) merged.addAll(Map<String, dynamic>.from(sub));
  if (current is Map) merged.addAll(Map<String, dynamic>.from(current));

  if (merged['isExpired'] == true) return null;

  final daysUntilExpire =
      _pickNum(merged, ['daysUntilExpire', 'days_until_expire']);
  if (daysUntilExpire != null && daysUntilExpire <= 0) return null;

  final inTrial = merged['inTrial'] == true ||
      merged['in_trial'] == true ||
      merged['trial'] == true;

  num? dur;
  dur = _pickNum(
    merged,
    [
      'trialDaysRemaining',
      'trial_days_remaining',
      'daysRemaining',
      'trialLeft',
    ],
  );
  dur ??= _pickNum(merged, ['daysUntilRenewal', 'days_until_renewal']);

  num? td = _pickNum(merged, ['trialDays', 'trial_days']);
  td ??= _pickNum(merged, ['trialDayCount']);

  final expire = pickSubscriptionString(
    merged,
    ['expireDate', 'expire_date', 'trialEnd', 'trial_end'],
  );
  DateTime? exp;
  if (expire != null) exp = DateTime.tryParse(expire);

  if (dur != null && dur > 0) {
    if (inTrial == true || td != null) {
      return '${dur.ceil()} ${dur == 1 ? 'day' : 'days'} left in your trial.${td != null && td > 0 ? ' (${td.ceil()}-day plan trial)' : ''}';
    }
    return '${dur.ceil()} ${dur == 1 ? 'day' : 'days'} until renewal.';
  }

  if (inTrial && exp != null) {
    final delta = exp.difference(DateTime.now()).inDays.clamp(0, 366);
    if (delta > 0) {
      return '$delta ${delta == 1 ? 'day' : 'days'} left before your subscription renews.';
    }
  }
  return null;
}

num? _pickNum(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v;
    final p = num.tryParse(v?.toString() ?? '');
    if (p != null) return p;
  }
  return null;
}
