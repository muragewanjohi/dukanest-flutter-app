import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../subscription_snapshot_helpers.dart';

/// Single renewal / payment banner — replaces duplicate grace + pay CTAs.
class SubscriptionRenewalBanner extends StatelessWidget {
  const SubscriptionRenewalBanner({
    super.key,
    required this.data,
    this.onRenew,
  });

  final Map<String, dynamic> data;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final level = accessRestrictionLevel(data);
    final restricted = level != null && level != 'full';
    final needsPay = needsRenewalPayment(data);
    if (!restricted && !needsPay) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final message = _renewalBannerMessage(
      level: level,
      needsPay: needsPay,
      expiringSoon: isExpiringSoon(data),
    );

    final Color bg;
    final Color fg;
    switch (level) {
      case 'read-only':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
      case 'restricted':
      case 'blocked':
        bg = theme.colorScheme.errorContainer;
        fg = theme.colorScheme.onErrorContainer;
      default:
        bg = AppTheme.primary.withValues(alpha: 0.08);
        fg = AppTheme.primaryDark;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: fg,
              height: 1.35,
            ),
          ),
          if (onRenew != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
              ),
              onPressed: onRenew,
              child: const Text('Renew now'),
            ),
          ],
        ],
      ),
    );
  }
}

String _renewalBannerMessage({
  required String? level,
  required bool needsPay,
  required bool expiringSoon,
}) {
  if (level != null && level != 'full') {
    return accessRestrictionBannerMessage(level);
  }
  if (expiringSoon) {
    return 'Your plan is expiring soon. Renew to avoid interruption.';
  }
  if (needsPay) {
    return 'Payment is required to keep your subscription active.';
  }
  return 'Renew your subscription to restore full access.';
}

@Deprecated('Use SubscriptionRenewalBanner')
class SubscriptionAccessBanner extends StatelessWidget {
  const SubscriptionAccessBanner({
    super.key,
    required this.data,
    this.onRenew,
  });

  final Map<String, dynamic> data;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    return SubscriptionRenewalBanner(data: data, onRenew: onRenew);
  }
}

@Deprecated('Use SubscriptionRenewalBanner')
class SubscriptionRenewalCta extends StatelessWidget {
  const SubscriptionRenewalCta({
    super.key,
    required this.data,
    this.onPayNow,
  });

  final Map<String, dynamic> data;
  final VoidCallback? onPayNow;

  @override
  Widget build(BuildContext context) {
    return SubscriptionRenewalBanner(data: data, onRenew: onPayNow);
  }
}

class ScheduledDowngradeChip extends StatelessWidget {
  const ScheduledDowngradeChip({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final downgrade = scheduledDowngrade(data);
    if (downgrade == null || downgrade.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Chip(
        avatar: Icon(Icons.schedule, size: 18, color: AppTheme.primary),
        label: Text(
          scheduledDowngradeLabel(downgrade),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceContainerLow,
        side: BorderSide.none,
      ),
    );
  }
}
