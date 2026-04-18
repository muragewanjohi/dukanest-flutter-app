import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';
import '../../settings/providers/dashboard_settings_provider.dart';
import '../data/attribute_value_format.dart';
import '../data/attributes_repository.dart';
import '../providers/attributes_list_provider.dart';

/// Add / edit attribute — Stitch: "Add/Edit Attribute (Mobile) - Updated"
/// (screen 9f4bb7a2717f46f0bb0fe3168f0873a3).
class AttributeEditorScreen extends ConsumerStatefulWidget {
  const AttributeEditorScreen({super.key, this.attributeId});

  /// `null` → create (`/attributes/new`).
  final String? attributeId;

  bool get isNew => attributeId == null;

  @override
  ConsumerState<AttributeEditorScreen> createState() => _AttributeEditorScreenState();
}

class _DraftColorRow {
  _DraftColorRow({String label = '', Color? color})
      : label = TextEditingController(text: label),
        color = color ?? const Color(0xFF9E9E9E);

  final TextEditingController label;
  Color color;

  void dispose() => label.dispose();
}

class _DraftPlainRow {
  _DraftPlainRow([String text = '']) : value = TextEditingController(text: text);

  final TextEditingController value;

  void dispose() => value.dispose();
}

class _AttributeEditorScreenState extends ConsumerState<AttributeEditorScreen>
    with FormErrorHighlightMixin {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  AttributeDisplayType _displayType = AttributeDisplayType.text;
  List<_DraftColorRow> _colorRows = [];
  List<_DraftPlainRow> _plainRows = [];

  bool _loadingRemote = false;
  bool _saving = false;
  final Set<String> _remoteValueIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      _seedEmptyRows();
    } else {
      Future.microtask(_loadRemote);
    }
  }

  Future<void> _loadRemote() async {
    setState(() => _loadingRemote = true);
    try {
      final detail = await ref.read(dashboardAttributeDetailProvider(widget.attributeId!).future);
      if (!mounted || detail == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load attribute')),
          );
          _seedEmptyRows();
        }
        return;
      }
      final pa = productAttributeFromApi(detail);
      _remoteValueIds
        ..clear()
        ..addAll(_collectValueIds(detail));
      setState(() {
        _nameController.text = pa.name;
        _descController.text = pa.description;
        _displayType = pa.displayType;
        _hydrateRowsFromStorage(pa.values);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load attribute')),
        );
        _seedEmptyRows();
      }
    } finally {
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  Iterable<String> _collectValueIds(Map<String, dynamic> detail) sync* {
    final vals = detail['values'] ?? detail['attributeValues'] ?? detail['attribute_values'];
    if (vals is! List) return;
    for (final v in vals) {
      if (v is Map && v['id'] != null) {
        yield v['id'].toString();
      }
    }
  }

  Map<String, dynamic> _apiBodyForSerializedValue(String serialized) {
    if (_displayType == AttributeDisplayType.color) {
      final parsed = AttributeValueFormat.parse(serialized);
      var label = parsed.$1;
      final col = parsed.$2;
      if (label.isEmpty) label = 'Option';
      return {
        'value': label,
        if (col != null) 'color_code': AttributeValueFormat.encodeColor(label, col).split('|').last,
      };
    }
    return {'value': AttributeValueFormat.toPlainEditorText(serialized)};
  }

  void _seedEmptyRows() {
    if (_displayType == AttributeDisplayType.color) {
      _colorRows = [_DraftColorRow()];
      _plainRows = [];
    } else {
      _plainRows = [_DraftPlainRow()];
      _colorRows = [];
    }
  }

  void _hydrateRowsFromStorage(List<String> values) {
    if (_displayType == AttributeDisplayType.color) {
      _colorRows = values.isEmpty
          ? [_DraftColorRow()]
          : values.map((s) {
              final (label, color) = AttributeValueFormat.parse(s);
              return _DraftColorRow(
                label: label,
                color: color ?? const Color(0xFF9E9E9E),
              );
            }).toList();
      _plainRows = [];
      return;
    }
    _plainRows = values.isEmpty
        ? [_DraftPlainRow()]
        : values.map((s) => _DraftPlainRow(AttributeValueFormat.toPlainEditorText(s))).toList();
    _colorRows = [];
  }

  void _disposeColorRows() {
    for (final r in _colorRows) {
      r.dispose();
    }
    _colorRows = [];
  }

  void _disposePlainRows() {
    for (final r in _plainRows) {
      r.dispose();
    }
    _plainRows = [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _disposeColorRows();
    _disposePlainRows();
    super.dispose();
  }

  List<String> _serializeForStorage() {
    if (_displayType == AttributeDisplayType.color) {
      return _colorRows
          .map((r) {
            final lab = r.label.text.trim();
            if (lab.isEmpty) return null;
            return AttributeValueFormat.encodeColor(lab, r.color);
          })
          .whereType<String>()
          .toList();
    }
    return _plainRows.map((r) => r.value.text.trim()).where((s) => s.isNotEmpty).toList();
  }

  void _onDisplayTypeChanged(AttributeDisplayType next) {
    if (next == _displayType) return;
    final stored = _serializeForStorage();
    _disposeColorRows();
    _disposePlainRows();
    _displayType = next;

    if (next == AttributeDisplayType.color) {
      if (stored.isEmpty) {
        _colorRows = [_DraftColorRow()];
      } else {
        _colorRows = stored.map((s) {
          if (s.contains('|')) {
            final (lab, c) = AttributeValueFormat.parse(s);
            return _DraftColorRow(label: lab, color: c ?? const Color(0xFF9E9E9E));
          }
          final (lab, col) = AttributeValueFormat.fromPlainEditorText(s);
          return _DraftColorRow(label: lab, color: col);
        }).toList();
      }
      _plainRows = [];
    } else {
      if (stored.isEmpty) {
        _plainRows = [_DraftPlainRow()];
      } else {
        _plainRows = stored.map((s) => _DraftPlainRow(AttributeValueFormat.toPlainEditorText(s))).toList();
      }
      _colorRows = [];
    }
    setState(() {});
  }

  Future<void> _pickColor(_DraftColorRow row) async {
    Color scratch = row.color;
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Pick color',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return ColorPicker(
                  pickerColor: scratch,
                  onColorChanged: (c) {
                    scratch = c;
                    setDialogState(() {});
                  },
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hueWheel,
                  labelTypes: const [],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, scratch),
              child: const Text('Use color'),
            ),
          ],
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => row.color = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      reportFieldError(
        fieldId: 'name',
        message: 'Enter an attribute name.',
      );
      return;
    }
    final values = _serializeForStorage();
    if (values.isEmpty) {
      reportFieldError(
        fieldId: 'values',
        message: 'Add at least one option value.',
      );
      return;
    }
    final isColor = _displayType == AttributeDisplayType.color;
    if (isColor) {
      for (var i = 0; i < _colorRows.length; i++) {
        if (_colorRows[i].label.text.trim().isEmpty) {
          reportFieldError(
            fieldId: 'value_$i',
            message: 'Enter a label for value ${i + 1}.',
          );
          return;
        }
      }
    } else {
      for (var i = 0; i < _plainRows.length; i++) {
        if (_plainRows[i].value.text.trim().isEmpty) {
          reportFieldError(
            fieldId: 'value_$i',
            message: 'Enter value ${i + 1}.',
          );
          return;
        }
      }
    }
    clearAllFieldErrors();

    if (_saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
      final safeSlug = slug.isEmpty ? 'attribute' : slug;

      if (widget.isNew) {
        final cr = await api.createDashboardAttribute({
          'name': name,
          'type': apiTypeFromDisplay(_displayType),
          'slug': safeSlug,
          if (_descController.text.trim().isNotEmpty) 'description': _descController.text.trim(),
        });
        if (!cr.success) throw StateError(cr.error?.message ?? 'Create failed');
        final root = unwrapSettingsData(cr.data) ?? cr.data;
        final attrMap = root is Map<String, dynamic>
            ? Map<String, dynamic>.from(root['attribute'] ?? root['item'] ?? root)
            : <String, dynamic>{};
        final newId = attrMap['id']?.toString() ?? '';
        if (newId.isEmpty) throw StateError('Missing attribute id');
        for (final v in values) {
          final vr = await api.createAttributeValue(newId, _apiBodyForSerializedValue(v));
          if (!vr.success) throw StateError(vr.error?.message ?? 'Value create failed');
        }
      } else {
        final id = widget.attributeId!;
        final ur = await api.updateDashboardAttribute(id, {
          'name': name,
          'type': apiTypeFromDisplay(_displayType),
          if (_descController.text.trim().isNotEmpty) 'description': _descController.text.trim(),
        });
        if (!ur.success) throw StateError(ur.error?.message ?? 'Update failed');
        for (final vid in _remoteValueIds) {
          await api.deleteAttributeValue(id, vid);
        }
        _remoteValueIds.clear();
        for (final v in values) {
          final vr = await api.createAttributeValue(id, _apiBodyForSerializedValue(v));
          if (!vr.success) throw StateError(vr.error?.message ?? 'Value create failed');
        }
      }
      ref.invalidate(dashboardAttributesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attribute saved')),
        );
        context.pop();
      }
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

  Future<void> _confirmDeleteAttribute() async {
    final id = widget.attributeId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete attribute?'),
        content: const Text(
          'This removes the attribute from the catalog. Product variants using it may need updates.',
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
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.deleteDashboardAttribute(id);
      if (!r.success) throw StateError(r.error?.message ?? 'Delete failed');
      ref.invalidate(dashboardAttributesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attribute removed')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  /// Stitch-style control: red circular outline + horizontal minus.
  Widget _roundRedMinusButton({
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final error = Theme.of(context).colorScheme.error;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: error, width: 2),
                ),
                child: Icon(Icons.remove, color: error, size: 20, weight: 700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isColor = _displayType == AttributeDisplayType.color;

    if (_loadingRemote) {
      return const Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: DashboardAppBar(title: 'Attribute'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: widget.isNew ? 'Add attribute' : 'Edit attribute',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          KeyedSubtree(
            key: keyFor('name'),
            child: TextField(
              controller: _nameController,
              onChanged: (_) => clearFieldError('name'),
              decoration: _deco(
                'Name',
                'e.g. Color, Material',
                isInvalid: isFieldInvalid('name'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: _deco('Description', 'Optional — internal note'),
          ),
          const SizedBox(height: 20),
          Text(
            'Display type',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AttributeDisplayType.values
                .map(
                  (t) => ChoiceChip(
                    label: Text(
                      t.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _displayType == t,
                    onSelected: (_) => _onDisplayTypeChanged(t),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.22),
                    labelStyle: GoogleFonts.inter(
                      color: _displayType == t ? AppTheme.primaryDark : AppTheme.onSurfaceVariant,
                    ),
                    side: BorderSide(
                      color: _displayType == t ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    showCheckmark: false,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          _examplesBox(),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: keyFor('values'),
            child: Builder(builder: (context) {
              final invalid = isFieldInvalid('values');
              final errorColor = Theme.of(context).colorScheme.error;
              return Container(
                padding: invalid ? const EdgeInsets.all(12) : EdgeInsets.zero,
                decoration: invalid
                    ? BoxDecoration(
                        color: errorColor.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: errorColor, width: 1.5),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Values',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: invalid ? errorColor : AppTheme.primaryDark,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            clearFieldError('values');
                            setState(() {
                              if (isColor) {
                                _colorRows.add(_DraftColorRow());
                              } else {
                                _plainRows.add(_DraftPlainRow());
                              }
                            });
                          },
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add value'),
                        ),
                      ],
                    ),
                    if (invalid) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline,
                                size: 16, color: errorColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Add at least one option value.',
                                style: TextStyle(
                                  color: errorColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const SizedBox(height: 8),
                    if (isColor)
                      ..._colorRows
                          .asMap()
                          .entries
                          .map((e) => _colorRowTile(e.key, e.value)),
                    if (!isColor)
                      ..._plainRows
                          .asMap()
                          .entries
                          .map((e) => _plainRowTile(e.key, e.value)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!widget.isNew) ...[
                _roundRedMinusButton(
                  tooltip: 'Delete attribute',
                  onPressed: _confirmDeleteAttribute,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.isNew ? 'Create attribute' : 'Save changes',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorRowTile(int index, _DraftColorRow row) {
    final fieldId = 'value_$index';
    final invalid = isFieldInvalid(fieldId);
    return Padding(
      key: keyFor(fieldId),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: row.label,
              decoration: _deco('Label', 'e.g. Red', isInvalid: invalid),
              onChanged: (_) {
                clearFieldError(fieldId);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: row.color,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _pickColor(row),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Icon(Icons.palette_outlined, color: _contrastOn(row.color)),
              ),
            ),
          ),
          if (_colorRows.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _roundRedMinusButton(
                tooltip: 'Remove value',
                onPressed: () {
                  setState(() {
                    row.dispose();
                    _colorRows.removeAt(index);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _plainRowTile(int index, _DraftPlainRow row) {
    final isNumber = _displayType == AttributeDisplayType.number;
    final fieldId = 'value_$index';
    final invalid = isFieldInvalid(fieldId);
    return Padding(
      key: keyFor(fieldId),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: row.value,
              keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
              inputFormatters: isNumber
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                  : null,
              onChanged: (_) => clearFieldError(fieldId),
              decoration: _deco(
                isNumber ? 'Value' : 'Value',
                isNumber ? 'e.g. 200g, 500g' : 'e.g. Cotton',
                isInvalid: invalid,
              ),
            ),
          ),
          if (_plainRows.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _roundRedMinusButton(
                tooltip: 'Remove value',
                onPressed: () {
                  setState(() {
                    row.dispose();
                    _plainRows.removeAt(index);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _contrastOn(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? AppTheme.primaryDark : Colors.white;
  }

  InputDecoration _deco(String label, String hint, {bool isInvalid = false}) {
    final errorColor = Theme.of(context).colorScheme.error;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: isInvalid
          ? BorderSide(color: errorColor, width: 1.5)
          : BorderSide.none,
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : AppTheme.surfaceContainerLow,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : AppTheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _examplesBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Examples:',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(height: 10),
          _exampleLine('Size', 'Small, Medium, Large, XL'),
          _exampleLine('Color', 'Red (#FF0000), Blue (#0000FF), Green (#00FF00)'),
          _exampleLine('Weight', '200g, 500g, 1kg'),
          _exampleLine('Material', 'Cotton, Polyester, Silk'),
          const SizedBox(height: 12),
          Text(
            'Attributes are reusable across products. Once created, you can use them when creating product variants.',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.35,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exampleLine(String title, String values) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.secondary)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.secondary, height: 1.35),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondary),
                  ),
                  TextSpan(text: values),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
