# Flutter shop-owner app: required mobile APIs

This document lists **REST APIs the Flutter tenant app needs** to replace demo/local-only data. It assumes the mobile namespace **`/api/v1/mobile`** (see `AppConfig.apiBaseUrl` in the app) and **Bearer authentication** on protected routes unless noted otherwise.

Companion docs: [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md) (pagination, registration, store context), [FLUTTER_TENANT_WEB_PARITY_CHECKLIST.md](./FLUTTER_TENANT_WEB_PARITY_CHECKLIST.md).

---

## Conventions

| Item | Detail |
|------|--------|
| **Base URL (mobile)** | e.g. `https://<host>/api/v1/mobile` — paths below are relative to this unless written as absolute `/api/...`. |
| **Auth** | `Authorization: Bearer <accessToken>` after login/MFA. |
| **Success envelope** | Prefer `{ "success": true, "data": { ... } }` consistent with existing mobile routes. |
| **Errors** | `{ "success": false, "error": { "code", "message", "details?" } }`. |
| **Tenant scope** | One store per user; session resolves `tenant_id` (no `X-Tenant-Id` in the current product phase per API_MULTI_STORE_CHANGES). |

### Quick advice for Flutter teams

1. **Base URL** — Use one host for all calls (e.g. `https://www.dukanest.com`). Mobile routes live under **`/api/v1/mobile/...`**. Public registration helpers use **`/api/tenants/...`** (see [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md)).
2. **Responses** — Parse **`success` + `data`** (and **`pagination`** on list endpoints). On errors use **`error.code`** / **`error.message`**.
3. **New store has no products** — Registration must send **`includeDemoContent: true`**, **`businessType`**, **`selling`**, etc. Same rule for **`POST /api/v1/mobile/auth/register`** and **`POST /api/tenants/register`** (see starter-content checklist in API_MULTI_STORE_CHANGES).
4. **Cold start** — Call **`GET /auth/me`** with the access token to restore **`user`** + **`tenant`** context; use **`POST /auth/refresh`** when the access token expires.

---

## StoreFlow backend: mobile routes implemented in this repo

These paths are relative to **`/api/v1/mobile`** (full URL example: `https://www.dukanest.com/api/v1/mobile/auth/login`). Auth is **Bearer** unless noted.

| Method | Path | Notes |
|--------|------|--------|
| POST | `/auth/login` | Email/password; MFA flow per response |
| POST | `/auth/register` | Same body as tenant register; mobile `{ success, data }` envelope |
| POST | `/auth/google` | Google `idToken` (+ `accessToken` if required) |
| POST | `/auth/refresh` | Rotate session |
| POST | `/auth/logout` | Invalidate server-side session if applicable |
| POST | `/auth/forgot-password` | Password reset request |
| POST | `/auth/mfa/send-code` | Send MFA code |
| POST | `/auth/mfa/status` | MFA status |
| POST | `/auth/mfa/verify` | Complete MFA |
| GET | `/auth/me` | Session restore: `user` + `tenant` (dashboard roles); landlord returns `tenant: null` |
| GET | `/dashboard/overview` | Metrics + recent orders *(checklist: use **`/dashboard/getting-started`**) |
| GET | `/dashboard/getting-started` | On **`items[]`** with `id`, `completed`, `progressPercent`, `storeUrl`, … |
| POST | `/dashboard/getting-started` | Body `{ "action": "preview_done" \| "share_done" }` → persists flags (see below) |
| GET | `/dashboard/orders` | Paginated; see API_MULTI_STORE_CHANGES |
| GET | `/dashboard/orders/:id` | Order detail + line items |
| PATCH | `/dashboard/orders/:id` | Same as web `PUT /api/orders/:id`: `status` and/or `payment_status`, optional `notes`, tracking |
| GET | `/dashboard/products` | Paginated; see API_MULTI_STORE_CHANGES |
| POST | `/dashboard/products` | Create product (`createProductSchema`); respects plan limits + `canEditData` |
| GET | `/dashboard/products/:id` | Product + variants |
| PUT/PATCH | `/dashboard/products/:id` | Update (`updateProductSchema`) |
| DELETE | `/dashboard/products/:id` | Delete + cache invalidation |
| GET | `/dashboard/customers` | Paginated list + `search` |
| GET | `/dashboard/customers/:id` | Profile + order aggregates |
| GET | `/dashboard/categories` | List (`parent_id`, `status`, `include_children`) |
| POST | `/dashboard/categories` | Create |
| GET | `/dashboard/categories/:id` | Detail |
| PUT/PATCH | `/dashboard/categories/:id` | Update |
| DELETE | `/dashboard/categories/:id` | Delete (guards: children, products) |
| GET | `/dashboard/delivery-zones` | List zones (`items`) |
| POST | `/dashboard/delivery-zones` | Create — **`tenant_admin` only** |
| PUT/PATCH | `/dashboard/delivery-zones/:id` | Update — **`tenant_admin` only** |
| DELETE | `/dashboard/delivery-zones/:id` | Delete — **`tenant_admin` only** |
| GET | `/dashboard/blogs` | List + pagination (`blogQuerySchema`) |
| POST | `/dashboard/blogs` | Create |
| GET | `/dashboard/blogs/:id` | Detail |
| PUT/PATCH | `/dashboard/blogs/:id` | Update |
| DELETE | `/dashboard/blogs/:id` | Delete |
| GET | `/dashboard/analytics` | Optional `?days=` (1–365, default **30**) |
| GET | `/dashboard/sales` | **List** promotions/sales (paginated) |
| POST | `/dashboard/sales` | Create sale |
| GET | `/dashboard/sales/:id` | Sale + `product_sales` |
| PUT/PATCH | `/dashboard/sales/:id` | Update |
| DELETE | `/dashboard/sales/:id` | Delete |
| GET | `/dashboard/inventory` | Paginated stock list; `search`, `low_stock_only`, `threshold`, etc. (see `inventoryQuerySchema`) |
| GET | `/dashboard/settings` | Read store identity, currency, shipping, payment, tax snapshot (`tenant_admin` + `tenant_staff`) |
| PATCH | `/dashboard/settings` | Partial update; body mirrors GET `data` shape (nested `store`, `currency`, `shipping`, `payment`, `tax`); **`tenant_admin` only** |
| POST | `/dashboard/settings/delete-account` | Account deletion |
| GET | `/notifications/list` | In-app notifications |
| POST | `/notifications/register-device` | FCM token |
| GET | `/notifications/preferences` | |
| PUT | `/notifications/preferences` | |
| POST | `/media/upload` | Tenant media (product/logo, etc.) |
| POST | `/mpesa/initiate` | M-Pesa flow |
| GET | `/mpesa/status` | Poll payment status |

**Public (not under `/api/v1/mobile`):**

| Method | Path |
|--------|------|
| GET | `/api/tenants/check-subdomain` |
| POST | `/api/tenants/register` |
| POST | `/api/v1/mobile/auth/register` | *(recommended mobile envelope)* |

**Still out of scope on mobile (use web tenant APIs if needed):** storefront **pages/hero** CRUD, **order packing-slip / invoice** download, **attributes/facets** CRUD, dedicated **`PATCH /dashboard/onboarding-progress`** (use **`/dashboard/getting-started`** instead). **CMS:** blogs are covered; **theme page builder** is not.

**Settings write parity:** `PATCH /dashboard/settings` updates `static_options` + `tenants` (`name`, `contact_email`, `data.business_type` / `data.selling`) for fields the mobile GET exposes. At least one of cash or M-Pesa must remain enabled if the client sends `payment` fields.

---

## Progress steps (Getting Started checklist)

The home dashboard shows a **Getting Started** carousel until all steps are done.

### How onboarding steps are persisted (authoritative)

StoreFlow does **not** use a separate “onboarding table”. Completion is computed from tenant **`static_options`** and real domain data, same as the web dashboard (`buildGettingStartedProgress` in `src/lib/onboarding/getting-started-progress.ts`).

| Step id (API) | Becomes `completed: true` when |
|---------------|--------------------------------|
| `product` | At least one **active** product with `created_by` set (matches web count query). |
| `preview` | `static_options.getting_started_previewed_store === 'true'` — set via **`POST .../dashboard/getting-started`** with `{ "action": "preview_done" }`. |
| `share` | `static_options.getting_started_shared_link === 'true'` — **`POST`** with `{ "action": "share_done" }`. |
| `contact_phone` | `store_phone` static option non-empty (`PATCH /dashboard/settings` → `store.phone`). |
| `payment` | Cash enabled and/or M-Pesa enabled **with** a configured M-Pesa number/till/paybill (see same lib). |
| `delivery` | `shipping_enabled` and either delivery zones exist **or** flat rate amount set. |
| `logo` | `store_logo` static option set (e.g. via media + web settings; extend mobile settings if needed). |

**Flutter:** Call **`GET /api/v1/mobile/dashboard/getting-started`** for the checklist (mobile envelope). After the user previews the storefront or shares the link, call **`POST`** on the same path with the actions above so **web and app stay in sync**.

**Legacy app behavior:** If the client still reads checklist only from **`GET .../dashboard/overview`**, note that the **mobile overview route does not embed steps yet** — switch to **`GET .../getting-started`** or merge both responses in the app.

**Optional client keys:** If your Flutter code uses `preview_store` / `share_store` / `sms`, map them to server ids **`preview`** / **`share`** / **`contact_phone`**.

### Canonical step keys

Align server keys with the app’s `DashboardOnboardingStepKeys` (Flutter: `lib/features/dashboard/providers/dashboard_local_onboarding_provider.dart`):

| Key | Meaning |
|-----|---------|
| `product` | First product added / catalog ready |
| `preview_store` | Storefront previewed (or infer from analytics/events) |
| `share_store` | Store link shared/copied (or infer) |
| `sms` | Order/SMS alerts configured |
| `payment` | Checkout/payments configured |
| `shipping` | Shipping/delivery configured |
| `logo` | Store logo present |

Servers may use aliases in stored data if the overview mapper normalizes them (the app also accepts fuzzy `title`-based routing for some legacy rows).

### A. Embedded in dashboard overview (minimum)

**`GET /dashboard/overview`** (existing) should include a stable checklist payload the app already understands, for example under one of:

- `data.gettingStarted.steps`
- `data.getting_started.steps`
- `data.onboarding.steps`
- `data.setupChecklist.items`
- `data.setup_checklist.items`
- or top-level `data.onboardingSteps` **`/`** `data.checklist`

Each step object should be mappable to:

| Field | Type | Notes |
|-------|------|--------|
| `title` | string | Required for display |
| `completed` or `done` | boolean | **Authoritative** completion |
| `key` or `id` or `stepKey` | string | Prefer **`key`** matching the canonical keys above |
| `description` / `subtitle` | string | Optional |
| `durationHint` / `duration_hint` | string | Optional |
| `actionLabel` / `action_label` / `cta` | string | Optional |

**Inference rule (recommended):** When the user performs a real action (saves payments, shipping, uploads logo, creates a product), **update tenant/store state** so the **next overview response** shows `completed: true` for that key—even if no separate “mark step” call exists.

### B. Dedicated progress API (recommended for explicit updates)

If you want the client to **mark** a step without waiting for domain aggregates to refresh:

| | |
|--|--|
| **Method / path** | `PATCH /dashboard/onboarding-progress` *(proposed)* |
| **Auth** | Bearer |
| **Body (example)** | `{ "completeStepKey": "payment" }` or `{ "steps": { "payment": true, "shipping": true } }` |
| **Response** | `{ "success": true, "data": { "steps": [ ... ] } }` — full merged list or minimal acknowledgements |
| **Validation** | Reject unknown keys; optionally ignore already-completed idempotently |

Alternate naming (pick one and document in OpenAPI):  
`PATCH /dashboard/getting-started`, `POST /dashboard/setup-checklist/complete`, etc.

### C. Optional read-only snapshot

For lighter payloads if overview grows large:

| | |
|--|--|
| **Method / path** | `GET /dashboard/onboarding-progress` *(proposed)* |
| **Auth** | Bearer |
| **Response** | Same `steps[]` shape as embedded in overview |

---

## API inventory

Legend: **Exists** = available on the StoreFlow mobile API (and ideally wired in Flutter `ApiClient`); **Required** = still missing on mobile API and/or client; **Partial** = list or subset only, or client still mocks some flows.

### Auth & session

| Status | Method | Path | Purpose |
|--------|--------|------|---------|
| Exists | POST | `/auth/login` | Email/password (MFA challenge as per server) |
| Exists | POST | `/auth/register` | Mobile registration envelope (see API_MULTI_STORE_CHANGES) |
| Parity | POST | `/auth/google` | Google id token exchange |
| Parity | * | `/auth/mfa/*`, refresh, logout | As implemented server-side |
| Exists | GET | `/auth/me` | Restore session: `data.user`, `data.tenant` (tenant roles); landlord gets `tenant: null` |

Public (non-mobile base): `GET /api/tenants/check-subdomain`, `POST /api/tenants/register` — see API_MULTI_STORE_CHANGES.

---

### Dashboard & analytics

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/overview` | Metrics + recent orders | `DashboardScreen` |
| Exists | GET | `/dashboard/analytics` | Metrics for last `days` (query `days`, 1–365, default 30) | `AnalyticsScreen` |

---

### Orders

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/orders` | Paginated list, `search`, `status`, `payment_status` | `OrdersListScreen` |
| Exists | GET | `/dashboard/orders/:id` | Order detail | `OrderDetailScreen` |
| Exists | PATCH | `/dashboard/orders/:id` | Status / payment; `notes` → order `message` | Order detail actions |
| Partial | POST | `/dashboard/orders/:id/notes` | Prefer **PATCH** with `notes` | Order notes |
| Optional | GET | `/dashboard/orders/:id/packing-slip` | PDF or print URL | Print packing slip |

---

### Products

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/products` | Paginated list | `ProductsListScreen` |
| Exists | GET | `/dashboard/products/:id` | Detail + variants | `ProductEditorScreen` |
| Exists | POST | `/dashboard/products` | Create | `ProductEditorScreen` |
| Exists | PUT/PATCH | `/dashboard/products/:id` | Update (partial fields) | `ProductEditorScreen` |
| Exists | DELETE | `/dashboard/products/:id` | Delete | `ProductsListScreen` |
| Exists | POST | `/media/upload` | Tenant media upload | Editors, store identity |

---

### Customers

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/customers` | Paginated list + `search` / `email` / sort (see validation) | `CustomersListScreen` |
| Exists | GET | `/dashboard/customers/:id` | Profile + spent / counts | Customer detail |

---

### Settings / store configuration

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/settings` | Read snapshot (`tenant_admin` + `tenant_staff`) | `SettingsScreen`, dedicated editors |
| Exists | PATCH | `/dashboard/settings` | Partial update — **`tenant_admin` only**; body keys mirror GET (`store`, `currency`, `shipping`, `payment`, `tax`) | `SettingsScreen` |
| Partial | GET/PATCH | `/dashboard/settings` | **Store identity / tax / payments / shipping** fields exposed in mobile snapshot | `StoreIdentityScreen`, `TaxSettingsScreen`, `PaymentSettingsScreen`, `ShippingDeliveryScreen` |
| Exists | GET/POST | `/dashboard/delivery-zones` | List + create (**admin** for POST) | `ManageZonesScreen` |
| Exists | PUT/PATCH/DELETE | `/dashboard/delivery-zones/:id` | **Admin only** | `DeliveryZoneEditorScreen` |
| Parity | POST | `/dashboard/settings/delete-account` | Account deletion (see parity checklist) | `StoreIdentityScreen` |

Exact split between one coarse `PATCH /dashboard/settings` vs fine-grained routes can follow the web dashboard’s API shape; the Flutter app mainly needs **real read/write** instead of demo snackbars.

---

### Categories & attributes (catalog structure)

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/categories` | List (`include_children`, `parent_id`, `status`) | `CategoriesManagementScreen` |
| Exists | POST | `/dashboard/categories` | Create | `CategoryEditorScreen` |
| Exists | PUT/PATCH | `/dashboard/categories/:id` | Update | `CategoryEditorScreen` |
| Exists | DELETE | `/dashboard/categories/:id` | Delete (with guards) | Management screen |
| Required | GET | `/dashboard/attributes` or `/dashboard/facets` | List attributes/facets | `AttributesManagementScreen` |
| Required | POST/PATCH/DELETE | *(attribute routes)* | CRUD | `AttributeEditorScreen` |

---

### Content & CMS (lower priority for MVP)

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/blogs` | List + pagination | `ContentManagementScreen` |
| Exists | POST | `/dashboard/blogs` | Create | `BlogPostEditorScreen` |
| Exists | GET | `/dashboard/blogs/:id` | Detail | `BlogPostEditorScreen` |
| Exists | PUT/PATCH | `/dashboard/blogs/:id` | Update | `BlogPostEditorScreen` |
| Exists | DELETE | `/dashboard/blogs/:id` | Delete | `BlogPostEditorScreen` |
| Required | GET/PATCH | pages / hero routes | Storefront page & hero | `PageEditorScreen`, `HeroSectionEditorScreen` |

---

### Promotions / sales

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/sales` | Paginated list + filters | Sales list |
| Exists | POST | `/dashboard/sales` | Create | `SalesEditorScreen` |
| Exists | GET | `/dashboard/sales/:id` | Detail + products | `SalesEditorScreen` |
| Exists | PUT/PATCH | `/dashboard/sales/:id` | Update | `SalesEditorScreen` |
| Exists | DELETE | `/dashboard/sales/:id` | Delete | `SalesEditorScreen` |

---

### Notifications

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/notifications` | In-app notification list | `NotificationsScreen` |
| Exists | POST | `/notifications/register-device` | FCM token registration | Push setup |

**Note:** Remove or gate **demo list fallback** on error once the API is reliable.

---

## Implementation sequencing (suggested)

1. **Overview + progress steps** — Ensure `GET /dashboard/overview` returns checklist with authoritative `completed` flags; add **`PATCH /dashboard/onboarding-progress`** if inference is insufficient.
2. **Settings bundle** — Single `GET/PATCH /dashboard/settings` (or split resources) so Store identity, Payments, Shipping, Tax persist.
3. **Order mutations + product PATCH/DELETE** — Complete operational flows from list/detail screens.
4. **Customers** — Replace `demo_data`.
5. **Categories & attributes** — Replace in-memory repositories.
6. **Analytics, CMS, Sales** — Align with web surface area.

---

## References in repo

| Resource | Location |
|----------|----------|
| Mobile API client (current methods) | `lib/core/api/api_client.dart` |
| Overview + checklist parsing | `lib/features/dashboard/screens/dashboard_screen.dart` |
| Local step completions (until server is source of truth) | `lib/features/dashboard/providers/dashboard_local_onboarding_provider.dart` |
| Pagination contract (orders/products) | [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md) |

---

## What changed in this document (summary)

Compared to an earlier “wishlist-only” version, this file now includes:

1. **StoreFlow backend table** — A concrete inventory of **implemented** mobile routes (`/auth/*`, `/dashboard/*`, `/notifications/*`, `/media/upload`, `/mpesa/*`, etc.) relative to `/api/v1/mobile`.
2. **Getting Started / progress** — Documents **server truth** via `static_options` + domain checks (`buildGettingStartedProgress`), step ids (`product`, `preview`, `share`, `contact_phone`, `payment`, `delivery`, `logo`), and explicit **`GET` + `POST /dashboard/getting-started`** (actions `preview_done`, `share_done`). Notes that **mobile overview may not embed steps** yet and suggests Flutter call **`/getting-started`** instead of relying only on overview.
3. **Key mapping** — API ids vs optional Flutter aliases (`preview_store` → `preview`, etc.).
4. **Inventory tables** — Per-area **Exists / Partial / Required** with Flutter screen names; blogs, sales, delivery-zones, inventory, and customers marked where the backend exposes them.
5. **Settings** — `GET`/`PATCH /dashboard/settings` shape and **tenant_admin** constraints for writes.
6. **Categories vs attributes** — Categories routes marked **Exists** on API; **attributes/facets** still called out as **out of scope on mobile** in the backend table (line ~97) while the inventory still lists attribute routes as **Required** for Flutter — intentional tension until a mobile facet API ships.

---

## Flutter `ApiClient` vs this document

The **backend** column in § “StoreFlow backend: mobile routes implemented in this repo” describes what the StoreFlow server exposes. The **Flutter app** only implements a **subset** in `lib/core/api/api_client.dart` today:

| Implemented in Flutter | Not in `ApiClient` yet (examples) |
|------------------------|-----------------------------------|
| `POST /auth/login`, `POST /auth/register` | `GET /auth/me`, refresh, MFA routes, Google |
| `GET /dashboard/overview` | `GET/POST /dashboard/getting-started`, `GET /dashboard/analytics` |
| `GET /dashboard/orders`, `GET /dashboard/orders/:id` | `PATCH /dashboard/orders/:id` |
| `GET /dashboard/products`, `GET/POST/PUT .../products/:id` | `DELETE /dashboard/products/:id` |
| `GET /notifications` (path must match server: see note below), `POST /notifications/register-device` | `/notifications/list`, preferences, customers, categories, settings, blogs, sales, zones, `POST /media/upload`, etc. |

**Product editor** — Loads/saves via **product GET/PUT** with API-populated fields (not the old static SKU demo seed).

**Categories / attributes** — **Categories**: server routes exist per this doc, but **`CategoriesRepository`** is still **in-memory** in Flutter. **Attributes**: still **in-memory** (`AttributesRepository`); align with backend “facets” when the mobile API is finalized.

**Notifications path** — This doc lists **`GET /notifications/list`** in the big table but **`GET /notifications`** in the inventory. Confirm the live StoreFlow route and use the same path in `ApiClient` + notifications screen.
