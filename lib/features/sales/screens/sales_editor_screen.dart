import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';

/// Edit Sale — Stitch: Sales Editor (8792636371ab4a40bf1c564d2419a238).
/// Full-screen route: no dashboard bottom bar (Stitch mock nav omitted in app).
class SalesEditorScreen extends StatefulWidget {
  const SalesEditorScreen({super.key});

  @override
  State<SalesEditorScreen> createState() => _SalesEditorScreenState();
}

class _SaleProduct {
  _SaleProduct({
    required this.name,
    required this.original,
    required this.salePriceCtrl,
    required this.imageUrl,
  });

  final String name;
  final double original;
  final TextEditingController salePriceCtrl;
  final String imageUrl;
}

class _SalesEditorScreenState extends State<SalesEditorScreen> {
  late List<_SaleProduct> _products;

  final _saleName = TextEditingController(text: 'Summer Solstice Clearance');
  final _startDateDisplay = TextEditingController();
  final _endDateDisplay = TextEditingController();
  DateTime _startDate = DateTime(2024, 6, 21);
  DateTime _endDate = DateTime(2024, 6, 30);
  final _note = TextEditingController(
    text: 'Focusing on top sellers for the summer clearance event.',
  );

  static const _imgWatch =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCTdqT2--QFc1OdPIKI-h3R2mEYccgcTIHLF1ZekF7QiOEDoscpw7-9pASVFGIvqNQJduHOI2zQpRj3byf8DoIIC6-Q0GmxnqwPnE3nG6YOye6cgEmhO4zLdv3KEZ9PRWUNSxIj14CAecSnTaxEJQCThCTX0ssquqtvIZ52XNfI3HunQ_S_iEeYebG0AwgbHZV8tUNRs6WV9KQXJW2O43MRhToJrEHNII8lOsImOgbd9FSY21vPe4Ki_qrs-N7q4ZG6Iuqrk30LJHoy';
  static const _imgHeadphones =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAr-TmD6bGqu7rrVKDnk7OFvWhKhzveE6EznZuL2-_ZY_mp671PETbsHtzy5eNf2O7eTdxqhpPzRYw5_UZO2sGo_zjRWpNOKPSz9BV2zTXqFEolQ4RtYTxjGsFPwmvuQVMgGSp6k6iMCW3RTXbb7Vr6R1Q2Yt9HjQx1bUj_2gTZwy_nMMSW2vrxBpJ5bcsQJKfzYZgRekijnhRahlpcOujZ9niGdL51_REMchFgi7wrIBlo2q6wDjLg_55DWg7pxwDEuQM7rCMjp80M';
  static const _imgSneakers =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCg9j4DS723vZU5EZSqm0rCQMfAlHp7eWXJsYQxSJOcGwE8VmA2x-DRtKxTfThhvcy8yy4PZUbsa5daRKC1iP9WuqCDHqUak94QTIgavReecYmdPz3-TsOC9dNNlrI5uP4KPmhe2khcRgdFnH5O_cRMzhiP62s8pFYfkjIZo_bwVO-noV1YOmUP3Xp0modw-IPc6HXyvL_WId893rs57e0dwmsf5Ke3gclK9CH44B0bLDFW5KzomcKpzHW5M_5ucC45UxiAkEk-anEG';

  static final _dateFmt = DateFormat.yMMMMd();

  void _syncDateFields() {
    _startDateDisplay.text = _dateFmt.format(_startDate);
    _endDateDisplay.text = _dateFmt.format(_endDate);
  }

  @override
  void initState() {
    super.initState();
    _syncDateFields();
    _products = [
      _SaleProduct(
        name: 'Minimalist Chrono Watch',
        original: 120,
        salePriceCtrl: TextEditingController(text: '89.00'),
        imageUrl: _imgWatch,
      ),
      _SaleProduct(
        name: 'Studio Wireless Gen 2',
        original: 299,
        salePriceCtrl: TextEditingController(text: '245.00'),
        imageUrl: _imgHeadphones,
      ),
      _SaleProduct(
        name: 'CloudRun Performance',
        original: 85,
        salePriceCtrl: TextEditingController(text: '65.00'),
        imageUrl: _imgSneakers,
      ),
    ];
  }

  @override
  void dispose() {
    for (final p in _products) {
      p.salePriceCtrl.dispose();
    }
    _saleName.dispose();
    _startDateDisplay.dispose();
    _endDateDisplay.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _syncDateFields();
    });
  }

  void _removeProduct(int index) {
    setState(() {
      final removed = _products.removeAt(index);
      removed.salePriceCtrl.dispose();
    });
  }

  void _addProduct() {
    setState(() {
      _products.add(
        _SaleProduct(
          name: 'New product',
          original: 0,
          salePriceCtrl: TextEditingController(text: '0.00'),
          imageUrl: _imgWatch,
        ),
      );
    });
  }

  Future<void> _confirmDeleteSale() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this sale?'),
        content: const Text(
          'This removes the sale campaign from your workspace (demo). This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.pop();
    }
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale saved (demo)')),
    );
    context.pop();
  }

  InputDecoration _fieldDeco(ThemeData theme, {String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.primaryDark, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Sale',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'General Info',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                'Step 1 of 2',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Sale Name',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _saleName,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            decoration: _fieldDeco(theme, hint: 'Enter sale name'),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 520;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _dateField(
                        theme,
                        label: 'Start Date',
                        controller: _startDateDisplay,
                        icon: Icons.calendar_today_outlined,
                        onPick: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _dateField(
                        theme,
                        label: 'End Date',
                        controller: _endDateDisplay,
                        icon: Icons.calendar_month_outlined,
                        onPick: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dateField(
                    theme,
                    label: 'Start Date',
                    controller: _startDateDisplay,
                    icon: Icons.calendar_today_outlined,
                    onPick: () => _pickDate(isStart: true),
                  ),
                  const SizedBox(height: 16),
                  _dateField(
                    theme,
                    label: 'End Date',
                    controller: _endDateDisplay,
                    icon: Icons.calendar_month_outlined,
                    onPick: () => _pickDate(isStart: false),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Products',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text('Add Product', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No products in this sale. Tap Add Product.',
                  style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...List.generate(_products.length, (i) => _productCard(context, theme, i)),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth > 600) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _revenueCard(theme)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _quickNoteCard(theme)),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _revenueCard(theme),
                  const SizedBox(height: 16),
                  _quickNoteCard(theme),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Step 2 coming soon (demo)')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Continue to step 2',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _confirmDeleteSale,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.15), width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Delete sale',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(
    ThemeData theme, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onPick,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          decoration: _fieldDeco(
            theme,
            suffix: IconButton(
              icon: Icon(icon, color: theme.colorScheme.outline, size: 22),
              onPressed: onPick,
              tooltip: 'Choose date',
            ),
          ),
        ),
      ],
    );
  }

  Widget _productCard(BuildContext context, ThemeData theme, int i) {
    final p = _products[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0C0528).withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CachedNetworkImage(
                    imageUrl: p.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ColoredBox(color: theme.colorScheme.surfaceContainerLow),
                    errorWidget: (_, __, ___) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerLow,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Original: \$${p.original.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Sale Price:',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: p.salePriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              prefixText: '\$ ',
                              prefixStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.outlineVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove product',
                onPressed: () => _removeProduct(i),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _revenueCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            bottom: -28,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Revenue Impact',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '+\$4,250.00',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: Colors.white.withValues(alpha: 0.9), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '12% higher than last sale campaign',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickNoteCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'QUICK NOTE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 4,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.45,
              color: AppTheme.onSurfaceVariant,
            ),
            decoration: InputDecoration(
              hintText: 'Note for your team…',
              hintStyle: GoogleFonts.inter(color: theme.colorScheme.outline, fontStyle: FontStyle.italic),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
