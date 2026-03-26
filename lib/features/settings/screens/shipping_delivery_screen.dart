import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// Shipping & delivery — Stitch: Shipping & Delivery (Mobile) (b1de30ad39f34a3ba10883af6a0de581).
class ShippingDeliveryScreen extends StatefulWidget {
  const ShippingDeliveryScreen({super.key});

  @override
  State<ShippingDeliveryScreen> createState() => _ShippingDeliveryScreenState();
}

class _ShippingDeliveryScreenState extends State<ShippingDeliveryScreen> {
  bool _localDelivery = true;
  bool _nationwide = true;
  bool _storePickup = false;

  final _flatRate = TextEditingController(text: '250');
  final _freeOver = TextEditingController(text: '5000');
  final _handlingDays = TextEditingController(text: '1');

  @override
  void dispose() {
    _flatRate.dispose();
    _freeOver.dispose();
    _handlingDays.dispose();
    super.dispose();
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shipping settings saved (demo)')),
    );
    context.pop();
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
          'Shipping & Delivery',
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
                  'Shipping & Delivery',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Define how customers receive orders: zones, fees, estimated timelines, and pickup options.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _section(
                  theme,
                  icon: Icons.map_outlined,
                  title: 'Coverage',
                  child: Column(
                    children: [
                      _switchRow(
                        theme,
                        title: 'Local delivery',
                        subtitle: 'Deliver within your city or metro area',
                        value: _localDelivery,
                        onChanged: (v) => setState(() => _localDelivery = v),
                      ),
                      const Divider(height: 24),
                      _switchRow(
                        theme,
                        title: 'Nationwide shipping',
                        subtitle: 'Courier or partner delivery across the country',
                        value: _nationwide,
                        onChanged: (v) => setState(() => _nationwide = v),
                      ),
                      const Divider(height: 24),
                      _switchRow(
                        theme,
                        title: 'Store pickup',
                        subtitle: 'Let customers collect orders at your location',
                        value: _storePickup,
                        onChanged: (v) => setState(() => _storePickup = v),
                      ),
                      const Divider(height: 28),
                      _manageZonesRow(context, theme),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  theme,
                  icon: Icons.local_shipping_outlined,
                  title: 'Rates & free shipping',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Standard flat rate (KES)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _flatRate,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDeco(
                          theme,
                          hint: 'e.g. 250',
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
                        'Free shipping on orders over (KES)',
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
                        decoration: _fieldDeco(theme, hint: 'e.g. 5000 (0 to disable)'),
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
                        'Estimated order handling (business days)',
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
                          'Shipping rules shown here apply to your storefront checkout. Carrier integrations can be connected from your dashboard in a future release.',
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
                            'Save Changes',
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

  Widget _manageZonesRow(BuildContext context, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/shipping-zones'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage zones',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Group areas and set fees per delivery zone',
                      style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
