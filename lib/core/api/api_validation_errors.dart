/// Parsed field-level issue from StoreFlow mobile API validation responses.
class ApiValidationIssue {
  const ApiValidationIssue({
    required this.fieldKey,
    required this.message,
  });

  final String fieldKey;
  final String message;
}

/// Extracts validation issues from `{ success, error: { details } }` or similar shapes.
List<ApiValidationIssue> parseApiValidationIssues(dynamic raw) {
  final issues = <ApiValidationIssue>[];
  final seen = <String>{};

  void add(String fieldKey, String message) {
    final key = fieldKey.trim();
    final msg = message.trim();
    if (msg.isEmpty) return;
    final dedupe = '${key.toLowerCase()}|$msg';
    if (seen.contains(dedupe)) return;
    seen.add(dedupe);
    issues.add(ApiValidationIssue(fieldKey: key, message: msg));
  }

  String? messageFrom(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List) {
      for (final item in value) {
        final nested = messageFrom(item);
        if (nested != null) return nested;
      }
    }
    if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      return messageFrom(
        m['message'] ??
            m['msg'] ??
            m['error'] ??
            m['detail'] ??
            m['description'],
      );
    }
    return null;
  }

  String fieldKeyFrom(dynamic pathOrField) {
    if (pathOrField is String) return pathOrField;
    if (pathOrField is List) {
      for (var i = pathOrField.length - 1; i >= 0; i--) {
        final segment = pathOrField[i]?.toString().trim() ?? '';
        if (segment.isEmpty) continue;
        if (segment == 'body' || segment == 'data') continue;
        return segment;
      }
    }
    return pathOrField?.toString() ?? '';
  }

  void walk(dynamic node) {
    if (node == null) return;
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      final err = map['error'];
      if (err is Map) walk(err);

      for (final key in [
        'details',
        'errors',
        'fieldErrors',
        'validation',
        'issues'
      ]) {
        final segment = map[key];
        if (segment is List) {
          for (final item in segment) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item);
            final field = fieldKeyFrom(
              m['field'] ??
                  m['path'] ??
                  m['key'] ??
                  m['param'] ??
                  m['property'],
            );
            final msg = messageFrom(
              m['message'] ?? m['msg'] ?? m['error'] ?? m['detail'],
            );
            if (field.isNotEmpty && msg != null) add(field, msg);
          }
        } else if (segment is Map) {
          for (final entry in Map<String, dynamic>.from(segment).entries) {
            final msg = messageFrom(entry.value);
            if (msg != null) add(entry.key, msg);
          }
        }
      }

      for (final entry in map.entries) {
        if (entry.key == 'error' ||
            entry.key == 'success' ||
            entry.key == 'data' ||
            entry.key == 'code') {
          continue;
        }
        if (entry.value is Map || entry.value is List) {
          walk(entry.value);
        }
      }
      return;
    }
    if (node is List) {
      for (final item in node) {
        walk(item);
      }
    }
  }

  walk(raw);
  return issues;
}

/// First issue mapped through [mapFieldId], or `null` if none found.
({String fieldId, String message})? mapFirstApiValidationIssue(
  dynamic raw,
  String Function(String apiFieldKey) mapFieldId,
) {
  final issues = parseApiValidationIssues(raw);
  if (issues.isEmpty) return null;
  final first = issues.first;
  return (fieldId: mapFieldId(first.fieldKey), message: first.message);
}

/// Human-readable summary for snackbars when multiple fields fail.
String? formatApiValidationSummary(dynamic raw) {
  final issues = parseApiValidationIssues(raw);
  if (issues.isEmpty) return null;
  if (issues.length == 1) {
    final i = issues.first;
    final label = i.fieldKey.isEmpty ? 'Validation' : i.fieldKey;
    return '$label: ${i.message}';
  }
  final lines = issues.map((i) {
    final label = i.fieldKey.isEmpty ? 'Field' : i.fieldKey;
    return '• $label — ${i.message}';
  }).join('\n');
  return 'Please fix the following:\n$lines';
}

String? readApiErrorMessage(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final top = map['message'];
  if (top is String && top.trim().isNotEmpty) return top.trim();
  final err = map['error'];
  if (err is Map) {
    final m = (err['message'] ?? '').toString().trim();
    if (m.isNotEmpty) return m;
  }
  return formatApiValidationSummary(raw);
}
