import 'package:flutter/material.dart';

import '../../../config/theme.dart';

/// Home dashboard aligned with Stitch screen
/// `projects/13184140852829986275/screens/a93fc25cee2c4ac98d30472dc7535058`
/// (HTML + screenshot in `docs/backend-context/stitch-exports/`).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(12, 5, 40, 0.06),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8 + MediaQuery.of(context).padding.top, 24, 120),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                child: Icon(Icons.person, size: 22, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Text(
                'DukaNest',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'OVERVIEW',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.primaryDark,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back, Sarah',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          _gettingStartedCard(context, theme),
          const SizedBox(height: 24),
          _weeklyRevenueCard(context, theme),
          const SizedBox(height: 24),
          _pendingOrdersCard(theme),
          const SizedBox(height: 24),
          _completedOrdersCard(theme),
          const SizedBox(height: 24),
          _stockAlertsCard(context, theme),
          const SizedBox(height: 24),
          _growCard(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _gettingStartedCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Getting Started',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '2 of 4 steps completed',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.5,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceContainerLow,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          const _StitchStepRow(
            completed: true,
            title: 'Add your first product',
            actionLabel: 'Edit',
          ),
          const SizedBox(height: 16),
          const _StitchStepRow(
            completed: false,
            title: 'Configure payment settings',
            actionLabel: 'Set Up',
          ),
          const SizedBox(height: 16),
          const _StitchStepRow(
            completed: true,
            title: 'Customize store design',
            actionLabel: 'View',
          ),
          const SizedBox(height: 16),
          const _StitchStepRow(
            completed: false,
            title: 'Share your store link',
            actionLabel: 'Share',
          ),
        ],
      ),
    );
  }

  Widget _weeklyRevenueCard(BuildContext context, ThemeData theme) {
    const chartHeight = 192.0; // Tailwind h-48
    const barGap = 4.0;
    const fractions = <double>[0.40, 0.55, 0.45, 0.70, 0.90, 0.60, 0.75];
    const highlightedIndex = 4;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Revenue',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+12.5% from last week',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '7 DAYS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < fractions.length; i++) ...[
                  if (i > 0) const SizedBox(width: barGap),
                  Expanded(
                    child: _WeeklyRevenueBar(
                      heightFraction: fractions[i],
                      highlighted: i == highlightedIndex,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$12,450.00',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total earned',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pendingOrdersCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppTheme.primaryDark, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryDark, size: 26),
              Text(
                'PENDING',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '24',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active Orders',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedOrdersCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.check_circle_outline, color: theme.colorScheme.onSurfaceVariant, size: 26),
              Text(
                'COMPLETED',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '182',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 30 days',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockAlertsCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stock Alerts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ACTION REQUIRED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _stockRow(context, theme, 'Organic Coffee Beans', 'Only 2 units left'),
          const SizedBox(height: 16),
          _stockRow(context, theme, 'Almond Milk 1L', 'Only 5 units left'),
        ],
      ),
    );
  }

  Widget _stockRow(BuildContext context, ThemeData theme, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              'Restock',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _growCard(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(child: ColoredBox(color: AppTheme.primaryDark)),
          Positioned(
            right: -48,
            top: -48,
            child: IgnorePointer(
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 64,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grow your store',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add new products or explore marketing insights.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(
                        'Add Product',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'View Orders',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyRevenueBar extends StatelessWidget {
  const _WeeklyRevenueBar({
    required this.heightFraction,
    required this.highlighted,
  });

  final double heightFraction;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final track = AppTheme.surfaceContainerLow;
    final fill = highlighted ? AppTheme.primary : track;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight * heightFraction;
        return Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
        );
      },
    );
  }
}

class _StitchStepRow extends StatelessWidget {
  const _StitchStepRow({
    required this.completed,
    required this.title,
    required this.actionLabel,
  });

  final bool completed;
  final String title;
  final String actionLabel;

  static const _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (completed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: _green, width: 4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 22, color: Color(0xFF16A34A)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryDark),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.radio_button_unchecked, size: 22, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              actionLabel,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
