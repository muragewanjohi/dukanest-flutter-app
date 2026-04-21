import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/screens/landing_screen.dart';
import '../features/onboarding/screens/onboarding_carousel_screen.dart';
import '../features/onboarding/screens/login_screen.dart';
import '../features/onboarding/screens/reset_password_screen.dart';
import '../features/onboarding/screens/register_screen.dart';
import '../features/onboarding/screens/session_restore_screen.dart';
import '../features/onboarding/screens/mfa_screen.dart';
import '../features/dashboard/screens/dashboard_shell.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/orders/screens/orders_list_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/products/screens/products_list_screen.dart';
import '../features/products/screens/product_editor_screen.dart';
import '../features/products/screens/categories_management_screen.dart';
import '../features/products/screens/category_editor_screen.dart';
import '../features/products/screens/attributes_management_screen.dart';
import '../features/products/screens/attribute_editor_screen.dart';
import '../features/dashboard/screens/more_menu_screen.dart';
import '../features/analytics/screens/analytics_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/store_identity_screen.dart';
import '../features/settings/screens/tax_settings_screen.dart';
import '../features/settings/screens/payment_settings_screen.dart';
import '../features/settings/screens/shipping_delivery_screen.dart';
import '../features/settings/screens/manage_zones_screen.dart';
import '../features/settings/screens/delivery_zone_editor_screen.dart';
import '../features/content/screens/content_management_screen.dart';
import '../features/content/screens/blog_post_editor_screen.dart';
import '../features/content/screens/page_editor_screen.dart';
import '../features/content/screens/hero_section_editor_screen.dart';
import '../features/sales/screens/sales_list_screen.dart';
import '../features/sales/screens/sales_editor_screen.dart';
import '../features/customers/screens/customers_list_screen.dart';
import '../features/onboarding/providers/auth_provider.dart';
import '../core/auth/auth_state.dart';
import '../core/providers/onboarding_seen_provider.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
GoRouter? _previousRouter;

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final onboardingSeenState = ref.watch(onboardingSeenProvider);
  final previousRouter = _previousRouter;

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Keep current location when Riverpod rebuilds the router due to auth/onboarding updates.
    // This prevents briefly resetting to `/splash` during sign-in transitions.
    initialLocation:
        previousRouter?.routerDelegate.currentConfiguration.uri.toString() ??
        '/splash',
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isLanding = state.matchedLocation == '/landing';
      final isMfaPhase = state.matchedLocation == '/mfa';
      final atSplash = state.matchedLocation == '/splash';
      final onboardingSeen = onboardingSeenState.valueOrNull;
      final onboardingKnown = onboardingSeenState.hasValue;

      final isResolvingSession = authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.sessionRestoring;
      if (isResolvingSession) {
        return atSplash ? null : '/splash';
      }
      if (atSplash) {
        if (!onboardingKnown) {
          return null;
        }
        switch (authState.status) {
          case AuthStatus.authenticated:
            return '/dashboard';
          case AuthStatus.awaitingMfa:
            return '/mfa';
          case AuthStatus.unauthenticated:
            return onboardingSeen == true ? '/landing' : '/onboarding';
          default:
            return onboardingSeen == true ? '/landing' : '/onboarding';
        }
      }

      // While secure storage is still loading, avoid flashing the intro carousel.
      if (authState.status == AuthStatus.initial && isOnboarding) {
        return '/landing';
      }

      if (authState.status == AuthStatus.unauthenticated) {
        if (!onboardingKnown) {
          return '/splash';
        }
        if (onboardingSeen != true) {
          if (isOnboarding) {
            return null;
          }
          return '/onboarding';
        }
        if (isLanding ||
            isLoggingIn ||
            isOnboarding ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/reset-password') {
          return null;
        }
        return '/landing';
      }

      if (authState.status == AuthStatus.awaitingMfa && !isMfaPhase) {
        return '/mfa';
      }

      if (authState.status == AuthStatus.authenticated) {
        final isRegister = state.matchedLocation == '/register';
        final isResetPassword =
            state.matchedLocation == '/reset-password';
        if (isLanding ||
            isLoggingIn ||
            isMfaPhase ||
            isOnboarding ||
            isRegister ||
            isResetPassword) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SessionRestoreScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingCarouselScreen(),
      ),
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/mfa',
        builder: (context, state) => const MfaScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/store-identity',
        builder: (context, state) => const StoreIdentityScreen(),
      ),
      GoRoute(
        path: '/tax-settings',
        builder: (context, state) => const TaxSettingsScreen(),
      ),
      GoRoute(
        path: '/payment-settings',
        builder: (context, state) => const PaymentSettingsScreen(),
      ),
      GoRoute(
        path: '/shipping-delivery',
        builder: (context, state) => const ShippingDeliveryScreen(),
      ),
      GoRoute(
        path: '/shipping-zones',
        builder: (context, state) => const ManageZonesScreen(),
      ),
      GoRoute(
        path: '/shipping-zone-editor',
        builder: (context, state) {
          final extra = state.extra;
          final args = extra is DeliveryZoneEditorArgs ? extra : null;
          return DeliveryZoneEditorScreen(args: args);
        },
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomersListScreen(),
      ),
      GoRoute(
        path: '/content-management',
        builder: (context, state) => const ContentManagementScreen(),
      ),
      GoRoute(
        path: '/blog-post/new',
        builder: (context, state) => const BlogPostEditorScreen(),
      ),
      GoRoute(
        path: '/blog-post/edit/:id',
        builder: (context, state) {
          final id = Uri.decodeComponent(state.pathParameters['id']!);
          return BlogPostEditorScreen(postId: id);
        },
      ),
      GoRoute(
        path: '/page-editor/:slug',
        builder: (context, state) {
          final slug = Uri.decodeComponent(state.pathParameters['slug']!);
          return PageEditorScreen(pageSlug: slug);
        },
      ),
      GoRoute(
        path: '/hero-section/edit',
        builder: (context, state) => const HeroSectionEditorScreen(),
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) => const SalesListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const SalesEditorScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return SalesEditorScreen(saleId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesManagementScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const CategoryEditorScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return CategoryEditorScreen(categoryId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/attributes',
        builder: (context, state) => const AttributesManagementScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const AttributeEditorScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return AttributeEditorScreen(attributeId: id);
            },
          ),
        ],
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
                routes: [
                  GoRoute(
                    path: 'detail/:orderKey',
                    builder: (context, state) {
                      final key = Uri.decodeComponent(state.pathParameters['orderKey']!);
                      return OrderDetailScreen(orderKey: key);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (context, state) => const ProductsListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const ProductEditorScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:sku',
                    builder: (context, state) {
                      final sku = Uri.decodeComponent(state.pathParameters['sku']!);
                      return ProductEditorScreen(initialSku: sku);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreMenuScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  _previousRouter = router;
  return router;
});
