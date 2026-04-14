import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../providers/dashboard_settings_provider.dart';

/// Tax Settings — Stitch: Tax Settings (Mobile) (cfb73a5c3d7646ef8c811e474c6c7b33).
class TaxSettingsScreen extends ConsumerStatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  ConsumerState<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends ConsumerState<TaxSettingsScreen> {
  bool _taxEnabled = true;
  final _defaultRate = TextEditingController(text: '0.00');
  bool _taxInclusive = true;
  String _calculationBase = 'Billing Address';
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _defaultRate.dispose();
    super.dispose();
  }

  void _hydrateFrom(Map<String, dynamic>? root) {
    final tax = settingsSection(root, 'tax') ?? {};
    _taxEnabled = settingsPickBool(tax, ['enabled', 'tax_enabled', 'taxEnabled'], fallback: true);
    final rate = settingsPick(tax, ['default_rate', 'defaultRate', 'rate', 'tax_rate', 'taxRate'], fallback: '0');
    _defaultRate.text = rate.isEmpty ? '0' : rate;
    _taxInclusive = settingsPickBool(tax, [
      'inclusive',
      'tax_inclusive',
      'taxInclusive',
      'prices_include_tax',
      'pricesIncludeTax',
    ], fallback: true);
    _calculationBase = _displayTaxBasisFromApi(settingsPick(tax, [
      'based_on',
      'basedOn',
      'calculate_tax_based_on',
      'calculation_base',
      'tax_basis',
    ]));
  }

  static String _displayTaxBasisFromApi(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[\s-]'), '_');
    if (s.contains('shipping')) return 'Shipping Address';
    if (s.contains('store')) return 'Store Location';
    return 'Billing Address';
  }

  String _apiTaxBasis() {
    switch (_calculationBase) {
      case 'Shipping Address':
        return 'shipping_address';
      case 'Store Location':
        return 'store_location';
      default:
        return 'billing_address';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final rate = num.tryParse(_defaultRate.text.trim());
      final body = <String, dynamic>{
        'tax': {
          'enabled': _taxEnabled,
          'rate': rate ?? 0,
          'inclusive': _taxInclusive,
          'basedOn': _apiTaxBasis(),
        },
      };
      final api = ref.read(apiClientProvider);
      final r = await api.patchDashboardSettings(body);
      if (!mounted) return;
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.message ?? 'Could not save tax settings')),
        );
        return;
      }
      ref.invalidate(dashboardSettingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tax settings saved')),
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

  InputDecoration _fieldDeco(ThemeData theme) {
    return InputDecoration(
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
        appBar: AppBar(title: const Text('Tax Settings')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Tax Settings'),
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
        if (!_hydrated) {
          _hydrated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _hydrateFrom(root);
            setState(() {});
          });
        }
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
        title: const Text('Tax Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              children: [
                Text(
                  'Tax Settings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure tax calculation and display settings for your DukaNest storefront.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enable Tax Calculation',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Automatically calculate taxes at checkout.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _taxEnabled,
                              onChanged: (v) => setState(() => _taxEnabled = v),
                              activeTrackColor: theme.colorScheme.primaryContainer,
                              activeThumbColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Default Tax Rate (%)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _defaultRate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _fieldDeco(theme).copyWith(
                          suffix: Padding(
                            padding: const EdgeInsets.only(right: 16, top: 14),
                            child: Text(
                              '%',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 6),
                        child: Text(
                          'Set the default tax rate applied when no specific rules exist.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tax Pricing Type',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _pricingOption(
                        theme,
                        title: 'Tax-Inclusive Pricing',
                        description:
                            'Prices listed already include tax. Total price displayed to the customer is the final amount.',
                        selected: _taxInclusive,
                        onTap: () => setState(() => _taxInclusive = true),
                      ),
                      const SizedBox(height: 12),
                      _pricingOption(
                        theme,
                        title: 'Tax-Exclusive Pricing',
                        description:
                            'Prices are listed without tax. Taxes are calculated and added at the final checkout stage.',
                        selected: !_taxInclusive,
                        onTap: () => setState(() => _taxInclusive = false),
                        footer: Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            border: Border(
                              left: BorderSide(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55), width: 4),
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Example: \$100 Product + 10% Tax = \$110 Total at checkout.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Calculate Tax Based On',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _calculationBase,
                            isExpanded: true,
                            icon: Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant),
                            items: const [
                              'Billing Address',
                              'Shipping Address',
                              'Store Location',
                            ]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 14))))
                                .toList(),
                            onChanged: (v) => setState(() => _calculationBase = v ?? 'Billing Address'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryFixed.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primaryFixed.withValues(alpha: 0.8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primaryContainer, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NOTE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.onPrimaryFixed,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tax changes will be applied to all new orders. Active subscriptions or pending invoices will not be modified.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: theme.colorScheme.onPrimaryFixedVariant,
                              ),
                            ),
                          ],
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
            color: AppTheme.surface.withValues(alpha: 0.88),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF001790), Color(0xFF0025CC)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryDark.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _saving ? null : _save,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_saving)
                              const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            else ...[
                              Text(
                                'Save Changes',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                            ],
                          ],
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

  Widget _pricingOption(
    ThemeData theme, {
    required String title,
    required String description,
    required bool selected,
    required VoidCallback onTap,
    Widget? footer,
  }) {
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: 2,
              color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45) : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.outline,
                        width: 2,
                      ),
                      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
                    ),
                    child: selected
                        ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (footer != null) footer,
            ],
          ),
        ),
      ),
    );
  }
}
