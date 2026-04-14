import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../dashboard/providers/dashboard_local_onboarding_provider.dart';
import '../providers/dashboard_settings_provider.dart';

/// Payment / M-Pesa configuration — Stitch: Payment Settings (d63f85c750fe4eb09247834fad7ca49f).
class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

enum _PayTiming { beforeDelivery, afterDelivery, either }

enum _MpesaMethod { sendMoney, buyGoods, paybill, pochi }

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen> {
  _PayTiming _timing = _PayTiming.afterDelivery;
  bool _cashEnabled = true;
  bool _mpesaEnabled = true;
  _MpesaMethod _mpesaMethod = _MpesaMethod.sendMoney;
  bool _saving = false;
  /// Server snapshot signature; avoids re-applying GET data on every local [setState] while still hydrating after refetch.
  String _lastHydratedPaymentSignature = '';

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

  void _hydrateFrom(Map<String, dynamic>? root) {
    final p = settingsSection(root, 'payment') ?? {};
    _cashEnabled = settingsPickBool(p, ['cash_enabled', 'cashEnabled', 'cod_enabled', 'cash'], fallback: true);
    _mpesaEnabled = settingsPickBool(p, ['mpesa_enabled', 'mpesaEnabled', 'mpesa'], fallback: true);
    _timing = _parsePayTiming(
      settingsPick(p, ['payment_timing', 'paymentTiming', 'pay_timing', 'when_to_pay', 'whenToPay']),
    );
    _mpesaMethod = _parseMpesa(
      settingsPick(p, ['mpesa_method', 'mpesaMethod', 'mpesa_type', 'mpesaType', 'lipa_method']),
    );
    _sendMoneyPhone.text = settingsPick(p, [
      'mpesa_phone',
      'mpesaPhone',
      'phone',
      'send_money_phone',
      'lipa_phone',
    ]);
    _tillNumber.text = settingsPick(p, ['till_number', 'tillNumber', 'till']);
    _paybillNumber.text = settingsPick(p, ['paybill_number', 'paybillNumber', 'paybill']);
    _accountNumber.text = settingsPick(p, ['account_number', 'accountNumber', 'paybill_account', 'paybillAccount']);
    _pochiPhone.text = settingsPick(p, ['pochi_phone', 'pochiPhone', 'pochi']);
  }

  static String _paymentSectionSignature(Map<String, dynamic>? p) {
    if (p == null || p.isEmpty) return '';
    final keys = p.keys.toList()..sort();
    return jsonEncode({for (final k in keys) k: p[k]});
  }

  void _hydrateWhenPaymentSectionChanges(Map<String, dynamic>? root) {
    final sig = _paymentSectionSignature(settingsSection(root, 'payment'));
    if (sig == _lastHydratedPaymentSignature) return;
    _lastHydratedPaymentSignature = sig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hydrateFrom(root);
      setState(() {});
    });
  }

  static _PayTiming _parsePayTiming(String raw) {
    final s = raw.toLowerCase().replaceAll('-', '_');
    if (s.contains('before')) return _PayTiming.beforeDelivery;
    if (s.contains('either') || s.contains('choice') || s.contains('any')) return _PayTiming.either;
    return _PayTiming.afterDelivery;
  }

  static _MpesaMethod _parseMpesa(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('till') || s.contains('buy_goods')) return _MpesaMethod.buyGoods;
    if (s.contains('paybill')) return _MpesaMethod.paybill;
    if (s.contains('pochi')) return _MpesaMethod.pochi;
    return _MpesaMethod.sendMoney;
  }

  String _apiTiming() {
    switch (_timing) {
      case _PayTiming.beforeDelivery:
        return 'before_delivery';
      case _PayTiming.either:
        return 'either';
      case _PayTiming.afterDelivery:
        return 'after_delivery';
    }
  }

  String _apiMpesaMethod() {
    switch (_mpesaMethod) {
      case _MpesaMethod.buyGoods:
        return 'buy_goods';
      case _MpesaMethod.paybill:
        return 'paybill';
      case _MpesaMethod.pochi:
        return 'pochi';
      case _MpesaMethod.sendMoney:
        return 'send_money';
    }
  }

  Future<void> _save() async {
    if (!_cashEnabled && !_mpesaEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable cash or M-Pesa before saving.')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final timing = _apiTiming();
      final mpesaMethod = _apiMpesaMethod();
      final mpesaPhone = _sendMoneyPhone.text.trim();
      final till = _tillNumber.text.trim();
      final paybill = _paybillNumber.text.trim();
      final account = _accountNumber.text.trim();
      final pochi = _pochiPhone.text.trim();
      // Mirror camelCase + snake_case so the API persists regardless of which keys the server reads.
      final body = <String, dynamic>{
        'payment': {
          'cashEnabled': _cashEnabled,
          'cash_enabled': _cashEnabled,
          'mpesaEnabled': _mpesaEnabled,
          'mpesa_enabled': _mpesaEnabled,
          'paymentTiming': timing,
          'payment_timing': timing,
          'mpesaMethod': mpesaMethod,
          'mpesa_method': mpesaMethod,
          'mpesaPhone': mpesaPhone,
          'mpesa_phone': mpesaPhone,
          'tillNumber': till,
          'till_number': till,
          'paybillNumber': paybill,
          'paybill_number': paybill,
          'paybillAccount': account,
          'paybill_account': account,
          'pochiPhone': pochi,
          'pochi_phone': pochi,
        },
      };
      final api = ref.read(apiClientProvider);
      final r = await api.patchDashboardSettings(body);
      if (!mounted) return;
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.message ?? 'Could not save payment settings')),
        );
        return;
      }
      final patched = unwrapSettingsData(r.data);
      if (patched != null && settingsSection(patched, 'payment') != null) {
        _hydrateFrom(patched);
        _lastHydratedPaymentSignature = _paymentSectionSignature(settingsSection(patched, 'payment'));
      }
      final refreshedRoot = await ref.refresh(dashboardSettingsProvider.future);
      if (refreshedRoot != null) {
        _lastHydratedPaymentSignature =
            _paymentSectionSignature(settingsSection(refreshedRoot, 'payment'));
      }
      if (!mounted) return;
      ref.read(dashboardLocalStepCompletionsProvider.notifier).markComplete(DashboardOnboardingStepKeys.payment);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment settings saved')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final settingsAsync = ref.watch(dashboardSettingsProvider);

    return settingsAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(title: const Text('Payments')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Payments'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(dashboardSettingsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (root) {
        _hydrateWhenPaymentSectionChanges(root);
        return _buildScaffold(theme);
      },
    );
  }

  Widget _buildScaffold(ThemeData theme) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Payments'),
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
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 22),
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
