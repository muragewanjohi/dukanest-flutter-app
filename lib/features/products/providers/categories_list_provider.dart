import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/categories_repository.dart';

final categoriesListProvider = FutureProvider.autoDispose<List<CategoryEntry>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getCategories(includeChildren: true);
  if (!response.success || response.data == null) {
    throw StateError(response.error?.message ?? 'Failed to load categories');
  }
  var root = response.data;
  if (root is Map<String, dynamic> && root['data'] is Map) {
    root = root['data'];
  }
  final items = root is Map<String, dynamic>
      ? (root['items'] ?? root['categories'] ?? root['data'])
      : null;
  if (items is! List) {
    throw const FormatException('Invalid categories response');
  }
  return items.whereType<Map>().map((raw) => categoryEntryFromApi(Map<String, dynamic>.from(raw))).toList();
});

/// Maps a single category object from `GET/POST /dashboard/categories` responses.
CategoryEntry categoryEntryFromApi(Map<String, dynamic> m) {
  final id = (m['id'] ?? m['_id'] ?? '').toString();
  final name = (m['name'] ?? 'Category').toString();
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
