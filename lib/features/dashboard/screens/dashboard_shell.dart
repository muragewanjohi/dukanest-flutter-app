import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../orders/providers/pending_orders_count_provider.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
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

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goBranch,
          destinations: [
            NavigationDestination(
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
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
