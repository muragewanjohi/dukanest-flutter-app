import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';
import '../../dashboard/providers/dashboard_local_onboarding_provider.dart';
import '../providers/dashboard_settings_provider.dart';
import '../tumizi_integration_sync.dart';

/// Merchant admin: storefront payment options (cash / M-Pesa / Tumizi, defaults). Does not initiate customer payments. Stitch: Payment Settings (d63f85c750fe4eb09247834fad7ca49f).
class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

enum _PayTiming { beforeDelivery, afterDelivery, either }

enum _MpesaMethod { sendMoney, buyGoods, paybill, pochi }
enum _DefaultPaymentMethod { cash, mpesa, tumizi }

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen>
    with FormErrorHighlightMixin {
  _PayTiming _timing = _PayTiming.beforeDelivery;
  bool _cashEnabled = true;
  bool _mpesaEnabled = true;
  bool _tumiziEnabled = true;
  _DefaultPaymentMethod _defaultMethod = _DefaultPaymentMethod.tumizi;
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
    _tumiziEnabled = _readTumiziEnabled(p);
    _timing = _parsePayTiming(
      settingsPick(p, ['payment_timing', 'paymentTiming', 'pay_timing', 'when_to_pay', 'whenToPay']),
    );
    // Prefer camelCase keys — legacy snake_case `payment_method: cash` must not override `paymentMethod: tumizi`.
    _defaultMethod = _parseDefaultMethod(
      settingsPick(p, [
        'paymentMethod',
        'defaultMethod',
        'payment_method',
        'default_method',
      ]),
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
    _applyTumiziPreferredDefault();
  }

  /// Tumizi on when the API omits flags; explicit `false` is respected.
  bool _readTumiziEnabled(Map<String, dynamic> p) {
    for (final k in [
      'tumiziEnabled',
      'tumizi_enabled',
      'payment_tumizi_enabled',
    ]) {
      if (p.containsKey(k)) {
        return settingsPickBool(p, [k], fallback: false);
      }
    }
    return true;
  }

  /// Product default: Tumizi wallet is preferred whenever it is enabled.
  void _applyTumiziPreferredDefault() {
    if (_tumiziEnabled) {
      _defaultMethod = _DefaultPaymentMethod.tumizi;
      return;
    }
    _normalizeDefaultMethod();
  }

  /// Preferred order when auto-picking default: Tumizi → Cash → M-Pesa.
  _DefaultPaymentMethod _firstEnabledDefaultMethod() {
    if (_tumiziEnabled) return _DefaultPaymentMethod.tumizi;
    if (_cashEnabled) return _DefaultPaymentMethod.cash;
    if (_mpesaEnabled) return _DefaultPaymentMethod.mpesa;
    return _DefaultPaymentMethod.tumizi;
  }

  void _normalizeDefaultMethod() {
    final enabled = switch (_defaultMethod) {
      _DefaultPaymentMethod.tumizi => _tumiziEnabled,
      _DefaultPaymentMethod.cash => _cashEnabled,
      _DefaultPaymentMethod.mpesa => _mpesaEnabled,
    };
    if (!enabled) {
      _defaultMethod = _firstEnabledDefaultMethod();
    }
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
    if (s.contains('after')) return _PayTiming.afterDelivery;
    return _PayTiming.beforeDelivery;
  }

  static _MpesaMethod _parseMpesa(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('till') || s.contains('buy_goods')) return _MpesaMethod.buyGoods;
    if (s.contains('paybill')) return _MpesaMethod.paybill;
    if (s.contains('pochi')) return _MpesaMethod.pochi;
    return _MpesaMethod.sendMoney;
  }

  static _DefaultPaymentMethod _parseDefaultMethod(String raw) {
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return _DefaultPaymentMethod.tumizi;
    if (s == 'cash' || s == 'cod') return _DefaultPaymentMethod.cash;
    if (s == 'mpesa') return _DefaultPaymentMethod.mpesa;
    if (s == 'tumizi') return _DefaultPaymentMethod.tumizi;
    return _DefaultPaymentMethod.tumizi;
  }

  String _apiDefaultMethod() {
    switch (_defaultMethod) {
      case _DefaultPaymentMethod.cash:
        return 'cash';
      case _DefaultPaymentMethod.mpesa:
        return 'mpesa';
      case _DefaultPaymentMethod.tumizi:
        return 'tumizi';
    }
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
    if (!_cashEnabled && !_mpesaEnabled && !_tumiziEnabled) {
      reportFieldError(
        fieldId: 'paymentMethods',
        message: 'Enable at least one payment method before saving.',
      );
      return;
    }
    if (_defaultMethod == _DefaultPaymentMethod.cash && !_cashEnabled) {
      reportFieldError(
        fieldId: 'defaultPaymentMethod',
        message: 'Cash is selected as default but Cash is disabled.',
      );
      return;
    }
    if (_defaultMethod == _DefaultPaymentMethod.mpesa && !_mpesaEnabled) {
      reportFieldError(
        fieldId: 'defaultPaymentMethod',
        message: 'M-Pesa is selected as default but M-Pesa is disabled.',
      );
      return;
    }
    if (_defaultMethod == _DefaultPaymentMethod.tumizi && !_tumiziEnabled) {
      reportFieldError(
        fieldId: 'defaultPaymentMethod',
        message: 'Tumizi wallet can be default only when Tumizi wallet is enabled.',
      );
      return;
    }
    if (_mpesaEnabled) {
      switch (_mpesaMethod) {
        case _MpesaMethod.sendMoney:
          if (_sendMoneyPhone.text.trim().isEmpty) {
            reportFieldError(
              fieldId: 'sendMoneyPhone',
              message: 'Enter the M-Pesa Send Money phone number.',
            );
            return;
          }
          break;
        case _MpesaMethod.buyGoods:
          if (_tillNumber.text.trim().isEmpty) {
            reportFieldError(
              fieldId: 'tillNumber',
              message: 'Enter your Till Number.',
            );
            return;
          }
          break;
        case _MpesaMethod.paybill:
          if (_paybillNumber.text.trim().isEmpty) {
            reportFieldError(
              fieldId: 'paybillNumber',
              message: 'Enter your Paybill Number.',
            );
            return;
          }
          if (_accountNumber.text.trim().isEmpty) {
            reportFieldError(
              fieldId: 'accountNumber',
              message: 'Enter the Paybill Account Number.',
            );
            return;
          }
          break;
        case _MpesaMethod.pochi:
          if (_pochiPhone.text.trim().isEmpty) {
            reportFieldError(
              fieldId: 'pochiPhone',
              message: 'Enter your Pochi la Biashara phone number.',
            );
            return;
          }
          break;
      }
    }
    clearAllFieldErrors();
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final timing = _apiTiming();
      final mpesaMethod = _apiMpesaMethod();
      if (_tumiziEnabled) {
        _defaultMethod = _DefaultPaymentMethod.tumizi;
      }
      final defaultMethod = _apiDefaultMethod();
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
          'tumiziEnabled': _tumiziEnabled,
          'tumizi_enabled': _tumiziEnabled,
          'payment_tumizi_enabled': _tumiziEnabled,
          'paymentMethod': defaultMethod,
          'payment_method': defaultMethod,
          'defaultMethod': defaultMethod,
          'default_method': defaultMethod,
          'paymentTiming': timing,
          'payment_timing': timing,
          'timing': timing,
          'mpesaMethod': mpesaMethod,
          'mpesa_method': mpesaMethod,
          'mpesaPhone': mpesaPhone,
          'mpesa_phone': mpesaPhone,
          'mpesaSendMoneyNumber': mpesaPhone,
          'mpesaBuyGoodsTill': till,
          'mpesaPaybillNumber': paybill,
          'mpesaPaybillAccount': account,
          'mpesaPochiPhone': pochi,
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
      final tumiziSyncError = await syncTumiziIntegration(
        api,
        enabled: _tumiziEnabled,
      );
      if (!mounted) return;
      if (tumiziSyncError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tumiziSyncError)),
        );
        return;
      }
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

  InputDecoration _inputDeco(
    ThemeData theme, {
    required String hint,
    bool isInvalid = false,
  }) {
    final errorColor = theme.colorScheme.error;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: isInvalid
          ? BorderSide(color: errorColor, width: 1.5)
          : BorderSide.none,
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: theme.colorScheme.outlineVariant),
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainerLow,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(dashboardSettingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: DashboardAppBar(title: 'Payments'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: const DashboardAppBar(title: 'Payments'),
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
      appBar: const DashboardAppBar(title: 'Payments'),
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
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Tumizi wallet',
                  subtitle:
                      'Customers pay with an M-Pesa STK prompt; payments confirm automatically when this is on.',
                  value: _tumiziEnabled,
                  isPreferred:
                      _defaultMethod == _DefaultPaymentMethod.tumizi && _tumiziEnabled,
                  onChanged: (v) => setState(() {
                    _tumiziEnabled = v;
                    if (v) {
                      _defaultMethod = _DefaultPaymentMethod.tumizi;
                    } else if (_defaultMethod == _DefaultPaymentMethod.tumizi) {
                      _defaultMethod = _firstEnabledDefaultMethod();
                    }
                  }),
                ),
                const SizedBox(height: 12),
                _methodToggleRow(
                  theme,
                  icon: Icons.payments_outlined,
                  title: 'Cash',
                  subtitle: 'Enable cash on delivery payments',
                  value: _cashEnabled,
                  isPreferred:
                      _defaultMethod == _DefaultPaymentMethod.cash && _cashEnabled,
                  onChanged: (v) => setState(() {
                    _cashEnabled = v;
                    if (!v && _defaultMethod == _DefaultPaymentMethod.cash) {
                      _defaultMethod = _firstEnabledDefaultMethod();
                    }
                  }),
                ),
                const SizedBox(height: 12),
                _mpesaSection(theme),
                const SizedBox(height: 16),
                Text(
                  'Default Payment Method',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                KeyedSubtree(
                  key: keyFor('defaultPaymentMethod'),
                  child: _defaultMethodCard(theme),
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

  Widget _defaultMethodCard(ThemeData theme) {
    Widget tile({
      required _DefaultPaymentMethod value,
      required String label,
      required bool enabled,
    }) {
      final selected = _defaultMethod == value;
      return Opacity(
        opacity: enabled ? 1 : 0.55,
        child: InkWell(
          onTap: enabled ? () => setState(() => _defaultMethod = value) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _radioDot(theme, selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!enabled)
                  Text(
                    'Disabled',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (selected)
                  _preferredBadge(theme),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFieldInvalid('defaultPaymentMethod')
              ? theme.colorScheme.error
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: isFieldInvalid('defaultPaymentMethod') ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          tile(
            value: _DefaultPaymentMethod.tumizi,
            label: 'Tumizi wallet',
            enabled: _tumiziEnabled,
          ),
          tile(
            value: _DefaultPaymentMethod.cash,
            label: 'Cash',
            enabled: _cashEnabled,
          ),
          tile(
            value: _DefaultPaymentMethod.mpesa,
            label: 'M-Pesa',
            enabled: _mpesaEnabled,
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

  Widget _preferredBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        'Preferred',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _methodToggleRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    bool isPreferred = false,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isPreferred
            ? theme.colorScheme.surfaceContainerLowest
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: isPreferred
            ? Border.all(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                width: 2,
              )
            : null,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isPreferred) ...[
                      const SizedBox(width: 8),
                      _preferredBadge(theme),
                    ],
                  ],
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
    final isPreferred =
        _defaultMethod == _DefaultPaymentMethod.mpesa && _mpesaEnabled;
    return Container(
      decoration: BoxDecoration(
        color: isPreferred
            ? theme.colorScheme.surfaceContainerLowest
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: isPreferred
            ? Border.all(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                width: 2,
              )
            : null,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'M-Pesa',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (_defaultMethod == _DefaultPaymentMethod.mpesa &&
                              _mpesaEnabled) ...[
                            const SizedBox(width: 8),
                            _preferredBadge(theme),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manual mpesa verification',
                        style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _mpesaEnabled,
                  onChanged: (v) => setState(() {
                    _mpesaEnabled = v;
                    if (!v && _defaultMethod == _DefaultPaymentMethod.mpesa) {
                      _defaultMethod = _firstEnabledDefaultMethod();
                    }
                  }),
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
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
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
                              color: const Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All M-Pesa payment options require manual verification. The system cannot automatically verify payments. You will need to manually confirm payments before fulfilling orders.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.4,
                              color: const Color(0xFF9A3412),
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
                        KeyedSubtree(
                          key: keyFor('sendMoneyPhone'),
                          child: TextField(
                            controller: _sendMoneyPhone,
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => clearFieldError('sendMoneyPhone'),
                            decoration: _inputDeco(
                              theme,
                              hint: '0712 345 678',
                              isInvalid: isFieldInvalid('sendMoneyPhone'),
                            ),
                          ),
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
                        KeyedSubtree(
                          key: keyFor('tillNumber'),
                          child: TextField(
                            controller: _tillNumber,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => clearFieldError('tillNumber'),
                            decoration: _inputDeco(
                              theme,
                              hint: 'Enter Till Number (e.g., 123456)',
                              isInvalid: isFieldInvalid('tillNumber'),
                            ),
                          ),
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
                        KeyedSubtree(
                          key: keyFor('paybillNumber'),
                          child: TextField(
                            controller: _paybillNumber,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => clearFieldError('paybillNumber'),
                            decoration: _inputDeco(
                              theme,
                              hint: 'Enter Paybill Number (e.g., 123456)',
                              isInvalid: isFieldInvalid('paybillNumber'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: keyFor('accountNumber'),
                          child: TextField(
                            controller: _accountNumber,
                            keyboardType: TextInputType.text,
                            onChanged: (_) => clearFieldError('accountNumber'),
                            decoration: _inputDeco(
                              theme,
                              hint: 'Enter Account Number',
                              isInvalid: isFieldInvalid('accountNumber'),
                            ),
                          ),
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
                        KeyedSubtree(
                          key: keyFor('pochiPhone'),
                          child: TextField(
                            controller: _pochiPhone,
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => clearFieldError('pochiPhone'),
                            decoration: _inputDeco(
                              theme,
                              hint: 'Enter Phone Number (e.g., 0712345678)',
                              isInvalid: isFieldInvalid('pochiPhone'),
                            ),
                          ),
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
