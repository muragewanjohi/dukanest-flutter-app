import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import 'adjust_stock_sheet.dart';

/// Multi-row bulk stock adjustment via `POST /dashboard/inventory/bulk`.
/// Lets the merchant set a shared adjustment type and per-row quantities, then
/// submits every non-zero row in a single request.
Future<void> showBulkAdjustSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<AdjustmentRow> rows,
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
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _BulkAdjustBody(
          rows: rows,
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

class _TypeChoice {
  const _TypeChoice(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class _BulkAdjustBody extends StatefulWidget {
  const _BulkAdjustBody({
    required this.rows,
    required this.ref,
    required this.onDone,
  });

  final List<AdjustmentRow> rows;
  final WidgetRef ref;
  final VoidCallback onDone;

  @override
  State<_BulkAdjustBody> createState() => _BulkAdjustBodyState();
}

class _BulkAdjustBodyState extends State<_BulkAdjustBody> {
  static const _types = [
    _TypeChoice('increase', 'Add stock (+)'),
    _TypeChoice('decrease', 'Remove stock (–)'),
    _TypeChoice('correction', 'Correction / count fix'),
    _TypeChoice('restock', 'Restock inbound'),
    _TypeChoice('damage', 'Damage / loss'),
    _TypeChoice('return', 'Customer return'),
  ];

  _TypeChoice _selected = _types.first;
  bool _submitting = false;
  late final List<TextEditingController> _qty;

  @override
  void initState() {
    super.initState();
    _qty = List.generate(widget.rows.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _qty) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final adjustments = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.rows.length; i++) {
      final qty = int.tryParse(_qty[i].text.trim()) ?? 0;
      if (qty <= 0) continue;
      final row = widget.rows[i];
      if (row.productId.trim().isEmpty) continue;
      final entry = <String, dynamic>{
        'productId': row.productId.trim(),
        'adjustmentType': _selected.apiValue,
        'quantity': qty,
      };
      if (row.variantId.trim().isNotEmpty) {
        entry['variantId'] = row.variantId.trim();
      }
      adjustments.add(entry);
    }
    if (adjustments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a quantity for at least one product')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = widget.ref.read(apiClientProvider);
      final response = await api.bulkAdjustInventory({
        'adjustmentType': _selected.apiValue,
        'adjustments': adjustments,
        'items': adjustments,
      });
      if (!response.success) {
        throw Exception(response.error?.message ?? 'Bulk adjustment failed');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${adjustments.length} product(s)')),
      );
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk stock adjustment',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set quantities for the products you want to adjust.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
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
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              itemCount: widget.rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final row = widget.rows[i];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              if (row.skuLabel.isNotEmpty)
                                'SKU ${row.skuLabel}',
                              if (row.currentStockLabel.isNotEmpty)
                                'Stock ${row.currentStockLabel}',
                            ].join(' • '),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 84,
                      child: TextField(
                        controller: _qty[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Apply bulk adjustment'),
            ),
          ),
        ],
      ),
    );
  }
}
