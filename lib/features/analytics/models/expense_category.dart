class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String? slug;
  final String? description;
  final bool isDefault;

  String get label => name;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? json['_id'] ?? ''}'.trim();
    final name =
        '${json['name'] ?? json['title'] ?? 'Category'}'.trim();
    return ExpenseCategory(
      id: id.isNotEmpty ? id : '${json['slug'] ?? ''}'.trim(),
      name: name.isEmpty ? 'Category' : name,
      slug: _optionalString(json, const ['slug']),
      description: _optionalString(json, const ['description']),
      isDefault: json['is_default'] == true || json['isDefault'] == true,
    );
  }

  static String? _optionalString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}

List<ExpenseCategory> parseExpenseCategoryList(dynamic payload) {
  if (payload == null) return const [];

  Map<String, dynamic>? root;
  if (payload is Map<String, dynamic>) {
    root = payload;
  } else if (payload is Map) {
    root = Map<String, dynamic>.from(payload);
  } else if (payload is List) {
    return _mapList(payload);
  } else {
    return const [];
  }

  final nested = root['data'];
  final bag = nested is Map<String, dynamic>
      ? nested
      : nested is Map
          ? Map<String, dynamic>.from(nested)
          : root;

  final raw = bag['items'] ??
      bag['categories'] ??
      root['items'] ??
      root['categories'] ??
      bag['category'];

  if (raw is List) return _mapList(raw);
  if (raw is Map) {
    final single = ExpenseCategory.fromJson(Map<String, dynamic>.from(raw));
    if (single.id.isNotEmpty) return [single];
  }
  return const [];
}

List<ExpenseCategory> _mapList(List raw) {
  return raw
      .whereType<Map>()
      .map((e) => ExpenseCategory.fromJson(Map<String, dynamic>.from(e)))
      .where((c) => c.id.isNotEmpty)
      .toList();
}

ExpenseCategory? parseExpenseCategoryFromCreateResponse(dynamic payload) {
  if (payload == null) return null;
  Map<String, dynamic>? map;
  if (payload is Map<String, dynamic>) {
    map = payload;
  } else if (payload is Map) {
    map = Map<String, dynamic>.from(payload);
  } else {
    return null;
  }

  final data = map['data'];
  if (data is Map) {
    map = Map<String, dynamic>.from(data);
  }

  final category = map['category'];
  if (category is Map) {
    return ExpenseCategory.fromJson(Map<String, dynamic>.from(category));
  }

  return ExpenseCategory.fromJson(map);
}

String expenseCategoryLabelFromExpense(
  Map<String, dynamic> expense, {
  List<ExpenseCategory> categories = const [],
}) {
  final details = expense['category_details'] ?? expense['categoryDetails'];
  if (details is Map) {
    final name = details['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
  }

  final cid =
      '${expense['category_id'] ?? expense['categoryId'] ?? ''}'.trim();
  if (cid.isNotEmpty) {
    for (final c in categories) {
      if (c.id == cid) return c.label;
    }
  }

  final nested = expense['category'];
  if (nested is Map && nested['name'] != null) {
    return '${nested['name']}'.trim();
  }

  final legacy = expense['category'];
  if (legacy is String && legacy.trim().isNotEmpty) return legacy.trim();

  return 'Uncategorized';
}
