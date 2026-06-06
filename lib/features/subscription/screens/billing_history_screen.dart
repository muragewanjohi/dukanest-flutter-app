import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/billing_history_provider.dart';
import '../subscription_snapshot_helpers.dart';
import '../widgets/subscription_status_banners.dart';

class BillingHistoryScreen extends ConsumerWidget {
  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(billingHistoryProvider);
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Billing history',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => ref.refresh(billingHistoryProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ApiErrorView(
                error: e,
                title: 'Could not load billing history',
                onRetry: () => ref.invalidate(billingHistoryProvider),
              ),
            ],
          ),
          data: (data) {
            if (data == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  Text('No billing data returned.'),
                ],
              );
            }

            final items = extractBillingHistoryRows(data);

            final metaChunks = <String>[];
            _appendIfPresent(metaChunks, data, 'planName', 'plan');
            _appendIfPresent(metaChunks, data, 'current_plan', 'plan');
            _appendDate(
              metaChunks,
              data,
              ['expireDate', 'expire_date', 'nextRenewal', 'renewal'],
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                SubscriptionRenewalCta(
                  data: data,
                  onPayNow: () => context.push('/subscription'),
                ),
                if (needsRenewalPayment(data)) const SizedBox(height: 8),
                SubscriptionAccessBanner(
                  data: data,
                  onRenew: () => context.push('/subscription'),
                ),
                if (metaChunks.isNotEmpty) ...[
                  _MetaCard(theme: theme, lines: metaChunks),
                  const SizedBox(height: 16),
                ],
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        'No invoice or payment rows yet.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...items.map((row) => _BillingTile(
                        theme: theme,
                        row: row,
                        currencyFormat: currency,
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.theme, required this.lines});

  final ThemeData theme;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      l,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _BillingTile extends StatelessWidget {
  const _BillingTile({
    required this.theme,
    required this.row,
    required this.currencyFormat,
  });

  final ThemeData theme;
  final Map<String, dynamic> row;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final title = _first(
          row,
          ['title', 'description', 'type', 'planName', 'plan'],
        ) ??
        'Entry';
    final status =
        (_first(row, ['status', 'paymentStatus', 'state']) ?? '').trim();
    final amountRaw = row['amount'] ?? row['price'] ?? row['total'];
    final amountLabel =
        amountRaw != null ? _formatAmount(amountRaw, currencyFormat) : '';
    final when = _first(row, [
      'paidAt',
      'paid_at',
      'createdAt',
      'created_at',
      'date',
      'invoiceDate',
    ]);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((when ?? '').trim().isNotEmpty)
              Text(when!, style: theme.textTheme.bodySmall),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  status.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        trailing: amountLabel.isEmpty
            ? null
            : Text(
                amountLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

void _appendIfPresent(
    List<String> chunks, Map<String, dynamic> data, String a, String b) {
  final v = data[a] ?? data[b];
  if (v != null && v.toString().trim().isNotEmpty) {
    chunks.add('Plan: ${v.toString().trim()}');
  }
}

void _appendDate(
    List<String> chunks, Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final v = data[k];
    if (v == null || v.toString().trim().isEmpty) continue;
    final parsed = DateTime.tryParse(v.toString());
    if (parsed != null) {
      chunks.add(
        'Renewal / expiry: ${DateFormat.yMMMd().format(parsed)}',
      );
      return;
    }
  }
}

String? _first(Map<String, dynamic> row, List<String> keys) {
  for (final k in keys) {
    final v = row[k];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
    }
  }
  return null;
}

String _formatAmount(dynamic raw, NumberFormat currencyFormat) {
  if (raw is num) {
    try {
      return currencyFormat.format(raw);
    } catch (_) {}
  }
  final p = double.tryParse(raw.toString());
  if (p != null) {
    try {
      return currencyFormat.format(p);
    } catch (_) {}
  }
  return raw.toString();
}
