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
5. **After store registration** — On **`201`** from **`POST /auth/register`**, read **`data.loginUrl`** (see [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md) § *Post-registration redirect*). Open it in a browser or in-app WebView when you want the merchant to use the web dashboard login on the tenant host. For an in-app API-only session, ignore **`loginUrl`** and call **`POST /auth/login`** with the same email/password as usual.

---

## StoreFlow backend: mobile routes implemented in this repo

These paths are relative to **`/api/v1/mobile`** (full URL example: `https://www.dukanest.com/api/v1/mobile/auth/login`). Auth is **Bearer** unless noted.

| Method | Path | Notes |
|--------|------|--------|
| POST | `/auth/login` | Email/password; MFA flow per response |
| POST | `/auth/register` | Same body as tenant register; **`data.loginUrl`** points at tenant **`/dashboard/login`** after **201** — see [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md) § *Post-registration redirect* |
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
| DELETE | `/dashboard/products/demo` | Remove active demo products; ordered demo products are archived |
| GET | `/dashboard/products/:id` | Product + variants |
| PUT/PATCH | `/dashboard/products/:id` | Update (`updateProductSchema`) |
| DELETE | `/dashboard/products/:id` | Delete + cache invalidation |
| GET | `/dashboard/products/:id/variants` | List variants for product |
| POST | `/dashboard/products/:id/variants` | Create variant (stock per variant) |
| PUT/PATCH | `/dashboard/products/:id/variants/:variantId` | Update variant |
| DELETE | `/dashboard/products/:id/variants/:variantId` | Delete variant |
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
| GET | `/dashboard/attributes` | List attributes + values (`data.items`) |
| POST | `/dashboard/attributes` | Create attribute |
| GET | `/dashboard/attributes/:id` | Detail + values |
| PUT/PATCH | `/dashboard/attributes/:id` | Update (body must include ≥1 of `name`, `slug`, `type`) |
| DELETE | `/dashboard/attributes/:id` | Delete (cascades values) |
| GET | `/dashboard/attributes/:id/values` | List values for attribute |
| POST | `/dashboard/attributes/:id/values` | Create value (`value`, optional `color_code` `#RRGGBB`) |
| PUT/PATCH | `/dashboard/attributes/:id/values/:valueId` | Update value |
| DELETE | `/dashboard/attributes/:id/values/:valueId` | Delete value |
| GET | `/dashboard/pages` | Paginated list (`data.items`, `pagination`) — query like web `pageQuerySchema` |
| POST | `/dashboard/pages` | Create page (`createPageSchema`); plan limit via `canCreatePage` |
| GET | `/dashboard/pages/:id` | Full page row (incl. `content`, `published_content`) |
| PUT/PATCH | `/dashboard/pages/:id` | Update page (`updatePageSchema`); revalidates storefront paths |
| DELETE | `/dashboard/pages/:id` | Delete; **blocked** for slugs `home`, `about`, `contact` |
| GET | `/dashboard/analytics` | Optional `?days=` (1–365, default **30**) |
| GET | `/dashboard/analytics/pnl` | Profit & Loss summary (`start_date`, `end_date`) |
| GET | `/dashboard/expense-categories` | List tenant expense categories |
| POST | `/dashboard/expense-categories` | Create tenant expense category (`name`, optional `slug`, `description`) |
| GET | `/dashboard/expense-categories/:id` | Get expense category |
| PATCH | `/dashboard/expense-categories/:id` | Update expense category |
| DELETE | `/dashboard/expense-categories/:id` | Delete expense category if unused |
| GET | `/dashboard/expenses` | Paginated expense ledger list |
| POST | `/dashboard/expenses` | Create expense (`category_id` or existing category slug) |
| PATCH | `/dashboard/expenses/:id` | Update expense, including `category_id`/category |
| DELETE | `/dashboard/expenses/:id` | Delete expense |
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

**Still out of scope or optional:** **order packing-slip / invoice** download, dedicated **`PATCH /dashboard/onboarding-progress`** (use **`/dashboard/getting-started`** instead). **CMS:** blogs and **pages** (page builder JSON / hero via `home` page `content`) are on mobile; **theme template** switching is not a dedicated mobile route. **Facets** in this codebase map to **attributes** + **attribute values** (no separate `/facets` path).

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
| Exists | POST | `/auth/register` | Mobile registration envelope; **`data.loginUrl`** (tenant login) — see API_MULTI_STORE_CHANGES *Post-registration redirect* |
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
| Exists | GET | `/dashboard/products/:id/variants` | List variants | Variant list/editor |
| Exists | POST | `/dashboard/products/:id/variants` | Create variant | Variant list/editor |
| Exists | PUT/PATCH | `/dashboard/products/:id/variants/:variantId` | Update variant | Variant list/editor |
| Exists | DELETE | `/dashboard/products/:id/variants/:variantId` | Delete variant | Variant list/editor |
| Exists | POST | `/media/upload` | Tenant media upload | Editors, store identity |

#### Product stock behavior for Flutter

- **No variants:** send/edit `stock_quantity` on the product (`POST`/`PATCH /dashboard/products`).
- **Has variants:** treat product-level `stock_quantity` as read-only and manage stock on variant rows.
- Backend auto-syncs product stock from variant totals after variant create/update/delete.

#### Product cost fields for P&L

- `cost_price` is now supported for both products and variants.
- Flutter should send/read:
  - product: `cost_price` in create/update payloads
  - variant: `cost_price` in create/update payloads
- Backend snapshots COGS at checkout (`unit_cost_at_sale`, `cogs_total`) so historical margins remain correct.

---

## Flutter implementation details: expense categories and demo products

This section documents the latest backend changes that affect the Flutter tenant app.

### 1) Expense categories

Expense categories are now tenant-specific. Flutter should stop treating expense categories as a fixed enum and instead load them from the API.

#### Endpoints

Use the mobile base URL `/api/v1/mobile`.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/dashboard/expense-categories` | List default + custom tenant expense categories |
| POST | `/dashboard/expense-categories` | Create custom expense category |
| GET | `/dashboard/expense-categories/:id` | Get one expense category |
| PATCH | `/dashboard/expense-categories/:id` | Update category name/slug/description |
| DELETE | `/dashboard/expense-categories/:id` | Delete category if unused |

#### Suggested Flutter files

Add or update these files in the Flutter app:

| File | Change |
|------|--------|
| `lib/core/api/api_client.dart` | Add expense category CRUD methods and send `category_id` on expenses |
| `lib/features/analytics/screens/expenses_screen.dart` | Replace fixed category list with API-loaded categories |
| `lib/features/analytics/models/expense_category.dart` | Add `ExpenseCategory` model if the screen is split into typed models |
| `lib/features/analytics/models/expense.dart` | Add `categoryId` and `categoryDetails` if expenses are typed |
| `lib/features/analytics/widgets/expense_category_picker.dart` | Optional reusable picker backed by API data |
| `lib/features/analytics/screens/expense_categories_screen.dart` | Optional management screen for custom categories |

#### ExpenseCategory model shape

```dart
class ExpenseCategory {
  final String id;
  final String tenantId;
  final String name;
  final String slug;
  final String? description;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
```

JSON field mapping:

| Dart field | API JSON field |
|------------|----------------|
| `id` | `id` |
| `tenantId` | `tenant_id` |
| `name` | `name` |
| `slug` | `slug` |
| `description` | `description` |
| `isDefault` | `is_default` |
| `createdAt` | `created_at` |
| `updatedAt` | `updated_at` |

#### Expense model changes

Add:

```dart
final String? categoryId;
final ExpenseCategory? categoryDetails;
```

JSON field mapping:

| Dart field | API JSON field |
|------------|----------------|
| `categoryId` | `category_id` |
| `categoryDetails` | `category_details` |

`category` may still appear as a legacy/category slug string. Prefer displaying `categoryDetails.name` when present, then fallback to `category`.

#### Create category request

```http
POST /api/v1/mobile/dashboard/expense-categories
Content-Type: application/json
Authorization: Bearer <accessToken>
```

```json
{
  "name": "Fuel",
  "slug": "fuel",
  "description": "Fuel and transport costs"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "category": {
      "id": "uuid",
      "tenant_id": "uuid",
      "name": "Fuel",
      "slug": "fuel",
      "description": "Fuel and transport costs",
      "is_default": false
    }
  }
}
```

#### Create expense request

Prefer `category_id`:

```http
POST /api/v1/mobile/dashboard/expenses
Content-Type: application/json
Authorization: Bearer <accessToken>
```

```json
{
  "expense_date": "2026-01-18",
  "category_id": "expense-category-uuid",
  "amount": 1250,
  "tax_amount": 0,
  "payment_method": "mpesa",
  "reference": "META-ADS-001",
  "notes": "January boosted posts"
}
```

Legacy fallback is still accepted if the category slug exists:

```json
{
  "expense_date": "2026-01-18",
  "category": "fuel",
  "amount": 1250
}
```

#### Update expense category

To correct a wrongly selected category:

```http
PATCH /api/v1/mobile/dashboard/expenses/:id
Content-Type: application/json
Authorization: Bearer <accessToken>
```

```json
{
  "category_id": "new-expense-category-uuid"
}
```

You can update category and amount in the same request:

```json
{
  "category_id": "new-expense-category-uuid",
  "amount": 1320,
  "notes": "Corrected category and amount"
}
```

#### UI behavior

- On expense create/edit screen load categories with `GET /dashboard/expense-categories`.
- Show default categories and custom categories in the same picker.
- Add a quick “Create category” action if the merchant cannot find a category.
- After creating a category, insert it into the local list and select it immediately.
- Send `category_id` for create/update.
- If `DELETE /dashboard/expense-categories/:id` returns an error, show the message. Categories used by expenses cannot be deleted.

### 2) Demo product cleanup

Starter/demo products are marked by the backend with product metadata:

```json
{
  "metadata": {
    "is_demo": true,
    "source": "starter_pack_ai",
    "demo_type": "onboarding_starter_pack"
  }
}
```

The mobile app does not need to send this metadata for normal merchant-created products. It is added by onboarding/demo seed flows.

#### Endpoint

```http
DELETE /api/v1/mobile/dashboard/products/demo
Authorization: Bearer <accessToken>
```

Behavior:

- Active demo products with no order history are deleted.
- Demo products already referenced by orders are archived, not deleted.
- The getting-started checklist is complete when no active demo products remain.

Response:

```json
{
  "success": true,
  "data": {
    "matchedCount": 10,
    "deletedCount": 8,
    "archivedCount": 2,
    "removedCount": 10,
    "message": "Demo products removed successfully"
  }
}
```

#### Suggested Flutter files

| File | Change |
|------|--------|
| `lib/features/products/data/product_api.dart` | Add `removeDemoProducts()` calling `DELETE /dashboard/products/demo` |
| `lib/features/products/repositories/product_repository.dart` | Expose remove demo products action |
| `lib/features/products/models/remove_demo_products_result.dart` | Parse cleanup response |
| `lib/features/dashboard/models/getting_started_item.dart` | Ensure it supports `id`, `label`, `description`, `completed`, `href`, `cta`, `priority` |
| `lib/features/dashboard/widgets/getting_started_card.dart` | If item id is `demo_products`, show button that calls cleanup API |
| `lib/features/dashboard/screens/dashboard_screen.dart` | Refresh checklist/products after cleanup |

#### RemoveDemoProductsResult model shape

```dart
class RemoveDemoProductsResult {
  final int matchedCount;
  final int deletedCount;
  final int archivedCount;
  final int removedCount;
  final String message;
}
```

#### Getting-started item

`GET /dashboard/getting-started` can now return:

```json
{
  "id": "demo_products",
  "label": "Remove demo products",
  "description": "Clear sample products once your real catalog is ready",
  "completed": false,
  "href": "/products",
  "cta": "Remove demo products",
  "priority": 8
}
```

Flutter handling:

- Render it like other checklist items.
- If `id == "demo_products"` and `completed == false`, CTA should call `DELETE /dashboard/products/demo`.
- After success, refresh:
  - `GET /dashboard/getting-started`
  - `GET /dashboard/products`
- Success copy can use `removedCount`, `deletedCount`, and `archivedCount`.

Example message:

```dart
if (result.archivedCount > 0) {
  showSuccess(
    'Removed ${result.deletedCount} demo products and archived ${result.archivedCount} used in orders.',
  );
} else {
  showSuccess('Removed ${result.deletedCount} demo products.');
}
```

### 3) Implementation checklist

1. Add `ExpenseCategory` and `RemoveDemoProductsResult` models.
2. Update `Expense` parsing for `category_id` and `category_details`.
3. Add expense category CRUD methods to the expense API/repository.
4. Replace any hard-coded expense category enum/dropdown with API-loaded categories.
5. Send `category_id` when creating/updating expenses.
6. Add “create category” flow from the expense form or a category management screen.
7. Add `removeDemoProducts()` to product API/repository.
8. Update getting-started UI to handle `demo_products`.
9. Refresh dashboard/products after demo cleanup.

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
| Exists | GET | `/dashboard/attributes` | List attributes + embedded values | `AttributesManagementScreen` |
| Exists | POST/PUT/PATCH/DELETE | `/dashboard/attributes`, `/dashboard/attributes/:id` | Attribute CRUD | `AttributeEditorScreen` |
| Exists | GET/POST | `/dashboard/attributes/:id/values` | List / create values | Value editor |
| Exists | PUT/PATCH/DELETE | `/dashboard/attributes/:id/values/:valueId` | Value CRUD | Value editor |

---

### Content & CMS (lower priority for MVP)

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/blogs` | List + pagination | `ContentManagementScreen` |
| Exists | POST | `/dashboard/blogs` | Create | `BlogPostEditorScreen` |
| Exists | GET | `/dashboard/blogs/:id` | Detail | `BlogPostEditorScreen` |
| Exists | PUT/PATCH | `/dashboard/blogs/:id` | Update | `BlogPostEditorScreen` |
| Exists | DELETE | `/dashboard/blogs/:id` | Delete | `BlogPostEditorScreen` |
| Exists | GET/POST | `/dashboard/pages` | List / create pages | `PageEditorScreen` |
| Exists | GET/PUT/PATCH/DELETE | `/dashboard/pages/:id` | Page CRUD; hero/home = edit **`home`** page **`content`** JSON | `PageEditorScreen`, `HeroSectionEditorScreen` |

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

### Push notifications follow-up checklist (Android + iOS)

Use this checklist to complete push setup end-to-end now that backend uses **FCM HTTP v1**.

#### 1) Backend environment (required for Android/Web push)

Set these server env vars (same Firebase project as the Flutter app):

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY` (single-line env value, keep `\n` line breaks escaped)

Example format:

```env
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-firebase-project-id.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

Where to get them:

- Firebase Console -> Project settings -> Service accounts -> **Generate new private key** (JSON download)
- Map JSON fields directly:
  - `project_id` -> `FIREBASE_PROJECT_ID`
  - `client_email` -> `FIREBASE_CLIENT_EMAIL`
  - `private_key` -> `FIREBASE_PRIVATE_KEY`

Optional iOS relay env (only if using APNs relay path):

- `APNS_PUSH_URL`
- `APNS_AUTH_TOKEN`

#### 2) Flutter app registration flow (required)

After login (with valid bearer token), app must register device token:

- `POST /api/v1/mobile/notifications/register-device`
- Headers:
  - `Authorization: Bearer <accessToken>`
  - `Content-Type: application/json`
- Body:

```json
{
  "deviceId": "stable-device-id",
  "token": "fcm-registration-token",
  "platform": "android",
  "appVersion": "1.0.0",
  "deviceName": "Pixel 7"
}
```

Important:

- Register once on login/startup.
- Register again on `onTokenRefresh`.
- Re-register when user changes account/store.

#### 3) Flutter runtime handling (required)

- Request notification permission (Android 13+ and iOS).
- Handle foreground messages (`onMessage`) and show local notification.
- Handle notification taps (`onMessageOpenedApp` + initial message).
- Use payload `data.link` for deep-link navigation to the target screen.

#### 4) Quick verification steps

1. Login in Flutter as tenant user.
2. Confirm `POST /notifications/register-device` returns success.
3. Place a new order in storefront.
4. Confirm backend logs do not show FCM auth/config errors.
5. Confirm Android device receives push.

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
