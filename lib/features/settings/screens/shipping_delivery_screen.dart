import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/widgets/api_error_view.dart';
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
  ConsumerState<ShippingDeliveryScreen> createState() =>
      _ShippingDeliveryScreenState();
}

enum _ShippingRateMode { zones, flatRate }

/// Matches web [StoreHoursEditor] — day keys with open/close/closed per day.
const _pickupHoursJsonExample =
    '{"monday":{"open":"09:00","close":"17:00","closed":false},'
    '"tuesday":{"open":"09:00","close":"17:00","closed":false}}';

class _ShippingDeliveryScreenState extends ConsumerState<ShippingDeliveryScreen>
    with FormErrorHighlightMixin {
  bool _allowDelivery = false;
  bool _storePickup = false;
  _ShippingRateMode _rateMode = _ShippingRateMode.zones;

  final _flatRate = TextEditingController(text: '250');
  final _freeOver = TextEditingController(text: '5000');
  final _pickupLocation = TextEditingController();
  final _pickupInstructions = TextEditingController();
  final _pickupHours = TextEditingController();
  final _pickupAddressLine1 = TextEditingController();
  final _pickupAddressCity = TextEditingController();
  final _pickupAddressCountry = TextEditingController(text: 'Kenya');
  int _handlingDays = 1;
  String _lastHydratedShippingSignature = '';
  bool _saving = false;

  /// One-shot flat-rate suggestion when opened from Getting started (`?tutorial=1`).
  bool _gettingStartedShippingDefaultsApplied = false;

  @override
  void dispose() {
    _flatRate.dispose();
    _freeOver.dispose();
    _pickupLocation.dispose();
    _pickupInstructions.dispose();
    _pickupHours.dispose();
    _pickupAddressLine1.dispose();
    _pickupAddressCity.dispose();
    _pickupAddressCountry.dispose();
    super.dispose();
  }

  bool _hasPhysicalPickupAddress() {
    final line1 = _pickupAddressLine1.text.trim();
    final city = _pickupAddressCity.text.trim();
    final country = _pickupAddressCountry.text.trim();
    if (line1.isNotEmpty) return true;
    return city.isNotEmpty && country.isNotEmpty;
  }

  bool _pickupAddressMeetsSaveRequirements() {
    final line1 = _pickupAddressLine1.text.trim();
    final city = _pickupAddressCity.text.trim();
    final country = _pickupAddressCountry.text.trim();
    return line1.isNotEmpty && city.isNotEmpty && country.isNotEmpty;
  }

  String _pickFromSources(
    List<Map<String, dynamic>> sources,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final source in sources) {
      final value = settingsPick(source, keys);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  bool _pickBoolFromSources(
    List<Map<String, dynamic>> sources,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final source in sources) {
      for (final k in keys) {
        final v = source[k];
        if (v is bool) return v;
        if (v is String) {
          final s = v.toLowerCase();
          if (s == 'true' || s == '1') return true;
          if (s == 'false' || s == '0') return false;
        }
        if (v is num) return v != 0;
      }
    }
    return fallback;
  }

  static String _shippingSectionSignature(Map<String, dynamic>? shipping) {
    if (shipping == null || shipping.isEmpty) return '';
    final keys = shipping.keys.toList()..sort();
    return jsonEncode({for (final k in keys) k: shipping[k]});
  }

  bool _isGettingStartedEntry() {
    return GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
  }

  void _hydrateWhenShippingSectionChanges(Map<String, dynamic>? root) {
    final sig = _shippingSectionSignature(settingsSection(root, 'shipping'));
    if (sig == _lastHydratedShippingSignature) return;
    _lastHydratedShippingSignature = sig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hydrateFrom(root);
      setState(() {});
    });
  }

  void _hydrateFrom(Map<String, dynamic>? root) {
    final s = settingsSection(root, 'shipping') ?? {};
    final staticRaw = root?['static_options'] ?? root?['staticOptions'];
    final staticOpts = staticRaw is Map
        ? Map<String, dynamic>.from(staticRaw)
        : <String, dynamic>{};
    final sources = [s, staticOpts];

    _allowDelivery = _pickBoolFromSources(
      sources,
      [
        'enabled',
        'shipping_enabled',
        'shippingEnabled',
        'local_delivery',
        'localDelivery'
      ],
    );
    final pickup = settingsSection(root, 'pickup') ?? {};
    final pickupSources = [pickup, s, staticOpts];
    _storePickup = _pickBoolFromSources(
      pickupSources,
      [
        'enabled',
        'pickupEnabled',
        'pickup_enabled',
        'store_pickup',
        'storePickup'
      ],
    );
    _pickupLocation.text = _pickFromSources(
      pickupSources,
      ['locationName', 'location_name', 'location', 'name'],
    );
    _pickupInstructions.text = _pickFromSources(
      pickupSources,
      ['instructions', 'pickup_instructions', 'pickupInstructions'],
    );
    _pickupHours.text = _pickFromSources(
      pickupSources,
      ['hours', 'pickup_hours', 'pickupHours'],
    );

    final store = settingsSection(root, 'store') ?? {};
    final addressRaw = store['address'];
    final address = addressRaw is Map
        ? Map<String, dynamic>.from(addressRaw)
        : <String, dynamic>{};
    final addressSources = [address, store, staticOpts];
    _pickupAddressLine1.text = _pickFromSources(
      addressSources,
      ['line1', 'address_line_1', 'store_address', 'address'],
    );
    _pickupAddressCity.text = _pickFromSources(
      addressSources,
      ['city', 'store_city'],
    );
    _pickupAddressCountry.text = _pickFromSources(
      addressSources,
      ['country', 'store_country'],
      fallback: 'Kenya',
    );

    final methodType = _pickFromSources(
      sources,
      [
        'methodType',
        'method_type',
        'shippingMethodType',
        'shipping_method_type',
        'shipping_mode',
        'shippingMode',
      ],
    ).toLowerCase();
    final flatRateText = _pickFromSources(
      sources,
      ['flatRateAmount', 'flat_rate_amount', 'flat_rate', 'flatRate'],
      fallback: '0',
    );
    final flatRateVal = num.tryParse(flatRateText) ?? 0;

    if (methodType == 'delivery_zones' || methodType.contains('zone')) {
      _rateMode = _ShippingRateMode.zones;
    } else if (methodType == 'flat_rate' ||
        methodType.contains('flat') ||
        flatRateVal > 0) {
      _rateMode = _ShippingRateMode.flatRate;
    } else {
      _rateMode = _ShippingRateMode.zones;
    }

    _flatRate.text = flatRateText;
    _freeOver.text = _pickFromSources(
      sources,
      [
        'freeShippingThreshold',
        'free_shipping_threshold',
        'free_over',
        'freeOver',
      ],
      fallback: '0',
    );
    final daysRaw = _pickFromSources(
      sources,
      [
        'defaultEstimatedDeliveryDays',
        'default_estimated_delivery_days',
        'handling_days',
        'handlingDays',
        'estimated_days',
        'estimatedDays',
      ],
      fallback: '1',
    );
    _handlingDays = int.tryParse(daysRaw)?.clamp(0, 90) ?? 1;

    if (_isGettingStartedEntry() && !_gettingStartedShippingDefaultsApplied) {
      _gettingStartedShippingDefaultsApplied = true;
      _allowDelivery = true;
      _rateMode = _ShippingRateMode.flatRate;
      final current = num.tryParse(_flatRate.text.trim()) ?? 0;
      if (current <= 0) {
        _flatRate.text = '250';
      }
    }
  }

  Future<bool> _confirmZeroFlatRateIfNeeded() async {
    if (_rateMode != _ShippingRateMode.flatRate) return true;
    final flat = num.tryParse(_flatRate.text.trim());
    if (flat == null || flat != 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Free delivery?'),
        content: const Text(
          'A flat rate of KES 0 means every order ships with no delivery fee. '
          'Save free delivery, or go back to enter a positive amount.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save KES 0'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Map<String, dynamic> _shippingSettingsPatch({
    required bool localDelivery,
    required bool storePickup,
    required bool useZones,
    required bool useFlat,
    required num flatRate,
    required num freeThreshold,
    required int handlingDays,
    required String pickupLocation,
    required String pickupInstructions,
    required String pickupHours,
    required String pickupAddressLine1,
    required String pickupAddressCity,
    required String pickupAddressCountry,
  }) {
    final shipping = <String, dynamic>{
      'enabled': localDelivery,
    };

    if (localDelivery) {
      shipping['methodType'] = useZones ? 'delivery_zones' : 'flat_rate';
      if (useFlat) {
        shipping['flatRateAmount'] = flatRate;
        shipping['freeShippingEnabled'] = freeThreshold > 0;
        shipping['freeShippingThreshold'] =
            freeThreshold > 0 ? freeThreshold : null;
      } else {
        shipping['flatRateAmount'] = null;
        shipping['freeShippingEnabled'] = false;
        shipping['freeShippingThreshold'] = null;
      }
    }

    shipping['defaultEstimatedDeliveryDays'] = handlingDays;

    final body = <String, dynamic>{
      'shipping': shipping,
      'pickup': {
        'enabled': storePickup,
        'locationName':
            pickupLocation.trim().isEmpty ? null : pickupLocation.trim(),
        'instructions': pickupInstructions.trim().isEmpty
            ? null
            : pickupInstructions.trim(),
        'hours': pickupHours.trim().isEmpty ? null : pickupHours.trim(),
      },
    };

    if (storePickup) {
      final line1 = pickupAddressLine1.trim();
      final city = pickupAddressCity.trim();
      final country = pickupAddressCountry.trim();
      if (line1.isNotEmpty || city.isNotEmpty || country.isNotEmpty) {
        body['store'] = {
          'address': {
            'line1': line1.isEmpty ? null : line1,
            'city': city.isEmpty ? null : city,
            'country': country.isEmpty ? null : country,
          },
        };
      }
    }

    return body;
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
            SnackBar(content: Text(apiErrorMessage(e))),
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
        if (!await _confirmZeroFlatRateIfNeeded()) return;
      }
    }

    if (_storePickup && !_pickupAddressMeetsSaveRequirements()) {
      if (_pickupAddressLine1.text.trim().isEmpty) {
        reportFieldError(
          fieldId: 'pickupAddressLine1',
          message: 'Enter your store street address for pickup.',
        );
      } else if (_pickupAddressCity.text.trim().isEmpty) {
        reportFieldError(
          fieldId: 'pickupAddressCity',
          message: 'Enter your store city for pickup.',
        );
      } else {
        reportFieldError(
          fieldId: 'pickupAddressCountry',
          message: 'Enter your store country for pickup.',
        );
      }
      return;
    }

    if (_storePickup && _pickupHours.text.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(_pickupHours.text.trim());
        if (decoded is! Map) {
          throw const FormatException('Expected a JSON object');
        }
      } catch (_) {
        reportFieldError(
          fieldId: 'pickupHours',
          message:
              'Store hours must be valid JSON. See the example format below the field.',
        );
        return;
      }
    }

    clearAllFieldErrors();
    setState(() => _saving = true);
    try {
      final flat = num.tryParse(_flatRate.text.trim()) ?? 0;
      final free = num.tryParse(_freeOver.text.trim()) ?? 0;
      final useZones = _allowDelivery && _rateMode == _ShippingRateMode.zones;
      final useFlat = _allowDelivery && _rateMode == _ShippingRateMode.flatRate;

      final body = _shippingSettingsPatch(
        localDelivery: _allowDelivery,
        storePickup: _storePickup,
        useZones: useZones,
        useFlat: useFlat,
        flatRate: flat,
        freeThreshold: free,
        handlingDays: _handlingDays,
        pickupLocation: _pickupLocation.text,
        pickupInstructions: _pickupInstructions.text,
        pickupHours: _pickupHours.text,
        pickupAddressLine1: _pickupAddressLine1.text,
        pickupAddressCity: _pickupAddressCity.text,
        pickupAddressCountry: _pickupAddressCountry.text,
      );
      final api = ref.read(apiClientProvider);
      final r = await api.patchDashboardSettings(body);
      if (!mounted) return;
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(r.error?.message ?? 'Could not save shipping settings')),
        );
        return;
      }
      final patched = unwrapSettingsData(r.data);
      if (patched != null) {
        _hydrateFrom(patched);
        _lastHydratedShippingSignature =
            _shippingSectionSignature(settingsSection(patched, 'shipping'));
      }
      try {
        final refreshedRoot =
            await ref.refresh(dashboardSettingsProvider.future);
        if (refreshedRoot != null) {
          _lastHydratedShippingSignature = _shippingSectionSignature(
              settingsSection(refreshedRoot, 'shipping'));
        }
      } catch (_) {
        // PATCH response already hydrated local state; ignore refresh timeout.
      }
      ref.invalidate(dashboardGettingStartedProvider);
      ref
          .read(dashboardLocalStepCompletionsProvider.notifier)
          .markComplete(DashboardOnboardingStepKeys.shipping);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipping settings saved')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
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
    final idleOutline =
        theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
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
        body: ApiErrorView(
          error: err,
          title: 'Could not load shipping settings',
          onRetry: () => ref.invalidate(dashboardSettingsProvider),
        ),
      ),
      data: (root) {
        _hydrateWhenShippingSectionChanges(root);
        return _buildScaffold(theme);
      },
    );
  }

  Widget _buildScaffold(ThemeData theme) {
    final showZonesUi = _allowDelivery && _rateMode == _ShippingRateMode.zones;
    final showFlatRateUi =
        _allowDelivery && _rateMode == _ShippingRateMode.flatRate;

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
                        subtitle:
                            'Let customers collect orders at your location',
                        value: _storePickup,
                        onChanged: (v) => setState(() => _storePickup = v),
                      ),
                      if (_storePickup) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Pickup address',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _hasPhysicalPickupAddress()
                              ? 'Customers will see this address when choosing store pickup.'
                              : 'Store pickup needs a physical address. Add it here or in Store profile.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        KeyedSubtree(
                          key: keyFor('pickupAddressLine1'),
                          child: TextField(
                            controller: _pickupAddressLine1,
                            onChanged: (_) => clearFieldError('pickupAddressLine1'),
                            decoration: _fieldDeco(
                              theme,
                              hint: 'Street address',
                              isInvalid: isFieldInvalid('pickupAddressLine1'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: keyFor('pickupAddressCity'),
                          child: TextField(
                            controller: _pickupAddressCity,
                            onChanged: (_) => clearFieldError('pickupAddressCity'),
                            decoration: _fieldDeco(
                              theme,
                              hint: 'City',
                              isInvalid: isFieldInvalid('pickupAddressCity'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: keyFor('pickupAddressCountry'),
                          child: TextField(
                            controller: _pickupAddressCountry,
                            onChanged: (_) => clearFieldError('pickupAddressCountry'),
                            decoration: _fieldDeco(
                              theme,
                              hint: 'Country',
                              isInvalid: isFieldInvalid('pickupAddressCountry'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pickupLocation,
                          decoration:
                              _fieldDeco(theme, hint: 'Pickup location name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pickupInstructions,
                          maxLines: 2,
                          decoration:
                              _fieldDeco(theme, hint: 'Pickup instructions'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Store hours (JSON)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: keyFor('pickupHours'),
                          child: TextField(
                            controller: _pickupHours,
                            maxLines: 5,
                            onChanged: (_) => clearFieldError('pickupHours'),
                            decoration: _fieldDeco(
                              theme,
                              hint: _pickupHoursJsonExample,
                              isInvalid: isFieldInvalid('pickupHours'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'One entry per day (monday–sunday). Each day needs '
                          '"open" and "close" in 24-hour format (e.g. 09:00, 17:00) '
                          'and "closed" (true/false). Example:\n'
                          '{\n'
                          '  "monday": {"open": "09:00", "close": "17:00", "closed": false},\n'
                          '  "sunday": {"open": "09:00", "close": "17:00", "closed": true}\n'
                          '}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
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
                                padding:
                                    const EdgeInsets.only(left: 12, right: 4),
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
                        const SizedBox(height: 6),
                        Text(
                          'Use 0 for free delivery on every order, or enter a positive amount (e.g. 250).',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
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
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: theme.colorScheme.primary, size: 22),
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
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
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
              backgroundColor:
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
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
          color: selected
              ? AppTheme.primaryDark
              : theme.colorScheme.outlineVariant,
          width: 2,
        ),
        color: selected
            ? AppTheme.primaryDark.withValues(alpha: 0.12)
            : Colors.transparent,
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

  Widget _section(ThemeData theme,
      {required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
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
                style: GoogleFonts.inter(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create your delivery zone',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
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
