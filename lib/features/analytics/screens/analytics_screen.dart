import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../analytics_parse.dart';
import '../providers/dashboard_analytics_provider.dart';

/// Analytics Center — data from `GET /dashboard/analytics?days=`.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _period = 1;

  int get _days => switch (_period) {
        0 => 7,
        1 => 30,
        2 => 90,
        _ => 30,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(dashboardAnalyticsProvider(_days));
    final view = parseAnalyticsViewData(async.valueOrNull, _days);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardAnalyticsProvider(_days));
          await ref.read(dashboardAnalyticsProvider(_days).future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + MediaQuery.of(context).padding.top, 16, 24),
          children: [
            DashboardPageHeader(
              title: 'Analytics Center',
              subtitle:
                  'Deep-dive insights into your store performance and customer behavior across all channels.',
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => context.push('/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _PeriodChip(
                    label: '7d',
                    selected: _period == 0,
                    onTap: () => setState(() => _period = 0),
                  ),
                  _PeriodChip(
                    label: '30d',
                    selected: _period == 1,
                    onTap: () => setState(() => _period = 1),
                  ),
                  _PeriodChip(
                    label: '90d',
                    selected: _period == 2,
                    onTap: () => setState(() => _period = 2),
                  ),
                ],
              ),
            ),
            if (async.isLoading) const LinearProgressIndicator(minHeight: 2),
            if (async.hasError && !async.hasValue) ...[
              const SizedBox(height: 12),
              Material(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Could not load analytics. Pull to retry.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _SalesPerformanceCard(view: view, theme: theme),
            const SizedBox(height: 16),
            _ConversionCard(view: view, theme: theme),
            const SizedBox(height: 16),
            _TopProductsCard(view: view, theme: theme),
            const SizedBox(height: 16),
            _CustomerLoyaltyCard(returningShare: view.returningShare),
            const SizedBox(height: 16),
            _TrafficSourcesCard(rows: view.trafficSources),
          ],
        ),
      ),
    );
  }
}

class _SalesPerformanceCard extends StatelessWidget {
  const _SalesPerformanceCard({required this.view, required this.theme});

  final AnalyticsViewData view;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final change = view.changePercent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
                      'Sales Performance',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      view.revenueSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    view.totalRevenueFormatted,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (change != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          change >= 0 ? Icons.trending_up : Icons.trending_down,
                          size: 16,
                          color: change >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: change >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _LineChartPainter(
                color: AppTheme.primary,
                normalizedPoints: view.lineNormalized,
              ),
              size: const Size(double.infinity, 160),
            ),
          ),
          const SizedBox(height: 8),
          if (view.xLabels.isNotEmpty && view.xLabels.length <= 16)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: view.xLabels
                  .map(
                    (d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            )
          else if (view.lineNormalized.isNotEmpty)
            Text(
              '${view.lineNormalized.length} points · ${view.periodDays} day window',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversionCard extends StatelessWidget {
  const _ConversionCard({required this.view, required this.theme});

  final AnalyticsViewData view;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final pct = view.conversionPercent;
    final display = pct != null ? '${pct.toStringAsFixed(pct >= 10 ? 1 : 2)}%' : '—';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_outlined, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Conversion Rate',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            display,
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Text(
            view.conversionFootnote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.view, required this.theme});

  final AnalyticsViewData view;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Products',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (view.topProducts.isEmpty)
            Text(
              'No top products in this period. When your API returns a `topProducts` (or similar) list, it will show here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            for (var i = 0; i < view.topProducts.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _TopProductRow(
                name: view.topProducts[i].name,
                sub: view.topProducts[i].sub,
                amount: view.topProducts[i].amount,
              ),
            ],
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => context.push('/products'),
              child: const Text('View Inventory Insights'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        elevation: selected ? 1 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? AppTheme.primary : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.name, required this.sub, required this.amount});

  final String name;
  final String sub;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.outline),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Text(
          amount,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CustomerLoyaltyCard extends StatelessWidget {
  const _CustomerLoyaltyCard({this.returningShare});

  final double? returningShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = returningShare;
    final returning = share ?? 0.5;
    final newShare = (1 - returning).clamp(0.0, 1.0);
    final hasData = share != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Loyalty',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasData
                ? 'Breakdown of new vs. returning customers in this period.'
                : 'Cohort split not returned for this period. Showing a neutral placeholder.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: _DonutPainter(
                        percent: returning.clamp(0.0, 1.0),
                        activeColor: AppTheme.primary,
                        trackColor: theme.colorScheme.surfaceContainerHigh,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasData ? '${(returning * 100).round()}%' : '—',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'RETURNING',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoyaltyBarRow(
                      label: 'Returning Customers',
                      valueLabel: hasData ? '${(returning * 100).round()}%' : '—',
                      fill: returning,
                      fillColor: AppTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    _LoyaltyBarRow(
                      label: 'New Customers',
                      valueLabel: hasData ? '${(newShare * 100).round()}%' : '—',
                      fill: newShare,
                      fillColor: theme.colorScheme.outlineVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoyaltyBarRow extends StatelessWidget {
  const _LoyaltyBarRow({
    required this.label,
    required this.valueLabel,
    required this.fill,
    required this.fillColor,
  });

  final String label;
  final String valueLabel;
  final double fill;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fill.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            color: fillColor,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.percent,
    required this.activeColor,
    required this.trackColor,
  });

  final double percent;
  final Color activeColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -pi / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, start, 2 * pi, false, trackPaint);
    canvas.drawArc(rect, start, 2 * pi * percent, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.percent != percent ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.trackColor != trackColor;
}

class _TrafficSourcesCard extends StatelessWidget {
  const _TrafficSourcesCard({required this.rows});

  final List<({String label, double fraction})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Traffic Sources',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(
                  'Export Report',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              'Traffic breakdown not included in the API response yet. '
              'When `trafficSources` or `traffic` is returned, it will appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrafficSourceBlock(label: r.label, fraction: r.fraction),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrafficSourceBlock extends StatelessWidget {
  const _TrafficSourceBlock({required this.label, required this.fraction});

  final String label;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = '${(fraction * 100).round()}%';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pct,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.color,
    required this.normalizedPoints,
  });

  final Color color;
  final List<double> normalizedPoints;

  @override
  void paint(Canvas canvas, Size size) {
    if (normalizedPoints.isEmpty) {
      final p = Paint()..color = color.withValues(alpha: 0.12);
      canvas.drawRect(Rect.fromLTWH(0, size.height * 0.85, size.width, 1), p);
      return;
    }

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final n = normalizedPoints.length;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : i * size.width / (n - 1);
      final y = size.height * (1 - normalizedPoints[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.normalizedPoints.length != normalizedPoints.length) return true;
    for (var i = 0; i < normalizedPoints.length; i++) {
      if (oldDelegate.normalizedPoints[i] != normalizedPoints[i]) return true;
    }
    return false;
  }
}
