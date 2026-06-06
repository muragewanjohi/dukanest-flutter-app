class RemoveDemoProductsResult {
  const RemoveDemoProductsResult({
    required this.matchedCount,
    required this.deletedCount,
    required this.archivedCount,
    required this.removedCount,
    this.message,
  });

  final int matchedCount;
  final int deletedCount;
  final int archivedCount;
  final int removedCount;
  final String? message;

  static RemoveDemoProductsResult? tryParse(dynamic payload) {
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

    return RemoveDemoProductsResult(
      matchedCount: _int(map, const ['matchedCount', 'matched_count']),
      deletedCount: _int(map, const ['deletedCount', 'deleted_count']),
      archivedCount: _int(map, const ['archivedCount', 'archived_count']),
      removedCount: _int(map, const ['removedCount', 'removed_count']),
      message: _string(map, const ['message']),
    );
  }

  String get successSnackBarMessage {
    if (archivedCount > 0) {
      return 'Removed $deletedCount demo products and archived '
          '$archivedCount used in orders.';
    }
    if (deletedCount > 0) {
      return 'Removed $deletedCount demo products.';
    }
    final trimmed = message?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (removedCount > 0) {
      return 'Removed $removedCount demo products.';
    }
    return 'Demo products removed.';
  }

  static int _int(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
    }
    return 0;
  }

  static String? _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}
