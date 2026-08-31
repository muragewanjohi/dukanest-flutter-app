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
import '../features/onboarding/screens/first_run_tutorial_screen.dart';
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
import '../features/analytics/screens/expense_categories_screen.dart';
import '../features/analytics/screens/expenses_screen.dart';
import '../features/analytics/screens/scheduled_reports_screen.dart';
import '../features/themes/screens/themes_screen.dart';
import '../features/media/screens/media_library_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/assistant/screens/assistant_chat_screen.dart';
import '../features/onboarding/screens/onboarding_chat_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/store_identity_screen.dart';
import '../features/settings/screens/tax_settings_screen.dart';
import '../features/settings/screens/payment_settings_screen.dart';
import '../features/settings/screens/tumizi_web_dashboard_screen.dart';
import '../features/settings/screens/shipping_delivery_screen.dart';
import '../features/settings/screens/manage_zones_screen.dart';
import '../features/settings/screens/delivery_zone_editor_screen.dart';
import '../features/content/screens/content_management_screen.dart';
import '../features/content/screens/blog_post_editor_screen.dart';
import '../features/content/screens/forms_list_screen.dart';
import '../features/content/screens/form_editor_screen.dart';
import '../features/content/screens/form_submissions_screen.dart';
import '../features/content/screens/page_editor_screen.dart';
import '../features/content/screens/hero_section_editor_screen.dart';
import '../features/content/screens/banners_section_editor_screen.dart';
import '../features/content/screens/split_layout_section_editor_screen.dart';
import '../features/sales/screens/sales_list_screen.dart';
import '../features/sales/screens/sales_editor_screen.dart';
import '../features/customers/screens/customers_list_screen.dart';
import '../features/customers/screens/customer_detail_screen.dart';
import '../features/customers/screens/customer_edit_screen.dart';
import '../features/inventory/screens/inventory_screen.dart';
import '../features/pos/providers/pos_providers.dart';
import '../features/pos/screens/pos_register_screen.dart';
import '../features/pos/screens/pos_cart_screen.dart';
import '../features/pos/screens/pos_tender_screen.dart';
import '../features/pos/screens/pos_receipt_screen.dart';
import '../features/subscription/screens/change_plan_screen.dart';
import '../features/subscription/screens/subscription_screen.dart';
import '../features/subscription/screens/billing_history_screen.dart';
import '../features/subscription/screens/referral_screen.dart';
import '../features/onboarding/providers/auth_provider.dart';
import '../core/auth/auth_state.dart';
import '../core/providers/first_run_tutorial_seen_provider.dart';
import '../core/providers/onboarding_seen_provider.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Re-run [GoRouter.redirect] when auth/onboarding changes without recreating the router
/// (recreating it duplicates Navigator page keys and crashes the shell).
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(onboardingSeenProvider, (_, __) => notifyListeners());
    ref.listen(firstRunTutorialSeenProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  ref.keepAlive();
  final refresh = _RouterRefreshListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final onboardingSeenState = ref.read(onboardingSeenProvider);
      final firstRunTutorialSeenState = ref.read(firstRunTutorialSeenProvider);
      bool isFirstRunSetupRoute(String location) {
        return location == '/settings' ||
            location == '/store-identity' ||
            location == '/payment-settings' ||
            location == '/subscription' ||
            location == '/change-plan' ||
            location == '/billing-history' ||
            location == '/tumizi-dashboard' ||
            location == '/shipping-delivery' ||
            location == '/shipping-zones' ||
            location == '/shipping-zone-editor' ||
            location.startsWith('/products') ||
            location.startsWith('/categories') ||
            location.startsWith('/attributes');
      }

      final tutorialBypass = state.uri.queryParameters['tutorial'] == '1';
      final tutorialReplay = state.uri.queryParameters['replay'] == '1';

      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isLanding = state.matchedLocation == '/landing';
      final isMfaPhase = state.matchedLocation == '/mfa';
      final isFirstRunTutorial = state.matchedLocation == '/first-run-tutorial';
      final atSplash = state.matchedLocation == '/splash';
      final onboardingSeen = onboardingSeenState.valueOrNull;
      final onboardingKnown = onboardingSeenState.hasValue;
      final firstRunTutorialSeen = firstRunTutorialSeenState.valueOrNull;
      final firstRunTutorialKnown = firstRunTutorialSeenState.hasValue;

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
            if (!firstRunTutorialKnown) {
              return null;
            }
            return firstRunTutorialSeen == true
                ? '/dashboard'
                : '/first-run-tutorial';
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
        if (!firstRunTutorialKnown) {
          return atSplash ? null : '/splash';
        }
        if (firstRunTutorialSeen != true) {
          return (isFirstRunTutorial ||
                  (tutorialBypass &&
                      isFirstRunSetupRoute(state.matchedLocation)))
              ? null
              : '/first-run-tutorial';
        }
        final isRegister = state.matchedLocation == '/register';
        final isResetPassword = state.matchedLocation == '/reset-password';
        if (isFirstRunTutorial && tutorialReplay) {
          return null;
        }
        if (isLanding ||
            isLoggingIn ||
            isMfaPhase ||
            isOnboarding ||
            isFirstRunTutorial ||
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
        builder: (context, state) {
          final refCode = state.uri.queryParameters['ref']?.trim();
          return RegisterScreen(
            initialReferrerSubdomain:
                refCode != null && refCode.isNotEmpty ? refCode : null,
          );
        },
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
        path: '/first-run-tutorial',
        builder: (context, state) => const FirstRunTutorialScreen(),
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
        // OC.3 (docs/IMPLEMENTATION_TRACKER.md, "UI — Onboarding AI Chat")
        // — a plain pushed route, not a bottom-nav tab, same treatment as
        // /analytics and /assistant. Reached via OC.4's post-registration
        // wiring (register_screen.dart) or manually later; never a gate —
        // every state the screen can be in offers a way through to
        // /dashboard (see onboarding_chat_screen.dart).
        path: '/onboarding-chat',
        builder: (context, state) => const OnboardingChatScreen(),
      ),
      GoRoute(
        // Phase 3 of the Flutter assistant plan (IMPLEMENTATION_TRACKER.md)
        // — demoted from a StatefulShellBranch (bottom-nav tab) to a plain
        // pushed route, reachable from the More menu instead, so the AI
        // Assistant could take the center tab slot. Path and children kept
        // exactly as before so every existing context.go('/analytics') /
        // context.push('/analytics/...') call site (analytics_screen.dart,
        // expenses_screen.dart, dashboard_screen.dart, more_menu_screen.dart)
        // keeps working unchanged.
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
        routes: [
          GoRoute(
            path: 'expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: 'expense-categories',
            builder: (context, state) => const ExpenseCategoriesScreen(),
          ),
          GoRoute(
            path: 'scheduled-reports',
            builder: (context, state) => const ScheduledReportsScreen(),
          ),
        ],
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
        path: '/tumizi-dashboard',
        builder: (context, state) => const TumiziWebDashboardScreen(),
      ),
      GoRoute(
        path: '/tumizi-dashboard/general',
        builder: (context, state) => const TumiziGeneralInformationScreen(),
      ),
      GoRoute(
        path: '/tumizi-dashboard/edit-merchant',
        builder: (context, state) => const TumiziEditMerchantScreen(),
      ),
      GoRoute(
        path: '/tumizi-dashboard/refunds',
        builder: (context, state) => const TumiziRefundsScreen(),
      ),
      GoRoute(
        path: '/tumizi-dashboard/withdrawals',
        builder: (context, state) => const TumiziMpesaWithdrawalScreen(),
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
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/change-plan',
        builder: (context, state) => const ChangePlanScreen(),
      ),
      GoRoute(
        path: '/referrals',
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/billing-history',
        builder: (context, state) => const BillingHistoryScreen(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) => const PosRegisterScreen(),
        routes: [
          GoRoute(
            path: 'cart',
            builder: (context, state) => const PosCartScreen(),
          ),
          GoRoute(
            path: 'tender',
            builder: (context, state) => const PosTenderScreen(),
          ),
          GoRoute(
            path: 'receipt',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is PosCompletedSale) {
                return PosReceiptScreen(sale: extra);
              }
              // Direct hit / reload with no sale in hand — back to the register.
              return const PosRegisterScreen();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomersListScreen(),
        routes: [
          GoRoute(
            path: 'detail/:id',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return CustomerDetailScreen(customerId: id);
            },
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return CustomerEditScreen(customerId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/content-management',
        builder: (context, state) => const ContentManagementScreen(),
      ),
      GoRoute(
        path: '/media-library',
        builder: (context, state) => const MediaLibraryScreen(),
      ),
      GoRoute(
        path: '/themes',
        builder: (context, state) => const ThemesScreen(),
        routes: [
          GoRoute(
            path: 'customize',
            builder: (context, state) => const ThemeCustomizationScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/forms',
        builder: (context, state) => const FormsListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const FormEditorScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return FormEditorScreen(formId: id);
            },
          ),
          GoRoute(
            path: ':id/submissions',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return FormSubmissionsScreen(formId: id);
            },
          ),
        ],
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
        routes: [
          GoRoute(
            path: 'sections/hero',
            builder: (context, state) {
              final slug =
                  Uri.decodeComponent(state.pathParameters['slug']!);
              return HeroSectionEditorScreen(pageSlug: slug);
            },
          ),
          GoRoute(
            path: 'sections/banners',
            builder: (context, state) {
              final slug =
                  Uri.decodeComponent(state.pathParameters['slug']!);
              return BannersSectionEditorScreen(pageSlug: slug);
            },
          ),
          GoRoute(
            path: 'sections/split-layout',
            builder: (context, state) {
              final slug =
                  Uri.decodeComponent(state.pathParameters['slug']!);
              return SplitLayoutSectionEditorScreen(pageSlug: slug);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/hero-section/edit',
        redirect: (context, state) => '/page-editor/home/sections/hero',
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
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CategoriesManagementScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const CategoryEditorScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return CategoryEditorScreen(categoryId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/attributes',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AttributesManagementScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const AttributeEditorScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            parentNavigatorKey: _rootNavigatorKey,
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
                      final key = Uri.decodeComponent(
                          state.pathParameters['orderKey']!);
                      return OrderDetailScreen(orderKey: key);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            // Center slot — AI Assistant, deliberately prominent (see
            // dashboard_shell.dart's NavigationDestination styling for this
            // branch). Took Analytics's old center-adjacent position;
            // Analytics moved to the More menu (see the plain /analytics
            // GoRoute above) so it kept its exact path.
            routes: [
              GoRoute(
                path: '/assistant',
                builder: (context, state) => const AssistantChatScreen(),
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
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ProductEditorScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:sku',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final sku =
                          Uri.decodeComponent(state.pathParameters['sku']!);
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
                path: '/more',
                builder: (context, state) => const MoreMenuScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
