import 'package:flutter/material.dart';

/// Mixin that adds per-field validation error tracking, scrolling and
/// highlighting to a `State<T>`.
///
/// Usage:
///
/// 1. `class _FooScreenState extends State<FooScreen> with FormErrorHighlightMixin`
/// 2. Wrap each validatable field with `KeyedSubtree(key: keyFor('myField'), ...)`
/// 3. Pass `isInvalid: isFieldInvalid('myField')` to the field decoration so it
///    paints a red border, and call `clearFieldError('myField')` from `onChanged`.
/// 4. From your save handler call:
///    ```dart
///    final res = validate();
///    if (res != null) {
///      reportFieldError(fieldId: res.fieldId, message: res.message);
///      return;
///    }
///    ```
///    where `validate()` returns `({String fieldId, String message})?`.
mixin FormErrorHighlightMixin<T extends StatefulWidget> on State<T> {
  String? _errorFieldId;
  final Map<String, GlobalKey> _fieldKeys = <String, GlobalKey>{};

  String? get errorFieldId => _errorFieldId;

  /// Return (and lazily create) a stable GlobalKey for the given [fieldId].
  /// Attach this key to a `KeyedSubtree`/widget that wraps the field so it can
  /// be scrolled into view.
  GlobalKey keyFor(String fieldId) =>
      _fieldKeys.putIfAbsent(fieldId, () => GlobalKey(debugLabel: 'field:$fieldId'));

  /// True when [fieldId] is currently the highlighted error field.
  bool isFieldInvalid(String fieldId) => _errorFieldId == fieldId;

  /// Clears the error highlight for [fieldId] if it is currently highlighted.
  /// Safe to call from `onChanged` callbacks – it is a no-op when the error
  /// has already been resolved.
  void clearFieldError(String fieldId) {
    if (_errorFieldId == fieldId && mounted) {
      setState(() => _errorFieldId = null);
    }
  }

  /// Clears any current field error highlight.
  void clearAllFieldErrors() {
    if (_errorFieldId != null && mounted) {
      setState(() => _errorFieldId = null);
    }
  }

  /// Highlight the field, scroll it into view and surface a red snackbar with
  /// [message]. Call this from your save handler when validation fails.
  void reportFieldError({
    required String fieldId,
    required String message,
    Duration snackBarDuration = const Duration(seconds: 4),
  }) {
    setState(() => _errorFieldId = fieldId);
    scrollToField(fieldId);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: snackBarDuration,
        ),
      );
  }

  /// Scroll the widget tagged with [fieldId] into view. Falls back to scrolling
  /// to a parent group when [fieldId] follows the `<groupId>_<fieldName>` /
  /// `<groupId>__<fieldName>` convention (e.g. `variant_0_stock` → `variant_0`).
  void scrollToField(String fieldId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BuildContext? ctx = _fieldKeys[fieldId]?.currentContext;
      if (ctx == null) {
        final m = RegExp(r'^(.*?)_[^_]+$').firstMatch(fieldId);
        if (m != null) {
          ctx = _fieldKeys[m.group(1)!]?.currentContext;
        }
      }
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    });
  }
}

/// Returns an [InputDecoration] that paints a red border + soft red fill when
/// [isInvalid] is true, while otherwise mirroring a "filled" Material 3 input.
///
/// Pass [base] to start from a custom decoration (e.g. one with a `prefixIcon`,
/// `labelText`, `suffixIcon` etc.). The returned decoration replaces the
/// border/fill colors but copies everything else from [base].
InputDecoration buildErrorAwareFieldDecoration(
  ThemeData theme, {
  bool isInvalid = false,
  String? hint,
  InputDecoration? base,
  double borderRadius = 10,
  Color? defaultFillColor,
  Color? defaultBorderColor,
}) {
  final errorColor = theme.colorScheme.error;
  final idleBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: BorderSide(
      color: isInvalid
          ? errorColor
          : defaultBorderColor ??
              theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
      width: isInvalid ? 1.5 : 1,
    ),
  );
  final focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: BorderSide(
      color: isInvalid ? errorColor : theme.colorScheme.primary,
      width: 1.5,
    ),
  );
  final fill = isInvalid
      ? errorColor.withValues(alpha: 0.06)
      : defaultFillColor ?? theme.colorScheme.surfaceContainerHighest;

  if (base != null) {
    return base.copyWith(
      hintText: base.hintText ?? hint,
      filled: true,
      fillColor: fill,
      border: idleBorder,
      enabledBorder: idleBorder,
      focusedBorder: focusedBorder,
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
    ),
    filled: true,
    fillColor: fill,
    border: idleBorder,
    enabledBorder: idleBorder,
    focusedBorder: focusedBorder,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
