import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// Arguments when opening the editor from the manage-zones list (optional).
class DeliveryZoneEditorArgs {
  const DeliveryZoneEditorArgs({
    this.zoneKey,
    this.initialName,
    this.initialAreas,
    this.initialFeeKes,
    this.initialFreeOverKes,
    this.initialHandlingDays,
    this.initialIsDefault = false,
  });

  final String? zoneKey;
  final String? initialName;
  final List<String>? initialAreas;
  final String? initialFeeKes;
  final String? initialFreeOverKes;
  final String? initialHandlingDays;
  final bool initialIsDefault;

  bool get isEditing => zoneKey != null && zoneKey!.isNotEmpty;
}

/// Add / edit a delivery zone — Stitch: Add/Edit Delivery Zone (Mobile) (e7c632589b41441bb5bf8fa8e3f5a531).
class DeliveryZoneEditorScreen extends StatefulWidget {
  const DeliveryZoneEditorScreen({super.key, this.args});

  final DeliveryZoneEditorArgs? args;

  @override
  State<DeliveryZoneEditorScreen> createState() => _DeliveryZoneEditorScreenState();
}

class _DeliveryZoneEditorScreenState extends State<DeliveryZoneEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _fee;
  late final TextEditingController _freeOver;
  late final TextEditingController _handlingDays;
  late List<String> _areas;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    _name = TextEditingController(text: a?.initialName ?? '');
    _fee = TextEditingController(text: a?.initialFeeKes ?? '200');
    _freeOver = TextEditingController(text: a?.initialFreeOverKes ?? '0');
    _handlingDays = TextEditingController(text: a?.initialHandlingDays ?? '1');
    _areas = List<String>.from(a?.initialAreas ?? const []);
    _isDefault = a?.initialIsDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    _freeOver.dispose();
    _handlingDays.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.args?.isEditing ?? false;

  String get _appBarTitle => _isEditing ? 'Edit delivery zone' : 'Add delivery zone';

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Zone updated (demo)' : 'Zone created (demo)')),
    );
    context.pop();
  }

  void _addAreaPrompt() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add area',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'County, city, or sub-area',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final t = controller.text.trim();
                if (t.isNotEmpty) setState(() => _areas = [..._areas, t]);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _fieldDeco(ThemeData theme, {String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: prefixIcon,
    );
  }

  Widget _section(ThemeData theme, {required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _switchRow(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: theme.colorScheme.primaryContainer,
          activeThumbColor: Colors.white,
        ),
      ],
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.primaryDark, size: 26),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _appBarTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              children: [
                Text(
                  _isEditing ? 'Edit delivery zone' : 'New delivery zone',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Name the zone, choose which areas it covers, and set the delivery fee shoppers pay at checkout.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _section(
                  theme,
                  icon: Icons.badge_outlined,
                  title: 'Zone details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zone name',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDeco(theme, hint: 'e.g. Nairobi Metro'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  theme,
                  icon: Icons.map_outlined,
                  title: 'Coverage',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Included areas',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_areas.isEmpty)
                        Text(
                          'No areas yet. Add counties, cities, or neighborhoods customers can order from within this zone.',
                          style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: theme.colorScheme.outline),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _areas
                              .map(
                                (a) => InputChip(
                                  label: Text(a, style: GoogleFonts.inter(fontSize: 13)),
                                  deleteIcon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.outline),
                                  onDeleted: () => setState(() => _areas.remove(a)),
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _addAreaPrompt,
                        icon: Icon(Icons.add_rounded, size: 20, color: AppTheme.primaryDark),
                        label: Text(
                          'Add area',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryDark,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          side: BorderSide(color: AppTheme.primaryDark.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  theme,
                  icon: Icons.payments_outlined,
                  title: 'Rates',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flat delivery fee (KES)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fee,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDeco(
                          theme,
                          hint: 'e.g. 200',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 4),
                            child: Center(
                              widthFactor: 1,
                              child: Text('KES', style: GoogleFonts.inter(color: theme.colorScheme.outline, fontSize: 14)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Free delivery on orders over (KES)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _freeOver,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDeco(theme, hint: '0 = not offered in this zone'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  theme,
                  icon: Icons.schedule_outlined,
                  title: 'Fulfillment',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated handling (business days)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _handlingDays,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDeco(theme, hint: 'e.g. 1'),
                      ),
                      const SizedBox(height: 20),
                      _switchRow(
                        theme,
                        title: 'Default zone',
                        subtitle: 'Use this zone when an address does not match another zone',
                        value: _isDefault,
                        onChanged: (v) => setState(() => _isDefault = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Overlapping areas use the most specific zone match. Review your list so customers always see the right fee.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.45,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            elevation: 8,
            color: AppTheme.surface.withValues(alpha: 0.9),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF001790), Color(0xFF0025CC)],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _save,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            _isEditing ? 'Save zone' : 'Create zone',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
