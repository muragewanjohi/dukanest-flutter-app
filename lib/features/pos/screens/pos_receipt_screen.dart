import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme.dart';
import '../providers/pos_providers.dart';

/// Sale complete — shows the receipt, lets the cashier share it, and starts
/// the next sale.
class PosReceiptScreen extends ConsumerWidget {
  const PosReceiptScreen({super.key, required this.sale});

  final PosCompletedSale sale;

  String _plainTextReceipt() {
    final c = sale.settings.currency;
    final r = sale.result;
    final b = StringBuffer()
      ..writeln(sale.settings.store.name)
      ..writeln(sale.settings.store.address ?? '')
      ..writeln('')
      ..writeln('Receipt ${r.receiptNumber}')
      ..writeln('Order ${r.orderNumber}')
      ..writeln(DateFormat('d MMM y, h:mm a')
          .format((r.createdAt ?? DateTime.now()).toLocal()))
      ..writeln('------------------------------');
    for (final l in sale.lines) {
      b.writeln('${l.quantity} x ${l.displayName}');
      b.writeln('   ${c.format(l.lineTotal)}');
    }
    b
      ..writeln('------------------------------')
      ..writeln('Subtotal   ${c.format(r.subtotal)}');
    if (r.discountTotal > 0) {
      b.writeln('Discount  -${c.format(r.discountTotal)}');
    }
    if (r.taxAmount > 0) b.writeln('Tax        ${c.format(r.taxAmount)}');
    b.writeln('TOTAL      ${c.format(r.total)}');
    if (r.amountTendered != null) {
      b.writeln('Cash       ${c.format(r.amountTendered!)}');
    }
    if (r.changeDue != null && r.changeDue! > 0) {
      b.writeln('Change     ${c.format(r.changeDue!)}');
    }
    b
      ..writeln(r.isPaid
          ? 'Paid via ${sale.method.label}'
          : '${sale.method.label} — AWAITING PAYMENT')
      ..writeln('')
      ..writeln('Thank you!');
    return b.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = sale.settings.currency;
    final r = sale.result;
    final awaitingPayment = !r.isPaid;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sale complete'),
        actions: [
          TextButton(
            onPressed: () => context.go('/pos'),
            child: const Text('New sale'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  awaitingPayment
                      ? Icons.hourglass_bottom_rounded
                      : Icons.check_circle_rounded,
                  size: 56,
                  color: awaitingPayment
                      ? theme.colorScheme.tertiary
                      : AppTheme.mpesaGreen,
                ),
                const SizedBox(height: 8),
                Text(
                  awaitingPayment
                      ? 'Sale recorded — awaiting M-Pesa'
                      : r.deduplicated
                          ? 'Already recorded'
                          : 'Payment recorded',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                Text(
                  c.format(r.total),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (awaitingPayment) _Banner.info(
            'The M-Pesa payment has not been confirmed yet. Check '
            'this order in Orders — it updates to Paid automatically when the '
            'customer completes the STK prompt.',
          ),
          if (r.oversold.isNotEmpty) _Banner.warning(
            'Stock went below zero for '
            '${r.oversold.map((o) => o.name).join(', ')}. '
            'Review your counts in Inventory.',
          ),
          if (r.overLimit) _Banner.info(
            'You have reached your plan\'s order limit. The sale was still '
            'recorded — consider upgrading.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Receipt', r.receiptNumber),
                _kv('Order', r.orderNumber),
                if (r.invoiceNumber != null) _kv('Invoice', r.invoiceNumber!),
                _kv(
                  'Date',
                  DateFormat('d MMM y, h:mm a')
                      .format((r.createdAt ?? DateTime.now()).toLocal()),
                ),
                _kv('Payment', sale.method.label),
                _kv('Status', r.isPaid ? 'Paid' : 'Awaiting payment'),
                if (sale.customerName.isNotEmpty)
                  _kv('Customer', sale.customerName),
                const Divider(height: 20),
                for (final l in sale.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${l.quantity} × ${l.displayName}'),
                        ),
                        Text(c.format(l.lineTotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                _kv('Subtotal', c.format(r.subtotal)),
                if (r.discountTotal > 0)
                  _kv('Discount', '− ${c.format(r.discountTotal)}'),
                if (r.taxAmount > 0) _kv('Tax', c.format(r.taxAmount)),
                _kv('Total', c.format(r.total), bold: true),
                if (r.amountTendered != null)
                  _kv('Cash received', c.format(r.amountTendered!)),
                if (r.changeDue != null && r.changeDue! > 0)
                  _kv('Change', c.format(r.changeDue!)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => SharePlus.instance
                .share(ShareParams(text: _plainTextReceipt())),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share receipt'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () => context.go('/pos'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('New sale',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style: const TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(v,
                  style: TextStyle(
                      fontWeight:
                          bold ? FontWeight.w900 : FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner._(this.message, this.icon, this.background, this.foreground);

  factory _Banner.warning(String message) => _Banner._(
        message,
        Icons.warning_amber_rounded,
        const Color(0xFFFFF4E5),
        const Color(0xFF8A4B00),
      );

  factory _Banner.info(String message) => _Banner._(
        message,
        Icons.info_outline_rounded,
        const Color(0xFFE8ECFF),
        AppTheme.primaryDark,
      );

  final String message;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
