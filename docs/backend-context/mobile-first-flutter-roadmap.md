# DukaNest Mobile-First & Flutter App Roadmap

> **Created**: February 27, 2026
> **Status**: In progress (Phase 1 partial; Phase 0 pending)
> **Goal**: Transform DukaNest into a mobile-first platform with native Flutter apps for Android & iOS, enabling business owners to create and run their online shop entirely from their phone.

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Analytics & Market Data](#2-analytics--market-data)
3. [Phase 0 — API Foundation](#3-phase-0--api-foundation)
4. [Phase 1 — Mobile-First Web Dashboard](#4-phase-1--mobile-first-web-dashboard)
5. [Phase 2 — Flutter Shop Owner App (MVP)](#5-phase-2--flutter-shop-owner-app-mvp)
6. [Phase 3 — Flutter Customer Storefront App](#6-phase-3--flutter-customer-storefront-app)
7. [Phase 4 — Platform Maturity & Growth](#7-phase-4--platform-maturity--growth)
8. [Technical Architecture](#8-technical-architecture)
9. [Database Changes Required](#9-database-changes-required)
10. [Risk Assessment](#10-risk-assessment)
11. [Success Metrics](#11-success-metrics)
12. [Timeline Summary](#12-timeline-summary)

---

## 🚧 Progress Snapshot (March 10, 2026)

### Overall Phase Status
- [ ] Phase 0 — API Foundation (in progress)
- [ ] Phase 1 — Mobile-First Web Dashboard
- [ ] Phase 2 — Flutter Shop Owner App (MVP)
- [ ] Phase 3 — Flutter Customer Storefront App
- [ ] Phase 4 — Platform Maturity & Growth

### Current Position
- [x] Started execution on Phase 1 (partial implementation)
- [x] Product mobile quick actions/cards shipped
- [x] Product page mobile UX improvements shipped (Add Product FAB, search/filter UX)
- [x] Product-adjacent pages have responsive table/layout improvements (Categories, Attributes, Inventory, Inventory Settings)
- [x] Phase 0 core mobile auth shell started (`/api/v1/mobile/auth/*`)
- [x] Phase 0 initial mobile dashboard endpoints started (`overview`, `products`, `orders`, `customers`, `inventory`, `settings`)
- [x] Postman mobile collection updated for end-to-end testing (login/refresh/MFA/dashboard/logout)
- [x] Phase 0 foundation complete
- [ ] Phase 1 complete

### Phase 0 — API Foundation Checklist

#### P0.1: Mobile API Namespace
- [x] Create `/api/v1/mobile/*` route namespace
- [x] Add mobile auth endpoints (`login`, `google`, `refresh`, `logout`, `mfa/*`, `forgot-password`)
- [x] Add mobile dashboard endpoints (`overview`, `products`, `orders`, `customers`, `inventory`, `sales`, `analytics`, `settings`)
- [x] Add `POST /api/v1/mobile/dashboard/settings/delete-account` (Bearer; same soft-delete as web)
- [x] Add mobile notifications endpoints (`list`, `register-device`, `preferences`)
- [x] Add mobile media upload endpoint
- [x] Add mobile M-Pesa endpoints (`initiate`, `status`)

#### P0.2: Token-Based Authentication
- [x] Implement bearer-token middleware for mobile (`Authorization: Bearer <token>`)
- [x] Add shared `authenticateMobileRequest()` helper
- [x] Map authenticated Supabase user to platform auth context (`role`, `tenant_id`)
- [x] Add token refresh flow for mobile clients

#### P0.3: Standardized API Response Format
- [x] Enforce `{ success, data, error, pagination }` envelope across mobile endpoints
- [x] Define and apply shared mobile error codes

#### P0.4: Push Notification Infrastructure
- [x] Add device token persistence model/table
- [x] Add notification dispatch wiring to FCM/APNs path
- [x] Add notification preferences per user/device

### Phase 1 — Mobile-First Web Dashboard Checklist

#### P1.1: Mobile Navigation Redesign
- [x] Add mobile bottom tab navigation
- [x] Add mobile full-screen "More" menu
- [x] Integrate mobile nav into dashboard layout/client shell

#### P1.2: Mobile-Optimized Dashboard Pages
- [x] Products page: mobile-first quick action cards and FAB workflow
- [x] Products page: improved mobile search/filter interaction
- [x] Categories page: responsive list/table behavior
- [x] Attributes page: responsive list/table behavior
- [x] Inventory pages: responsive layouts/tables
- [x] Dashboard Home mobile redesign complete
- [x] Orders mobile redesign complete
- [x] Order Detail mobile redesign complete
- [x] Product Add/Edit mobile redesign complete

#### P1.3: PWA Enablement
- [x] Complete `public/favicon_io/site.webmanifest` for installable PWA
- [x] Add `public/sw.js` service worker with caching/sync strategy
- [x] Add install prompt UX in dashboard
- [x] Register and wire web push notifications

#### P1.4: Mobile Camera & Media Integration
- [x] Camera-first capture flow for product media
- [x] Client-side image compression
- [x] Upload progress UX for slow networks

#### P1.5: Storefront Mobile Audit
- [x] Touch target audit/fixes (44x44 minimum)
- [x] Checkout flow validation on 360px widths
- [x] Mobile M-Pesa flow audit/fixes
- [x] Typography/form readability and no-horizontal-scroll checks

---

## 1. Current State Assessment

### Tech Stack
| Layer | Technology |
|-------|-----------|
| Framework | Next.js 15 (React 19) |
| Styling | Tailwind CSS + Shadcn/ui + Radix UI |
| Database | PostgreSQL via Supabase |
| ORM | Prisma 7 with Row Level Security |
| Auth | Supabase Auth (cookie-based sessions) |
| Payments | M-Pesa (STK Push) + PesaPal |
| Hosting | Vercel |
| State | TanStack Query |
| Analytics | Vercel Analytics + Google Analytics + Meta Pixel |
| Email | SendGrid |
| Cache | Upstash Redis + Vercel KV |

### Architecture
- **Multi-tenant SaaS**: Each shop is a tenant with subdomain (`shop.dukanest.com`) or custom domain
- **API**: 212+ Next.js REST API route handlers in `src/app/api/`
- **Dashboard**: 61 pages for shop owners (products, orders, inventory, analytics, blogs, themes, etc.)
- **Storefront**: Server-rendered tenant storefronts with themeable layouts
- **Auth system**: Supabase Auth with roles (`tenant_admin`, `tenant_staff`, `landlord`)
- **MFA**: TOTP-based multi-factor authentication with trusted devices

### What Exists
- Full CRUD for: products, orders, customers, categories, inventory, blogs, pages, forms, sales/promotions, attributes, variants, media, delivery zones, coupons, reviews, wishlists
- M-Pesa production integration (STK Push for payments + subscription billing)
- PesaPal integration for subscription payments
- Analytics engine (revenue, traffic, conversions, product performance, geographic, real-time)
- Support ticket system (customer <-> store, store <-> platform)
- Theme system with customization
- Role-based access control
- Notification system (new_order, pending_payment, failed_payment, low_stock, support tickets, delivery fees)

### What Does NOT Exist
- ❌ No Flutter or any native mobile app code
- ❌ No service worker / PWA capabilities
- ❌ No push notifications (FCM/APNs)
- ❌ No JWT/token-based auth (only cookie-based via Supabase SSR)
- ❌ No versioned mobile API namespace
- ❌ No offline support
- ❌ No device token storage
- ❌ Web manifest (`site.webmanifest`) exists but is empty (no name, no start_url, no scope)

### Current Dashboard Navigation Structure
The dashboard sidebar contains these sections:
1. **Dashboard** (home/overview)
2. **Themes** (admin only)
3. **Orders**
4. **Products** group: Products, Categories, Attributes, Inventory, Inventory Settings
5. **Customers**
6. **Marketing** group: Sales/Promotions, Analytics
7. **Content** group: Pages, Blogs, Blog Categories, Forms, Media Library
8. **Settings**
9. **Support** group: Support Tickets, Platform Support, User Guide
10. **Admin-only**: Users, Subscription

### Current Auth Flow
- Uses Supabase `getUser()` server-side (verifies JWT with Supabase server)
- Cookie-based session management via `@supabase/ssr`
- MFA support with TOTP codes + trusted devices
- Roles stored in `user_metadata`: `tenant_admin`, `tenant_staff`, `landlord`
- **Problem for mobile**: Cookies don't work well in native apps. Need bearer token auth.

---

## 2. Analytics & Market Data

**Source**: Google Analytics (February 2026)

| Metric | Value |
|--------|-------|
| Mobile users | **83.7%** |
| Desktop users | 15.5% |
| Tablet users | 0.8% |
| Top OS | Android: 785, Windows: 129, iOS: 88, Linux: 27, Mac: 3 |
| Platform split | web/mobile: 865, web/desktop: 160, web/tablet: 8 |
| Top browsers | Android Webview, Chrome, Safari |
| Top resolutions | 360x800, 360x806, 1366x768, 385x854, 412x915 |

### Key Insights
- **Android dominates** (785 vs 88 iOS) — prioritize Android testing and Play Store launch
- **360px wide screens** are the most common — every UI must work perfectly at this width
- **Android WebView** is a top browser — some users are accessing via in-app browsers (WhatsApp, Facebook)
- Very few desktop users — desktop can be secondary priority
- The market strongly validates mobile-first approach

---

## 3. Phase 0 — API Foundation

> **Priority**: CRITICAL — Must complete before Flutter development starts
> **Estimated effort**: 2-3 weeks
> **Dependencies**: None (can start immediately)

### P0.1: Mobile API Namespace

Create a versioned API namespace at `/api/v1/mobile/` that wraps existing business logic.

**Why**: Separates mobile-specific concerns from web routes. Allows independent evolution without breaking the web app. Enables API versioning for when mobile apps can't be force-updated.

**Implementation plan**:
```
src/app/api/v1/mobile/
├── auth/
│   ├── login/route.ts          # Returns JWT access + refresh tokens
│   ├── google/route.ts         # Google ID token → same MFA/tenant flow as login
│   ├── register/route.ts       # Wraps POST /api/tenants/register → mobile envelope
│   ├── customers/google/route.ts # Customer Google Sign-In / Sign-Up
│   ├── refresh/route.ts        # Token refresh endpoint
│   ├── logout/route.ts         # Invalidate tokens
│   ├── mfa/
│   │   ├── status/route.ts
│   │   ├── verify/route.ts
│   │   └── send-code/route.ts
│   └── forgot-password/route.ts
├── dashboard/
│   ├── overview/route.ts       # Dashboard home stats
│   ├── products/route.ts       # CRUD
│   ├── products/[id]/route.ts
│   ├── orders/route.ts         # List + update status
│   ├── orders/[id]/route.ts
│   ├── customers/route.ts
│   ├── customers/[id]/route.ts
│   ├── inventory/route.ts
│   ├── sales/route.ts
│   ├── analytics/route.ts
│   └── settings/route.ts
├── notifications/
│   ├── route.ts                # List notifications
│   ├── register-device/route.ts # Register FCM token
│   └── preferences/route.ts    # Notification preferences
├── media/
│   └── upload/route.ts         # Mobile-optimized image upload
└── mpesa/
    ├── initiate/route.ts       # STK Push
    └── status/route.ts         # Payment status check
```

**Key decisions**:
- Mobile routes should reuse existing business logic (service layer functions) but with token-based auth middleware
- Standardized response envelope: `{ success: boolean, data?: T, error?: { code: string, message: string }, pagination?: { page, limit, total, totalPages } }`
- Mobile-specific optimizations: compressed payloads, pagination defaults tuned for mobile, image URLs with mobile-appropriate sizes

### P0.2: Token-Based Authentication

**Current state**: Supabase cookie-based auth (`@supabase/ssr`)

**Required**: JWT bearer token auth for native apps

**Implementation approach**:
1. **Use Supabase's built-in JWT** — Supabase already issues JWTs. For mobile, use the Supabase client SDK's `signInWithPassword()` which returns `access_token` + `refresh_token`
2. **Create a middleware layer** that accepts `Authorization: Bearer <token>` headers
3. **Validate tokens** using `supabase.auth.getUser(token)` server-side
4. **Token storage on mobile**: Use Flutter's `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences on Android)

```typescript
// src/lib/auth/mobile-auth.ts — New file
import { createClient } from '@supabase/supabase-js';

export async function authenticateMobileRequest(request: Request): Promise<AuthUser | null> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;

  const token = authHeader.substring(7);
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return null;

  // Map to AuthUser with role, tenant_id, etc.
  return mapSupabaseUserToAuthUser(user);
}
```

**Mobile auth flow**:
1. User enters email/password in Flutter app
2. Flutter calls Supabase `signInWithPassword()` directly (or via our API)
3. Receives `access_token` (JWT, 1hr expiry) + `refresh_token`
4. Stores both in secure storage
5. Attaches `Authorization: Bearer <access_token>` to all API requests
6. When access_token expires, uses refresh_token to get new one
7. If refresh fails, redirect to login

### P0.3: Standardized API Response Format

Every mobile API endpoint must return consistent responses:

```typescript
// Success response
{
  "success": true,
  "data": { ... },
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}

// Error response
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Product name is required",
    "details": [
      { "field": "name", "message": "Required" }
    ]
  }
}

// Error codes enum
type ErrorCode =
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'VALIDATION_ERROR'
  | 'RATE_LIMITED'
  | 'INTERNAL_ERROR'
  | 'PAYMENT_FAILED'
  | 'SUBSCRIPTION_EXPIRED';
```

### P0.4: Push Notification Infrastructure

**Components needed**:
1. **Firebase Cloud Messaging (FCM)** setup for both Android and iOS
2. **Device token storage** in database (see [Database Changes](#9-database-changes-required))
3. **Notification dispatch service** that sends to FCM when events occur
4. **Notification preferences** per user

**Events that trigger push notifications**:
| Event | Priority | Audience |
|-------|----------|----------|
| New order received | High | Shop owner |
| Payment confirmed (M-Pesa) | High | Shop owner |
| Payment failed | High | Shop owner |
| Low stock alert | Medium | Shop owner |
| New support ticket | Medium | Shop owner |
| Support ticket reply | Medium | Both |
| Order status updated | Medium | Customer |
| Delivery fee quote ready | Medium | Customer |
| Subscription expiring | High | Shop owner |

---

## 4. Phase 1 — Mobile-First Web Dashboard

> **Priority**: HIGH — Immediate improvement for 83.7% of users
> **Estimated effort**: 3-4 weeks
> **Dependencies**: Can run in parallel with Phase 0

### P1.1: Mobile Navigation Redesign

**Current problem**: Desktop sidebar with hamburger menu on mobile. Users need 2 taps minimum to navigate. No persistent navigation on mobile.

**Solution**: Bottom tab navigation on mobile screens.

**Bottom tab structure** (5 tabs, most important actions):
| Tab | Icon | Destination |
|-----|------|------------|
| Home | HomeIcon | Dashboard overview |
| Orders | ShoppingCartIcon | Orders list |
| Add | PlusCircleIcon | Quick add product (FAB-style) |
| Products | CubeIcon | Products list |
| More | Squares2X2Icon | Full menu (current sidebar items) |

**Implementation**:
- Add a `<MobileBottomNav />` component that renders only below `lg:` breakpoint
- The "More" tab opens a full-screen slide-up menu with all navigation items
- Keep the existing sidebar for desktop (no regression)
- Update `layout-client.tsx` to conditionally render

**Files to modify**:
- `src/components/dashboard/layout-client.tsx` — Add bottom nav
- Create `src/components/dashboard/mobile-bottom-nav.tsx`
- Create `src/components/dashboard/mobile-full-menu.tsx`
- `src/components/dashboard/header.tsx` — Simplify for mobile

### P1.2: Mobile-Optimized Dashboard Pages

Redesign the 5 most critical pages for mobile-first:

**a) Dashboard Home** (`src/app/dashboard/page.tsx`)
- Stack stats cards vertically (not 4-column grid)
- Large, tappable stat cards with swipe for more
- Quick action buttons: "New Order", "Add Product", "View Low Stock"
- Recent orders as a scrollable list (not table)

**b) Orders** (`src/app/dashboard/orders/page.tsx`)
- Replace data table with card-based list
- Swipe-to-action (swipe right = mark as shipped, etc.)
- Status filter pills at top (horizontal scroll)
- Pull-to-refresh
- Quick status update without opening detail page

**c) Products** (`src/app/dashboard/products/page.tsx`)
- Product cards with image thumbnails (not table rows)
- Quick stock update inline
- FAB for "Add Product"
- Search bar always visible at top

**d) Order Detail** (`src/app/dashboard/orders/[id]/page.tsx`)
- Full-screen layout optimized for phone
- One-tap status update buttons
- Click-to-call customer phone number
- Click-to-WhatsApp customer
- Share order/invoice via native share

**e) Product Add/Edit** (`src/app/dashboard/products/new/page.tsx`, `[id]/edit/page.tsx`)
- Camera button prominently placed for product photos
- Image preview and reorder
- Simplified form layout (single column)
- Bottom sticky "Save" button

### P1.3: PWA Enablement

**a) Complete the Web Manifest** (`public/favicon_io/site.webmanifest`)

```json
{
  "name": "DukaNest - Manage Your Shop",
  "short_name": "DukaNest",
  "description": "Create and manage your online shop from your phone",
  "start_url": "/dashboard",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#ffffff",
  "theme_color": "#2563eb",
  "icons": [
    { "src": "/favicon_io/android-chrome-192x192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/favicon_io/android-chrome-512x512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/favicon_io/android-chrome-512x512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ],
  "categories": ["business", "shopping"],
  "lang": "en",
  "dir": "ltr"
}
```

**b) Service Worker** — Create `public/sw.js`
- Cache dashboard shell (HTML, CSS, JS)
- Cache API responses for offline viewing (products, orders)
- Background sync for queued actions (order status updates done offline)
- Push notification handler

**c) Install Prompt**
- Show a "Add to Home Screen" banner for mobile users who visit the dashboard 2+ times
- Create `src/components/dashboard/pwa-install-prompt.tsx`

**d) Web Push Notifications**
- Register for push via service worker
- Use the same FCM infrastructure from P0.4
- Bridge between web push and native push when Flutter app exists

### P1.4: Mobile Camera & Media Integration

- Ensure `<input type="file" capture="environment">` works for product photos
- Client-side image compression before upload (reduce file size for mobile data)
- Preview thumbnails after capture
- Progress indicator for uploads on slow connections
- Consider using the `compressorjs` library for client-side compression

### P1.5: Storefront Mobile Audit

Current storefront layout (`src/app/(tenant-storefront)/layout.tsx`) uses a basic `flex-col` layout. Audit and fix:
- Touch targets (minimum 44x44px per Apple HIG)
- Image loading performance (lazy loading, proper `sizes` attributes)
- Checkout flow on 360px screens
- M-Pesa payment flow on mobile
- Font sizes readable without zoom
- Form inputs don't cause horizontal scroll

---

## 5. Phase 2 — Flutter Shop Owner App (MVP)

> **Priority**: HIGH — This is the core product differentiator
> **Estimated effort**: 8-12 weeks
> **Dependencies**: Phase 0 (P0.1 + P0.2) must be complete

### Project Structure

```
dukanest_app/
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   ├── app_config.dart          # API URLs, environment
│   │   ├── theme.dart               # App theming (DukaNest brand)
│   │   └── routes.dart              # Route definitions
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart      # HTTP client with auth interceptor
│   │   │   ├── api_response.dart    # Response models matching P0.3
│   │   │   └── api_exceptions.dart
│   │   ├── auth/
│   │   │   ├── auth_provider.dart   # Auth state management
│   │   │   ├── auth_service.dart    # Login, register, refresh
│   │   │   └── token_storage.dart   # Secure token storage
│   │   ├── notifications/
│   │   │   ├── push_service.dart    # FCM setup
│   │   │   └── notification_handler.dart
│   │   └── storage/
│   │       └── local_db.dart        # SQLite/Hive for offline
│   ├── features/
│   │   ├── onboarding/
│   │   │   ├── screens/
│   │   │   │   ├── welcome_screen.dart
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   └── setup_shop_screen.dart
│   │   │   ├── providers/
│   │   │   └── widgets/
│   │   ├── dashboard/
│   │   │   ├── screens/
│   │   │   │   └── dashboard_screen.dart    # Home with stats
│   │   │   ├── providers/
│   │   │   │   └── dashboard_provider.dart
│   │   │   └── widgets/
│   │   │       ├── stat_card.dart
│   │   │       ├── recent_orders.dart
│   │   │       └── quick_actions.dart
│   │   ├── orders/
│   │   │   ├── screens/
│   │   │   │   ├── orders_list_screen.dart
│   │   │   │   └── order_detail_screen.dart
│   │   │   ├── providers/
│   │   │   │   └── orders_provider.dart
│   │   │   ├── models/
│   │   │   │   └── order.dart
│   │   │   └── widgets/
│   │   │       ├── order_card.dart
│   │   │       └── status_badge.dart
│   │   ├── products/
│   │   │   ├── screens/
│   │   │   │   ├── products_list_screen.dart
│   │   │   │   └── product_form_screen.dart  # Add + Edit
│   │   │   ├── providers/
│   │   │   │   └── products_provider.dart
│   │   │   ├── models/
│   │   │   │   └── product.dart
│   │   │   └── widgets/
│   │   │       ├── product_card.dart
│   │   │       └── image_picker_widget.dart
│   │   ├── customers/
│   │   │   ├── screens/
│   │   │   │   ├── customers_list_screen.dart
│   │   │   │   └── customer_detail_screen.dart
│   │   │   ├── providers/
│   │   │   └── models/
│   │   ├── inventory/
│   │   │   ├── screens/
│   │   │   │   ├── inventory_screen.dart
│   │   │   │   └── stock_adjust_screen.dart
│   │   │   └── providers/
│   │   ├── analytics/
│   │   │   ├── screens/
│   │   │   │   └── analytics_screen.dart
│   │   │   └── widgets/
│   │   │       ├── revenue_chart.dart
│   │   │       └── top_products.dart
│   │   ├── notifications/
│   │   │   ├── screens/
│   │   │   │   └── notifications_screen.dart
│   │   │   └── providers/
│   │   ├── settings/
│   │   │   ├── screens/
│   │   │   │   └── settings_screen.dart
│   │   │   └── providers/
│   │   └── payments/
│   │       ├── screens/
│   │       │   └── mpesa_payment_screen.dart
│   │       └── services/
│   │           └── mpesa_service.dart
│   ├── shared/
│   │   ├── widgets/
│   │   │   ├── loading_indicator.dart
│   │   │   ├── error_view.dart
│   │   │   ├── empty_state.dart
│   │   │   ├── search_bar.dart
│   │   │   └── pull_to_refresh.dart
│   │   └── utils/
│   │       ├── formatters.dart      # Currency, date, etc.
│   │       └── validators.dart
│   └── l10n/                        # Localization
│       ├── app_en.arb
│       └── app_sw.arb               # Swahili
├── test/
├── pubspec.yaml
└── README.md
```

### P2.1: Flutter Project Scaffolding

**Core dependencies** (pubspec.yaml):
```yaml
dependencies:
  flutter:
    sdk: flutter
  # State management
  flutter_riverpod: ^2.x
  riverpod_annotation: ^2.x
  # Networking
  dio: ^5.x                    # HTTP client
  retrofit: ^4.x               # Type-safe API calls
  # Auth
  flutter_secure_storage: ^9.x # Secure token storage
  google_sign_in: ^6.x         # Google OAuth on Android/iOS
  # Navigation
  go_router: ^14.x
  # UI
  flutter_svg: ^2.x
  cached_network_image: ^3.x
  shimmer: ^3.x               # Loading skeletons
  fl_chart: ^0.x               # Charts for analytics
  # Camera & Media
  image_picker: ^1.x
  image_cropper: ^5.x
  flutter_image_compress: ^2.x
  # Push Notifications
  firebase_core: ^3.x
  firebase_messaging: ^15.x
  flutter_local_notifications: ^17.x
  # Local Storage
  hive_flutter: ^1.x          # Offline cache
  # Payments
  url_launcher: ^6.x          # For M-Pesa USSD fallback
  # Utilities
  intl: ^0.x                  # Date/currency formatting
  connectivity_plus: ^6.x     # Network status
  share_plus: ^9.x            # Native share
  package_info_plus: ^8.x     # App version info

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.x
  riverpod_generator: ^2.x
  retrofit_generator: ^8.x
  flutter_lints: ^3.x
  mockito: ^5.x
```

**State management choice: Riverpod**
- Code generation support reduces boilerplate
- Built-in dependency injection
- Excellent for caching API responses
- Testable without widget tree
- Active ecosystem and good documentation

### P2.2: Authentication & Onboarding

**Screens**:
1. **Splash Screen** — Check for stored tokens, auto-login if valid
2. **Welcome Screen** — App value proposition, "Login" and "Create Shop" buttons
3. **Login Screen** — Email + password, **Continue with Google**, "Forgot password" link
4. **MFA Screen** — If MFA enabled, prompt for TOTP code
5. **Register Screen** — Name, email, password, shop name, subdomain picker
6. **Setup Shop** — Upload logo, choose theme, add first product (guided)

**Create-shop API:** Prefer **`POST /api/v1/mobile/auth/register`** (same body as web `POST /api/tenants/register`, mobile `{ success, data }` envelope). Alternatives: call web **`POST /api/tenants/register`** directly. Always use **`GET /api/tenants/check-subdomain`** for live availability. Required fields include **`adminPhone`** / optional **`adminPhoneCountry`**. After **201**, call **`POST /api/v1/mobile/auth/login`** with the same credentials (then MFA if required). Full contract: **`docs/API_MULTI_STORE_CHANGES.md`**.

**Google Sign-In requirements (Shop Owner app)**:
- Add Google Sign-In on both **Login** and **Register** flows (Android + iOS)
- Reuse existing Supabase Google OAuth project configuration already used by web
- Exchange resulting session/tokens through mobile auth flow and keep `accessToken`/`refreshToken` in secure storage
- Support MFA continuation for tenant roles after Google auth (same flow as email login)
- Fallback auth option remains email/password to avoid account lockout

**Google Sign-In (shop owner)**:
- `POST /api/v1/mobile/auth/google` with `{ "idToken": "<Google OIDC id_token>", "accessToken"?: "<optional>" }` — same response shape as password login (`requiresMfa` + `tempSession` for tenants, or direct tokens for landlord). Flutter obtains `idToken` via `google_sign_in`, then calls this endpoint (no browser OAuth redirect).
- Keep using `mfa/verify`, `refresh`, and `logout` after Google login the same as email login.

**Auth state machine**:
```
UNAUTHENTICATED → (login) → CHECKING_MFA
CHECKING_MFA → (no MFA) → AUTHENTICATED
CHECKING_MFA → (has MFA) → AWAITING_MFA
AWAITING_MFA → (verify) → AUTHENTICATED
AUTHENTICATED → (logout/token expired) → UNAUTHENTICATED
```

### P2.3: Core Dashboard Features (MVP)

**Home screen — backend binding (Stitch / Flutter)**:

- **Primary data:** `GET /api/v1/mobile/dashboard/overview` (Bearer token). Response `data` includes `metrics` (products, orders, customers, `revenue.monthlyPaid` for the current calendar month) and `recentOrders` (up to 5). Implement Stitch/design layouts against this JSON; Stitch exports are UI-only and do not call the API.
- **Charts / period trends (if the design needs them):** `GET /api/v1/mobile/dashboard/analytics?days=30` (same auth).
- **Deeper lists** when the user navigates from home: `GET .../dashboard/orders`, `.../products`, etc. (see `docs/API_MULTI_STORE_CHANGES.md` for pagination).
- **Registration subdomain checks** (store creation): `GET /api/tenants/check-subdomain?subdomain=...` — documented in `docs/API_MULTI_STORE_CHANGES.md`.

**Home Screen** (UX checklist — align fields with `overview` above):
- Today's stats: Orders count, Revenue, New customers, Low stock items
- Quick action buttons: View Orders, Add Product, Check Inventory
- Recent orders list (last 5, tappable)
- Stock alert banner if any items are low

**Orders Management**:
- List view with status filter tabs (All, Pending, Processing, Shipped, Delivered, Cancelled)
- Pull-to-refresh
- Order cards showing: order number, customer name, total, status, time ago
- Detail screen: full order info, product list, customer details, status timeline
- Quick action buttons: Update Status, Call Customer, WhatsApp Customer, Share Invoice
- Swipe actions for common status transitions

**Product Management**:
- Grid/list toggle view
- Product cards with image, name, price, stock level
- Quick stock update (tap stock number to edit inline)
- Add product with camera integration:
  1. Tap "Add Product" FAB
  2. Camera opens for product photo
  3. Fill in: Name, Price, Sale Price, SKU, Stock, Category, Description
  4. Save → product live immediately
- Edit product: pre-filled form with existing data
- Bulk stock update screen

**Customer Management**:
- Customer list with search
- Customer detail: order history, total spent, contact info
- Tap phone to call, tap email to email, tap WhatsApp to message

### P2.4: Push Notifications

**Setup**:
1. Firebase project creation (one project for both Android & iOS)
2. FCM integration in Flutter app
3. Device token registration on app launch → POST to `/api/v1/mobile/notifications/register-device`
4. Background message handler for when app is closed
5. Notification tap → deep link to relevant screen (order detail, product, etc.)

**Notification display**:
- In-app notification bell with unread count badge
- Notification list screen
- Toast/snackbar for real-time notifications when app is open
- System notification with sound for high-priority events (new order)

**Notification preferences**:
- Toggle per notification type (new orders, low stock, support, etc.)
- Quiet hours setting
- Sound on/off

### P2.5: M-Pesa Integration In-App

**Two use cases**:

a) **Shop owner paying subscription** (DukaNest billing):
- Display pricing plans
- "Pay with M-Pesa" button
- Initiate STK Push via `/api/v1/mobile/mpesa/initiate`
- Show "Waiting for M-Pesa confirmation..." screen with timer
- Poll `/api/v1/mobile/mpesa/status` for completion
- Success → update subscription status

b) **Receiving customer payments** (already handled by storefront checkout):
- Dashboard shows payment status per order
- Notification when M-Pesa payment confirmed
- Manual payment verification trigger

### P2.6: Offline-First Capabilities

**Strategy**: Cache-first with background sync

**What to cache locally** (using Hive):
| Data | Cache Duration | Update Strategy |
|------|---------------|----------------|
| Products | Until sync | Full refresh on pull-to-refresh |
| Orders (last 50) | 30 minutes | Incremental sync |
| Customers (last 50) | 1 hour | Full refresh on access |
| Dashboard stats | 15 minutes | Refresh on app foreground |
| Tenant/Shop settings | Until changed | Refresh on settings screen |
| Categories | Until sync | Full refresh on access |

**Offline actions queue**:
When offline, allow these actions and queue them:
- Update order status
- Update product stock
- Edit product details
- (Show "pending sync" indicator on queued items)

When connection restored:
- Process queue in order
- Handle conflicts (e.g., order already updated by another user)
- Show sync summary

**Network status handling**:
- Use `connectivity_plus` to detect connection state
- Show subtle banner: "You're offline — changes will sync when connected"
- Disable actions that require real-time data (e.g., M-Pesa payment initiation)

---

## 6. Phase 3 — Flutter Customer Storefront App

> **Priority**: MEDIUM — After shop owner app is stable
> **Estimated effort**: 6-8 weeks
> **Dependencies**: Phase 2 MVP complete + feedback incorporated

### P3.0: Customer Authentication (Google + Email)

Customer app must support both Google and email/password auth from day one.

**Recommended auth options**:
- **Primary**: Sign in with Google (one tap on Android)
- **Fallback**: Email + password
- **Optional later**: Phone OTP

**Customer registration flow**:
1. Open app and choose store/subdomain
2. Tap **Continue with Google** (or email signup)
3. If account exists, sign in immediately
4. If account does not exist, create customer profile automatically
5. Redirect to storefront home with authenticated session

**Implementation notes**:
- Use Supabase OAuth provider for Google
- Store customer role/type in metadata (e.g., `customer`)
- Keep tenant binding strict (customer belongs to selected tenant/store)
- Keep email/password as fallback to avoid lockouts and provider dependency

### P3.1: Dynamic Multi-Tenant Storefront

**Challenge**: Unlike the shop owner app (one tenant per user), the customer app needs to load ANY tenant's store dynamically.

**Approaches**:
- **Option A**: Customer enters store URL/subdomain → app loads that store's branding, products, theme
- **Option B**: App has a "Discover Stores" directory of all DukaNest stores
- **Recommended**: Option A with an optional B — let customers bookmark multiple shops

**Implementation**:
- On first launch: "Enter your shop's address" (e.g., `myshop.dukanest.com`)
- App fetches tenant config (name, logo, theme colors, currency)
- Applies dynamic theming based on tenant's brand colors
- Stores as "favorite shop" for quick return

### P3.2: Product Browsing & Search

- Category navigation (horizontal scrollable categories at top)
- Product grid (2 columns on phone, 3 on tablet)
- Product detail with image gallery (swipeable)
- Search with recent searches and suggestions
- Filters: price range, category, in-stock only
- Sort: newest, price low-high, price high-low, popular

### P3.3: Cart & Checkout

- Persistent cart (synced with server)
- Cart icon with item count badge
- Slide-up cart sheet for quick access
- Checkout flow:
  1. Review cart
  2. Delivery address (saved addresses + add new)
  3. Delivery zone selection + fee display
  4. Payment method: M-Pesa, Cash on Delivery, Payment on Pickup
  5. Order confirmation
- Guest checkout support (no account needed)

### P3.4: Customer Account

- Google Sign-In and email login options in customer account/auth screens
- Customer registration with Google as primary option
- Order history with status tracking
- Order detail with timeline
- Wishlist
- Delivery addresses management
- Reviews (leave review after order delivered)
- Profile management

### P3.5: Deep Linking & Sharing

- Product links: `https://shop.dukanest.com/products/slug` → opens in app or web
- App Links (Android) and Universal Links (iOS)
- Share product to WhatsApp with image + link
- Dynamic links for referral tracking

---

## 7. Phase 4 — Platform Maturity & Growth

> **Priority**: POST-MVP
> **Estimated effort**: Ongoing
> **Dependencies**: Phase 2 + 3 complete

### P4.1: App Store Submission

**Google Play Store**:
- Developer account (KES 2,500 one-time)
- App signing setup
- Store listing: screenshots (at least 4), feature graphic, description (English + Swahili)
- Privacy policy URL
- Data safety questionnaire
- Content rating
- Target: 2-3 day review

**Apple App Store**:
- Developer account ($99/year)
- App Review guidelines compliance
- App Store Connect setup
- Screenshots for all required device sizes
- App privacy details
- Target: 1-7 day review

**Pre-submission checklist**:
- [ ] Crash-free rate > 99%
- [ ] All screens tested on target devices (360px Android, iPhone SE, standard sizes)
- [ ] Offline mode tested
- [ ] M-Pesa flow tested end-to-end
- [ ] MFA flow tested
- [ ] Deep links tested
- [ ] Push notifications tested (foreground, background, terminated)
- [ ] Performance: app launch < 3 seconds
- [ ] Accessibility: screen reader support for core flows

### P4.2: Analytics SDK

- Firebase Analytics in Flutter app
- Custom events: product_added, order_viewed, payment_initiated, etc.
- Screen tracking for user flow analysis
- Crash reporting via Firebase Crashlytics
- Performance monitoring

### P4.3: In-App Support

- Integrate with existing support ticket system
- Chat-like UI for ticket messages
- Image attachment support for tickets
- Push notification on reply

### P4.4: WhatsApp & SMS Integration

**WhatsApp Business API** (or WhatsApp Cloud API):
- Order confirmation messages to customers
- Delivery updates
- "Your order is ready for pickup" notifications
- Shop owner can send promotional messages

**SMS fallback** (Africa's Talking or similar):
- For customers without WhatsApp
- Order status SMS
- M-Pesa payment confirmation SMS

### P4.5: Social Sharing

- Share product to WhatsApp (with image + link)
- Share to Instagram Stories
- Share to TikTok
- Generate product image cards for sharing (branded with shop logo)
- QR code generation for products/shop

---

## 8. Technical Architecture

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENTS                                   │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ Flutter App   │  │ Flutter App   │  │ Next.js Web App      │   │
│  │ (Shop Owner)  │  │ (Customer)    │  │ (Dashboard + Store)  │   │
│  │ Android/iOS   │  │ Android/iOS   │  │ Vercel               │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘   │
│         │                  │                      │               │
│         │ Bearer Token     │ Bearer Token          │ Cookies       │
│         ▼                  ▼                      ▼               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   API LAYER (Next.js)                        │ │
│  │                                                               │ │
│  │  /api/v1/mobile/*          /api/*                            │ │
│  │  (Token auth, versioned,   (Cookie auth, existing routes,    │ │
│  │   mobile-optimized)         web-optimized)                   │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                          │                                        │
│                          ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                 BUSINESS LOGIC LAYER                         │ │
│  │  (Shared service functions used by both web and mobile API) │ │
│  │  src/lib/orders/  src/lib/products/  src/lib/inventory/     │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                          │                                        │
│         ┌────────────────┼────────────────┐                      │
│         ▼                ▼                ▼                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────────┐            │
│  │ Supabase   │  │ Supabase   │  │ External APIs  │            │
│  │ PostgreSQL │  │ Auth       │  │ M-Pesa, FCM,   │            │
│  │ (Prisma)   │  │ (JWT)      │  │ SendGrid, etc. │            │
│  └────────────┘  └────────────┘  └────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### Key Architecture Decisions

1. **Single Backend**: The Next.js app serves both web and mobile. No separate backend needed. Mobile API routes are just a new namespace within the same codebase.

2. **Shared Business Logic**: Extract core logic into `src/lib/services/` (if not already there) so that both `/api/` (web) and `/api/v1/mobile/` routes use the same underlying functions.

3. **Auth Duality**: Cookie-based for web, token-based for mobile. Both verify against the same Supabase auth instance.

4. **Database**: No changes to multi-tenancy model. Flutter app users are still `tenant_admin` or `tenant_staff` with the same `tenant_id` binding.

5. **Monorepo vs Separate Repo**: 
   - **Recommended**: Keep Flutter in a separate repository (`dukanest-app/`)
   - **Reason**: Different toolchains (Dart vs TS), different CI/CD pipelines, different deployment targets. The only shared artifact is the API contract.
   - Alternative: monorepo with `packages/mobile/` but adds complexity to CI

6. **API Contract**: Consider generating TypeScript types from the API and converting to Dart models. Tools like `quicktype` can generate Dart classes from JSON samples.

---

## 9. Database Changes Required

### New Tables

```sql
-- Device tokens for push notifications
CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,                    -- References Supabase auth.users
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  token TEXT NOT NULL,                      -- FCM registration token
  platform VARCHAR(10) NOT NULL,           -- 'android' | 'ios' | 'web'
  device_name VARCHAR(255),                -- e.g., "Samsung Galaxy S24"
  app_version VARCHAR(20),                 -- e.g., "1.0.0"
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(user_id, token)
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id);
CREATE INDEX idx_device_tokens_tenant ON device_tokens(tenant_id);
CREATE INDEX idx_device_tokens_active ON device_tokens(is_active) WHERE is_active = true;

-- Notification preferences per user
CREATE TABLE notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  new_order BOOLEAN DEFAULT true,
  payment_confirmed BOOLEAN DEFAULT true,
  payment_failed BOOLEAN DEFAULT true,
  low_stock BOOLEAN DEFAULT true,
  support_ticket BOOLEAN DEFAULT true,
  subscription_expiring BOOLEAN DEFAULT true,
  quiet_hours_start TIME,                  -- e.g., '22:00'
  quiet_hours_end TIME,                    -- e.g., '07:00'
  sound_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notification_prefs_user ON notification_preferences(user_id);

-- Push notification log (for debugging and analytics)
CREATE TABLE push_notification_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  notification_type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT,
  data JSONB,
  status VARCHAR(20) DEFAULT 'sent',       -- 'sent', 'delivered', 'failed', 'clicked'
  error_message TEXT,
  sent_at TIMESTAMP DEFAULT NOW(),
  delivered_at TIMESTAMP,
  clicked_at TIMESTAMP
);

CREATE INDEX idx_push_log_user ON push_notification_log(user_id);
CREATE INDEX idx_push_log_tenant ON push_notification_log(tenant_id);
CREATE INDEX idx_push_log_sent ON push_notification_log(sent_at);

-- API refresh tokens (if not relying solely on Supabase refresh tokens)
CREATE TABLE mobile_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  device_token_id UUID REFERENCES device_tokens(id) ON DELETE SET NULL,
  refresh_token_hash VARCHAR(255) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  last_active_at TIMESTAMP DEFAULT NOW(),
  ip_address VARCHAR(45),
  user_agent TEXT,
  is_revoked BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mobile_sessions_user ON mobile_sessions(user_id);
CREATE INDEX idx_mobile_sessions_refresh ON mobile_sessions(refresh_token_hash);
```

### Prisma Schema Additions

```prisma
model device_tokens {
  id          String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  user_id     String    @db.Uuid
  tenant_id   String?   @db.Uuid
  token       String
  platform    String    @db.VarChar(10)
  device_name String?   @db.VarChar(255)
  app_version String?   @db.VarChar(20)
  is_active   Boolean?  @default(true)
  last_used_at DateTime? @default(now()) @db.Timestamp(6)
  created_at  DateTime? @default(now()) @db.Timestamp(6)
  updated_at  DateTime? @default(now()) @db.Timestamp(6)
  tenants     tenants?  @relation(fields: [tenant_id], references: [id], onDelete: Cascade)

  @@unique([user_id, token])
  @@index([user_id], map: "idx_device_tokens_user")
  @@index([tenant_id], map: "idx_device_tokens_tenant")
}

model notification_preferences {
  id                     String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  user_id                String    @unique @db.Uuid
  tenant_id              String?   @db.Uuid
  new_order              Boolean?  @default(true)
  payment_confirmed      Boolean?  @default(true)
  payment_failed         Boolean?  @default(true)
  low_stock              Boolean?  @default(true)
  support_ticket         Boolean?  @default(true)
  subscription_expiring  Boolean?  @default(true)
  quiet_hours_start      String?   @db.VarChar(5)
  quiet_hours_end        String?   @db.VarChar(5)
  sound_enabled          Boolean?  @default(true)
  created_at             DateTime? @default(now()) @db.Timestamp(6)
  updated_at             DateTime? @default(now()) @db.Timestamp(6)
  tenants                tenants?  @relation(fields: [tenant_id], references: [id], onDelete: Cascade)

  @@index([user_id], map: "idx_notification_prefs_user")
}
```

---

## 10. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Flutter dev resources** — Finding experienced Flutter developers in the team | High | High | Start with web mobile-first (Phase 1) to buy time. Consider hiring/contracting. |
| **API breaking changes** — Mobile app can't be force-updated like web | High | High | Strict API versioning (`/v1/`). Never remove fields, only add. Deprecation policy. |
| **M-Pesa in-app complexity** — STK Push has timing/callback issues on mobile | Medium | High | Already have production M-Pesa working on web. Reuse same backend logic. Test extensively on real devices. |
| **Offline sync conflicts** — Two users update same order from different devices | Medium | Medium | Last-write-wins for simple fields. Server-side validation. Show conflict resolution UI if needed. |
| **App Store rejection** — Apple may have concerns with payment flows | Medium | Medium | Ensure in-app purchases don't apply (M-Pesa is an external payment method, not in-app purchase). Document this in review notes. |
| **Performance on low-end Android** — Target users have budget phones | High | Medium | Test on low-end devices (2GB RAM). Optimize images, limit animations, lazy load. Flutter is generally performant. |
| **Scope creep** — Trying to replicate all 61 dashboard pages in Flutter | High | High | Strict MVP. Start with 5 core screens. Link to web dashboard for advanced features. |
| **Data usage concerns** — Users may be on expensive mobile data | Medium | Medium | Implement aggressive caching, image compression, offline mode. Show data usage indicators. |

---

## 11. Success Metrics

### Phase 1 (Mobile-First Web)
- [ ] Mobile Lighthouse performance score > 80
- [ ] Dashboard usable at 360px width without horizontal scroll
- [ ] PWA install rate > 10% of mobile dashboard users
- [ ] Reduction in mobile bounce rate by > 20%

### Phase 2 (Flutter Shop Owner App)
- [ ] App launch time < 3 seconds on mid-range Android
- [ ] 50+ shop owners using the app within first month of launch
- [ ] Order management possible entirely from phone
- [ ] Product addition via camera takes < 60 seconds
- [ ] Push notification delivery rate > 95%
- [ ] Crash-free rate > 99%
- [ ] App Store rating > 4.0

### Phase 3 (Flutter Customer App)
- [ ] Cart-to-checkout conversion rate > web baseline
- [ ] M-Pesa payment completion rate > 90%
- [ ] Customer return rate > 30% in first month
- [ ] Average session duration > 3 minutes

### Overall Platform
- [ ] Mobile app drives > 30% of new tenant signups within 6 months
- [ ] "Manage from phone" becomes top-cited reason in user feedback
- [ ] Reduction in support tickets about "can't do X on my phone"

---

## 12. Timeline Summary

```
Week  1-3:  Phase 0 — API Foundation (JWT auth, mobile API namespace, response format)
Week  1-4:  Phase 1 — Mobile-First Web (in parallel with Phase 0)
Week  4-6:  Phase 2.1-2.2 — Flutter scaffolding + auth/onboarding
Week  6-10: Phase 2.3-2.4 — Core dashboard features + push notifications
Week 10-12: Phase 2.5-2.6 — M-Pesa + offline support
Week 12-13: Testing, bug fixes, beta with select shop owners
Week 13-14: Play Store submission (Android first)
Week 14-15: App Store submission (iOS)
Week 16-22: Phase 3 — Customer storefront app
Week 22+:   Phase 4 — Maturity features, WhatsApp, social sharing
```

### Parallel Work Streams

```
WEEK     1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
         ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
Phase 0  ████████████
Phase 1  ████████████████
Phase 2              ████████████████████████████████████
Testing                                          ████████
Launch                                                   ████████
```

---

## Appendix A: Existing API Routes Reference

**Shop-owner mobile (Flutter MVP)** — use `/api/v1/mobile/*` with Bearer auth: `auth/login`, `auth/google`, `auth/register`, `auth/*`, `dashboard/overview`, `dashboard/orders`, `dashboard/products`, `dashboard/customers`, `dashboard/inventory`, `dashboard/sales`, `dashboard/analytics`, `dashboard/settings`, `notifications/*`, `media/upload`, `mpesa/*`. Detail: Postman `StoreFlow_API_Collection.json` and `docs/API_MULTI_STORE_CHANGES.md`.

The following existing API routes contain business logic that should be reused (not duplicated) in the mobile API layer:

**Auth** (19 routes): `/api/auth/tenant/login`, `/api/auth/tenant/register`, `/api/auth/tenant/mfa/*`, `/api/auth/me`, `/api/auth/refresh`, `/api/auth/logout`

**Products**: `/api/products/*`, `/api/products/[id]/variants`, `/api/products/upload`, `/api/products/reviews`

**Orders**: `/api/orders/*`, `/api/orders/[id]/cancel`, `/api/orders/track`

**Customers**: `/api/customers/*`, `/api/customers/[id]/addresses/*`

**Inventory**: `/api/inventory/*`, `/api/inventory/bulk/*`, `/api/inventory/alerts`

**Analytics**: `/api/analytics/*` (overview, sales, revenue, customers, traffic, conversion, products, geographic, realtime, export)

**M-Pesa**: `/api/mpesa/subscription/initiate`, `/api/mpesa/subscription/callback`, `/api/mpesa/subscription/status`

**Settings**: `/api/dashboard/settings`, `/api/settings/currency`, `/api/themes/*`

**Notifications**: `/api/notifications/*`

**Media**: `/api/media/*`, `/api/media/upload`

---

## Appendix B: Key Files Reference

| Purpose | File Path |
|---------|-----------|
| Root layout | `src/app/layout.tsx` |
| Dashboard layout (server) | `src/app/dashboard/layout.tsx` |
| Dashboard layout (client) | `src/components/dashboard/layout-client.tsx` |
| Dashboard sidebar | `src/components/dashboard/sidebar.tsx` |
| Dashboard header | `src/components/dashboard/header.tsx` |
| Storefront layout | `src/app/(tenant-storefront)/layout.tsx` |
| Auth server utilities | `src/lib/auth/server.ts` |
| Auth types | `src/lib/auth/types.ts` |
| Tenant context | `src/lib/tenant-context.ts` |
| Notification types | `src/lib/notifications/types.ts` |
| Web manifest | `public/favicon_io/site.webmanifest` |
| Prisma schema | `prisma/schema.prisma` |
| Next.js config | `next.config.ts` |
| M-Pesa routes | `src/app/api/mpesa/subscription/*.ts` |

---

## 13. Registration Page Simplification

> **Priority**: HIGH — Direct impact on conversion rate
> **Estimated effort**: 1-2 weeks
> **Dependencies**: Supabase Google OAuth provider setup

### Current Registration Flow (10 fields)

The current form at `/register` (`src/app/register/page.tsx`) requires:

1. **Select Plan** (dropdown) — pre-selected to Basic
2. **Store Name** * — text input
3. **Subdomain** * — auto-generated from store name, editable
4. **Your Name** * — text input
5. **Admin Email** * — text input
6. **Password** * — text input (min 8 chars)
7. **Theme** * — dropdown (fetched from `/api/public/themes`)
8. **Business Type** * — dropdown (13 options)
9. **Demo content** — checkbox (default: checked)
10. **Demo attributes** — checkbox (default: checked)

This is **too many fields** for a mobile-first flow. Industry benchmarks show every additional form field reduces conversion by ~7-10%.

### Proposed Simplified Flow (with optional "What are you selling?")

| Field | Change | Rationale |
|-------|--------|-----------|
| Select Plan | **Keep** | Pre-selected to Basic with trial. Still needed. |
| Store Name | **Keep** | Essential. Also auto-generates subdomain. |
| Subdomain | **Keep** (auto-generated, collapsed) | Show as preview text under store name, expandable to edit. |
| Your Name | **Remove from form → collect post-registration** | Google provides display name; for email signups, ask on first dashboard login. |
| Admin Email | **Replaced by Google Sign-In** | Google handles auth entirely. |
| Password | **Replaced by Google Sign-In** | No password to create or remember. |
| Theme | **Remove → auto-install Multipurpose** | Default to Multipurpose theme silently. Can change in dashboard later. |
| Business Type | **Keep** | Determines color scheme and demo content. Important for personalization. |
| What are you selling? | **Add (optional)** | Captures the specific offering within a business type (e.g., business type: Fashion/Clothing, selling: Bags). If empty during store creation, auto-fill with selected `business_type`. |
| Demo content | **Keep enabled by default** | Demo content remains on by default in store creation. Current UI presents this as an informational helper card (no explicit checkbox). |
| Demo attributes | **Remove as separate option → always include with demo content** | Simplify — if demo content is on, include attributes too. |

**Why this field matters**:

- Improves analytics segmentation: track both broad `business_type` and specific `selling` category; expose this breakdown on landlord analytics views.
- Enables dynamic content generation: better demo products/images/copy for niche categories (e.g., ornamental fishes) instead of generic business-type-only defaults.

**Resulting form (what the user sees)**:

```
┌──────────────────────────────────────────┐
│                                          │
│   Create your store (Free 14-day trial)  │
│   Set up in under a minute               │
│                                          │
│   Selected: Basic (14-day trial)   [▼]   │
│                                          │
│   ┌──────────────────────────────────┐   │
│   │                                  │   │
│   │  Store Name *                    │   │
│   │  ┌──────────────────────────┐    │   │
│   │  │ My Awesome Store         │    │   │
│   │  └──────────────────────────┘    │   │
│   │  yourstore.dukanest.com          │   │
│   │                                  │   │
│   │  Business Type *                 │   │
│   │  ┌──────────────────────────┐    │   │
│   │  │ Select your business     │ ▼  │   │
│   │  └──────────────────────────┘    │   │
│   │                                  │   │
│   │  What are you selling?           │   │
│   │  ┌──────────────────────────┐    │   │
│   │  │ e.g. Bags (optional)     │    │   │
│   │  └──────────────────────────┘    │   │
│   │                                  │   │
│   │  We customize your store setup   │   │
│   │                                  │   │
│   │  ┌──────────────────────────┐    │   │
│   │  │  🔵 Continue with Google │    │   │
│   │  └──────────────────────────┘    │   │
│   │                                  │   │
│   │  ── or ──                        │   │
│   │                                  │   │
│   │  Continue with email →           │   │
│   │  (shows email/password fields)   │   │
│   │                                  │   │
│   └──────────────────────────────────┘   │
│                                          │
│   No card required. Cancel anytime.      │
│                                          │
└──────────────────────────────────────────┘
```

### Conversion Impact Analysis

**Expected improvement**: 40-60% increase in registration completion rate.

| Factor | Impact |
|--------|--------|
| Removing 5 fields (name, email, password, theme, attributes) | ~35-50% fewer drop-offs |
| Google Sign-In (one tap on mobile) | ~20-30% faster completion |
| No password to create/remember | Removes top friction point |
| No email verification step blocking access | Immediate access |
| Mobile-optimized (fewer scroll, fewer keyboards) | Better for 83.7% mobile users |
| Trust signal (Google auth is familiar) | Reduces hesitation |

**Industry reference**: Shopify's registration is 3 fields (email, password, store name). Reducing to Google Sign-In + 2 fields would be even simpler.

### Impact on Existing 10 Customers

**Short answer**: Zero disruption. All 10 existing customers will continue working exactly as they are.

**Detailed breakdown**:

| Concern | Impact | Details |
|---------|--------|---------|
| **Existing accounts** | ✅ No change | Their email/password auth continues to work. Supabase supports multiple auth providers simultaneously. |
| **Dashboard login** | ✅ No change | Add "Sign in with Google" as an **additional** option on the login page. Keep email/password login. |
| **Linking accounts** | ✅ Optional | If an existing user wants to switch to Google, they can link their Google account to their existing Supabase account (Supabase supports this natively). |
| **MFA** | ✅ No change | Existing MFA setup stays. Google Sign-In users get Google's own 2FA. |
| **Tenant data** | ✅ No change | User's `tenant_id`, role, and all data remain the same regardless of auth method. |
| **Theme** | ✅ No change | Existing tenants already have their theme installed. The default-to-Multipurpose change only affects **new** registrations. |
| **Name field** | ✅ No change | Existing users already have their name set. New users will be prompted on first dashboard visit. |

### Implementation Plan

### Execution Tracker (mark as we complete)

- [x] Step 1: Enable Google OAuth in Supabase
- [x] Step 2: Update registration page (`src/app/register/page.tsx`)
- [x] Step 3: Update registration API (`src/app/api/tenants/register/route.ts`)
- [x] Step 4: Add profile completion nudges (onboarding checklist + settings fields for `business_type`/`selling`)
- [x] Step 5: Update dashboard login page (`src/app/dashboard/login/tenant-login-form.tsx`)
- [x] Step 6: Google OAuth login compatibility via Supabase session flow
- [x] Customer auth strategy added to roadmap (Google primary + email fallback)
- [x] Customer Google auth API contract drafted (see section below)

### Priority To-Do (deferred until post-free-plan)

- [ ] Configure branded auth domain for Supabase (e.g., `auth.dukanest.com`) to reduce visible `*.supabase.co` in OAuth flows.
  - **Reason deferred**: Supabase free plan limitations / prioritizing core mobile delivery first.
  - **Target phase**: Platform Maturity (post-MVP, after initial mobile launch).
  - **Follow-up tasks**:
    - Enable custom auth domain in Supabase project settings
    - Update Google OAuth redirect URI to custom auth domain callback
    - Re-test Google sign-in for registration and dashboard login

#### Step 1: Enable Google OAuth in Supabase

1. Go to Supabase Dashboard → Authentication → Providers → Google
2. Create OAuth credentials in Google Cloud Console
3. Add authorized redirect URI: `https://<your-supabase-url>/auth/v1/callback`
4. Enable the provider and add Client ID + Client Secret
5. Add `NEXT_PUBLIC_GOOGLE_CLIENT_ID` to environment variables

#### Step 2: Update Registration Page (`src/app/register/page.tsx`)

**Changes**:
- Remove `adminEmail`, `adminPassword`, `adminName` from `formData` state
- Remove `themes` state and theme fetching `useEffect`
- Remove `selectedThemeId` state (hardcode Multipurpose theme ID or slug lookup)
- Add Google Sign-In button using Supabase's `signInWithOAuth`
- Keep "Continue with email" as a collapsed fallback (expands to show email/password)
- Simplify demo content to a single checkbox
- Show subdomain as preview text, not a separate input field

**Google Sign-In flow (implemented)**:
1. User fills in: Store Name, Business Type, and optionally `selling`
2. Clicks "Continue with Google"
3. Before redirecting to Google, save form data to `localStorage`
4. Google auth completes → redirect back to registration page
5. Page restores saved state and validates active Google session
6. User sees Google connection indicator, then taps "Create My Store"
7. Submit to `/api/tenants/register` with Google user info + stored form data, then redirect to dashboard on success

**Store creation fallback rule**:
- If `selling` is empty, set `selling = business_type` before persisting tenant/store onboarding data.

#### Step 3: Update Registration API (`src/app/api/tenants/register/route.ts`)

**Changes**:
- Make `adminPassword` optional in `registerTenantSchema` (not needed for Google auth)
- Make `adminName` optional (can be empty, filled from Google profile or later)
- Add `authProvider` field: `'google' | 'email'`
- When `authProvider === 'google'`:
  - Skip Supabase user creation (user already exists from OAuth)
  - Get user info from Supabase session/token
  - Extract name from Google profile if available
- When no `themeId` provided, auto-select Multipurpose theme:
  ```typescript
  if (!validatedData.themeId) {
    const multipurposeTheme = await prisma.themes.findFirst({
      where: { 
        slug: { in: ['multipurpose', 'grocery'] },
        status: 'active' 
      },
    });
    if (multipurposeTheme) {
      validatedData.themeId = multipurposeTheme.id;
    }
  }
  ```
- Always include demo attributes when demo content is enabled

#### Step 4: Add profile completion nudges

Implemented profile-completion nudges for missing business metadata:
- Added a "Tell us what you are selling" checklist item in getting-started when `selling` is missing
- Added editable `Business Type` and `What are you selling?` fields in Dashboard Settings
- Persists these values into `tenants.data` for analytics + personalization

Optional future enhancement:
- Add a first-visit modal/banner for display name completion

#### Step 5: Update Dashboard Login Page

**File**: `src/app/dashboard/login/tenant-login-form.tsx`

- Add "Sign in with Google" button above the existing email/password form
- Keep email/password as-is (for existing users + fallback)
- Layout: Google button → "or" divider → email/password form

#### Step 6: Update Login API for Google Auth

The Supabase client SDK handles Google OAuth tokens automatically. The existing `requireAuthOrRedirect` in the dashboard layout will work with Google-authenticated users since Supabase treats all providers equally once authenticated.

### Migration Considerations

| Item | Action |
|------|--------|
| Existing email/password login | **Keep forever** — never remove, just de-emphasize visually |
| Customer login/register auth | Add Google Sign-In for customer auth screens, keep email fallback |
| Registration page URL params | Keep `?plan=xxx` support |
| UTM tracking | Keep `utm_source`, `utm_medium`, `utm_campaign` tracking |
| Meta Pixel / GA events | Update event parameters to include `auth_method: 'google' | 'email'` |
| Onboarding email | Still send Day 1 email — Google provides verified email |
| Email-based 2FA | Not needed for Google users (Google handles 2FA). Keep for email/password users. |

### Flutter App Registration

The simplified registration flow is even more important for the Flutter app:

1. **Native Google Sign-In** via `google_sign_in` Flutter package — one tap on Android
2. Form is: Store Name + Business Type + optional "What are you selling?" + "Create Shop" button
3. On Android (785 of your users), Google Sign-In is literally one tap since they're already signed into Google
4. This makes the "create a shop from your phone in under a minute" promise real

### Flutter Customer App Auth

Customer app should mirror the same low-friction approach:

1. **Google Sign-In for customers** as default login/register method
2. **Email/password fallback** for customers who do not use Google
3. **Auto-create customer profile** on first successful Google auth
4. **Tenant-aware auth** so customer sessions are tied to the selected store

### Customer Google Auth API Contract (Draft)

Use this as the backend contract for Flutter customer login/registration.

**Endpoint**
- `POST /api/v1/mobile/auth/customers/google`

**Headers**
- `Authorization: Bearer <supabase_google_access_token>`
- `Content-Type: application/json`

**Request body**

```json
{
  "tenantSubdomain": "mystore",
  "device": {
    "platform": "android",
    "appVersion": "1.0.0",
    "deviceName": "Samsung Galaxy A54"
  }
}
```

**Behavior**
1. Verify bearer token with Supabase (`auth.getUser(token)`).
2. Resolve tenant by `tenantSubdomain`.
3. Look up customer by `(tenant_id, email)`:
   - if exists -> sign in
   - if missing -> create customer profile automatically
4. Return mobile session payload + customer profile.

**Success response (existing customer)**

```json
{
  "success": true,
  "data": {
    "authMethod": "google",
    "isNewCustomer": false,
    "tenant": {
      "id": "tenant_uuid",
      "subdomain": "mystore",
      "name": "My Store"
    },
    "customer": {
      "id": "customer_uuid",
      "email": "customer@example.com",
      "name": "Jane Doe",
      "phone": null
    },
    "session": {
      "accessToken": "jwt",
      "refreshToken": "refresh_token",
      "expiresIn": 3600
    }
  }
}
```

**Success response (new customer auto-created)**

```json
{
  "success": true,
  "data": {
    "authMethod": "google",
    "isNewCustomer": true,
    "customer": {
      "id": "customer_uuid",
      "email": "customer@example.com",
      "name": "Jane Doe"
    }
  }
}
```

**Error responses**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired Google session token"
  }
}
```

```json
{
  "success": false,
  "error": {
    "code": "TENANT_NOT_FOUND",
    "message": "Store not found for provided subdomain"
  }
}
```

```json
{
  "success": false,
  "error": {
    "code": "CUSTOMER_AUTH_DISABLED",
    "message": "Customer authentication is disabled for this store"
  }
}
```

### Flutter Onboarding Starter Pack APIs (Gemini + Nano Banana)

To support niche onboarding from Flutter (e.g., `business_type: Pets`, `selling: Ornamental Fish`) while avoiding unnecessary generation costs, use this API sequence.

#### 1) Pre-check if selling already exists

**Endpoint**
- `POST /api/onboarding/selling-exists`

**Purpose**
- Check whether this `selling` value already exists in tenant onboarding data before calling Gemini/Nano Banana.
- If it exists, reuse existing content strategy and skip expensive generation by default.

**Request body**

```json
{
  "selling": "Ornamental Fish",
  "businessType": "Pets"
}
```

**Response (example)**

```json
{
  "success": true,
  "data": {
    "query": {
      "selling": "Ornamental Fish",
      "sellingKey": "ornamental fish",
      "businessType": "Pets"
    },
    "exists": true,
    "exactMatchCount": 7,
    "matches": [
      {
        "selling": "Ornamental Fish",
        "businessType": "Pets",
        "tenantCount": 7
      }
    ]
  }
}
```

#### 2) Generate starter pack directly (sync mode)

**Endpoint**
- `POST /api/onboarding/starter-pack`

**Key behavior**
- Includes full theme color settings contract (all color keys + descriptions from theme settings).
- Performs built-in selling precheck when `checkSellingExists = true`.
- Skips Gemini call when selling exists unless forced.

**Important request flags**
- `includeGeminiCall` (default `false`)
- `checkSellingExists` (default `true`)
- `forceExternalGeneration` (default `false`)

**Starter pack request example**

```json
{
  "businessType": "Pets",
  "selling": "Ornamental Fish",
  "themeSlug": "grocery",
  "locale": "en-KE",
  "currency": "KES",
  "productsCount": 8,
  "categoriesCount": 5,
  "blogPostsCount": 2,
  "includeGeminiCall": true,
  "checkSellingExists": true,
  "forceExternalGeneration": false
}
```

#### 3) Async job mode for Flutter (recommended)

Use async mode for better mobile UX: create job, poll status, then save generated assets.

##### 3a) Create generation job

**Endpoint**
- `POST /api/onboarding/starter-pack-jobs`

**Response**
- Returns `202` with `jobId` and `statusUrl`.

```json
{
  "success": true,
  "data": {
    "jobId": "uuid",
    "status": "running",
    "statusUrl": "/api/onboarding/starter-pack-jobs/uuid"
  }
}
```

##### 3b) Poll job status

**Endpoint**
- `GET /api/onboarding/starter-pack-jobs/{jobId}`

**Status values**
- `running`
- `success`
- `failed`

When `success`, `result` contains the same payload shape as `/api/onboarding/starter-pack` including:
- `sellingPrecheck`
- `themeConfig.requiredColorSettings`
- `gemini.generatedStarterPack`
- `nanoBanana.jobs`

##### 3c) Save generated image assets metadata

**Endpoint**
- `POST /api/onboarding/starter-pack-jobs/{jobId}/save-assets`

**Request body example**

```json
{
  "assets": [
    {
      "productName": "Fancy Red Cap Oranda",
      "sourcePrompt": "4k studio product photo ...",
      "imageUrl": "https://cdn.example.com/onboarding/red-cap-oranda.png",
      "storagePath": "onboarding/starter-pack/red-cap-oranda.png",
      "width": 2048,
      "height": 2048,
      "mimeType": "image/png",
      "provider": "nano-banana"
    }
  ],
  "persistMode": "tenant-profile",
  "tenantId": "tenant_uuid"
}
```

`persistMode` options:
- `job-only`: save only on job result payload
- `tenant-profile`: also persist under `tenants.data.onboarding_generated_assets`

#### Flutter implementation notes

Recommended flow in app code:

1. Call `/api/onboarding/selling-exists`.
2. If `exists == true`: skip external generation unless merchant explicitly requests a fresh pack.
3. Else call `/api/onboarding/starter-pack-jobs`.
4. Poll `/api/onboarding/starter-pack-jobs/{jobId}` every 2-3 seconds until `success|failed`.
5. On success, call Nano Banana for each `nanoBanana.jobs[*].prompt`.
6. Upload final images to storage, then call `/save-assets`.
7. Render preview and continue to simplified "update prices" flow.

This keeps onboarding fast while controlling AI spend.

---

## 14. Offline-First Strategy for Flutter Apps

> **Priority**: HIGH - major differentiator for DukaNest in low-connectivity markets  
> **Estimated effort**: 3-5 weeks (for robust MVP offline sync)  
> **Dependencies**: Phase 0 mobile API namespace (`/api/v1/mobile/*`) and JWT auth

### Executive Decision: Should we use Firebase for offline?

**Recommendation**: Use Firebase only for push notifications and app telemetry, not as the main offline data backend.

| Capability | Recommended Stack | Why |
|------------|-------------------|-----|
| Core data source of truth | Supabase Postgres + existing Next.js APIs | Existing business rules, pricing, M-Pesa, tenant logic already live here |
| Offline local storage | Flutter local DB (`drift`/SQLite preferred) | Strong local queries, transactions, and queue support |
| Sync orchestration | DukaNest sync endpoints (`/api/v1/mobile/sync/*`) | Full control over conflict rules and idempotency |
| Push notifications | Firebase Cloud Messaging (FCM) | Best-in-class Android/iOS push delivery |
| Crash/performance metrics | Firebase Crashlytics + Analytics (optional) | Faster debugging and mobile reliability monitoring |

If DukaNest uses Firebase Firestore as a second operational backend, you would duplicate rules and create consistency risk around orders, inventory, and payment status. Keep one source of truth: your existing backend.

### Product Positioning (Selling Point)

Market this as:

- "Run your store even without internet."
- "Every edit is saved on your phone instantly."
- "When internet returns, DukaNest syncs automatically."
- "No work is lost in poor network areas."

This aligns directly with your mobile-heavy and connectivity-variable market.

### Offline Scope: What works without internet

#### Safe to support offline in MVP

- Update product name, price, description, and stock
- Create draft products (including photos captured while offline)
- Update order status (with conflict handling)
- Edit store content drafts (banners/text/pages)
- View cached products/orders/customers/dashboard snapshots

#### Must stay online (or online-only confirmation)

- M-Pesa initiation and payment verification
- Subscription activation changes
- First login if no valid token cached
- Domain/SSL operations and other infra operations
- Real-time inventory guarantees at checkout

### Offline Architecture

```text
Flutter App
  ├─ Local DB (SQLite via drift)
  │   ├─ Cached tables: products, orders, customers, inventory, settings
  │   └─ Sync queue table: pending actions
  │
  ├─ Sync Engine
  │   ├─ Push queued actions -> /api/v1/mobile/sync/push
  │   ├─ Pull remote changes -> /api/v1/mobile/sync/changes?cursor=...
  │   └─ Resolve conflicts -> local state + user prompts
  │
  └─ Connectivity Monitor
      ├─ Detect offline/online transitions
      └─ Trigger sync cycles + retry backoff

Next.js Mobile API
  ├─ Idempotent mutation handlers
  ├─ Per-tenant auth + authorization checks
  ├─ Conflict detection with version checks
  └─ Change feed endpoints

Postgres/Supabase
  ├─ Source of truth
  ├─ updated_at/version tracking
  └─ sync operation log (recommended)
```

### Local Data Model (Flutter)

Use `drift` (SQLite) for reliable relational storage and transactions.

Core local tables:

1. `products_local`
2. `orders_local`
3. `customers_local`
4. `inventory_local`
5. `sync_queue`
6. `sync_state`
7. `media_upload_queue`

Suggested `sync_queue` shape:

```json
{
  "id": "uuid",
  "operationType": "UPDATE_PRODUCT",
  "entityType": "product",
  "entityId": "uuid",
  "tenantId": "uuid",
  "payload": { "price": 1200, "stock_quantity": 8 },
  "baseVersion": 12,
  "idempotencyKey": "uuid",
  "status": "pending",
  "retryCount": 0,
  "createdAt": "2026-02-27T10:00:00Z",
  "lastError": null
}
```

### Sync API Contracts (Backend)

Add these under `/api/v1/mobile/sync/`:

#### 1) Push queued actions

- `POST /api/v1/mobile/sync/push`
- Body: batched operations from `sync_queue`
- Response: per-operation result (`applied`, `conflict`, `rejected`)

#### 2) Pull remote changes

- `GET /api/v1/mobile/sync/changes?cursor=<cursor>&limit=200`
- Response: changed entities grouped by type + next cursor

#### 3) Sync status/handshake

- `POST /api/v1/mobile/sync/handshake`
- Client sends app version, last cursor, feature flags
- Server responds with sync policy (limits, retry hints, min version)

Response envelope standard:

```json
{
  "success": true,
  "data": {
    "applied": [],
    "conflicts": [],
    "rejected": []
  },
  "nextCursor": "2026-02-27T10:12:02.403Z#evt_98321"
}
```

### Conflict Resolution Policy

Define explicit rules up front:

| Domain | Policy | UX |
|--------|--------|----|
| Order payment status | Server wins | Inform user local change skipped |
| Order fulfillment status | Transition validation server-side | Show conflict and latest status |
| Inventory stock adjustments | Delta-based + server validation | Ask user to retry with latest quantity |
| Product content edits | Last-write-wins with version check warning | "Updated remotely, review changes" |
| Theme/page drafts | Keep draft + require merge if conflict | Show merge needed banner |

For MVP, avoid deep merge complexity. Use deterministic, auditable rules.

### Retry and Backoff Strategy

- Retry on transient errors (`429`, `5xx`, network timeout)
- Exponential backoff with jitter: `2s, 4s, 8s, 16s, 32s (max)`
- Stop after configurable max retries (e.g., 8), then mark as `failed`
- Keep failed items visible in a "Needs Attention" queue

### Idempotency (Critical)

All mutation operations must include `idempotencyKey`.

Backend should:

- Store processed keys for a retention window (e.g., 24-72h)
- Return previous result when duplicate key arrives
- Prevent duplicate side effects during reconnect storms

### Media Uploads Offline

Pattern:

1. User captures image offline
2. Save local file path + metadata in `media_upload_queue`
3. Attach temporary local URI to product draft
4. On reconnect, upload media first
5. Replace temp URI with real CDN URL
6. Push product update referencing final URL

Constraints:

- Compress images on device before queueing
- Limit queued media size per user/device
- Surface upload progress and failures clearly

### Notifications and Offline

Use FCM for:

- New order notifications
- Payment confirmations
- Low stock alerts
- Support ticket replies

Sync behavior with push:

- On push receipt, trigger lightweight pull sync
- If app is foregrounded and online, refresh relevant entity
- If offline, mark pending and sync on reconnect

### Observability and Reliability Metrics

Track these KPIs:

- Sync success rate (% operations applied)
- Average time-to-sync after reconnect
- Conflict rate by operation type
- Queue depth percentile (P50/P95)
- Failed operation aging (how long unresolved)
- Crash-free sessions during sync cycles

Target initial SLOs:

- 95% queued actions synced within 2 minutes of reconnect
- <2% permanent failure rate on queued operations
- >99% idempotency correctness (no duplicate side effects)

### Security Considerations

- Encrypt tokens in secure storage (`flutter_secure_storage`)
- Never store sensitive payment tokens in local plain text
- Sign all sync requests with JWT bearer token
- Enforce tenant scoping server-side for every operation
- Add server-side rate limits for sync endpoints

### Rollout Plan (Pragmatic)

#### Stage 1 - Read-only offline cache

- Cache products/orders/customers
- Offline viewing only
- No mutation queue yet

#### Stage 2 - Limited write queue

- Enable offline updates for products + stock only
- Add sync queue and retries
- Add "pending sync" badges

#### Stage 3 - Expanded writes

- Add order status updates and content drafts
- Introduce conflict resolution UI

#### Stage 4 - Full offline marketing launch

- Promote "offline mode" as key product feature
- Publish field-tested reliability metrics

### Implementation Checklist

- [ ] Add Flutter local DB schema (`drift`)
- [ ] Create sync queue service and repository layer
- [ ] Implement connectivity listener and sync scheduler
- [ ] Add `/api/v1/mobile/sync/push` endpoint
- [ ] Add `/api/v1/mobile/sync/changes` endpoint
- [ ] Add idempotency key processing backend utility
- [ ] Add conflict result payload format
- [ ] Build "Pending changes" and "Needs attention" screens
- [ ] Add media upload queue flow
- [ ] Add sync analytics and logging
- [ ] Run chaos tests (network flaps, duplicate posts, partial failures)

---

*This document is a living reference. Update it as decisions are made and phases are completed.*
