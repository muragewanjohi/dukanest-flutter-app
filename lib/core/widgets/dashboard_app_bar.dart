import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';

/// Shared top-of-screen app bar used by every secondary (non tab) screen in
/// the app. Ensures a single consistent "title bar" treatment: same
/// background, same rounded back button, same 18pt Plus Jakarta Sans title,
/// and the same optional bottom hairline divider.
///
/// Use via `Scaffold(appBar: DashboardAppBar(title: 'Something'))`. For
/// `CustomScrollView` screens, use [buildDashboardSliverAppBar] instead.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.leading,
    this.automaticallyImplyLeading = true,
    this.showDivider = false,
    this.bottom,
  });

  /// Title string. Style is inherited from `AppBarTheme.titleTextStyle` so
  /// every screen matches (18pt Plus Jakarta Sans, w700, primaryDark).
  final String title;

  /// Action icons/buttons shown on the right side of the bar.
  final List<Widget> actions;

  /// Replaces the default back button. When null, a rounded back button is
  /// shown automatically whenever [Navigator] can pop.
  final Widget? leading;

  /// When true (default) a rounded back button is shown automatically if the
  /// route can be popped.
  final bool automaticallyImplyLeading;

  /// Renders a 1dp outlineVariant hairline beneath the bar.
  final bool showDivider;

  /// Escape hatch for screens that need a custom [AppBar.bottom] widget
  /// (e.g. search field, tab strip). When provided, [showDivider] is ignored.
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? (showDivider ? 1 : 0);
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLeading = leading ??
        (automaticallyImplyLeading && _canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _handlePop(context),
              )
            : null);

    final resolvedBottom = bottom ??
        (showDivider
            ? PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              )
            : null);

    return AppBar(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(title),
      leading: effectiveLeading,
      automaticallyImplyLeading: false,
      actions: actions,
      bottom: resolvedBottom,
    );
  }
}

/// Sliver equivalent of [DashboardAppBar] for `CustomScrollView` layouts.
/// Use inside `slivers: [...]`.
SliverAppBar buildDashboardSliverAppBar({
  required BuildContext context,
  required String title,
  List<Widget> actions = const <Widget>[],
  Widget? leading,
  bool automaticallyImplyLeading = true,
  bool pinned = true,
  bool floating = false,
  bool showDivider = false,
  PreferredSizeWidget? bottom,
}) {
  final theme = Theme.of(context);
  final effectiveLeading = leading ??
      (automaticallyImplyLeading && _canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _handlePop(context),
            )
          : null);

  final resolvedBottom = bottom ??
      (showDivider
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            )
          : null);

  return SliverAppBar(
    pinned: pinned,
    floating: floating,
    backgroundColor: AppTheme.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    toolbarHeight: kToolbarHeight,
    title: Text(title),
    leading: effectiveLeading,
    automaticallyImplyLeading: false,
    actions: actions,
    bottom: resolvedBottom,
  );
}

bool _canPop(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.canPop();
  return Navigator.of(context).canPop();
}

void _handlePop(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) {
    router.pop();
    return;
  }
  Navigator.of(context).maybePop();
}
