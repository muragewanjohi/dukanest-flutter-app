import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../analytics_segment_parse.dart';
import '../providers/analytics_segment_provider.dart';

/// Renders an analytics segment payload as charts, metric cards, ranked
/// breakdowns and tables (instead of raw JSON), with CSV export + share.
class AnalyticsSegmentPane extends ConsumerStatefulWidget {
  const AnalyticsSegmentPane({
    super.key,
    required this.segment,
    required this.days,
  });

  final String segment;
  final int days;

  static AnalyticsSegmentParams paramsFor(String segment, int days) =>
      analyticsSegmentParamsFor(segment, days);

  @override
  ConsumerState<AnalyticsSegmentPane> createState() =>
      _AnalyticsSegmentPaneState();
}

/// Loads segment data only after the user opens this tab (avoids 10+ parallel
/// analytics calls when opening Analytics Center or changing the date range).
class LazyAnalyticsSegmentPane extends StatefulWidget {
  const LazyAnalyticsSegmentPane({
    super.key,
    required this.tabIndex,
    required this.tabController,
    required this.segment,
    required this.days,
  });

  final int tabIndex;
  final TabController tabController;
  final String segment;
  final int days;

  @override
  State<LazyAnalyticsSegmentPane> createState() =>
      _LazyAnalyticsSegmentPaneState();
}

class _LazyAnalyticsSegmentPaneState extends State<LazyAnalyticsSegmentPane> {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _activated = widget.tabController.index == widget.tabIndex;
    widget.tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_activated || widget.tabController.index != widget.tabIndex) return;
    setState(() => _activated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_activated) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              'Open this tab to load analytics',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return AnalyticsSegmentPane(
      key: ValueKey('${widget.segment}-${widget.days}'),
      segment: widget.segment,
      days: widget.days,
    );
  }
}

class _AnalyticsSegmentPaneState extends ConsumerState<AnalyticsSegmentPane> {
  bool _exporting = false;

  AnalyticsSegmentParams get _params =>
      AnalyticsSegmentPane.paramsFor(widget.segment, widget.days);

  String get _title {
    final spaced = widget.segment
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .trim();
    if (spaced.isEmpty) return 'Segment';
    return spaced
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final api = ref.read(apiClientProvider);
      final Response<dynamic> res = await api.exportAnalytics(
        type: widget.segment,
        format: 'csv',
        queryParameters: queryFromAnalyticsSegmentParams(_params),
      );
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
        );
      }
      final payload = res.data;
      Uint8List bytes;
      if (payload is Uint8List) {
        bytes = payload;
      } else if (payload is List) {
        bytes = Uint8List.fromList(List<int>.from(payload));
      } else if (payload is String) {
        bytes = Uint8List.fromList(payload.codeUnits);
      } else {
        throw FormatException(
            'Unexpected export payload: ${payload.runtimeType}');
      }
      final file = XFile.fromData(
        bytes,
        name: '${widget.segment}_export.csv',
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(subject: '$_title export', files: [file]),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(analyticsSegmentProvider(_params));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(analyticsSegmentProvider(_params));
        await ref.read(analyticsSegmentProvider(_params).future);
      },
      child: async.when(
        loading: () => _scroll(const [
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 120),
              child: CircularProgressIndicator(),
            ),
          ),
        ]),
        error: (e, _) => _scroll([
          _header(theme),
          const SizedBox(height: 16),
          Text(
            apiErrorMessage(e),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(analyticsSegmentProvider(_params)),
              child: const Text('Retry'),
            ),
          ),
        ]),
        data: (data) {
          if (data == null || data.isEmpty) {
            return _scroll([
              _header(theme),
              const SizedBox(height: 24),
              Text(
                'No data returned for this segment in the selected period.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ]);
          }
          final view = parseSegmentView(data);
          return _scroll([
            _header(theme),
            const SizedBox(height: 16),
            if (view.isEmpty)
              Text(
                'This segment returned data, but no chartable fields were found.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            if (view.metrics.isNotEmpty) ...[
              _MetricGrid(metrics: view.metrics),
              const SizedBox(height: 16),
            ],
            for (final s in view.series) ...[
              _SeriesCard(series: s),
              const SizedBox(height: 16),
            ],
            for (final b in view.breakdowns) ...[
              _BreakdownCard(breakdown: b),
              const SizedBox(height: 16),
            ],
            for (final t in view.tables) ...[
              _TableCard(table: t),
              const SizedBox(height: 16),
            ],
          ]);
        },
      ),
    );
  }

  Widget _scroll(List<Widget> children) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: children,
      );

  Widget _header(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _exporting ? null : _export,
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<SegmentMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics.map((m) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series});
  final SegmentSeries series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = series.values;
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final maxY = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final labelStep = (series.labels.length / 6).ceil().clamp(1, 999);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            series.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: spots.length < 2
                ? Center(
                    child: Text(
                      spots.isEmpty
                          ? 'No points'
                          : 'Single data point: ${values.first}',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY <= 0 ? 1 : maxY * 1.15,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: series.labels.isNotEmpty,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final i = value.round();
                              if (i < 0 || i >= series.labels.length) {
                                return const SizedBox.shrink();
                              }
                              if (i % labelStep != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  series.labels[i],
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppTheme.primary,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.breakdown});
  final SegmentBreakdown breakdown;

  static const _palette = [
    Color(0xFF0025CC),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = breakdown.rows;
    final total =
        rows.fold<double>(0, (a, r) => a + (r.value < 0 ? 0 : r.value));
    final usePie = rows.length <= 6 && total > 0;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            breakdown.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (usePie)
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 34,
                        sections: [
                          for (var i = 0; i < rows.length; i++)
                            PieChartSectionData(
                              value:
                                  rows[i].value <= 0 ? 0.0001 : rows[i].value,
                              color: _palette[i % _palette.length],
                              title: '',
                              radius: 42,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _palette[i % _palette.length],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rows[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                Text(
                                  '${((rows[i].value / total) * 100).toStringAsFixed(0)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ...rows.map((r) {
              final frac = total <= 0 ? 0.0 : (r.value / total).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _fmt(r.value),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerLow,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table});
  final SegmentTable table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            table.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 44,
              columns: table.columns
                  .map((c) => DataColumn(
                        label: Text(
                          c,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ))
                  .toList(),
              rows: table.rows
                  .map((r) => DataRow(
                        cells: r
                            .map((cell) => DataCell(
                                  Text(
                                    cell,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ))
                            .toList(),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
