import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../subscription_snapshot_helpers.dart';

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
    final level = accessRestrictionLevel(data);
    if (level == null || level == 'full') return const SizedBox.shrink();

    final theme = Theme.of(context);
    final Color bg;
    final Color fg;
    switch (level) {
      case 'read-only':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
      case 'restricted':
        bg = theme.colorScheme.errorContainer;
        fg = theme.colorScheme.onErrorContainer;
      case 'blocked':
        bg = theme.colorScheme.errorContainer;
        fg = theme.colorScheme.onErrorContainer;
      default:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurface;
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
            accessRestrictionBannerMessage(level),
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
    if (!needsRenewalPayment(data)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final expiring = isExpiringSoon(data);
    final label = expiring ? 'Renew now' : 'Pay now';
    final message = expiring
        ? 'Your plan is expiring soon. Renew to avoid interruption.'
        : 'Payment is required to keep your subscription active.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (onPayNow != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
              ),
              onPressed: onPayNow,
              child: Text(label),
            ),
          ],
        ],
      ),
    );
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
