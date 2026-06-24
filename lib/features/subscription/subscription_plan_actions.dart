import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import 'subscription_plan.dart';
import 'subscription_snapshot_helpers.dart';
import 'widgets/pesapal_checkout_webview.dart';
import 'widgets/subscription_plan_card.dart';
import 'widgets/tumizi_checkout_sheet.dart';

/// Shared upgrade, downgrade, and checkout flows for subscription screens.
class SubscriptionPlanActions {
  SubscriptionPlanActions({
    required this.ref,
    required this.context,
    required this.billingCycle,
    required this.onRefresh,
  });

  final WidgetRef ref;
  final BuildContext context;
  final String billingCycle;
  final Future<void> Function() onRefresh;

  Future<void> payWithTumizi(Map<String, dynamic> plan) async {
    final id = planId(plan);
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan identifier.')),
      );
      return;
    }
    final title = planTitle(plan);
    final ok = await TumiziCheckoutSheet.show(
      context,
      planId: id,
      planTitle: title,
    );
    if (ok == true && context.mounted) {
      await onRefresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment confirmed. Refreshing plan…')),
      );
    }
  }

  Future<void> payWithPesapal(
    Map<String, dynamic> data,
    Map<String, dynamic> plan,
  ) async {
    final id = planId(plan);
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
        'billingInterval': billingCycle,
      });

      if (!res.success) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(res.error?.message ?? 'Could not start PesaPal checkout'),
          ),
        );
        return;
      }

      final body = _unwrapEnvelope(res.data);
      final redirect = pickSubscriptionString(body, [
        'redirectUrl',
        'redirect_url',
        'checkoutUrl',
        'checkout_url',
        'paymentUrl',
        'payment_url',
        'url',
      ]);

      if (redirect == null || redirect.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No checkout URL returned from server.'),
          ),
        );
        return;
      }

      if (!context.mounted) return;
      final done = await PesapalCheckoutWebView.push(
        context,
        redirectUrl: redirect,
        title: 'PesaPal checkout',
      );
      if (done == true && context.mounted) {
        await onRefresh();
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> confirmDowngrade({
    required List<Map<String, dynamic>> plans,
    required String activeId,
    required Map<String, dynamic> targetPlan,
  }) async {
    final targetId = planId(targetPlan);
    final targetTitle =
        planTitle(targetPlan) ?? (targetId != null ? 'Plan $targetId' : '');
    if (targetId == null || targetId.isEmpty) return;
    if (targetId == activeId) return;

    final activePlan = findPlanById(plans, activeId);
    final lowerPriceThanActive = activePlan == null ||
        ((planMonthlyPriceAmount(activePlan) ?? 0) >
            (planMonthlyPriceAmount(targetPlan) ?? 0) + 0.001);

    if (!lowerPriceThanActive) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'To move to $targetTitle, pick M‑Pesa or PesaPal. Downgrade applies to cheaper plans.',
          ),
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

    if (ok != true || !context.mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.activateSubscription({
        'plan_id': targetId,
        'planId': targetId,
        'action': 'downgrade',
        'Action': 'downgrade',
      });
      if (!context.mounted) return;
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
      await onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> activateFree(Map<String, dynamic> plan) async {
    final id = planId(plan);
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing plan identifier.')),
      );
      return;
    }
    final title = planTitle(plan) ?? 'this plan';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activate plan'),
        content:
            Text('Switch to $title now? No payment is required for this plan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.activateSubscription({
        'plan_id': id,
        'planId': id,
        'action': 'activate',
        'billingCycle': billingCycle,
        'billing_cycle': billingCycle,
      });
      if (!context.mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.error?.message ?? 'Could not activate plan'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan activated.')),
      );
      await onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }
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
  return pickSubscriptionString(m, ['message', 'detail', 'status']);
}

num? pickYearlyDiscountPercent(Map<String, dynamic> data) {
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
    return pickYearlyDiscountPercent(Map<String, dynamic>.from(nested));
  }
  return null;
}
