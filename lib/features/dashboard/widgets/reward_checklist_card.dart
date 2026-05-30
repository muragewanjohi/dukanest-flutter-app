import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../providers/dashboard_reward_checklist_provider.dart';
import '../reward_checklist_data.dart';

/// Progress card for the onboarding reward (free month) program.
class RewardChecklistCard extends ConsumerWidget {
  const RewardChecklistCard({super.key});

  static bool shouldShow(Map<String, dynamic>? data) => shouldShowReward(data);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardRewardChecklistProvider);
    final data = async.valueOrNull;
    if (data == null || !shouldShowReward(data)) {
      return const SizedBox.shrink();
    }
    final reward = rewardMap(data)!;
    final theme = Theme.of(context);
    final granted = rewardBool(reward['granted']);
    final progress = (data['progressPercent'] is num)
        ? (data['progressPercent'] as num).toDouble().clamp(0.0, 100.0) / 100.0
        : 0.0;
    final completed = data['completedCount'];
    final total = data['totalCount'];
    final bonus = reward['bonusDays'];
    final daysLeft = reward['daysRemainingInWindow'];
    final headline = granted
        ? 'Reward unlocked'
        : 'Earn up to ${bonus is num ? bonus.toInt().toString() : '30'} bonus days';
    final sub = granted
        ? 'Your subscription was extended. Keep growing your store.'
        : (daysLeft is num
            ? '${daysLeft.toInt()} day${daysLeft == 1 ? '' : 's'} left in the reward window'
            : 'Complete every step before the window closes');

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.12),
            AppTheme.primaryDark.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                granted ? Icons.card_giftcard_rounded : Icons.stars_rounded,
                color: AppTheme.primaryDark,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Onboarding reward',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            headline,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (completed is num && total is num && total.toInt() > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${completed.toInt()} of ${total.toInt()} steps done',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (rewardSteps(data).isNotEmpty) ...[
            const SizedBox(height: 14),
            ...rewardSteps(data).map((s) => _StepRow(step: s)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => context.push('/subscription'),
              style: FilledButton.styleFrom(
                foregroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View subscription & plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final ({String title, String subtitle, bool done}) step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            step.done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: step.done
                ? Colors.green.shade600
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: step.done
                        ? theme.colorScheme.onSurfaceVariant
                        : AppTheme.primaryDark,
                    decoration: step.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (step.subtitle.isNotEmpty)
                  Text(
                    step.subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
