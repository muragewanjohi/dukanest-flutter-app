import 'package:flutter/material.dart';

import 'attributes_repository.dart';

/// Storage encoding for color options: `Label|#RRGGBB`. Plain types use the raw string (avoid `|` in text).
class AttributeValueFormat {
  AttributeValueFormat._();

  static String encodeColor(String label, Color color) {
    final hex = _colorToHexRgb(color);
    return '${label.trim()}|$hex';
  }

  static String shortLabel(String raw, AttributeDisplayType type) {
    if (type == AttributeDisplayType.color) {
      return parse(raw).$1;
    }
    return raw;
  }

  /// Label and optional color for UI previews.
  static (String label, Color? color) parse(String raw) {
    final pipe = raw.indexOf('|');
    if (pipe > 0 && pipe < raw.length - 1) {
      final label = raw.substring(0, pipe).trim();
      final hex = raw.substring(pipe + 1).trim();
      final c = _tryParseHex(hex);
      if (c != null) {
        return (label.isEmpty ? hex : label, c);
      }
    }
    final paren = RegExp(r'^(.+?)\s*\(#([0-9A-Fa-f]{6})\)\s*$');
    final m = paren.firstMatch(raw);
    if (m != null) {
      final c = _tryParseHex('#${m.group(2)}');
      return (m.group(1)!.trim(), c);
    }
    return (raw, null);
  }

  static Color? _tryParseHex(String s) {
    var h = s.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) {
      final v = int.tryParse(h, radix: 16);
      if (v != null) {
        return Color(0xFF000000 | v);
      }
    }
    return null;
  }

  static String _colorToHexRgb(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  /// When switching from color to a plain display type, one field per option.
  static String toPlainEditorText(String raw) {
    final (label, color) = parse(raw);
    if (color != null) {
      final hex = _colorToHexRgb(color);
      if (label.isEmpty) return hex;
      return '$label ($hex)';
    }
    return raw;
  }

  /// When switching from plain to color: parse "Name (#RRGGBB)" or use default swatch.
  static (String label, Color color) fromPlainEditorText(String text) {
    final trimmed = text.trim();
    final paren = RegExp(r'^(.+?)\s*\(#([0-9A-Fa-f]{6})\)\s*$');
    final m = paren.firstMatch(trimmed);
    if (m != null) {
      final c = _tryParseHex('#${m.group(2)}');
      if (c != null) {
        return (m.group(1)!.trim(), c);
      }
    }
    final soloHex = _tryParseHex(trimmed);
    if (soloHex != null && trimmed.startsWith('#')) {
      return ('', soloHex);
    }
    return (trimmed, const Color(0xFF9E9E9E));
  }
}
