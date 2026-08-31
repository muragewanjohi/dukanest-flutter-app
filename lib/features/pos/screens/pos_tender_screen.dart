import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../data/pos_models.dart';
import '../providers/pos_providers.dart';

/// Take payment and record the sale.
/// - Cash / Other: recorded paid immediately, then the receipt.
/// - M-Pesa: creates a `pending` order + fires a Tumizi STK push, then polls
///   for confirmation before showing the receipt (with a "confirm later" out).
class PosTenderScreen extends ConsumerStatefulWidget {
  const PosTenderScreen({super.key});

  @override
  ConsumerState<PosTenderScreen> createState() => _PosTenderScreenState();
}

enum _Phase { form, waitingForMpesa }

class _PosTenderScreenState extends ConsumerState<PosTenderScreen> {
  final _tendered = TextEditingController();
  final _phone = TextEditingController();
  PosPaymentMethod _method = PosPaymentMethod.cash;
  bool _submitting = false;

  _Phase _phase = _Phase.form;
  PosSaleResult? _pendingSale;
  String _mpesaStatus = 'pending';
  int _pollAttempts = 0;
  Timer? _pollTimer;

  static const _maxPolls = 24; // ~2 min at 5s

  @override
  void initState() {
    super.initState();
    _phone.text = ref.read(posCartProvider).customerPhone;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tendered.dispose();
    _phone.dispose();
    super.dispose();
  }

  double? get _tenderedValue => double.tryParse(_tendered.text.trim());

  PosCompletedSale _completed(PosSaleResult result) {
    final cart = ref.read(posCartProvider);
    return PosCompletedSale(
      result: result,
      settings: ref.read(posBootstrapProvider).valueOrNull?.settings ??
          PosSettings.empty,
      lines: List.of(cart.lines),
      method: _method,
      customerName: cart.customerName,
      customerPhone: cart.customerPhone,
    );
  }

  Future<void> _submit() async {
    final cart = ref.read(posCartProvider);
    setState(() => _submitting = true);
    try {
      final receiptNumber =
          'POS-${DateFormat('yyMMdd-HHmmss').format(DateTime.now())}';
      final isMpesa = _method == PosPaymentMethod.mpesa;
      final tendered =
          _method == PosPaymentMethod.cash ? _tenderedValue : null;

      final body = <String, dynamic>{
        'client_sale_id': posUuidV4(),
        'receipt_number': receiptNumber,
        'offline_created_at': DateTime.now().toUtc().toIso8601String(),
        'items': cart.lines.map((l) => l.toApiItem()).toList(),
        'order_discount_amount': cart.orderDiscount,
        'payment': {
          'method': _method.apiValue,
          'status': isMpesa ? 'pending' : 'paid',
          if (tendered != null) 'amount_tendered': tendered,
          if (isMpesa) 'phone_number': _phone.text.trim(),
        },
        if (cart.customerName.isNotEmpty || cart.customerPhone.isNotEmpty)
          'customer': {
            'name': cart.customerName,
            'phone': cart.customerPhone,
          },
        if (cart.notes.isNotEmpty) 'notes': cart.notes,
      };

      final result = await ref.read(posRepositoryProvider).submitSale(body);

      if (isMpesa && result.requiresPaymentConfirmation && !result.isPaid) {
        // Cart is safe to clear — the order exists server-side now.
        ref.read(posCartProvider.notifier).clear();
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _phase = _Phase.waitingForMpesa;
          _pendingSale = result;
          _mpesaStatus = 'pending';
          _pollAttempts = 0;
        });
        _startPolling();
        return;
      }

      final completed = _completed(result);
      ref.read(posCartProvider.notifier).clear();
      if (!mounted) return;
      context.go('/pos/receipt', extra: completed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    final sale = _pendingSale;
    if (sale == null || !mounted) return;
    setState(() => _pollAttempts++);
    try {
      final status =
          await ref.read(posRepositoryProvider).pollMpesaStatus(sale.id);
      if (!mounted) return;
      setState(() => _mpesaStatus = status);
      if (status == 'paid') {
        _pollTimer?.cancel();
        context.go('/pos/receipt',
            extra: _completed(sale.copyWith(paymentStatus: 'paid')));
        return;
      }
      if (status == 'failed' || status == 'cancelled' ||
          _pollAttempts >= _maxPolls) {
        _pollTimer?.cancel();
      }
    } catch (_) {
      // Transient — keep polling until the attempt cap.
      if (_pollAttempts >= _maxPolls) _pollTimer?.cancel();
    }
  }

  void _finishUnconfirmed() {
    _pollTimer?.cancel();
    final sale = _pendingSale;
    if (sale == null) {
      context.go('/pos');
      return;
    }
    context.go('/pos/receipt', extra: _completed(sale));
  }

  Future<void> _resendStk() async {
    final sale = _pendingSale;
    if (sale == null) return;
    try {
      await ref.read(apiClientProvider).initiateTumiziOrderPayment(
            sale.id,
            phoneNumber: _phone.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _mpesaStatus = 'pending';
        _pollAttempts = 0;
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(posCartProvider);
    final totals = ref.watch(posTotalsProvider);
    final settings = ref.watch(posBootstrapProvider).valueOrNull?.settings ??
        PosSettings.empty;

    if (_phase == _Phase.waitingForMpesa) {
      return _MpesaWaiting(
        currency: settings.currency,
        total: _pendingSale?.total ?? totals.total,
        phone: _phone.text.trim(),
        status: _mpesaStatus,
        exhausted: _pollAttempts >= _maxPolls,
        onResend: _resendStk,
        onFinish: _finishUnconfirmed,
      );
    }

    // Form phase — needs a non-empty cart.
    if (cart.isEmpty && !_submitting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/pos');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final currency = settings.currency;
    final total = totals.total;
    final tendered = _tenderedValue;
    final change = (_method == PosPaymentMethod.cash &&
            tendered != null &&
            tendered >= total)
        ? tendered - total
        : null;
    final phoneOk = _method != PosPaymentMethod.mpesa ||
        _phone.text.replaceAll(RegExp(r'\D'), '').length >= 9;
    final cashOk = _method != PosPaymentMethod.cash ||
        tendered == null ||
        tendered >= total;
    final canSubmit = !_submitting && phoneOk && cashOk;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                Text('Amount due',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(currency.format(total),
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SegmentedButton<PosPaymentMethod>(
            segments: [
              if (settings.payments.cashEnabled)
                const ButtonSegment(
                  value: PosPaymentMethod.cash,
                  label: Text('Cash'),
                  icon: Icon(Icons.payments_outlined),
                ),
              if (settings.payments.mpesaStkEnabled)
                const ButtonSegment(
                  value: PosPaymentMethod.mpesa,
                  label: Text('M-Pesa'),
                  icon: Icon(Icons.smartphone_rounded),
                ),
              const ButtonSegment(
                value: PosPaymentMethod.other,
                label: Text('Other'),
                icon: Icon(Icons.check_circle_outline_rounded),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 16),
          if (_method == PosPaymentMethod.cash)
            ..._cashFields(theme, currency, tendered, change, total)
          else if (_method == PosPaymentMethod.mpesa)
            ..._mpesaFields(theme)
          else
            Text(
              'Records the sale as paid without an electronic transaction — '
              'use this when the customer has already paid (e.g. to your own '
              'M-Pesa till).',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _method == PosPaymentMethod.mpesa
                        ? 'Send M-Pesa request • ${currency.format(total)}'
                        : 'Complete sale • ${currency.format(total)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _cashFields(
    ThemeData theme,
    PosCurrency currency,
    double? tendered,
    double? change,
    double total,
  ) =>
      [
        TextField(
          controller: _tendered,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Cash received (optional)',
            prefixText: '${currency.symbol} ',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (change != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.mpesaGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('Change due',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(currency.format(change),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          )
        else if (tendered != null && tendered < total)
          Text('That is less than the amount due.',
              style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600)),
      ];

  List<Widget> _mpesaFields(ThemeData theme) => [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Customer M-Pesa number',
            hintText: '07XX XXX XXX',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'An STK push is sent to this number. The sale is recorded straight '
          'away and marked paid once the customer approves it.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ];
}

class _MpesaWaiting extends StatelessWidget {
  const _MpesaWaiting({
    required this.currency,
    required this.total,
    required this.phone,
    required this.status,
    required this.exhausted,
    required this.onResend,
    required this.onFinish,
  });

  final PosCurrency currency;
  final double total;
  final String phone;
  final String status;
  final bool exhausted;
  final VoidCallback onResend;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = status == 'failed' || status == 'cancelled';
    final waiting = !failed && status != 'paid';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('M-Pesa payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (waiting)
              const CircularProgressIndicator()
            else
              Icon(
                failed ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                size: 56,
                color: failed
                    ? theme.colorScheme.error
                    : AppTheme.mpesaGreen,
              ),
            const SizedBox(height: 20),
            Text(
              failed
                  ? 'Payment not completed'
                  : exhausted
                      ? 'Still waiting for M-Pesa'
                      : 'Waiting for the customer',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              failed
                  ? 'The request to $phone was declined or timed out. The sale '
                      'is recorded as unpaid — you can resend the request or '
                      'finish and collect payment another way.'
                  : 'Ask the customer to enter their M-Pesa PIN on $phone to '
                      'pay ${currency.format(total)}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            if (failed || exhausted)
              FilledButton.icon(
                onPressed: onResend,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Resend request'),
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onFinish,
              child: Text(failed || exhausted
                  ? 'Finish (unpaid)'
                  : 'I\'ll confirm later'),
            ),
          ],
        ),
      ),
    );
  }
}
