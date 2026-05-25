import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/subscription_provider.dart';
import '../widgets/mpesa_checkout_sheet.dart';
import '../widgets/pesapal_checkout_webview.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
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
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                'Could not load subscription.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          data: (data) {
            if (data == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(22),
                children: [
                  Text(
                    'No subscription snapshot yet.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refreshAll,
                    style: _primaryButton(theme),
                    child: const Text('Retry'),
                  ),
                ],
              );
            }

            final plans = _parsePlans(data);
            final currentLabel = _currentPlanLabel(data);
            final currentId = _currentPlanId(data);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _TrialBanner(data: data, theme: theme),
                const SizedBox(height: 8),
                _SectionTitle(
                  text: 'Current plan',
                  theme: theme,
                ),
                const SizedBox(height: 8),
                _CurrentPlanCard(
                  theme: theme,
                  label:
                      currentLabel ?? (currentId != null ? 'Plan $currentId' : 'Not set'),
                ),
                _UsageBlocks(data: data, theme: theme),
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
                        isCurrent:
                            currentId != null && _planId(p) == currentId,
                        onMpesa: () => _onMpesa(p),
                        onPesapal: () => _onPesapal(data, p),
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

  ButtonStyle _primaryButton(ThemeData theme) => FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

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

  Future<void> _onPesapal(Map<String, dynamic> _, Map<String, dynamic> plan) async {
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
        SnackBar(content: Text('PesaPal error: $e')),
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

    final lowerPriceThanActive =
        activePlan == null ||
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
          SnackBar(
              content:
                  Text(res.error?.message ?? 'Plan change failed')),
        );
        return;
      }
      final suffix = _unwrapMessage(res.data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suffix != null ? 'Plan change noted: $suffix' : 'Plan change submitted.',
          ),
        ),
      );
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  double _extractPrice(Map<String, dynamic> p) {
    final keys = ['monthlyPrice', 'price', 'monthly', 'cost', 'amount'];
    for (final k in keys) {
      final v = p[k];
      final n =
          v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      if (n != null && n >= 0) return n;
    }
    return 0;
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

  final inTrial =
      merged['inTrial'] == true || merged['in_trial'] == true || merged['trial'] == true;

  num? dur;
  dur = _pickNum(
    merged,
    ['trialDaysRemaining', 'trial_days_remaining', 'daysRemaining', 'trialLeft'],
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

class _UsageBlocks extends StatelessWidget {
  const _UsageBlocks({required this.data, required this.theme});

  final Map<String, dynamic> data;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final usage = _pickMap(data, ['usage', 'limits', 'quota', 'usageSummary']);
    if (usage == null || usage.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        _SectionTitle(text: 'Usage & limits', theme: theme),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: usage.entries.map((e) {
            final label = _humanizeKey(e.key);
            final val = e.value?.toString() ?? '—';
            return Chip(
              label: Text('$label: $val'),
              backgroundColor: AppTheme.surfaceContainerLow,
              side: BorderSide.none,
            );
          }).toList(),
        ),
      ],
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
    required this.onMpesa,
    required this.onPesapal,
    required this.onDowngrade,
  });

  final Map<String, dynamic> plan;
  final ThemeData theme;
  final String billingCycle;
  final void Function(String) onBillingCycleChanged;
  final bool isCurrent;
  final VoidCallback onMpesa;
  final VoidCallback onPesapal;
  final VoidCallback onDowngrade;

  @override
  Widget build(BuildContext context) {
    final title = _planTitle(plan) ?? _planLabelFallback(plan);

    final desc = _pickString(plan, ['description', 'summary', 'blurb']);

    final priceMonthly = _formatMaybePrice(plan, 'month');
    final priceYear = _formatMaybePrice(plan, 'year');

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
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.12),
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
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
            if (priceMonthly != null || priceYear != null)
              Text(
                [
                  if (priceMonthly != null) 'Monthly: $priceMonthly',
                  if (priceYear != null) 'Yearly: $priceYear',
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              onSelectionChanged: (s) =>
                  onBillingCycleChanged(s.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: _btn(theme),
                    onPressed: isCurrent ? null : onMpesa,
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
                    onPressed: isCurrent ? null : onPesapal,
                    child: const Text('PesaPal'),
                  ),
                ),
              ],
            ),
            if (!isCurrent) ...[
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

  String? _formatMaybePrice(Map<String, dynamic> p, String mode) {
    final monthlyKeys = [
      'monthlyPrice',
      'price_monthly',
      'monthly_price',
      'priceMonthly',
    ];
    final yearlyKeys = [
      'yearlyPrice',
      'price_yearly',
      'yearly_price',
      'annualPrice',
    ];
    final keysPick = mode == 'month' ? monthlyKeys : yearlyKeys;
    dynamic raw;
    for (final k in keysPick) {
      if (p[k] != null) {
        raw = p[k];
        break;
      }
    }
    if (raw == null && p['pricing'] is Map) {
      final pm = p['pricing'] as Map;
      raw = pm[mode];
      raw ??= mode == 'month' ? pm['monthly'] ?? pm['month'] : pm['yearly'];
    }

    if (raw == null) return null;
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (n == null) return raw.toString();
    return 'KSh ${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2)}';
  }
}

/// --- Parsing helpers -------------------------------------------------------

List<Map<String, dynamic>> _parsePlans(Map<String, dynamic> data) {
  for (final key in [
    'plans',
    'pricePlans',
    'price_plans',
    'catalog',
    'items',
    'subscriptionPlans',
  ]) {
    final v = data[key];
    if (v is! List) continue;
    final out = <Map<String, dynamic>>[];
    for (final item in v) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
    if (out.isNotEmpty) return out;
  }

  final single = data['plan'];
  if (single is Map) return [Map<String, dynamic>.from(single)];
  return const [];
}

Map<String, dynamic>? _pickMap(Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final v = data[k];
    if (v is Map && v.isNotEmpty) return Map<String, dynamic>.from(v);
  }
  return null;
}

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

String _humanizeKey(String k) {
  final s = k.replaceAllMapped(
    RegExp(r'([A-Z])'),
    (m) => ' ${m[1]}',
  );
  return s.replaceAll('_', ' ').trim();
}
