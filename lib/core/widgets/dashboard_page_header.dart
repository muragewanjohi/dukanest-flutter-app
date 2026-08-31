import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../providers/store_identity_provider.dart';

/// Consistent header used at the top of bottom-nav tab screens.
///
/// Renders two rows:
/// 1. Store avatar + store name + optional trailing action buttons.
/// 2. A hero page [title] sized to a common style, with an optional [subtitle].
///
/// All tab screens should use this so that titles across the dashboard share
/// the same size, weight, and colour; only the title text differs per screen.
///
/// Pushed sub-screens (reached via a back button, not a bottom-nav tab) can
/// pass [showStoreRow] `false` to drop the store-identity row so the back
/// button sits directly beside the screen title.
class DashboardPageHeader extends ConsumerWidget {
  const DashboardPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.actions = const <Widget>[],
    this.leading,
    this.storeNameOverride,
    this.contentPadding = EdgeInsets.zero,
    this.showStoreRow = true,
  });

  /// Hero page title text (e.g. "Orders", "Analytics Center").
  final String title;

  /// Optional supporting copy rendered beneath the title.
  final String? subtitle;
  final Color? subtitleColor;

  /// Icon buttons / widgets rendered after the store name (right side of row).
  final List<Widget> actions;

  /// Replaces the default store avatar. Use for screens that need a back
  /// button or other custom leading.
  final Widget? leading;

  /// Override the text rendered next to the avatar. Falls back to the current
  /// store identity or "DukaNest".
  final String? storeNameOverride;

  /// Outer padding around the whole header block.
  final EdgeInsetsGeometry contentPadding;

  /// When false, the store avatar + name row is dropped and [leading] is
  /// placed directly beside the [title] (with [actions] trailing it).
  final bool showStoreRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final titleWidget = Text(
      title,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontSize: 28,
        height: 1.2,
        letterSpacing: -0.25,
        fontWeight: FontWeight.w800,
        color: AppTheme.primaryDark,
      ),
    );

    final subtitleWidget =
        (subtitle != null && subtitle!.trim().isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtitleColor ?? theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              )
            : null;

    if (!showStoreRow) {
      return Padding(
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      height: 1.2,
                      letterSpacing: -0.25,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
            if (subtitleWidget != null) subtitleWidget,
          ],
        ),
      );
    }

    final storeIdentity = ref.watch(storeIdentityProvider).asData?.value;
    final storeLogoUrl = storeIdentity?.logoUrl;
    final resolvedName =
        (storeNameOverride ?? storeIdentity?.name ?? '').trim();
    final displayName = resolvedName.isNotEmpty ? resolvedName : 'DukaNest';

    return Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leading ?? _StoreAvatar(logoUrl: storeLogoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 16),
          titleWidget,
          if (subtitleWidget != null) subtitleWidget,
        ],
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Icon(
      Icons.storefront_rounded,
      size: 22,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return CircleAvatar(
      radius: 20,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: (logoUrl != null && logoUrl!.trim().isNotEmpty)
            ? Image.network(
                logoUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}
