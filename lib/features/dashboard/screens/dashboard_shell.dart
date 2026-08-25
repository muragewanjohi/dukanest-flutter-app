import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../orders/providers/pending_orders_count_provider.dart';
import '../providers/assistant_spotlight_provider.dart';
import '../providers/dashboard_getting_started_provider.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(WidgetRef ref, int index) {
    if (index == 2) {
      ref.read(assistantSpotlightDismissedProvider.notifier).state = true;
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingOrdersCount = ref.watch(pendingOrdersCountProvider).maybeWhen(
          data: (count) => count,
          orElse: () => 0,
        );
    final badgeLabel = pendingOrdersCount > 99 ? '99+' : '$pendingOrdersCount';
    // Branch order is [Home, Orders, AI, Products, More] — see router.dart's
    // StatefulShellRoute.indexedStack branches list, which this index must
    // match exactly.
    final aiSelected = navigationShell.currentIndex == 2;

    // First-run spotlight (Flutter Assistant Phase 4,
    // IMPLEMENTATION_TRACKER.md): shown while the real, server-persisted
    // 'assistant' getting-started item is still incomplete (they haven't
    // sent a message yet) and hasn't been dismissed this session — see
    // assistant_spotlight_provider.dart for why dismissal is session-only,
    // not persisted.
    final dismissed = ref.watch(assistantSpotlightDismissedProvider);
    final gettingStarted = ref.watch(dashboardGettingStartedProvider).asData?.value;
    final assistantTried = _assistantItemCompleted(gettingStarted);
    final showSpotlight = !dismissed && assistantTried == false && navigationShell.currentIndex != 2;

    return Stack(
      children: [
        Scaffold(
          body: navigationShell,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.35),
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _goBranch(ref, index),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pendingOrdersCount > 0,
                    label: Text(badgeLabel),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: pendingOrdersCount > 0,
                    label: Text(badgeLabel),
                    child: const Icon(Icons.shopping_bag),
                  ),
                  label: 'Orders',
                ),
                // Center slot, deliberately prominent — the core interaction
                // surface (per the user's explicit request), not just
                // another tab. A filled brand-color circle instead of a
                // plain outline icon, same treatment selected or not, so it
                // always reads as the primary action at a glance.
                NavigationDestination(
                  icon: _AiNavIcon(selected: aiSelected),
                  selectedIcon: _AiNavIcon(selected: aiSelected),
                  label: 'Assistant',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Products',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  selectedIcon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
          ),
        ),
        if (showSpotlight)
          Positioned(
            left: 16,
            right: 16,
            bottom: 80 + MediaQuery.of(context).padding.bottom + 12,
            child: _AssistantSpotlight(
              onDismiss: () => ref.read(assistantSpotlightDismissedProvider.notifier).state = true,
            ),
          ),
      ],
    );
  }

  /// Reads the 'assistant' checklist item's completion out of
  /// dashboardGettingStartedProvider's raw payload. Returns null while
  /// loading/unavailable (spotlight stays hidden rather than flashing on
  /// briefly before the real state is known).
  static bool? _assistantItemCompleted(Map<String, dynamic>? data) {
    if (data == null) return null;
    final items = data['items'];
    if (items is! List) return null;
    for (final item in items) {
      if (item is Map && item['id'] == 'assistant') {
        return item['completed'] == true;
      }
    }
    return null;
  }
}

/// First-run nudge pointing at the Assistant tab. Purely additive UI — no
/// server calls of its own; dismissal is handled by the caller.
class _AssistantSpotlight extends StatelessWidget {
  const _AssistantSpotlight({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👋', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Try your Assistant',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ask about your store, get help, or find out what to do next.',
                        style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: AppTheme.onSurfaceVariant,
                  onPressed: onDismiss,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
              ],
            ),
          ),
        ),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: -5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Prominent center-tab icon for the AI Assistant — a filled circle badge
/// rather than a plain outline glyph, so it visually pops against the other
/// four destinations without needing a custom bottom-bar widget (which risks
/// layout issues neither `flutter analyze` nor this environment, with no
/// emulator available, can catch). Stays within NavigationDestination's
/// normal icon bounds — no overflow/transform tricks — to keep this safe
/// sight-unseen.
class _AiNavIcon extends StatelessWidget {
  const _AiNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.14),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: selected ? Colors.white : AppTheme.primary,
        size: 28,
      ),
    );
  }
}
