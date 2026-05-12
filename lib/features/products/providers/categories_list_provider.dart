import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/categories_repository.dart';

/// Extracts a categories array from common mobile API envelope shapes.
List<dynamic>? _extractCategoryList(dynamic root) {
  if (root == null) return null;
  if (root is List) return root;
  if (root is Map) {
    final map = Map<String, dynamic>.from(root);
    for (final key in ['items', 'categories', 'results', 'rows']) {
      final v = map[key];
      if (v is List) return v;
    }
    final data = map['data'];
    if (data is List) return data;
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      for (final key in ['items', 'categories', 'results', 'rows', 'data']) {
        final v = dm[key];
        if (v is List) return v;
      }
    }
  }
  return null;
}

void _flattenCategoryNodes(dynamic node, List<Map<String, dynamic>> out) {
  if (node is Map) {
    final m = Map<String, dynamic>.from(node);
    if ((m['name'] ?? m['title'] ?? '').toString().trim().isNotEmpty) {
      out.add(m);
    }
    final children = m['children'] ??
        m['childCategories'] ??
        m['subcategories'] ??
        m['subs'];
    if (children is List) {
      for (final c in children) {
        _flattenCategoryNodes(c, out);
      }
    }
  }
}

final categoriesListProvider = FutureProvider.autoDispose<List<CategoryEntry>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getCategories(includeChildren: true);
  if (!response.success || response.data == null) {
    throw StateError(response.error?.message ?? 'Failed to load categories');
  }

  final rawList = _extractCategoryList(response.data);
  if (rawList == null) {
    if (response.data is Map) {
      final m = Map<String, dynamic>.from(response.data as Map);
      if ((m['name'] ?? m['title']) != null) {
        return [categoryEntryFromApi(m)];
      }
    }
    if (kDebugMode) {
      debugPrint('categoriesListProvider: could not find list in response envelope');
    }
    return [];
  }

  final flat = <Map<String, dynamic>>[];
  for (final item in rawList) {
    _flattenCategoryNodes(item, flat);
  }
  return flat.map(categoryEntryFromApi).toList();
});

/// Maps a single category object from `GET/POST /dashboard/categories` responses.
CategoryEntry categoryEntryFromApi(Map<String, dynamic> m) {
  final id = (m['id'] ?? m['_id'] ?? '').toString();
  final name = (m['name'] ?? m['title'] ?? 'Category').toString();
  final countRaw = m['productCount'] ?? m['productsCount'] ?? m['product_count'] ?? m['products_count'] ?? 0;
  final productCount = countRaw is num ? countRaw.toInt() : int.tryParse(countRaw.toString()) ?? 0;
  final parent = m['parentId'] ?? m['parent_id'];
  final parentIdRaw = parent?.toString();
  final img = m['imageUrl'] ?? m['image'] ?? m['thumbnail'];
  final activeRaw = m['isActive'] ?? m['active'] ?? m['status'];
  final active = activeRaw is bool
      ? activeRaw
      : (activeRaw?.toString().toLowerCase() != 'inactive' &&
          activeRaw?.toString().toLowerCase() != 'archived');
  return CategoryEntry(
    id: id.isEmpty ? name.hashCode.toString() : id,
    name: name,
    productCount: productCount,
    imageUrl: img is String ? img : null,
    active: active,
    parentId: (parentIdRaw == null || parentIdRaw.isEmpty) ? null : parentIdRaw,
  );
}
