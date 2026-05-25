import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';

/// Bottom sheet for `POST /dashboard/inventory/adjust`.
///
/// Typical `adjustmentType` values served by backends: increase, decrease,
/// correction, restock — this UI maps friendly labels while sending the slug.
class AdjustmentRow {
  const AdjustmentRow({
    required this.productId,
    required this.variantId,
    required this.productName,
    this.skuLabel = '',
    this.currentStockLabel = '',
  });

  final String productId;
  final String variantId;
  final String productName;
  final String skuLabel;
  final String currentStockLabel;
}

Future<void> showAdjustStockSheet(
  BuildContext context,
  WidgetRef ref, {
  required AdjustmentRow row,
  VoidCallback? onSuccess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _AdjustStockSheetBody(
          row: row,
          ref: ref,
          onDone: () {
            Navigator.pop(ctx);
            onSuccess?.call();
          },
        ),
      );
    },
  );
}

class _AdjustmentTypeChoice {
  const _AdjustmentTypeChoice(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class _AdjustStockSheetBody extends StatefulWidget {
  const _AdjustStockSheetBody({
    required this.row,
    required this.ref,
    required this.onDone,
  });

  final AdjustmentRow row;
  final WidgetRef ref;
  final VoidCallback onDone;

  @override
  State<_AdjustStockSheetBody> createState() => _AdjustStockSheetBodyState();
}

class _AdjustStockSheetBodyState extends State<_AdjustStockSheetBody> {
  static const _types = [
    _AdjustmentTypeChoice('increase', 'Add stock (+)'),
    _AdjustmentTypeChoice('decrease', 'Remove stock (–)'),
    _AdjustmentTypeChoice('correction', 'Correction / count fix'),
    _AdjustmentTypeChoice('restock', 'Restock inbound'),
    _AdjustmentTypeChoice('damage', 'Damage / loss'),
    _AdjustmentTypeChoice('return', 'Customer return'),
  ];

  final _qtyController = TextEditingController(text: '1');
  _AdjustmentTypeChoice _selected = _types.first;
  bool _submitting = false;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a positive whole-number quantity')),
      );
      return;
    }
    if (widget.row.productId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing product id')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'productId': widget.row.productId.trim(),
        'adjustmentType': _selected.apiValue,
        'quantity': qty,
      };
      final variant = widget.row.variantId.trim();
      if (variant.isNotEmpty) {
        body['variantId'] = variant;
      }

      final api = widget.ref.read(apiClientProvider);
      final response = await api.adjustInventory(body);
      if (!response.success) {
        throw Exception(response.error?.message ?? 'Adjustment failed');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated')),
      );
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not adjust: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.row;
    final metaParts = [
      if (r.skuLabel.isNotEmpty) 'SKU: ${r.skuLabel}',
      if (r.variantId.trim().isNotEmpty) 'Variant: ${r.variantId}',
      if (r.currentStockLabel.isNotEmpty)
        'Current: ${r.currentStockLabel}',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Adjust stock',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            r.productName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (metaParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                metaParts.join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Adjustment type',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _types)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _selected.apiValue == t.apiValue,
                  onSelected: (_) => setState(() => _selected = t),
                  selectedColor: AppTheme.primary,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: _selected.apiValue == t.apiValue
                        ? Colors.white
                        : AppTheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quantity',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Units',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Apply adjustment'),
          ),
          TextButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).maybePop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
