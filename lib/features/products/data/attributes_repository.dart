import 'package:flutter/foundation.dart';

/// How attribute options are shown when editing variants (Stitch: Add/Edit Attribute).
enum AttributeDisplayType {
  color,
  text,
  number,
  size,
}

extension AttributeDisplayTypeLabel on AttributeDisplayType {
  String get label => switch (this) {
        AttributeDisplayType.color => 'Color',
        AttributeDisplayType.text => 'Text',
        AttributeDisplayType.number => 'Number',
        AttributeDisplayType.size => 'Size',
      };
}

/// Demo product attribute — replace with API models later.
class ProductAttribute {
  ProductAttribute({
    required this.id,
    required this.name,
    required this.description,
    required this.values,
    required this.displayType,
    this.valueIdByLabel = const {},
  });

  final String id;
  String name;
  String description;
  List<String> values;
  AttributeDisplayType displayType;
  final Map<String, String> valueIdByLabel;
}

class AttributesRepository {
  AttributesRepository._();

  static final ValueNotifier<List<ProductAttribute>> items = ValueNotifier([
    ProductAttribute(
      id: 'color',
      name: 'Color',
      description: 'Global variant for visual identity',
      displayType: AttributeDisplayType.color,
      values: [
        'Red|#FF0000',
        'Blue|#0000FF',
        'Green|#00FF00',
        'Midnight Black|#0F0F0F',
      ],
    ),
    ProductAttribute(
      id: 'size',
      name: 'Size',
      description: 'Dimensions and fitting standards',
      displayType: AttributeDisplayType.size,
      values: ['Small', 'Medium', 'Large', 'XL'],
    ),
    ProductAttribute(
      id: 'material',
      name: 'Material',
      description: 'Composition and fabric types',
      displayType: AttributeDisplayType.text,
      values: ['Cotton 100%', 'Polyester', 'Silk'],
    ),
  ]);

  static ProductAttribute? findById(String id) {
    try {
      return items.value.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static void upsert(ProductAttribute attr) {
    final list = [...items.value];
    final i = list.indexWhere((e) => e.id == attr.id);
    if (i >= 0) {
      list[i] = attr;
    } else {
      list.add(attr);
    }
    items.value = list;
  }

  static void remove(String id) {
    items.value = items.value.where((e) => e.id != id).toList();
  }

  static String uniqueId(String name) {
    final base = name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    var s = base.replaceFirst(RegExp(r'^-+'), '').replaceFirst(RegExp(r'-+$'), '');
    if (s.isEmpty) s = 'attribute';
    var candidate = s;
    var n = 2;
    while (items.value.any((e) => e.id == candidate)) {
      candidate = '$s-$n';
      n++;
    }
    return candidate;
  }
}
