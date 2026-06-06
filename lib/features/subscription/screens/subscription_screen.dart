import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../subscription_plan.dart';
import '../subscription_snapshot_helpers.dart';
import '../providers/subscription_provider.dart';
import '../widgets/mpesa_checkout_sheet.dart';
import '../widgets/pesapal_checkout_webview.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(subscriptionProvider);

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
            final currentLabel = _currentPlanLabel(data);
            final currentId = _currentPlanId(data);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _TrialBanner(data: data, theme: theme),
                SubscriptionAccessBanner(
                  data: data,
                  onRenew: () => _renewPayment(plans, currentId),
                ),
                SubscriptionRenewalCta(
                  data: data,
                  onPayNow: () => _renewPayment(plans, currentId),
                ),
                ScheduledDowngradeChip(data: data),
                const SizedBox(height: 12),
                _SectionTitle(
                  text: 'Current plan',
                  theme: theme,
                ),
                const SizedBox(height: 8),
                _CurrentPlanCard(
                  theme: theme,
                  label: currentLabel ??
                      (currentId != null ? 'Plan $currentId' : 'Not set'),
                ),
                _PesapalConfigStrip(data: data),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionTitle(text: 'Plans', theme: theme),
                    TextButton.icon(
                      onPressed: () => context.push('/billing-history'),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Billing history'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...plans.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PlanCard(
                        plan: p,
                        theme: theme,
                        billingCycle: _billingCycle,
                        onBillingCycleChanged: (v) =>
                            setState(() => _billingCycle = v),
                        isCurrent: currentId != null && _planId(p) == currentId,
                        changeType: planChangeType(p),
                        onMpesa: () => _onMpesa(p),
                        onPesapal: () => _onPesapal(data, p),
                        onActivateFree: () => _onActivateFree(p),
                        onDowngrade: () =>
                            _confirmDowngrade(plans, currentId ?? '', p),
                      ),
                    )),
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

  Future<void> _renewPayment(
    List<Map<String, dynamic>> plans,
    String? currentId,
  ) async {
    Map<String, dynamic>? target;
    if (currentId != null && currentId.isNotEmpty) {
      for (final p in plans) {
        if (_planId(p) == currentId) {
          target = p;
          break;
        }
      }
    }
    if (target == null) {
      for (final p in plans) {
        if (planChangeType(p) == 'upgrade') {
          target = p;
          break;
        }
      }
    }
    target ??= plans.isNotEmpty ? plans.first : null;

    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a plan below to renew with M-Pesa or PesaPal.'),
        ),
      );
      return;
    }

    if (isPlanFreeActivatable(target)) {
      await _onActivateFree(target);
      return;
    }

    await _onMpesa(target);
  }

  Future<void> _onMpesa(Map<String, dynamic> plan) async {
    final id = _planId(plan);
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan identifier.')),
      );
      return;
    }
    final title = _planTitle(plan);
    final ok = await MpesaCheckoutSheet.show(
      context,
      planId: id,
      planTitle: title,
    );
    if (ok == true && mounted) {
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment confirmed. Refreshing plan…')),
      );
    }
  }

  Future<void> _onPesapal(
      Map<String, dynamic> _, Map<String, dynamic> plan) async {
    final id = _planId(plan);
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan identifier.')),
      );
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.initiatePesapalCheckout({
        'planId': id,
        'plan_id': id,
        'billingCycle': _billingCycle,
        'billing_cycle': _billingCycle,
      });

      if (!res.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(res.error?.message ?? 'Could not start PesaPal checkout'),
          ),
        );
        return;
      }

      final body = _unwrapEnvelope(res.data);
      final redirect = _pickString(body, [
        'redirectUrl',
        'redirect_url',
        'checkoutUrl',
        'checkout_url',
        'paymentUrl',
        'payment_url',
        'url',
      ]);

      if (redirect == null || redirect.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No checkout URL returned from server.')),
        );
        return;
      }

      if (!mounted) return;
      final done = await PesapalCheckoutWebView.push(
        context,
        redirectUrl: redirect,
        title: 'PesaPal checkout',
      );
      if (done == true && mounted) {
        await _refreshAll();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _confirmDowngrade(
    List<Map<String, dynamic>> plans,
    String activeId,
    Map<String, dynamic> targetPlan,
  ) async {
    final targetId = _planId(targetPlan);
    final targetTitle =
        _planTitle(targetPlan) ?? (targetId != null ? 'Plan $targetId' : '');
    if (targetId == null || targetId.isEmpty) {
      return;
    }
    if (targetId == activeId) return;

    Map<String, dynamic>? activePlan;
    for (final p in plans) {
      if (_planId(p) == activeId) {
        activePlan = p;
        break;
      }
    }

    final lowerPriceThanActive = activePlan == null ||
        (_extractPrice(activePlan) > _extractPrice(targetPlan) + 0.001);

    if (!lowerPriceThanActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'To move to $targetTitle, pick M‑Pesa or PesaPal ("Subscribe"). Downgrade applies to cheaper plans.'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change plan'),
        content: Text(
          'Schedule downgrade to $targetTitle? Billing rules follow your storefront policy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.activateSubscription({
        'plan_id': targetId,
        'planId': targetId,
        'action': 'downgrade',
        'Action': 'downgrade',
      });
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error?.message ?? 'Plan change failed')),
        );
        return;
      }
      final suffix = _unwrapMessage(res.data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suffix != null
                ? 'Plan change noted: $suffix'
                : 'Plan change submitted.',
          ),
        ),
      );
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _onActivateFree(Map<String, dynamic> plan) async {
    final id = _planId(plan);
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan identifier.')),
      );
      return;
    }
    final title = _planTitle(plan) ?? 'this plan';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activate plan'),
        content:
            Text('Switch to $title now? No payment is required for this plan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Activate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.activateSubscription({
        'plan_id': id,
        'planId': id,
        'action': 'activate',
        'billingCycle': _billingCycle,
        'billing_cycle': _billingCycle,
      });
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res.error?.message ?? 'Could not activate plan')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan activated.')),
      );
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  double _extractPrice(Map<String, dynamic> p) {
    return planMonthlyPriceAmount(p) ?? 0;
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

String? _trialMessage(Map<String, dynamic> data) {
  final merged = {...data};
  final sub = data['subscription'];
  final current = data['currentSubscription'];
  if (sub is Map) merged.addAll(Map<String, dynamic>.from(sub));
  if (current is Map) merged.addAll(Map<String, dynamic>.from(current));

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
      'trialLeft'
    ],
  );
  dur ??= _pickNum(merged, ['daysUntilRenewal', 'days_until_renewal']);

  num? td = _pickNum(merged, ['trialDays', 'trial_days']);
  td ??= _pickNum(merged, ['trialDayCount']);

  final expire = _pickString(
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

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upgrade with M-Pesa STK or PesaPal. Downgrade schedules a lower plan when available.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PesapalConfigStrip extends ConsumerWidget {
  const _PesapalConfigStrip({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pesapalSnap = ref.watch(subscriptionPesapalConfigProvider);
    num? pct = _pickDiscountPercent(data);
    final extra = pesapalSnap.asData?.value;
    if (pct == null && extra != null) {
      pct = _pickDiscountPercent(extra);
    }

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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.theme,
    required this.billingCycle,
    required this.onBillingCycleChanged,
    required this.isCurrent,
    required this.changeType,
    required this.onMpesa,
    required this.onPesapal,
    required this.onActivateFree,
    required this.onDowngrade,
  });

  final Map<String, dynamic> plan;
  final ThemeData theme;
  final String billingCycle;
  final void Function(String) onBillingCycleChanged;
  final bool isCurrent;
  final String? changeType;
  final VoidCallback onMpesa;
  final VoidCallback onPesapal;
  final VoidCallback onActivateFree;
  final VoidCallback onDowngrade;

  bool get _isSamePlan =>
      isCurrent || isPlanChangeSame(plan) || changeType == 'same';

  bool get _showActivation =>
      changeType == 'activation' ||
      (changeType == null && _isFreeActivatable(plan) && !_isSamePlan);

  bool get _showUpgradeActions {
    if (_isSamePlan) return false;
    if (changeType == 'downgrade' || changeType == 'activation') return false;
    if (changeType == 'upgrade') return true;
    return !_isFreeActivatable(plan);
  }

  bool get _showDowngradeAction {
    if (_isSamePlan) return false;
    if (changeType == 'upgrade' || changeType == 'activation') return false;
    if (changeType == 'downgrade') return true;
    return !_isFreeActivatable(plan);
  }

  @override
  Widget build(BuildContext context) {
    final title = _planTitle(plan) ?? _planLabelFallback(plan);

    final desc = _pickString(plan, ['description', 'summary', 'blurb']);

    final prices = formatPlanPriceLines(plan);
    final selectedPrice = billingCycle == 'yearly'
        ? (prices.yearly ?? prices.monthly)
        : (prices.monthly ?? prices.yearly);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: const Text('Current'),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  )
                else if (changeType != null && changeType!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text(changeType!),
                      backgroundColor: AppTheme.surfaceContainerLow,
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (desc != null && desc.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                desc.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (selectedPrice != null) ...[
              Text(
                selectedPrice,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                ),
              ),
              Text(
                billingCycle == 'yearly' ? 'per year' : 'per month',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              if (prices.monthly != null && prices.yearly != null) ...[
                const SizedBox(height: 4),
                Text(
                  billingCycle == 'yearly'
                      ? 'Monthly: ${prices.monthly}'
                      : 'Yearly: ${prices.yearly}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
                ButtonSegment(value: 'yearly', label: Text('Yearly')),
              ],
              selected: {billingCycle},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: AppTheme.surfaceContainerLow,
                foregroundColor: AppTheme.primaryDark,
              ),
              onSelectionChanged: (s) => onBillingCycleChanged(s.first),
            ),
            const SizedBox(height: 14),
            if (_showActivation)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: _btn(theme),
                  onPressed: onActivateFree,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Activate (no payment)'),
                ),
              )
            else if (_showUpgradeActions)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: _btn(theme),
                      onPressed: onMpesa,
                      child: const Text('M-Pesa'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryDark,
                        side:
                            BorderSide(color: theme.colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: onPesapal,
                      child: const Text('PesaPal'),
                    ),
                  ),
                ],
              )
            else if (_isSamePlan)
              Text(
                'This is your current plan.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            if (_showDowngradeAction) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onDowngrade,
                  child: const Text('Downgrade to this plan'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ButtonStyle _btn(ThemeData theme) => FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      );

}

/// --- Parsing helpers -------------------------------------------------------

String? _currentPlanLabel(Map<String, dynamic> data) {
  return _pickString(data, ['planName', 'plan_title', 'currentPlanName']) ??
      _pickString(
          _nestedMap(data, ['currentPlan', 'current_plan', 'subscription']),
          ['name', 'title', 'label', 'planName']);
}

String? _currentPlanId(Map<String, dynamic> data) {
  final direct =
      _pickString(data, ['planId', 'plan_id', 'pricePlanId', 'price_plan_id']);
  if (direct != null) return direct;
  final sub = _nestedMap(data, ['subscription', 'currentSubscription']);
  return _pickString(sub, ['planId', 'plan_id']);
}

Map<String, dynamic>? _nestedMap(Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final v = data[k];
    if (v is Map) return Map<String, dynamic>.from(v);
  }
  return null;
}

String? _pickString(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
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

bool _isFreeActivatable(Map<String, dynamic> p) => isPlanFreeActivatable(p);

String? _planId(Map<String, dynamic> p) =>
    _pickString(p, ['id', 'planId', 'plan_id', 'pricePlanId']);

String? _planTitle(Map<String, dynamic> p) =>
    _pickString(p, ['name', 'title', 'label', 'planName']);

String _planLabelFallback(Map<String, dynamic> p) {
  final id = _planId(p);
  return id != null ? 'Plan $id' : 'Plan';
}

num? _pickDiscountPercent(Map<String, dynamic> data) {
  for (final k in [
    'yearlyDiscountPercent',
    'yearly_discount_percent',
    'pesapalYearlyDiscount',
    'pesapal_yearly_discount',
  ]) {
    final v = data[k];
    final n = v is num ? v : num.tryParse(v?.toString() ?? '');
    if (n != null && n > 0) return n;
  }
  final nested = data['pesapal'];
  if (nested is Map) {
    final m = Map<String, dynamic>.from(nested);
    return _pickDiscountPercent(m);
  }
  return null;
}

Map<String, dynamic>? _unwrapEnvelope(dynamic payload) {
  if (payload is! Map) return null;
  final outer = Map<String, dynamic>.from(payload);
  final inner = outer['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return outer;
}

String? _unwrapMessage(dynamic payload) {
  final m = _unwrapEnvelope(payload);
  if (m == null) return null;
  return _pickString(m, ['message', 'detail', 'status']);
}

