import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../subscription_plan.dart';
import '../subscription_snapshot_helpers.dart';

/// Plan summary card used on subscription and change-plan screens.
class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({
    super.key,
    required this.plan,
    required this.theme,
    required this.billingCycle,
    required this.onBillingCycleChanged,
    required this.yearlyDiscountPercent,
    required this.isCurrent,
    this.changeType,
    this.showBillingToggle = true,
    this.showPlanActions = false,
    this.onTumizi,
    this.onPesapal,
    this.onActivateFree,
    this.onDowngrade,
  });

  final Map<String, dynamic> plan;
  final ThemeData theme;
  final String billingCycle;
  final ValueChanged<String> onBillingCycleChanged;
  final num? yearlyDiscountPercent;
  final bool isCurrent;
  final String? changeType;
  final bool showBillingToggle;
  final bool showPlanActions;
  final VoidCallback? onTumizi;
  final VoidCallback? onPesapal;
  final VoidCallback? onActivateFree;
  final VoidCallback? onDowngrade;

  bool get _isSamePlan =>
      isCurrent || isPlanChangeSame(plan) || changeType == 'same';

  bool get _showActivation =>
      changeType == 'activation' ||
      (changeType == null && isPlanFreeActivatable(plan) && !_isSamePlan);

  bool get _showUpgradeActions {
    if (!showPlanActions || _isSamePlan) return false;
    if (changeType == 'downgrade' || changeType == 'activation') return false;
    if (changeType == 'upgrade') return true;
    return !isPlanFreeActivatable(plan);
  }

  bool get _showDowngradeAction {
    if (!showPlanActions || _isSamePlan) return false;
    if (changeType == 'upgrade' || changeType == 'activation') return false;
    if (changeType == 'downgrade') return true;
    return !isPlanFreeActivatable(plan);
  }

  @override
  Widget build(BuildContext context) {
    final title = planTitle(plan) ?? planLabelFallback(plan);
    final desc = pickSubscriptionString(
      plan,
      ['description', 'summary', 'blurb'],
    );
    final prices = formatPlanPriceLines(
      plan,
      yearlyDiscountPercent: yearlyDiscountPercent,
    );
    final selectedPrice = billingCycle == 'yearly'
        ? (prices.yearly ?? prices.monthly)
        : (prices.monthly ?? prices.yearly);
    final hasBothPrices = prices.monthly != null && prices.yearly != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrent
              ? AppTheme.primary.withValues(alpha: 0.55)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: isCurrent ? 1.5 : 1,
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
              if (hasBothPrices) ...[
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
            if (showBillingToggle) ...[
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
            ],
            if (showPlanActions) ...[
              const SizedBox(height: 14),
              if (_showActivation)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: _primaryBtn(),
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
                        style: _primaryBtn(),
                        onPressed: onTumizi,
                        child: const Text('M-Pesa'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryDark,
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
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
          ],
        ),
      ),
    );
  }

  ButtonStyle _primaryBtn() => FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      );
}

String? planId(Map<String, dynamic> p) =>
    pickSubscriptionString(p, ['id', 'planId', 'plan_id', 'pricePlanId']);

String? planTitle(Map<String, dynamic> p) =>
    pickSubscriptionString(p, ['name', 'title', 'label', 'planName']);

String planLabelFallback(Map<String, dynamic> p) {
  final id = planId(p);
  return id != null ? 'Plan $id' : 'Plan';
}

Map<String, dynamic>? findPlanById(
  List<Map<String, dynamic>> plans,
  String? id,
) {
  if (id == null || id.isEmpty) return null;
  for (final plan in plans) {
    if (planId(plan) == id) return plan;
  }
  return null;
}
