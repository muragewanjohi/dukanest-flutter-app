import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme.dart';
import '../providers/dashboard_reward_checklist_provider.dart';
import '../reward_checklist_data.dart';
import '../reward_step_navigation.dart';

/// Onboarding reward checklist — same carousel UX as [Getting started] on the
/// dashboard (collapsible header, horizontal step pager, primary CTA per step).
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
    final granted = rewardBool(reward['granted']);
    final bonus = reward['bonusDays'];
    final daysLeft = reward['daysRemainingInWindow'];

    final subtitle = granted
        ? 'Your subscription was extended. Complete every task to earn bonus days on your plan.'
        : (daysLeft is num
            ? '${daysLeft.toInt()} day${daysLeft == 1 ? '' : 's'} left — complete every step in the reward window.'
            : 'Complete every step before the reward window closes.');

    final steps = ensureAttributesRewardStep(rewardSteps(data), data);
    if (steps.isEmpty) return const SizedBox.shrink();

    final stepsCompleted = steps.where((s) => s.done).length;

    return _RewardChecklistCarousel(
      completed: stepsCompleted,
      total: steps.length,
      subtitle: subtitle,
      granted: granted,
      bonusDays: bonus is num ? bonus.toInt() : 30,
      steps: steps,
      onStepAction: (step) => navigateToRewardStep(context, step),
    );
  }
}

class _RewardChecklistCarousel extends StatefulWidget {
  const _RewardChecklistCarousel({
    required this.completed,
    required this.total,
    required this.subtitle,
    required this.granted,
    required this.bonusDays,
    required this.steps,
    required this.onStepAction,
  });

  final int completed;
  final int total;
  final String subtitle;
  final bool granted;
  final int bonusDays;
  final List<RewardStep> steps;
  final void Function(RewardStep step) onStepAction;

  @override
  State<_RewardChecklistCarousel> createState() =>
      _RewardChecklistCarouselState();
}

class _RewardChecklistCarouselState extends State<_RewardChecklistCarousel> {
  static const _cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(12, 5, 40, 0.06),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  late final PageController _pageController;
  late int _index;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final firstIncomplete = widget.steps.indexWhere((s) => !s.done);
    final initialPage = firstIncomplete >= 0 ? firstIncomplete : 0;
    _index = initialPage;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = widget.steps;
    final safeTotal = widget.total <= 0 ? 1 : widget.total;
    final progress = (widget.completed / safeTotal).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('reward_checklist_header'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    widget.granted
                        ? Icons.card_giftcard_rounded
                        : Icons.stars_rounded,
                    color: AppTheme.primaryDark,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Onboarding reward',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: AppTheme.surfaceContainerLow,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${widget.completed}/${widget.total} done',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Text(
                  widget.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (!widget.granted) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Earn up to ${widget.bonusDays} bonus days when you finish all steps.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 252,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: steps.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _RewardStepCarouselCard(
                          step: steps[i],
                          onAction: steps[i].done
                              ? null
                              : () => widget.onStepAction(steps[i]),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: _index > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Step ${_index + 1} of ${steps.length}',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _index < steps.length - 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(steps.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.primaryDark
                            : AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _RewardStepCarouselCard extends StatelessWidget {
  const _RewardStepCarouselCard({
    required this.step,
    this.onAction,
  });

  final RewardStep step;
  final VoidCallback? onAction;

  static const _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (step.done) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _green.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (step.subtitle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                step.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.radio_button_unchecked,
                  color: theme.colorScheme.outline, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (step.subtitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              step.subtitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                step.actionLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
