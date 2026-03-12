import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/screens/login_screen.dart';
import '../features/onboarding/screens/mfa_screen.dart';
import '../features/dashboard/screens/dashboard_shell.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/orders/screens/orders_list_screen.dart';
import '../features/products/screens/products_list_screen.dart';
import '../features/onboarding/providers/auth_provider.dart';
import '../core/auth/auth_state.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      final isMfaPhase = state.matchedLocation == '/mfa';

      if (authState.status == AuthStatus.unauthenticated && !isLoggingIn) {
        return '/login';
      }
      
      if (authState.status == AuthStatus.awaitingMfa && !isMfaPhase) {
        return '/mfa';
      }

      if (authState.status == AuthStatus.authenticated && (isLoggingIn || isMfaPhase)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/mfa',
        builder: (context, state) => const MfaScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (context, state) => const ProductsListScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
