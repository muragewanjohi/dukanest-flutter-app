import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_validation_errors.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';
import '../../dashboard/providers/dashboard_getting_started_provider.dart';
import '../../dashboard/providers/dashboard_local_onboarding_provider.dart';
import '../providers/dashboard_settings_provider.dart';
import '../providers/delivery_zones_provider.dart';

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
    this.returnToTutorialOnCreate = false,
  });

  final String? zoneKey;
  final String? initialName;
  final List<String>? initialAreas;
  final String? initialFeeKes;
  final String? initialFreeOverKes;
  final String? initialHandlingDays;
  final bool initialIsDefault;
  final bool returnToTutorialOnCreate;

  bool get isEditing => zoneKey != null && zoneKey!.isNotEmpty;
}

/// Add / edit a delivery zone — Stitch: Add/Edit Delivery Zone (Mobile) (e7c632589b41441bb5bf8fa8e3f5a531).
class DeliveryZoneEditorScreen extends ConsumerStatefulWidget {
  const DeliveryZoneEditorScreen({super.key, this.args});

  final DeliveryZoneEditorArgs? args;

  @override
  ConsumerState<DeliveryZoneEditorScreen> createState() => _DeliveryZoneEditorScreenState();
}

class _DeliveryZoneEditorScreenState extends ConsumerState<DeliveryZoneEditorScreen>
    with FormErrorHighlightMixin {
  late final TextEditingController _name;
  late final TextEditingController _fee;
  late final TextEditingController _freeOver;
  late final TextEditingController _handlingDays;
  late List<String> _areas;
  late bool _isDefault;
  bool _saving = false;
  String? _areasInlineError;
  String? _feeInlineError;
  String? _freeOverInlineError;
  String? _handlingDaysInlineError;

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

  Map<String, dynamic> _buildZoneBody() {
    final name = _name.text.trim();
    final fee = (parseKesAmount(_fee.text) ?? 0).toDouble();
    final freeOver = (parseKesAmount(_freeOver.text) ?? 0).toDouble();
    final days = parseWholeDays(_handlingDays.text) ?? 1;
    return {
      'name': name,
      'areas': _areas,
      'locations': _areas,
      'coveredAreas': _areas,
      'covered_areas': _areas,
      'regions': _areas,
      'fee': fee,
      'deliveryFee': fee,
      'delivery_fee': fee,
      'flatRate': fee,
      'flat_rate': fee,
      'rate': fee,
      'price': fee,
      'amount': fee,
      'freeShippingThreshold': freeOver,
      'free_shipping_threshold': freeOver,
      'freeOver': freeOver,
      'freeDeliveryMinimum': freeOver,
      'free_delivery_minimum': freeOver,
      'estimatedDays': days,
      'estimated_days': days,
      'estimatedHandlingDays': days,
      'estimated_handling_days': days,
      'handlingDays': days,
      'handling_days': days,
      'handlingBusinessDays': days,
      'handling_business_days': days,
      'deliveryDays': days,
      'isDefault': _isDefault,
      'is_default': _isDefault,
    };
  }

  String _mapApiFieldToFieldId(String apiFieldKey) {
    final k = apiFieldKey.toLowerCase();
    if (k.contains('area') ||
        k.contains('coverage') ||
        k.contains('location') ||
        k.contains('region')) {
      return 'areas';
    }
    if (k.contains('free') || k.contains('threshold')) return 'freeOver';
    if (k.contains('day') || k.contains('handling') || k.contains('estimate')) {
      return 'handlingDays';
    }
    if (k.contains('fee') || k.contains('rate') || k.contains('price') || k.contains('amount')) {
      return 'fee';
    }
    if (k.contains('name')) return 'name';
    if (k.contains('default')) return 'isDefault';
    return 'name';
  }

  void _reportZoneFieldError({
    required String fieldId,
    required String message,
  }) {
    setState(() {
      switch (fieldId) {
        case 'areas':
          _areasInlineError = message;
        case 'fee':
          _feeInlineError = message;
        case 'freeOver':
          _freeOverInlineError = message;
        case 'handlingDays':
          _handlingDaysInlineError = message;
        default:
          break;
      }
    });
    reportFieldError(fieldId: fieldId, message: message);
  }

  @override
  void clearFieldError(String fieldId) {
    setState(() {
      switch (fieldId) {
        case 'areas':
          _areasInlineError = null;
        case 'fee':
          _feeInlineError = null;
        case 'freeOver':
          _freeOverInlineError = null;
        case 'handlingDays':
          _handlingDaysInlineError = null;
        default:
          break;
      }
    });
    super.clearFieldError(fieldId);
  }

  @override
  void clearAllFieldErrors() {
    setState(() {
      _areasInlineError = null;
      _feeInlineError = null;
      _freeOverInlineError = null;
      _handlingDaysInlineError = null;
    });
    super.clearAllFieldErrors();
  }

  void _reportApiValidation(dynamic raw) {
    final mapped = mapFirstApiValidationIssue(raw, _mapApiFieldToFieldId);
    if (mapped != null) {
      _reportZoneFieldError(fieldId: mapped.fieldId, message: mapped.message);
      return;
    }
    final summary = formatApiValidationSummary(raw) ?? readApiErrorMessage(raw);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary ?? 'Could not save zone'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _reportZoneFieldError(
        fieldId: 'name',
        message: 'Enter a zone name.',
      );
      return;
    }
    final feeRaw = _fee.text.trim();
    final fee = parseKesAmount(feeRaw);
    if (feeRaw.isEmpty || fee == null || fee < 0) {
      _reportZoneFieldError(
        fieldId: 'fee',
        message: 'Enter a valid delivery fee (amount only, e.g. 250).',
      );
      return;
    }
    final freeRaw = _freeOver.text.trim();
    if (freeRaw.isNotEmpty) {
      final freeParsed = parseKesAmount(freeRaw);
      if (freeParsed == null || freeParsed < 0) {
        _reportZoneFieldError(
          fieldId: 'freeOver',
          message: 'Free-shipping threshold must be 0 or more.',
        );
        return;
      }
    }
    final daysRaw = _handlingDays.text.trim();
    final days = parseWholeDays(daysRaw);
    if (daysRaw.isEmpty || days == null || days < 0) {
      _reportZoneFieldError(
        fieldId: 'handlingDays',
        message: 'Enter handling time in whole days (0 or more).',
      );
      return;
    }
    if (_areas.isEmpty) {
      _reportZoneFieldError(
        fieldId: 'areas',
        message: 'Add at least one area this zone covers.',
      );
      return;
    }
    clearAllFieldErrors();
    if (_saving) return;
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final id = widget.args?.zoneKey;
    final editing = id != null && id.isNotEmpty;
    final body = _buildZoneBody();
    try {
      final response = editing
          ? await api.updateDeliveryZone(id, body)
          : await api.createDeliveryZone(body);
      if (!mounted) return;
      if (!response.success) {
        _reportApiValidation({
          'error': {
            'message': response.error?.message,
            'details': response.error?.details,
          },
        });
        return;
      }
      ref.invalidate(deliveryZonesListProvider);
      ref.invalidate(dashboardSettingsProvider);
      ref.invalidate(dashboardGettingStartedProvider);
      ref.read(dashboardLocalStepCompletionsProvider.notifier).markComplete(
            DashboardOnboardingStepKeys.shipping,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(editing ? 'Zone updated' : 'Zone created')),
      );
      if (!editing && (widget.args?.returnToTutorialOnCreate ?? false)) {
        context.go('/first-run-tutorial');
      } else {
        context.pop();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _reportApiValidation(e.response?.data);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save zone')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            decoration: _fieldDeco(theme, hint: 'County, city, or sub-area'),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final t = controller.text.trim();
                if (t.isNotEmpty) {
                  setState(() => _areas = [..._areas, t]);
                  clearFieldError('areas');
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _fieldDeco(
    ThemeData theme, {
    String? hint,
    String? prefixText,
    String? helperText,
    String? errorText,
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
      helperText: isInvalid ? null : helperText,
      errorText: isInvalid ? errorText : null,
      helperStyle: GoogleFonts.inter(
        fontSize: 11,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      errorStyle: GoogleFonts.inter(fontSize: 11, color: errorColor),
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
      prefixText: prefixText,
      prefixStyle: prefixText == null
          ? null
          : GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(title: _appBarTitle),
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
                      KeyedSubtree(
                        key: keyFor('name'),
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => clearFieldError('name'),
                          decoration: _fieldDeco(
                            theme,
                            hint: 'e.g. Nairobi Metro',
                            isInvalid: isFieldInvalid('name'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  theme,
                  icon: Icons.map_outlined,
                  title: 'Coverage',
                  child: KeyedSubtree(
                    key: keyFor('areas'),
                    child: Builder(builder: (context) {
                      final areasInvalid = isFieldInvalid('areas');
                      final errorColor = theme.colorScheme.error;
                      return Container(
                        padding: areasInvalid ? const EdgeInsets.all(12) : EdgeInsets.zero,
                        decoration: areasInvalid
                            ? BoxDecoration(
                                color: errorColor.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: errorColor, width: 1.5),
                              )
                            : null,
                        child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Included areas',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: areasInvalid
                              ? errorColor
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (areasInvalid) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 16, color: errorColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _areasInlineError ??
                                    'Add at least one area this zone covers.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: errorColor,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (_areas.isEmpty)
                        Text(
                          'No areas yet. Add counties, cities, or neighborhoods customers can order from within this zone (e.g. Nairobi CBD, Westlands, Nanyuki, Nakuru).',
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
                        onPressed: () {
                          clearFieldError('areas');
                          _addAreaPrompt();
                        },
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
                      );
                    }),
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
                        'Flat delivery fee',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      KeyedSubtree(
                        key: keyFor('fee'),
                        child: TextField(
                          controller: _fee,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          onChanged: (_) => clearFieldError('fee'),
                          decoration: _fieldDeco(
                            theme,
                            hint: '250',
                            prefixText: 'KES ',
                            helperText:
                                'Enter the amount only — KES is added for you.',
                            errorText: _feeInlineError,
                            isInvalid: isFieldInvalid('fee'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Free delivery on orders over',
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
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          onChanged: (_) => clearFieldError('freeOver'),
                          decoration: _fieldDeco(
                            theme,
                            hint: '0',
                            prefixText: 'KES ',
                            helperText: '0 means free delivery is not offered in this zone.',
                            errorText: _freeOverInlineError,
                            isInvalid: isFieldInvalid('freeOver'),
                          ),
                        ),
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
                      KeyedSubtree(
                        key: keyFor('handlingDays'),
                        child: TextField(
                          controller: _handlingDays,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => clearFieldError('handlingDays'),
                          decoration: _fieldDeco(
                            theme,
                            hint: '1',
                            helperText: 'Business days before the order ships.',
                            errorText: _handlingDaysInlineError,
                            isInvalid: isFieldInvalid('handlingDays'),
                          ),
                        ),
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
