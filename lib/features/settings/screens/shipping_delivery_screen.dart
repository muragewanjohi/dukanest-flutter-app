import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';
import '../../dashboard/providers/dashboard_getting_started_provider.dart';
import '../../dashboard/providers/dashboard_local_onboarding_provider.dart';
import '../providers/dashboard_settings_provider.dart';
import '../providers/delivery_zones_provider.dart';

/// Shipping & delivery — Stitch: Shipping & Delivery (Mobile) (b1de30ad39f34a3ba10883af6a0de581).
class ShippingDeliveryScreen extends ConsumerStatefulWidget {
  const ShippingDeliveryScreen({super.key});

  @override
  ConsumerState<ShippingDeliveryScreen> createState() => _ShippingDeliveryScreenState();
}

enum _ShippingRateMode { zones, flatRate }

class _ShippingDeliveryScreenState extends ConsumerState<ShippingDeliveryScreen>
    with FormErrorHighlightMixin {
  bool _allowDelivery = false;
  bool _storePickup = false;
  _ShippingRateMode _rateMode = _ShippingRateMode.zones;

  final _flatRate = TextEditingController(text: '250');
  final _freeOver = TextEditingController(text: '5000');
  int _handlingDays = 1;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _flatRate.dispose();
    _freeOver.dispose();
    super.dispose();
  }

  void _hydrateFrom(Map<String, dynamic>? root) {
    final s = settingsSection(root, 'shipping') ?? {};
    _allowDelivery = settingsPickBool(
      s,
      ['local_delivery', 'localDelivery'],
      fallback: false,
    );
    _storePickup = settingsPickBool(
      s,
      ['store_pickup', 'storePickup', 'pickup_enabled'],
      fallback: false,
    );

    final modeRaw = settingsPick(
      s,
      ['shipping_mode', 'shippingMode', 'rate_mode', 'rateMode', 'delivery_rate_mode'],
    ).toLowerCase();
    final useFlat = settingsPickBool(
      s,
      ['use_flat_rate', 'useFlatRate', 'flat_rate_enabled', 'flatRateEnabled'],
      fallback: false,
    );
    final useZones = settingsPickBool(
      s,
      ['use_delivery_zones', 'useDeliveryZones', 'zones_enabled', 'zonesEnabled'],
      fallback: false,
    );
    if (modeRaw.contains('flat')) {
      _rateMode = _ShippingRateMode.flatRate;
    } else if (useFlat && !useZones) {
      _rateMode = _ShippingRateMode.flatRate;
    } else {
      _rateMode = _ShippingRateMode.zones;
    }

    _flatRate.text = settingsPick(
      s,
      ['flat_rate', 'flatRate', 'standard_flat_rate', 'default_shipping_fee'],
      fallback: '0',
    );
    _freeOver.text = settingsPick(
      s,
      [
        'free_shipping_threshold',
        'freeShippingThreshold',
        'free_over',
        'freeOver',
      ],
      fallback: '0',
    );
    final daysRaw = settingsPick(
      s,
      ['handling_days', 'handlingDays', 'estimated_days', 'estimatedDays'],
      fallback: '1',
    );
    _handlingDays = int.tryParse(daysRaw)?.clamp(0, 90) ?? 1;
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_allowDelivery) {
      if (_rateMode == _ShippingRateMode.zones) {
        ref.invalidate(deliveryZonesListProvider);
        try {
          final zones = await ref.read(deliveryZonesListProvider.future);
          if (!mounted) return;
          if (zones.isEmpty) {
            reportFieldError(
              fieldId: 'deliveryZones',
              message:
                  'Add at least one delivery zone, or switch to flat rate under “How do you charge for delivery?”',
            );
            return;
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not verify delivery zones: $e')),
          );
          return;
        }
      } else if (_rateMode == _ShippingRateMode.flatRate) {
        final flatRaw = _flatRate.text.trim();
        final flatParsed = num.tryParse(flatRaw);
        if (flatRaw.isEmpty || flatParsed == null || flatParsed < 0) {
          reportFieldError(
            fieldId: 'flatRate',
            message: 'Enter a flat shipping rate (0 or more).',
          );
          return;
        }
        final freeRaw = _freeOver.text.trim();
        if (freeRaw.isNotEmpty && (num.tryParse(freeRaw) ?? -1) < 0) {
          reportFieldError(
            fieldId: 'freeOver',
            message: 'Free-shipping threshold must be 0 or more.',
          );
          return;
        }
      }
    }

    clearAllFieldErrors();
    setState(() => _saving = true);
    try {
      final flat = num.tryParse(_flatRate.text.trim()) ?? 0;
      final free = num.tryParse(_freeOver.text.trim()) ?? 0;
      final useZones = _allowDelivery && _rateMode == _ShippingRateMode.zones;
      final useFlat = _allowDelivery && _rateMode == _ShippingRateMode.flatRate;
      final body = <String, dynamic>{
        'shipping': {
          'localDelivery': _allowDelivery,
          'local_delivery': _allowDelivery,
          'storePickup': _storePickup,
          'store_pickup': _storePickup,
          'shippingEnabled': _allowDelivery || _storePickup,
          'shipping_enabled': _allowDelivery || _storePickup,
          'shippingMode': useZones ? 'zones' : (useFlat ? 'flat_rate' : 'none'),
          'shipping_mode': useZones ? 'zones' : (useFlat ? 'flat_rate' : 'none'),
          'useDeliveryZones': useZones,
          'use_delivery_zones': useZones,
          'useFlatRate': useFlat,
          'use_flat_rate': useFlat,
          'flatRate': useFlat ? flat : 0,
          'flat_rate': useFlat ? flat : 0,
          'freeShippingThreshold': useFlat ? free : 0,
          'free_shipping_threshold': useFlat ? free : 0,
          'handlingDays': _handlingDays,
          'handling_days': _handlingDays,
        },
      };
      final api = ref.read(apiClientProvider);
      final r = await api.patchDashboardSettings(body);
      if (!mounted) return;
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.message ?? 'Could not save shipping settings')),
        );
        return;
      }
      ref.invalidate(dashboardSettingsProvider);
      ref.invalidate(dashboardGettingStartedProvider);
      ref.read(dashboardLocalStepCompletionsProvider.notifier).markComplete(DashboardOnboardingStepKeys.shipping);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipping settings saved')),
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

  InputDecoration _fieldDeco(
    ThemeData theme, {
    String? hint,
    Widget? prefixIcon,
    bool isInvalid = false,
  }) {
    final errorColor = theme.colorScheme.error;
    final idleOutline = theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: isInvalid
          ? BorderSide(color: errorColor, width: 1.5)
          : BorderSide(color: idleOutline, width: 1),
    );
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainerLow,
      border: enabledBorder,
      enabledBorder: enabledBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: prefixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(dashboardSettingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: DashboardAppBar(title: 'Shipping & Delivery'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: const DashboardAppBar(title: 'Shipping & Delivery'),
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
    final showZonesUi = _allowDelivery && _rateMode == _ShippingRateMode.zones;
    final showFlatRateUi = _allowDelivery && _rateMode == _ShippingRateMode.flatRate;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Shipping & Delivery'),
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
                  'Define how customers receive orders: delivery zones or a flat fee, handling time, and pickup.',
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
                        title: 'Allow delivery',
                        subtitle: 'Deliver to customers in your service areas',
                        value: _allowDelivery,
                        onChanged: (v) => setState(() {
                          _allowDelivery = v;
                          if (v) {
                            _rateMode = _ShippingRateMode.zones;
                          }
                          clearFieldError('deliveryZones');
                        }),
                      ),
                      if (_allowDelivery) ...[
                        const SizedBox(height: 20),
                        Text(
                          'How do you charge for delivery?',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _rateModeTile(
                          theme,
                          mode: _ShippingRateMode.zones,
                          title: 'Manage zones',
                          subtitle: 'Set fees per area (recommended)',
                        ),
                        const SizedBox(height: 8),
                        _rateModeTile(
                          theme,
                          mode: _ShippingRateMode.flatRate,
                          title: 'Flat rate',
                          subtitle: 'One delivery fee for all orders',
                        ),
                        if (showZonesUi) ...[
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: keyFor('deliveryZones'),
                            child: _manageZonesRow(context, theme),
                          ),
                        ],
                      ],
                      const Divider(height: 28),
                      _switchRow(
                        theme,
                        title: 'Store pickup',
                        subtitle: 'Let customers collect orders at your location',
                        value: _storePickup,
                        onChanged: (v) => setState(() => _storePickup = v),
                      ),
                    ],
                  ),
                ),
                if (showFlatRateUi) ...[
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
                        KeyedSubtree(
                          key: keyFor('flatRate'),
                          child: TextField(
                            controller: _flatRate,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => clearFieldError('flatRate'),
                            decoration: _fieldDeco(
                              theme,
                              hint: 'e.g. 250',
                              isInvalid: isFieldInvalid('flatRate'),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 12, right: 4),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(
                                    'KES',
                                    style: GoogleFonts.inter(
                                      color: theme.colorScheme.outline,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
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
                        KeyedSubtree(
                          key: keyFor('freeOver'),
                          child: TextField(
                            controller: _freeOver,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => clearFieldError('freeOver'),
                            decoration: _fieldDeco(
                              theme,
                              hint: 'e.g. 5000 (0 to disable)',
                              isInvalid: isFieldInvalid('freeOver'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: keyFor('handlingDays'),
                        child: _handlingDaysStepper(theme),
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
                    border: Border.all(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Delivery zones set fees by area; flat rate uses one fee for every order. Rules apply at storefront checkout.',
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
                      onTap: _saving ? null : _save,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
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

  Widget _handlingDaysStepper(ThemeData theme) {
    final invalid = isFieldInvalid('handlingDays');
    final errorColor = theme.colorScheme.error;
    final label = _handlingDays == 1 ? 'day' : 'days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: invalid
            ? errorColor.withValues(alpha: 0.06)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: invalid
              ? errorColor
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: invalid ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: _handlingDays > 0
                ? () => setState(() {
                      _handlingDays--;
                      clearFieldError('handlingDays');
                    })
                : null,
            icon: const Icon(Icons.remove_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: AppTheme.primaryDark,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$_handlingDays',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _handlingDays < 90
                ? () => setState(() {
                      _handlingDays++;
                      clearFieldError('handlingDays');
                    })
                : null,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              foregroundColor: AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateModeTile(
    ThemeData theme, {
    required _ShippingRateMode mode,
    required String title,
    required String subtitle,
  }) {
    final selected = _rateMode == mode;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() {
          _rateMode = mode;
          clearFieldError('deliveryZones');
          clearFieldError('flatRate');
          clearFieldError('freeOver');
        }),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: 2,
              color: selected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
            color: selected ? theme.colorScheme.surfaceContainerLowest : null,
          ),
          child: Row(
            children: [
              _radioDot(theme, selected: selected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                decoration: const BoxDecoration(
                  color: AppTheme.primaryDark,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
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
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
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
    );
  }

  Widget _manageZonesRow(BuildContext context, ThemeData theme) {
    final inTutorialFlow =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    final invalid = isFieldInvalid('deliveryZones');
    final errorColor = theme.colorScheme.error;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          clearFieldError('deliveryZones');
          context.push(
            inTutorialFlow ? '/shipping-zones?tutorial=1' : '/shipping-zones',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: invalid
                  ? errorColor.withValues(alpha: 0.06)
                  : theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: invalid
                    ? errorColor
                    : theme.colorScheme.primary.withValues(alpha: 0.18),
                width: invalid ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage zones',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Group areas and set fees per delivery zone',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Zone A: UpperHill, Town CBD — KES 250',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zone B: Westlands, Highridge — KES 350',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
