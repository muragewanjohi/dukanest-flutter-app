/// Pure helpers for subscription snapshot maps from `GET /dashboard/subscription`
/// and `GET /dashboard/subscription/billing`.
library;

String? pickSubscriptionString(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
    }
  }
  return null;
}

bool pickSubscriptionBool(Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final v = data[k];
    if (v == true) return true;
    if (v == false) continue;
    if (v is String) {
      final lower = v.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    }
  }
  return false;
}

Map<String, dynamic>? pickSubscriptionMap(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final k in keys) {
    final v = data[k];
    if (v is Map && v.isNotEmpty) return Map<String, dynamic>.from(v);
  }
  return null;
}

/// `full` | `read-only` | `restricted` | `blocked`
String? accessRestrictionLevel(Map<String, dynamic> data) {
  final restriction = pickSubscriptionMap(data, [
    'accessRestriction',
    'access_restriction',
  ]);
  return pickSubscriptionString(restriction, ['level', 'accessLevel', 'access_level']);
}

bool needsRenewalPayment(Map<String, dynamic> data) {
  return pickSubscriptionBool(data, [
    'needsRenewalPayment',
    'needs_renewal_payment',
    'needsPayment',
    'needs_payment',
  ]);
}

bool isExpiringSoon(Map<String, dynamic> data) {
  return pickSubscriptionBool(data, [
    'isExpiringSoon',
    'is_expiring_soon',
    'expiringSoon',
    'expiring_soon',
  ]);
}

bool shouldShowSubscriptionRenewalBanner(Map<String, dynamic> data) {
  final level = accessRestrictionLevel(data);
  if (level != null && level != 'full') return true;
  if (needsRenewalPayment(data)) return true;
  return isExpiringSoon(data);
}

Map<String, dynamic>? scheduledDowngrade(Map<String, dynamic> data) {
  return pickSubscriptionMap(data, [
    'scheduledDowngrade',
    'scheduled_downgrade',
  ]);
}

String scheduledDowngradeLabel(Map<String, dynamic> downgrade) {
  final from = pickSubscriptionString(downgrade, [
    'fromPlanName',
    'from_plan_name',
    'fromPlan',
    'from_plan',
  ]);
  final to = pickSubscriptionString(downgrade, [
    'toPlanName',
    'to_plan_name',
    'toPlan',
    'to_plan',
  ]);
  final date = pickSubscriptionString(downgrade, [
    'effectiveDate',
    'effective_date',
    'date',
  ]);
  final parts = <String>[];
  if (from != null && to != null) {
    parts.add('$from → $to');
  } else if (to != null) {
    parts.add('Downgrade to $to scheduled');
  }
  if (date != null) {
    parts.add('effective $date');
  }
  return parts.isEmpty ? 'Plan downgrade scheduled' : parts.join(' · ');
}

String? planChangeType(Map<String, dynamic> plan) {
  return pickSubscriptionString(plan, [
    'changeType',
    'change_type',
    'planChangeType',
    'plan_change_type',
  ])?.toLowerCase();
}

bool isPlanChangeSame(Map<String, dynamic> plan) {
  final t = planChangeType(plan);
  return t == 'same' || plan['isCurrentPlan'] == true || plan['is_current_plan'] == true;
}

List<Map<String, dynamic>> parseAvailablePlans(Map<String, dynamic> data) {
  for (final key in [
    'availablePlans',
    'available_plans',
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

List<Map<String, dynamic>> extractBillingHistoryRows(Map<String, dynamic> data) {
  for (final key in [
    'billingHistory',
    'billing_history',
    'items',
    'history',
    'billing',
    'invoices',
    'payments',
    'transactions',
    'records',
  ]) {
    final v = data[key];
    if (v is List) {
      final out = <Map<String, dynamic>>[];
      for (final item in v) {
        if (item is Map) out.add(Map<String, dynamic>.from(item));
      }
      if (out.isNotEmpty) return out;
    }
  }
  return const [];
}

String accessRestrictionBannerMessage(String level) {
  switch (level) {
    case 'read-only':
      return 'Your subscription is in a grace period. Renew now to restore full access.';
    case 'restricted':
      return 'Your subscription is suspended. Renew to continue editing your store.';
    case 'blocked':
      return 'This store account is blocked. Contact support if you need help.';
    default:
      return 'Renew your subscription to restore full access.';
  }
}
