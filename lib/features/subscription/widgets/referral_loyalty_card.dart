import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/dio_envelope.dart';
import '../models/referral_summary.dart';
import '../providers/referrals_provider.dart';
import 'referral_actions.dart';

/// Compact referral program card for Subscription and dashboard surfaces.
class ReferralLoyaltyCard extends ConsumerWidget {
  const ReferralLoyaltyCard({
    super.key,
    this.summaryOverride,
    this.showViewAll = true,
    this.compactActions = false,
  });

  /// When set (e.g. from overview), avoids waiting on [dashboardReferralsProvider].
  final ReferralSummary? summaryOverride;
  final bool showViewAll;
  final bool compactActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (summaryOverride != null) {
      if (!summaryOverride!.hasShareContent) return const SizedBox.shrink();
      return _CardBody(
        theme: theme,
        summary: summaryOverride!,
        showViewAll: showViewAll,
        compactActions: compactActions,
      );
    }

    final async = ref.watch(dashboardReferralsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => _CompactErrorCard(
        theme: theme,
        message: apiErrorMessage(error),
        onRetry: () => ref.invalidate(dashboardReferralsProvider),
      ),
      data: (dashboard) {
        final summary = dashboard.summary;
        if (summary == null || !summary.hasShareContent) {
          return const SizedBox.shrink();
        }
        return _CardBody(
          theme: theme,
          summary: summary,
          showViewAll: showViewAll,
          compactActions: compactActions,
        );
      },
    );
  }
}

class _CompactErrorCard extends StatelessWidget {
  const _CompactErrorCard({
    required this.theme,
    required this.message,
    required this.onRetry,
  });

  final ThemeData theme;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.theme,
    required this.summary,
    required this.showViewAll,
    required this.compactActions,
  });

  final ThemeData theme;
  final ReferralSummary summary;
  final bool showViewAll;
  final bool compactActions;

  @override
  Widget build(BuildContext context) {
    final subdomain = summary.shareSubdomain?.trim();
    final link = summary.effectiveShareLink;

    return Card(
      elevation: 0,
      color: AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.card_giftcard_outlined,
                  color: AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Referral rewards',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                if (showViewAll)
                  TextButton(
                    onPressed: () => context.push('/referrals'),
                    child: const Text('View all'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              referralProgressLabel(summary),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (subdomain != null && subdomain.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Your referral code: $subdomain',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
            if (link != null && link.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                link,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ReferralActionsRow(
              summary: summary,
              compact: compactActions,
            ),
          ],
        ),
      ),
    );
  }
}
