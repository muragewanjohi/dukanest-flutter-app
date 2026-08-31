import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../data/pos_cart.dart';
import '../data/pos_models.dart';
import '../data/pos_totals.dart';
import '../providers/pos_providers.dart';

/// Review the cart before payment: quantities, line + order discounts,
/// optional customer, notes, and the totals breakdown.
class PosCartScreen extends ConsumerStatefulWidget {
  const PosCartScreen({super.key});

  @override
  ConsumerState<PosCartScreen> createState() => _PosCartScreenState();
}

class _PosCartScreenState extends ConsumerState<PosCartScreen> {
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cart = ref.read(posCartProvider);
    _customerName.text = cart.customerName;
    _customerPhone.text = cart.customerPhone;
    _notes.text = cart.notes;
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _editAmount({
    required String title,
    required double current,
    required ValueChanged<double> onSave,
  }) async {
    final controller =
        TextEditingController(text: current > 0 ? _trim(current) : '');
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(hintText: '0'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0.0),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.trim()) ?? current,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value != null) onSave(value < 0 ? 0 : value);
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  void _goToTender() {
    final notifier = ref.read(posCartProvider.notifier);
    notifier.setCustomer(
      name: _customerName.text.trim(),
      phone: _customerPhone.text.trim(),
    );
    notifier.setNotes(_notes.text.trim());
    context.push('/pos/tender');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = ref.watch(posCartProvider);
    final notifier = ref.read(posCartProvider.notifier);
    final totals = ref.watch(posTotalsProvider);
    final currency =
        ref.watch(posBootstrapProvider).valueOrNull?.settings.currency ??
            PosCurrency.fallback;

    if (cart.isEmpty) {
      // Nothing to review — bounce back to the register.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Review sale')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (final line in cart.lines)
            _LineCard(
              line: line,
              currency: currency,
              onQtyChanged: (q) => notifier.setQuantity(line.lineKey, q),
              onRemove: () => notifier.removeLine(line.lineKey),
              onDiscount: () => _editAmount(
                title: 'Discount — ${line.displayName}',
                current: line.discountAmount,
                onSave: (v) => notifier.setLineDiscount(line.lineKey, v),
              ),
            ),
          const SizedBox(height: 8),
          _RowButton(
            label: 'Order discount',
            value: cart.orderDiscount > 0
                ? '− ${currency.format(cart.orderDiscount)}'
                : 'Add',
            onTap: () => _editAmount(
              title: 'Order discount',
              current: cart.orderDiscount,
              onSave: notifier.setOrderDiscount,
            ),
          ),
          const SizedBox(height: 20),
          Text('Customer (optional)',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _customerName,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration(theme, 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customerPhone,
            keyboardType: TextInputType.phone,
            decoration: _fieldDecoration(theme, 'Phone'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: _fieldDecoration(theme, 'Note (optional)'),
          ),
          const SizedBox(height: 20),
          _TotalsCard(totals: totals, currency: currency),
          if (cart.hasOversoldLine) ...[
            const SizedBox(height: 12),
            _OversoldWarning(),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _goToTender,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Charge ${currency.format(totals.total)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(ThemeData theme, String label) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.currency,
    required this.onQtyChanged,
    required this.onRemove,
    required this.onDiscount,
  });

  final PosCartLine line;
  final PosCurrency currency;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;
  final VoidCallback onDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      line.displayName,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: onRemove,
                  ),
                ],
              ),
              Text(
                '${currency.format(line.unitPrice)} each',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (line.isOversold)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Only ${line.availableStock} in stock',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _QtyStepper(
                    quantity: line.quantity,
                    onChanged: onQtyChanged,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onDiscount,
                    icon: const Icon(Icons.percent_rounded, size: 16),
                    label: Text(
                      line.discountAmount > 0
                          ? '− ${currency.format(line.discountAmount)}'
                          : 'Discount',
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  currency.format(line.lineTotal),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.quantity, required this.onChanged});
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
            onPressed: () => onChanged(quantity - 1),
          ),
          Text('$quantity',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.totals,
    required this.currency,
  });
  final PosTotals totals;
  final PosCurrency currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: bold
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontWeight:
                          bold ? FontWeight.w900 : FontWeight.w700)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          row('Subtotal', currency.format(totals.grossSubtotal)),
          if (totals.discountTotal > 0)
            row('Discount', '− ${currency.format(totals.discountTotal)}'),
          if (totals.taxAmount > 0) row('Tax', currency.format(totals.taxAmount)),
          const Divider(height: 18),
          row('Total', currency.format(totals.total), bold: true),
        ],
      ),
    );
  }
}

class _OversoldWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Some lines exceed recorded stock. The sale will still go '
              'through — check your counts afterwards.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
