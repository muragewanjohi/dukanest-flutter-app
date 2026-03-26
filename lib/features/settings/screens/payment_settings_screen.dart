import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// Payment / M-Pesa configuration — Stitch: Payment Settings (d63f85c750fe4eb09247834fad7ca49f).
class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

enum _PayTiming { beforeDelivery, afterDelivery, either }

enum _MpesaMethod { sendMoney, buyGoods, paybill, pochi }

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  _PayTiming _timing = _PayTiming.afterDelivery;
  bool _cashEnabled = true;
  bool _mpesaEnabled = true;
  _MpesaMethod _mpesaMethod = _MpesaMethod.sendMoney;

  final _sendMoneyPhone = TextEditingController();
  final _tillNumber = TextEditingController();
  final _paybillNumber = TextEditingController();
  final _accountNumber = TextEditingController();
  final _pochiPhone = TextEditingController();

  @override
  void dispose() {
    _sendMoneyPhone.dispose();
    _tillNumber.dispose();
    _paybillNumber.dispose();
    _accountNumber.dispose();
    _pochiPhone.dispose();
    super.dispose();
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment settings saved (demo)')),
    );
    context.pop();
  }

  InputDecoration _inputDeco(ThemeData theme, {required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: theme.colorScheme.outlineVariant),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Payments',
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
              children: [
                Text(
                  'Payment Timing',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configure when your customers are required to settle payments.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _timingTile(theme, _PayTiming.beforeDelivery, 'Pay Before Delivery'),
                const SizedBox(height: 10),
                _timingTile(theme, _PayTiming.afterDelivery, 'Pay After Delivery'),
                const SizedBox(height: 10),
                _timingTile(theme, _PayTiming.either, 'User Can Pay Before or After'),
                const SizedBox(height: 28),
                Text(
                  'Payment Methods',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                _methodToggleRow(
                  theme,
                  icon: Icons.payments_outlined,
                  title: 'Cash',
                  subtitle: 'Enable cash on delivery payments',
                  value: _cashEnabled,
                  onChanged: (v) => setState(() => _cashEnabled = v),
                ),
                const SizedBox(height: 12),
                _mpesaSection(theme),
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
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 22),
                  label: Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timingTile(ThemeData theme, _PayTiming value, String label) {
    final selected = _timing == value;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _timing = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: 2,
              color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
            ),
            color: selected ? theme.colorScheme.surfaceContainerLowest : null,
          ),
          child: Row(
            children: [
              _radioDot(theme, selected: selected),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioDot(ThemeData theme, {required bool selected}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.primaryDark : theme.colorScheme.outlineVariant,
          width: 2,
        ),
        color: selected ? AppTheme.primaryDark.withValues(alpha: 0.12) : Colors.transparent,
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppTheme.primaryDark, shape: BoxShape.circle),
              ),
            )
          : null,
    );
  }

  Widget _methodToggleRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
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
      ),
    );
  }

  Widget _mpesaSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'M-Pesa',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mobile money integration',
                        style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _mpesaEnabled,
                  onChanged: (v) => setState(() => _mpesaEnabled = v),
                  activeTrackColor: theme.colorScheme.primaryContainer,
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
          ),
          if (_mpesaEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Verification Required',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All M-Pesa payment options require manual verification. The system cannot automatically verify payments. You will need to manually confirm payments before fulfilling orders.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.4,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: theme.colorScheme.surfaceContainer,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT M-PESA METHOD',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _mpesaMethodCard(
                    theme,
                    method: _MpesaMethod.sendMoney,
                    title: 'Send Money',
                    subtitle: null,
                    fields: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'M-PESA NUMBER',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _sendMoneyPhone,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDeco(theme, hint: '0712 345 678'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _mpesaMethodCard(
                    theme,
                    method: _MpesaMethod.buyGoods,
                    title: 'Buy Goods',
                    subtitle: 'Customers pay using your Till Number',
                    fields: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        TextField(
                          controller: _tillNumber,
                          keyboardType: TextInputType.number,
                          decoration: _inputDeco(theme, hint: 'Enter Till Number (e.g., 123456)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _mpesaMethodCard(
                    theme,
                    method: _MpesaMethod.paybill,
                    title: 'Paybill',
                    subtitle: 'Customers pay using your Paybill number and account number',
                    fields: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        TextField(
                          controller: _paybillNumber,
                          keyboardType: TextInputType.number,
                          decoration: _inputDeco(theme, hint: 'Enter Paybill Number (e.g., 123456)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _accountNumber,
                          keyboardType: TextInputType.text,
                          decoration: _inputDeco(theme, hint: 'Enter Account Number'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _mpesaMethodCard(
                    theme,
                    method: _MpesaMethod.pochi,
                    title: 'Pochi la Biashara',
                    subtitle: 'Customers pay using your Pochi la Biashara phone number',
                    fields: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pochiPhone,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDeco(theme, hint: 'Enter Phone Number (e.g., 0712345678)'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mpesaMethodCard(
    ThemeData theme, {
    required _MpesaMethod method,
    required String title,
    required String? subtitle,
    required Widget fields,
  }) {
    final selected = _mpesaMethod == method;
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _mpesaMethod = method),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: 2,
              color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _radioDot(theme, selected: selected),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (selected) fields,
            ],
          ),
        ),
      ),
    );
  }
}
