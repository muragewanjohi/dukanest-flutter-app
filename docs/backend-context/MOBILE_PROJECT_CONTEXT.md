# Mobile Project Context (Flutter)

Use this document as the bootstrap context for the new Flutter repository.

## Goal

Build the **Flutter Shop Owner App (MVP)** for DukaNest using the existing backend mobile APIs under:

- `/api/v1/mobile/*`

The app should let shop owners manage core operations from mobile (dashboard, orders, products, customers, inventory, notifications, settings), with Google Sign-In and M-Pesa support.

## Primary Reference Docs To Copy

Copy these files into the new Flutter repo (for example under `docs/backend-context/`):

- `docs/mobile-first-flutter-roadmap.md`
- `docs/API_DOCUMENTATION.md`
- `docs/ARCHITECTURE.md`
- `README.md`
- `postman/StoreFlow_API_Collection.json`
- `postman/StoreFlow_Environment.json`
- `postman/README.md`

Payments-specific (recommended):

- `docs/mpesa-subscription-integration-guide.md`
- `docs/mpesa-integration-quick-start.md`
- `docs/mpesa-stk-push-troubleshooting.md`
- `docs/mpesa-callback-url-setup.md`

## Current Backend Status (March 2026)

Completed in web/backend:

- Mobile API namespace and endpoints (`/api/v1/mobile/*`)
- Mobile auth endpoints:
  - `login`, `refresh`, `logout`, `mfa/status`, `mfa/send-code`, `mfa/verify`, `forgot-password`
- Mobile dashboard endpoints:
  - `overview`, `products`, `orders`, `customers`, `inventory`, `sales`, `analytics`, `settings`
  - `settings/delete-account` (POST, Bearer) — same soft-delete as web dashboard; body `{ "confirmation": "DELETE {subdomain}", "reason"?: string }`
- Mobile notifications endpoints:
  - `list`, `register-device`, `preferences`
- Mobile media upload endpoint
- Mobile M-Pesa endpoints:
  - `initiate`, `status`
- Standard response envelope:
  - `{ success, data, error, pagination }`
- PWA + push/web registration baseline (web side)

## Auth Requirements For Flutter

- Use bearer token auth with `Authorization: Bearer <accessToken>`.
- Store `accessToken` + `refreshToken` securely (`flutter_secure_storage`).
- Implement refresh-token flow and auto-retry on `401`.
- Support MFA continuation for tenant roles after login.
- Include **Google Sign-In** in Flutter:
  - Login screen and onboarding/register path.
  - Reuse Supabase Google OAuth configuration already used by web.
  - Keep email/password as fallback.

## Suggested Mobile Auth Flow

1. User signs in with email/password OR Google.
2. App receives temporary/full tokens.
3. If MFA required, app routes to MFA code verification.
4. On success, app stores tokens securely.
5. API client attaches bearer token to all `/api/v1/mobile/*` requests.
6. On token expiry, app calls refresh endpoint and retries.

## API Contract Rules

- Success response:
  - `success: true`
  - `data: ...`
  - optional `pagination`
- Error response:
  - `success: false`
  - `error: { code, message, details? }`
- Treat all network parsing through a shared response parser.

## Flutter MVP Scope (Phase 2)

- Onboarding + auth
- Dashboard home
- Orders list + detail + status actions
- Products list + add/edit (camera-first media)
- Customers list + detail
- Inventory views/adjust
- Notifications list + settings
- Settings screen (including optional “delete my store” via `POST .../settings/delete-account`)
- M-Pesa status/initiate screens for subscription flow

## Required Flutter Dependencies (Baseline)

- State: `flutter_riverpod`
- Networking: `dio`, `retrofit`
- Auth storage: `flutter_secure_storage`
- Navigation: `go_router`
- Media: `image_picker`, `flutter_image_compress`
- Push: `firebase_messaging`, `flutter_local_notifications`
- Connectivity: `connectivity_plus`
- Google auth: `google_sign_in`

## Non-Functional Requirements

- Mobile-first UI optimized for 360px widths
- 44x44 minimum touch targets
- No horizontal scrolling on key flows
- Loading and error states for every async screen
- Offline-ready caching strategy for core lists

## Recommended Repo Setup (New Flutter Project)

- `docs/backend-context/` for copied docs/Postman contracts
- `lib/core/` for API/auth/storage utilities
- `lib/features/` domain modules (orders/products/customers/etc.)
- `lib/shared/` reusable widgets/utilities

## First Sprint Checklist

- [ ] Import copied docs and Postman files
- [ ] Implement API client + auth interceptor
- [ ] Implement token refresh + secure storage
- [ ] Implement login (email/password) + MFA
- [ ] Implement Google Sign-In path
- [ ] Verify `overview`, `orders`, `products` endpoints in app
- [ ] Register mobile device token for notifications

