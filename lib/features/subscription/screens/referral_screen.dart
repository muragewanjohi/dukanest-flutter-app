import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../models/referral_summary.dart';
import '../models/referred_friend.dart';
import '../providers/referrals_provider.dart';
import '../widgets/referral_loyalty_card.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(dashboardReferralsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Referral program',
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
            onPressed: () => ref.invalidate(dashboardReferralsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(dashboardReferralsProvider);
          await ref.read(dashboardReferralsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ApiErrorView(
                error: e,
                title: 'Could not load referral program',
                onRetry: () => ref.invalidate(dashboardReferralsProvider),
              ),
            ],
          ),
          data: (dashboard) {
            final summary = dashboard.summary;
            if (summary == null || !summary.hasShareContent) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(22),
                children: [
                  Text(
                    'Referral program is not available for this store yet.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set your store subdomain in Store profile to get a referral '
                    'link, or try refreshing if you recently updated your store.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              );
            }

            final referredBy = summary.referredBySubdomain?.trim();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Invite merchants',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your signup link. When referred stores subscribe, '
                  'you can earn free subscription months according to your plan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (referredBy != null && referredBy.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReferredByBanner(referrer: referredBy, theme: theme),
                ],
                const SizedBox(height: 20),
                ReferralLoyaltyCard(
                  summaryOverride: summary,
                  showViewAll: false,
                  compactActions: false,
                ),
                const SizedBox(height: 24),
                _StatsSection(summary: summary, theme: theme),
                const SizedBox(height: 24),
                _ReferredFriendsSection(
                  friends: dashboard.referredFriends,
                  theme: theme,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReferredByBanner extends StatelessWidget {
  const _ReferredByBanner({required this.referrer, required this.theme});

  final String referrer;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You signed up with referral code $referrer. '
              'Referral codes can only be entered during registration.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.summary, required this.theme});

  final ReferralSummary summary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[];
    void add(String label, int? n) {
      if (n == null) return;
      rows.add((label: label, value: '$n'));
    }

    add('Total referrals', summary.referralCount);
    add('Successful referrals', summary.successfulReferrals);
    add('Free months earned', summary.rewardedMonths);
    add('Referrals per reward', summary.targetReferrals);
    add('Months per reward', summary.monthsPerReward);

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your progress',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 12),
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  r.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  r.value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferredFriendsSection extends StatelessWidget {
  const _ReferredFriendsSection({
    required this.friends,
    required this.theme,
  });

  final List<ReferredFriend> friends;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Referred stores',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        if (friends.isEmpty)
          Text(
            'No referred stores yet. Share your link to start earning rewards.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          )
        else
          ...friends.map(
            (friend) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  friend.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (friend.subdomain != null &&
                        friend.subdomain!.isNotEmpty)
                      Text(
                        friend.subdomain!,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (friend.createdAt != null)
                      Text(
                        'Joined ${DateFormat.yMMMd().format(friend.createdAt!.toLocal())}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                trailing: friend.status == null || friend.status!.isEmpty
                    ? null
                    : Chip(
                        label: Text(friend.status!),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: AppTheme.surfaceContainerLow,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
