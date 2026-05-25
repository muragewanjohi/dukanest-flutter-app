import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_segment_provider.dart';
class AnalyticsSegmentPane extends ConsumerWidget {
  const AnalyticsSegmentPane({
    super.key,
    required this.segment,
    required this.days,
  });

  final String segment;
  final int days;

  static Map<String, dynamic>? queryForSegment(String segment, int days) {
    if (segment == 'overview') return null;
    final end = DateTime.now();
    final startCalendar =
        DateTime(end.year, end.month, end.day)
            .subtract(Duration(days: days - 1));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {'startDate': fmt(startCalendar), 'endDate': fmt(end)};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final params = (
      segment: segment,
      query: queryForSegment(segment, days),
    );
    final async = ref.watch(analyticsSegmentProvider(params));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(analyticsSegmentProvider(params));
        await ref.read(analyticsSegmentProvider(params).future);
      },
      child: async.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: 120),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text('$e', style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
        data: (data) {
          if (data == null || data.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'No payload for `$segment`.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            );
          }
          final text =
              const JsonEncoder.withIndent('  ').convert(data);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              SelectableText(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
