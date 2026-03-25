import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../data/attribute_value_format.dart';
import '../data/attributes_repository.dart';

/// Add / edit attribute — Stitch: "Add/Edit Attribute (Mobile) - Updated"
/// (screen 9f4bb7a2717f46f0bb0fe3168f0873a3).
class AttributeEditorScreen extends StatefulWidget {
  const AttributeEditorScreen({super.key, this.attributeId});

  /// `null` → create (`/attributes/new`).
  final String? attributeId;

  bool get isNew => attributeId == null;

  @override
  State<AttributeEditorScreen> createState() => _AttributeEditorScreenState();
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

class _AttributeEditorScreenState extends State<AttributeEditorScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  AttributeDisplayType _displayType = AttributeDisplayType.text;
  List<_DraftColorRow> _colorRows = [];
  List<_DraftPlainRow> _plainRows = [];

  @override
  void initState() {
    super.initState();
    if (!widget.isNew) {
      final e = AttributesRepository.findById(widget.attributeId!);
      if (e != null) {
        _nameController.text = e.name;
        _descController.text = e.description;
        _displayType = e.displayType;
        _hydrateRowsFromStorage(e.values);
      } else {
        _seedEmptyRows();
      }
    } else {
      _seedEmptyRows();
    }
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

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an attribute name')),
      );
      return;
    }
    final values = _serializeForStorage();
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one option value')),
      );
      return;
    }

    if (widget.isNew) {
      AttributesRepository.upsert(
        ProductAttribute(
          id: AttributesRepository.uniqueId(name),
          name: name,
          description: _descController.text.trim(),
          values: values,
          displayType: _displayType,
        ),
      );
    } else {
      final e = AttributesRepository.findById(widget.attributeId!);
      if (e == null) {
        context.pop();
        return;
      }
      e.name = name;
      e.description = _descController.text.trim();
      e.values = values;
      e.displayType = _displayType;
      AttributesRepository.upsert(e);
    }
    context.pop();
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
    if (ok == true && mounted) {
      AttributesRepository.remove(id);
      context.pop();
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

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.primaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isNew ? 'Add attribute' : 'Edit attribute',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          TextField(
            controller: _nameController,
            decoration: _deco('Name', 'e.g. Color, Material'),
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
          Row(
            children: [
              Text(
                'Values',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
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
          const SizedBox(height: 8),
          if (isColor) ..._colorRows.asMap().entries.map((e) => _colorRowTile(e.key, e.value)),
          if (!isColor) ..._plainRows.asMap().entries.map((e) => _plainRowTile(e.key, e.value)),
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
                  onPressed: _save,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: row.label,
              decoration: _deco('Label', 'e.g. Red'),
              onChanged: (_) => setState(() {}),
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
    return Padding(
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
              decoration: _deco(isNumber ? 'Value' : 'Value', isNumber ? 'e.g. 200g, 500g' : 'e.g. Cotton'),
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

  static InputDecoration _deco(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppTheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
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
