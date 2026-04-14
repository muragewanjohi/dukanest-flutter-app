import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../settings/providers/dashboard_settings_provider.dart';
import '../data/attributes_repository.dart';

/// Maps `/dashboard/attributes` item → [ProductAttribute].
ProductAttribute productAttributeFromApi(Map<String, dynamic> m) {
  final id = (m['id'] ?? m['_id'] ?? '').toString();
  final name = (m['name'] ?? 'Attribute').toString();
  final desc = (m['description'] ?? '').toString();
  final typeStr = (m['type'] ?? m['attributeType'] ?? 'text').toString().toLowerCase();
  final AttributeDisplayType displayType;
  switch (typeStr) {
    case 'color':
    case 'colour':
      displayType = AttributeDisplayType.color;
      break;
    case 'number':
    case 'numeric':
      displayType = AttributeDisplayType.number;
      break;
    case 'size':
      displayType = AttributeDisplayType.size;
      break;
    default:
      displayType = AttributeDisplayType.text;
  }
  final valuesRaw =
      m['values'] ?? m['attributeValues'] ?? m['attribute_values'] ?? m['items'] ?? const [];
  final values = <String>[];
  if (valuesRaw is List) {
    for (final v in valuesRaw) {
      if (v is Map) {
        final vm = Map<String, dynamic>.from(v);
        final label = (vm['value'] ?? vm['name'] ?? '').toString();
        if (label.isEmpty) continue;
        final cc = (vm['colorCode'] ?? vm['color_code'] ?? '').toString().trim();
        if (cc.isNotEmpty) {
          final hex = cc.startsWith('#') ? cc : '#$cc';
          values.add('$label|$hex');
        } else {
          values.add(label);
        }
      } else if (v != null) {
        values.add(v.toString());
      }
    }
  }
  return ProductAttribute(
    id: id.isEmpty ? name : id,
    name: name,
    description: desc,
    values: values,
    displayType: displayType,
  );
}

String apiTypeFromDisplay(AttributeDisplayType t) => switch (t) {
      AttributeDisplayType.color => 'color',
      AttributeDisplayType.number => 'number',
      AttributeDisplayType.size => 'size',
      _ => 'text',
    };

final dashboardAttributesProvider = FutureProvider.autoDispose<List<ProductAttribute>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = await api.getDashboardAttributes();
  if (!r.success || r.data == null) {
    throw StateError(r.error?.message ?? 'Failed to load attributes');
  }
  final root = unwrapSettingsData(r.data) ?? r.data;
  if (root is! Map<String, dynamic>) {
    throw const FormatException('Invalid attributes response');
  }
  final items = root['items'] ?? root['attributes'] ?? root['data'];
  if (items is! List) {
    throw const FormatException('Invalid attributes list');
  }
  return items
      .whereType<Map>()
      .map((raw) => productAttributeFromApi(Map<String, dynamic>.from(raw)))
      .toList();
});

/// Loads one attribute (detail includes values with ids for edits).
final dashboardAttributeDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final r = await api.getDashboardAttribute(id);
  if (!r.success || r.data == null) return null;
  final root = unwrapSettingsData(r.data) ?? r.data;
  if (root is! Map<String, dynamic>) return null;
  return Map<String, dynamic>.from(root['attribute'] ?? root['item'] ?? root);
});
