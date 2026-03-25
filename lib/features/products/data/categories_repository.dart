import 'package:flutter/foundation.dart';

/// Demo category row — replace with API / local DB when wired.
class CategoryEntry {
  CategoryEntry({
    required this.id,
    required this.name,
    required this.productCount,
    this.imageUrl,
    this.localImagePath,
    this.active = true,
    this.parentId,
  });

  final String id;
  String name;
  int productCount;
  String? imageUrl;
  String? localImagePath;
  bool active;
  String? parentId;
}

/// In-memory catalog for MVP (list + editor share the same notifier).
class CategoriesRepository {
  CategoriesRepository._();

  static final ValueNotifier<List<CategoryEntry>> items = ValueNotifier(_seed);

  static const _kFootwear =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD6r4FrPJbxw3mGuAX4CVWU3bYnV4e8oo5jd2y66qEseQco70XYXy8TbS9iA1bL6D3etWN-0nctP8JU1vrq4jivMbJAUoacuOe0kZr03vgz4R4UjCrlScxnhCT-5T_WK4Ik09r8aalIP-jy9KxCz9Cpu21H44meqk_KVNAUUnjRHWYQcClPx7nngRXrnBXle0yQjCyRWiMT3X1gkVMNwhAz4CzXy3EegYbuYmyKKljMWnSvW_zpYZmDE8NDkq5VJV0McQWt9aq44gd5';
  static const _kElectronics =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBYyfy2DJA183Hdydl9es9gwcEdFLYj8JeB8PVj7NIEPPQES6pa1RB637ExP6ZGZMiztxD68T74c3Qa1TiQ95yJa1IfiXvGppxjmPqQ4vrSImAnHk_JjcifgEP29zGfV9O5B-k575ehwSI04KIFPPvf71ehAFgmV5_BSVwb7ybKQtDh-Ok65A2xP3ZrpQbYZzuQvE0XY6JgOpc-tnJr1GNFLLmSUs0bDy8_eLTIgbIm85u8JRnZnVT6TKdz9NFYXHMz3p_2pn7QMd3Y';
  static const _kHomeGarden =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCSjl5Ud97KKeT35FqWLgMpQQBsJyR33Lx5Z_1mPynqllWSgKkgq1CIjhfEFQNJaljCYCSeuujw_JlpeOYRSEG93GUsZea7GeVPMJOc718PER7gpUq_-KOJRw5MPQxb3dnoKExvH81lDT7INcatjD6lj131THgI9OMZVO-9SVcuIRlCP3YFqrBAGCg4D3NtQqq9FUAX_ryiEG8iIr0OSAhqtzurS9_Ll969U7rM-h0V6vcmWPAbzXxnphr06k5A3vKeknSko7RVMxrY';
  static const _kAccessories =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBoDt04oKpoWBXQ_ugBru47NCrDeaD-_YkubE0qEVTZUj2og74g2iQxRpHwGlz_M11GUbCNE49kTZA1eH0JcJGL2qaELZnNkvNwwOmwvxpMkwtq_HgemNSow2tEhgJ3rCdUnZlgAWUpICvJwZ9mjjx3L9NBfgFxD2j0-xOF99AS6rUUPPH_yiTOE6BexqwxxHsBpiPek3F7yUrFYIymB01qdTh_erqtV_A4fCQSh1sWvmxLWHnxVuhHxKDvKUOMTPX7e8ES8M8mZXml';

  static List<CategoryEntry> get _seed => [
        CategoryEntry(id: 'footwear', name: 'Footwear', productCount: 420, imageUrl: _kFootwear),
        CategoryEntry(id: 'electronics', name: 'Electronics', productCount: 156, imageUrl: _kElectronics),
        CategoryEntry(id: 'home-garden', name: 'Home & Garden', productCount: 89, imageUrl: _kHomeGarden),
        CategoryEntry(id: 'accessories', name: 'Accessories', productCount: 211, imageUrl: _kAccessories),
      ];

  static CategoryEntry? findById(String id) {
    try {
      return items.value.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static void upsert(CategoryEntry entry) {
    final list = [...items.value];
    final i = list.indexWhere((e) => e.id == entry.id);
    if (i >= 0) {
      list[i] = entry;
    } else {
      list.add(entry);
    }
    items.value = list;
  }

  static void remove(String id) {
    items.value = items.value.where((e) => e.id != id).toList();
  }

  static String slugify(String raw) {
    var s = raw.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceFirst(RegExp(r'^-+'), '');
    s = s.replaceFirst(RegExp(r'-+$'), '');
    return s.isEmpty ? 'category' : s;
  }

  static String uniqueSlug(String name) {
    final base = slugify(name);
    var candidate = base;
    var n = 2;
    while (items.value.any((e) => e.id == candidate)) {
      candidate = '$base-$n';
      n++;
    }
    return candidate;
  }
}
