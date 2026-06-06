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
3. **New store has no products** — Expected after registration: the server uses a **clean catalog** (no demo seeding). Send **`businessType`** / **`selling`** if you want better theme defaults; add products later from the dashboard or other APIs. Same behavior for **`POST /api/v1/mobile/auth/register`** and **`POST /api/tenants/register`** (see `docs/API_MULTI_STORE_CHANGES.md`).
4. **Cold start** — Call **`GET /auth/me`** with the access token to restore **`user`** + **`tenant`** context; use **`POST /auth/refresh`** when the access token expires.
5. **After store registration** — On **`201`** from **`POST /auth/register`**, read **`data.loginUrl`** (see [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md) § *Post-registration redirect*). Open it in a browser or in-app WebView when you want the merchant to use the web dashboard login on the tenant host. For an in-app API-only session, ignore **`loginUrl`** and call **`POST /auth/login`** with the same email/password as usual.
6. **If the merchant chooses Tumizi during mobile onboarding** — First complete registration, then login and use the returned `accessToken`. Call **`POST /api/v1/mobile/dashboard/tumizi/settings`** with `{ "enabled": true, "createMerchantIfMissing": true }`, then optionally call **`PATCH /api/v1/mobile/dashboard/settings`** to set `payment.tumiziEnabled: true` and `payment.paymentMethod: "tumizi"`.
7. **Referral at signup** — Optional field **`referrerSubdomain`** on **`POST /auth/register`** (friend’s store subdomain). No separate referral-submit API. After login, use **`GET /dashboard/referrals`** or overview `referrals` for the merchant’s own share link. See **[Referral program](#referral-program-signup--dashboard)**.
8. **Tumizi orders** — Customers pay on the **web storefront**, not in Flutter. The app only manages those orders; do not manually set `payment_status` for `payment_gateway: "tumizi"`. See **[Tumizi orders (merchant app)](#tumizi-orders-merchant-app)**.

---

## StoreFlow backend: mobile routes implemented in this repo

These paths are relative to **`/api/v1/mobile`** (full URL example: `https://www.dukanest.com/api/v1/mobile/auth/login`). Auth is **Bearer** unless noted.

| Method | Path | Notes |
|--------|------|--------|
| POST | `/auth/login` | Email/password; MFA flow per response |
| POST | `/auth/register` | Same body as tenant register (incl. optional **`referrerSubdomain`**); **`data.loginUrl`** after **201** — see [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md) § *Store registration* |
| POST | `/auth/google` | Google `idToken` (+ `accessToken` if required) |
| POST | `/auth/refresh` | Rotate session |
| POST | `/auth/logout` | Invalidate server-side session if applicable |
| POST | `/auth/forgot-password` | Password reset request |
| POST | `/auth/mfa/send-code` | Send MFA code |
| POST | `/auth/mfa/status` | MFA status |
| POST | `/auth/mfa/verify` | Complete MFA |
| GET | `/auth/me` | Session restore: `user` + `tenant` (dashboard roles); landlord returns `tenant: null` |
| GET | `/dashboard/overview` | Metrics + recent orders + `subscription` + `referrals` summary (`shareSubdomain`, `referralLink`) *(checklist: use **`/dashboard/getting-started`**)* |
| GET | `/dashboard/getting-started` | On **`items[]`** with `id`, `completed`, `progressPercent`, `storeUrl`, … |
| POST | `/dashboard/getting-started` | Body `{ "action": "preview_done" \| "share_done" }` → persists flags (see below) |
| GET | `/dashboard/reward-checklist` | Separate **reward** checklist — window + bonus days come from the tenant's **`price_plans`** row (see [Reward checklist](#reward-checklist-earn-1-month-free)) |
| GET | `/dashboard/orders` | Paginated; see API_MULTI_STORE_CHANGES |
| GET | `/dashboard/orders/:id` | Order detail + line items |
| PATCH | `/dashboard/orders/:id` | `status`, optional `notes`, tracking; **`payment_status` only when `payment_gateway` ≠ `tumizi`** (see [Tumizi orders](#tumizi-orders-merchant-app)) |
| POST | `/dashboard/orders/:id/cancel` | Cancel order; body `{ reason, refund?, notes? }` — restores stock |
| GET | `/dashboard/subscription` | Full subscription snapshot (plans catalog, usage progress, access restrictions, renew/pay CTAs) |
| GET | `/dashboard/referrals` | Referral subdomain, referral counts, rewarded months |
| GET | `/dashboard/subscription/billing` | Billing history + renewal flags + dual-currency plan price |
| POST | `/dashboard/subscription/activate` | Upgrade / schedule downgrade / trial activation (**admin**) |
| POST | `/dashboard/subscription/mpesa/initiate` | STK push for plan payment (**admin**) |
| GET | `/dashboard/subscription/mpesa/status` | Poll STK; `checkoutRequestId` query param |
| GET | `/dashboard/subscription/pesapal/config` | Public PesaPal UI config (yearly discount %) |
| POST | `/dashboard/subscription/pesapal/initiate` | Returns `redirectUrl` for WebView checkout (**admin**) |
| GET | `/dashboard/orders/:id/tumizi/sync-payment` | Poll Tumizi + update order `payment_status` |
| POST | `/dashboard/orders/:id/tumizi/initiate-payment` | Resend STK / initiate Tumizi customer payment |
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
| PUT/PATCH | `/dashboard/customers/:id` | Update profile fields (not email) |
| DELETE | `/dashboard/customers/:id` | Delete customer — **`tenant_admin` only** |
| GET | `/dashboard/customers/export` | Export CSV (`?format=csv` for raw file; default JSON envelope with `csv` string) |
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
| GET/POST | `/dashboard/blogs/categories` | Blog category list / create |
| GET/PUT/PATCH/DELETE | `/dashboard/blogs/categories/:id` | Blog category CRUD |
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
| GET | `/dashboard/analytics` | Optional `?days=` (1–365, default **30**) — simplified trend summary |
| GET | `/dashboard/analytics/pnl` | Profit & Loss summary (`start_date`, `end_date`) |
| GET | `/dashboard/analytics/:segment` | Full web parity via catch-all — see **Analytics suite** below |
| GET/POST/DELETE | `/dashboard/analytics/scheduled-reports` | Scheduled report CRUD (stored in tenant `data`) |
| GET | `/dashboard/expense-categories` | List tenant expense categories |
| POST | `/dashboard/expense-categories` | Create tenant expense category (`name`, optional `slug`, `description`) |
| GET | `/dashboard/expense-categories/:id` | Get expense category |
| PUT/PATCH | `/dashboard/expense-categories/:id` | Update expense category |
| DELETE | `/dashboard/expense-categories/:id` | Delete expense category if unused |
| GET | `/dashboard/expenses` | Paginated expense ledger list |
| POST | `/dashboard/expenses` | Create expense (`category_id` or existing category slug) |
| PATCH | `/dashboard/expenses/:id` | Update expense, including `category_id`/category |
| DELETE | `/dashboard/expenses/:id` | Delete expense |
| GET | `/dashboard/sales` | **List** promotions/sales (paginated) |
| POST | `/dashboard/sales` | Create sale |
| GET | `/dashboard/sales/:id` | Sale + embedded `product_sales` |
| GET | `/dashboard/sales/:id/products` | List products in sale (camelCase `items`) |
| POST | `/dashboard/sales/:id/products` | Add product `{ productId, salePrice?, orderIndex? }` |
| PUT/PATCH | `/dashboard/sales/:id/products` | Update `{ productId, salePrice?, orderIndex? }` |
| DELETE | `/dashboard/sales/:id/products?productId=` | Remove product from sale |
| PUT/PATCH | `/dashboard/sales/:id` | Update |
| DELETE | `/dashboard/sales/:id` | Delete |
| GET | `/dashboard/inventory` | Paginated stock list; `search`, `low_stock_only`, `threshold`, etc. (see `inventoryQuerySchema`) |
| POST | `/dashboard/inventory/adjust` | Single product/variant adjustment |
| POST | `/dashboard/inventory/bulk` | Bulk adjustments array |
| GET | `/dashboard/inventory/history` | Adjustment audit log |
| GET/PUT | `/dashboard/inventory/settings` | Low-stock threshold |
| GET | `/dashboard/inventory/alerts` | Low-stock products + variants |
| GET/POST | `/dashboard/forms` | Form builder list / create |
| GET/PUT/PATCH/DELETE | `/dashboard/forms/:id` | Form CRUD |
| GET | `/dashboard/forms/:id/submissions` | Paginated submissions |
| GET | `/dashboard/themes` | Available theme catalog |
| GET | `/dashboard/themes/current` | Active theme + customizations |
| PUT/PATCH | `/dashboard/themes/current` | Update theme customizations |
| GET | `/dashboard/themes/installed` | Installed theme map |
| GET | `/dashboard/themes/:id` | Theme detail |
| POST | `/dashboard/themes/install` | Install/activate theme |
| GET | `/dashboard/settings` | Read store identity, currency, shipping, payment, tax snapshot (`tenant_admin` + `tenant_staff`) |
| PATCH | `/dashboard/settings` | Partial update; body mirrors GET `data` shape (nested `store`, `currency`, `shipping`, `payment`, `tax`); **`tenant_admin` only** |
| POST | `/dashboard/settings/delete-account` | Account deletion |
| GET | `/dashboard/tumizi/settings` | Tumizi integration config snapshot |
| POST | `/dashboard/tumizi/settings` | Enable/disable Tumizi; can create merchant if missing; **`tenant_admin` only** |
| GET | `/dashboard/tumizi/merchant` | Merchant + normalized `walletAccountNumber`, `availableBalance`, `generalInfo` |
| PATCH | `/dashboard/tumizi/merchant` | Update Tumizi merchant/owner/wallet fields; **`tenant_admin` only** |
| GET | `/dashboard/tumizi/wallet` | Live wallet: `walletAccountNumber`, `availableBalance`, max withdrawable, recent withdrawals |
| POST | `/dashboard/tumizi/wallet/withdrawals` | Request wallet withdrawal to Kenya M-Pesa; **`tenant_admin` only** |
| GET | `/dashboard/tumizi/refunds` | Tumizi refund log |
| GET | `/notifications/list` | In-app notifications |
| POST | `/notifications/register-device` | FCM token |
| GET | `/notifications/preferences` | |
| PUT | `/notifications/preferences` | |
| POST | `/media/upload` | Tenant media (product/logo, etc.) |
| GET | `/dashboard/media` | Media library list (`limit`, `offset`, `search`, `?sync=true`) |
| PUT/PATCH | `/dashboard/media/:id` | Update title / alt text |
| DELETE | `/dashboard/media/:id` | Delete from storage + DB |
| POST | `/mpesa/initiate` | M-Pesa flow |
| GET | `/mpesa/status` | Poll payment status |

**Public (not under `/api/v1/mobile`):**

| Method | Path |
|--------|------|
| GET | `/api/tenants/check-subdomain` |
| POST | `/api/tenants/register` |
| POST | `/api/v1/mobile/auth/register` | *(recommended mobile envelope)* |

**Still out of scope or optional:** **order packing-slip / invoice** download, dedicated **`PATCH /dashboard/onboarding-progress`** (use **`/dashboard/getting-started`** instead). **CMS:** blogs and **pages** (page builder JSON / hero via `home` page `content`) are on mobile; **theme template** switching is not a dedicated mobile route. **Facets** in this codebase map to **attributes** + **attribute values** (no separate `/facets` path).

**Settings write parity:** `PATCH /dashboard/settings` updates `static_options` + `tenants` for all fields the mobile GET exposes: **store** (incl. logo, phones with E.164 validation; extra phones cleared on Basic plan), **countries** (GET-only list for address dropdowns), **currency** (code/symbol/position + thousand/decimal separators, decimal places), **pickup** (enabled, location, instructions, hours JSON string), **shipping** (enabled, methodType, flatRateAmount, free shipping), **payment** (methods, M-Pesa option + credentials, timing), **tax** (enabled, rate, pricingType / includedInPrice, calculationBasedOn). At least one of cash, M-Pesa, or Tumizi must remain enabled if the client sends `payment` fields.

**Store logo (two steps):** `POST /media/upload` only stores the file and returns `data.url`. Persist it with **`PATCH /dashboard/settings`**:

```json
{ "store": { "logo": "https://…/storage/v1/object/public/…" } }
```

Clear the logo with `{ "store": { "logo": null } }` or `{ "store": { "logo": "" } }`.

**Shipping flat rate:** `GET/PATCH` include `shipping.methodType` (`flat_rate` | `delivery_zones`) and `shipping.flatRateAmount`. Zone pricing uses **`/dashboard/delivery-zones`**.

**Pickup:** `GET/PATCH` → `pickup.enabled`, `pickup.locationName`, `pickup.instructions`, `pickup.hours` (weekly hours JSON string, same as web). Enabling pickup requires a store address first.

**M-Pesa credentials:** `payment.mpesaSendMoneyNumber`, `mpesaBuyGoodsTill`, `mpesaPaybillNumber`, `mpesaPaybillAccount`, `mpesaPochiPhone` — set alongside `payment.mpesaOption`.

**Payment timing:** `payment.timing` → `before_delivery` | `after_delivery` | `user_choice`.

**Tax pricing:** prefer `tax.pricingType` (`inclusive` | `exclusive`); `tax.includedInPrice` is also returned for backward compatibility.

**Tumizi (M-Pesa via Tumizi) — web vs mobile:** Web exposes Tumizi under **Settings → Payments** (`payment_tumizi_enabled`, default method `tumizi`) and **Settings → Tumizi** (`/api/tumizi/settings`, `/api/tumizi/merchant`, wallet, refunds). Mobile `GET/PATCH /dashboard/settings` includes Tumizi payment parity fields (`payment.tumiziEnabled`, `payment.paymentMethod`, and `payment.defaultMethod` supports `tumizi`). Native mobile Tumizi screens should use the Bearer-token routes under `/api/v1/mobile/dashboard/tumizi/*`; Flutter must never store or send the Tumizi partner API key. **Order payment verification** for Tumizi is automatic — see **[Tumizi orders (merchant app)](#tumizi-orders-merchant-app)**. Settings/wallet parity: **[TUMIZI_MOBILE_AND_SETTINGS.md](./tumizi/TUMIZI_MOBILE_AND_SETTINGS.md)**.

### Referral program (signup + dashboard)

**Entering a friend’s referral code (new store signup)**

| | |
|--|--|
| **When** | During **`POST /auth/register`** only (not after the store exists) |
| **Field** | `referrerSubdomain` (optional string) — the referring merchant’s **shop subdomain**, e.g. `janes-boutique` |
| **Web equivalent** | Register page “Who referred you?” field or `?ref=janes-boutique` on `/register` |
| **Validation** | Same rules as `subdomain` (lowercase, 3–63 chars, `a-z0-9-`). Invalid/self-referral is ignored; registration still returns **201** |

```json
{
  "name": "My Store",
  "subdomain": "my-store",
  "adminEmail": "owner@example.com",
  "adminPassword": "your-strong-password",
  "adminPhone": "+254712345678",
  "adminPhoneCountry": "KE",
  "authProvider": "email",
  "referrerSubdomain": "janes-boutique"
}
```

Deep link idea for mobile: open signup with a stored referrer value and send it as `referrerSubdomain` (web uses `?ref=`).

**Viewing own referral rewards (existing merchant)**

| Method | Path | Notes |
|--------|------|--------|
| GET | `/dashboard/referrals` | Summary + referred friends list |
| GET | `/dashboard/overview` | `data.referrals` includes `shareSubdomain`, `referralLink`, counts |

Share link format (same as web): `{marketingHost}/register?ref={shareSubdomain}`.

---

### Mobile registration + Tumizi onboarding flow

If the merchant selects Tumizi during the mobile registration/onboarding flow:

1. Register the store with **`POST /api/v1/mobile/auth/register`** (add **`referrerSubdomain`** here if the user was referred).
2. Login with **`POST /api/v1/mobile/auth/login`** and store `data.accessToken`.
3. Enable/provision Tumizi with **`POST /api/v1/mobile/dashboard/tumizi/settings`**:

```json
{
  "enabled": true,
  "createMerchantIfMissing": true
}
```

4. Set Tumizi as an offered/default payment method with **`PATCH /api/v1/mobile/dashboard/settings`**:

```json
{
  "payment": {
    "cashEnabled": true,
    "mpesaEnabled": false,
    "tumiziEnabled": true,
    "paymentMethod": "tumizi"
  }
}
```

Use this only when the merchant explicitly wants Tumizi. If they choose Cash or direct M-Pesa only, skip the Tumizi settings call and configure those payment methods through `/dashboard/settings`.

### Mobile settings JSON examples (Flutter)

`Authorization: Bearer <accessToken>` is required for both calls.

**GET** `/api/v1/mobile/dashboard/settings` (example success payload excerpt)

```json
{
  "success": true,
  "data": {
    "store": {
      "id": "tenant_123",
      "name": "Acme Store",
      "subdomain": "acme",
      "domain": "acme.dukanest.com",
      "logo": "https://example.supabase.co/storage/v1/object/public/product-images/media/tenant_123/logo.png"
    },
    "payment": {
      "cashEnabled": true,
      "mpesaEnabled": true,
      "tumiziEnabled": true,
      "mpesaOption": "buy_goods",
      "paymentMethod": "tumizi",
      "defaultMethod": "tumizi"
    }
  }
}
```

**PATCH** `/api/v1/mobile/dashboard/settings` (Tumizi-aware payment update)

```json
{
  "payment": {
    "cashEnabled": true,
    "mpesaEnabled": false,
    "tumiziEnabled": true,
    "paymentMethod": "tumizi"
  }
}
```

Server validation mirrors web:

- At least one of `cashEnabled`, `mpesaEnabled`, or `tumiziEnabled` must remain enabled.
- `paymentMethod` / `defaultMethod` cannot point to a disabled method.
- `defaultMethod` is accepted for backward compatibility; prefer `paymentMethod` in new mobile clients.

### Dart DTO snippet (copy/paste)

```dart
enum PaymentMethod { cash, mpesa, tumizi }

PaymentMethod paymentMethodFromJson(String? value) {
  switch (value) {
    case 'mpesa':
      return PaymentMethod.mpesa;
    case 'tumizi':
      return PaymentMethod.tumizi;
    case 'cash':
    default:
      return PaymentMethod.cash;
  }
}

String paymentMethodToJson(PaymentMethod value) {
  switch (value) {
    case PaymentMethod.mpesa:
      return 'mpesa';
    case PaymentMethod.tumizi:
      return 'tumizi';
    case PaymentMethod.cash:
      return 'cash';
  }
}

class SettingsPaymentDto {
  final bool cashEnabled;
  final bool mpesaEnabled;
  final bool tumiziEnabled;
  final String? mpesaOption;
  final PaymentMethod paymentMethod;
  final PaymentMethod defaultMethod;

  const SettingsPaymentDto({
    required this.cashEnabled,
    required this.mpesaEnabled,
    required this.tumiziEnabled,
    required this.mpesaOption,
    required this.paymentMethod,
    required this.defaultMethod,
  });

  factory SettingsPaymentDto.fromJson(Map<String, dynamic> json) {
    return SettingsPaymentDto(
      cashEnabled: json['cashEnabled'] == true,
      mpesaEnabled: json['mpesaEnabled'] == true,
      tumiziEnabled: json['tumiziEnabled'] == true,
      mpesaOption: json['mpesaOption'] as String?,
      paymentMethod: paymentMethodFromJson(json['paymentMethod'] as String?),
      // Backward-compat: server still returns defaultMethod.
      defaultMethod: paymentMethodFromJson(json['defaultMethod'] as String?),
    );
  }

  Map<String, dynamic> toPatchJson() {
    return {
      'cashEnabled': cashEnabled,
      'mpesaEnabled': mpesaEnabled,
      'tumiziEnabled': tumiziEnabled,
      // Prefer paymentMethod for new clients.
      'paymentMethod': paymentMethodToJson(paymentMethod),
    };
  }
}
```

### Full settings DTO (store/currency/shipping/payment/tax)

```dart
double? asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class SettingsAddressDto {
  final String? line1;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  const SettingsAddressDto({
    required this.line1,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
  });

  factory SettingsAddressDto.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return SettingsAddressDto(
      line1: m['line1'] as String?,
      city: m['city'] as String?,
      state: m['state'] as String?,
      country: m['country'] as String?,
      postalCode: m['postalCode'] as String?,
    );
  }
}

class SettingsStoreDto {
  final String id;
  final String name;
  final String subdomain;
  final String domain;
  final String? contactEmail;
  final String? description;
  final String? logo;
  final String? phone;
  final String? phone2;
  final String? phone3;
  final SettingsAddressDto address;
  final String? businessType;
  final String? selling;

  const SettingsStoreDto({
    required this.id,
    required this.name,
    required this.subdomain,
    required this.domain,
    required this.contactEmail,
    required this.description,
    required this.logo,
    required this.phone,
    required this.phone2,
    required this.phone3,
    required this.address,
    required this.businessType,
    required this.selling,
  });

  factory SettingsStoreDto.fromJson(Map<String, dynamic> json) {
    return SettingsStoreDto(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      subdomain: (json['subdomain'] ?? '').toString(),
      domain: (json['domain'] ?? '').toString(),
      contactEmail: json['contactEmail'] as String?,
      description: json['description'] as String?,
      logo: json['logo'] as String?,
      phone: json['phone'] as String?,
      phone2: json['phone2'] as String?,
      phone3: json['phone3'] as String?,
      address: SettingsAddressDto.fromJson(json['address'] as Map<String, dynamic>?),
      businessType: json['businessType'] as String?,
      selling: json['selling'] as String?,
    );
  }
}

class SettingsCurrencyDto {
  final String code;
  final String symbol;
  final String symbolPosition; // left | right

  const SettingsCurrencyDto({
    required this.code,
    required this.symbol,
    required this.symbolPosition,
  });

  factory SettingsCurrencyDto.fromJson(Map<String, dynamic> json) {
    return SettingsCurrencyDto(
      code: (json['code'] ?? 'USD').toString(),
      symbol: (json['symbol'] ?? r'$').toString(),
      symbolPosition: (json['symbolPosition'] ?? 'left').toString(),
    );
  }
}

class SettingsShippingDto {
  final bool enabled;
  final String methodType; // flat_rate | delivery_zones
  final double? flatRateAmount;
  final bool freeShippingEnabled;
  final double? freeShippingThreshold;

  const SettingsShippingDto({
    required this.enabled,
    required this.methodType,
    required this.flatRateAmount,
    required this.freeShippingEnabled,
    required this.freeShippingThreshold,
  });

  factory SettingsShippingDto.fromJson(Map<String, dynamic> json) {
    return SettingsShippingDto(
      enabled: json['enabled'] == true,
      methodType: (json['methodType'] ?? 'flat_rate').toString(),
      flatRateAmount: asNullableDouble(json['flatRateAmount']),
      freeShippingEnabled: json['freeShippingEnabled'] == true,
      freeShippingThreshold: asNullableDouble(json['freeShippingThreshold']),
    );
  }
}

class SettingsTaxDto {
  final bool enabled;
  final double? defaultRate;
  final String calculationBasedOn;

  const SettingsTaxDto({
    required this.enabled,
    required this.defaultRate,
    required this.calculationBasedOn,
  });

  factory SettingsTaxDto.fromJson(Map<String, dynamic> json) {
    return SettingsTaxDto(
      enabled: json['enabled'] == true,
      defaultRate: asNullableDouble(json['defaultRate']),
      calculationBasedOn: (json['calculationBasedOn'] ?? 'billing_address').toString(),
    );
  }
}

class MobileSettingsDto {
  final SettingsStoreDto store;
  final SettingsCurrencyDto currency;
  final SettingsShippingDto shipping;
  final SettingsPaymentDto payment;
  final SettingsTaxDto tax;

  const MobileSettingsDto({
    required this.store,
    required this.currency,
    required this.shipping,
    required this.payment,
    required this.tax,
  });

  factory MobileSettingsDto.fromJson(Map<String, dynamic> json) {
    return MobileSettingsDto(
      store: SettingsStoreDto.fromJson((json['store'] as Map<String, dynamic>?) ?? const {}),
      currency: SettingsCurrencyDto.fromJson(
        (json['currency'] as Map<String, dynamic>?) ?? const {},
      ),
      shipping: SettingsShippingDto.fromJson(
        (json['shipping'] as Map<String, dynamic>?) ?? const {},
      ),
      payment: SettingsPaymentDto.fromJson(
        (json['payment'] as Map<String, dynamic>?) ?? const {},
      ),
      tax: SettingsTaxDto.fromJson((json['tax'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}
```

Minimal PATCH body builder example:

```dart
Map<String, dynamic> buildSettingsPatch({
  SettingsStoreDto? store,
  SettingsCurrencyDto? currency,
  SettingsShippingDto? shipping,
  SettingsPaymentDto? payment,
  SettingsTaxDto? tax,
}) {
  final patch = <String, dynamic>{};

  if (store != null) {
    patch['store'] = {
      'name': store.name,
      'contactEmail': store.contactEmail,
      'description': store.description,
      'phone': store.phone,
      'phone2': store.phone2,
      'phone3': store.phone3,
      'businessType': store.businessType,
      'selling': store.selling,
      'address': {
        'line1': store.address.line1,
        'city': store.address.city,
        'state': store.address.state,
        'country': store.address.country,
        'postalCode': store.address.postalCode,
      },
    };
  }

  if (currency != null) {
    patch['currency'] = {
      'code': currency.code,
      'symbol': currency.symbol,
      'symbolPosition': currency.symbolPosition,
    };
  }

  if (shipping != null) {
    patch['shipping'] = {
      'enabled': shipping.enabled,
      'methodType': shipping.methodType,
      'flatRateAmount': shipping.flatRateAmount,
      'freeShippingEnabled': shipping.freeShippingEnabled,
      'freeShippingThreshold': shipping.freeShippingThreshold,
    };
  }

  if (payment != null) {
    patch['payment'] = payment.toPatchJson();
  }

  if (tax != null) {
    patch['tax'] = {
      'enabled': tax.enabled,
      'defaultRate': tax.defaultRate,
      'calculationBasedOn': tax.calculationBasedOn,
    };
  }

  return patch;
}
```

---

## Progress steps (Getting Started checklist)

The home dashboard shows a **Getting Started** carousel until all steps are done.

### How onboarding steps are persisted (authoritative)

StoreFlow does **not** use a separate “onboarding table”. Completion is computed from tenant **`static_options`** and real domain data, same as the web dashboard (`buildGettingStartedProgress` in `src/lib/onboarding/getting-started-progress.ts`).

| Step id (API) | Becomes `completed: true` when |
|---------------|--------------------------------|
| `category` | At least one row in **`categories`** for the tenant. |
| `product` | At least one **active** product with `created_by` set (matches web count query). |
| `preview` | `static_options.getting_started_previewed_store === 'true'` — set via **`POST .../dashboard/getting-started`** with `{ "action": "preview_done" }`. |
| `share` | `static_options.getting_started_shared_link === 'true'` — **`POST`** with `{ "action": "share_done" }`. |
| `contact_phone` | `store_phone` static option non-empty (`PATCH /dashboard/settings` → `store.phone`). |
| `payment` | Cash enabled and/or M-Pesa enabled **with** a configured M-Pesa number/till/paybill (see same lib). |
| `delivery` | `shipping_enabled` and either delivery zones exist **or** flat rate amount set. |
| `logo` | `store_logo` static option set via **`PATCH /dashboard/settings`** → `store.logo` (after **`POST /media/upload`** if uploading a file). |
| `demo_products` | *(Only in API response when sample products exist.)* Shown as incomplete cleanup — remove via web **DELETE `/api/products/demo`** or Products UI. |

**Flutter:** Call **`GET /api/v1/mobile/dashboard/getting-started`** for the checklist (mobile envelope). After the user previews the storefront or shares the link, call **`POST`** on the same path with the actions above so **web and app stay in sync**.

**Legacy app behavior:** If the client still reads checklist only from **`GET .../dashboard/overview`**, note that the **mobile overview route does not embed steps yet** — switch to **`GET .../getting-started`** or merge both responses in the app.

---

## Reward checklist (Earn 1 month free)

Separate from **Getting Started**. Complete **100%** of these steps within the plan's **`onboarding_reward_window_days`** (default **30**) of `tenants.start_date` and the server **automatically extends** `tenants.expire_date` by **`onboarding_reward_bonus_days`** (default **30**, i.e. 1 month free). Configured per plan in **Admin → Price Plans** (same area as trial period). Set either field to **0** to disable the reward for that plan.

| Method | Path |
|--------|------|
| GET | `/api/v1/mobile/dashboard/reward-checklist` |

**Response (`data`):**

| Field | Notes |
|-------|--------|
| `items[]` | Same shape as getting-started items: `id`, `label`, `description`, `completed`, `href`, `cta`, `priority` |
| `completedCount`, `totalCount`, `progressPercent`, `allComplete` | Aggregate progress |
| `nextAction`, `nextSteps` | Suggested incomplete steps |
| `homePageEditHref` | Deep link to homepage page builder (e.g. `/dashboard/pages/{id}/edit`) |
| `reward.enabled` | Plan has reward configured (`windowDays > 0` and `bonusDays > 0`) |
| `reward.windowDays` | From tenant plan (`onboarding_reward_window_days`) |
| `reward.eligible` | Still within the reward window |
| `reward.daysRemainingInWindow` | Countdown |
| `reward.eligibleUntil` | ISO timestamp |
| `reward.granted` | Bonus already applied |
| `reward.grantedAt` | ISO timestamp when granted |
| `reward.bonusDays` | From tenant plan (`onboarding_reward_bonus_days`) |

### Reward step ids and completion rules

| Step id | Becomes `completed: true` when |
|---------|----------------------------------|
| `products_five` | ≥ **5** active products with `created_by` set |
| `categories_two` | ≥ **2** categories |
| `hero_image` | Homepage **hero** image/banner_image is merchant media (`media/{tenantId}/…`) or changed from install snapshot (not default Unsplash) |
| `hero_description` | Homepage hero **`description`** non-empty and changed from install snapshot |
| `sale_active` | ≥ **1** sale with `status = 'active'` |
| `sale_products_two` | ≥ **2** products on **one** active sale (`product_sales`) |
| `banner_updated` | Homepage **`banners`** section: at least one slot customized (image/title/subtitle vs install snapshot) |
| `split_layout_image` | Homepage **`split_layout.left_side.image`** customized (same anti-default rules as hero) |

**Grant trigger:** On **`GET .../reward-checklist`**, when `allComplete === true` and `reward.eligible === true` and not yet `reward.granted`, the server updates `expire_date` and sets `tenants.data.onboarding_reward` audit fields. No separate POST is required.

**UI guidance:** Show the reward card only while `reward.enabled && (reward.eligible || reward.granted)`. Hide when disabled on the plan or after the window expires without grant.

**Optional client keys:** If your Flutter code uses `preview_store` / `share_store` / `sms`, map them to server ids **`preview`** / **`share`** / **`contact_phone`**. Use server id **`category`** for a first-category step (not `catalog_category` unless you map it client-side).

### Canonical step keys

Align server keys with the app’s `DashboardOnboardingStepKeys` (Flutter: `lib/features/dashboard/providers/dashboard_local_onboarding_provider.dart`):

| Key | Meaning |
|-----|---------|
| `category` | First product category created |
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
| Exists | GET | `/dashboard/overview` | Metrics, recent orders, **subscription/trial** + `referrals` snapshot (`shareSubdomain`, `referralLink`) | `DashboardScreen` |
| Exists | GET | `/dashboard/analytics` | Metrics for last `days` (query `days`, 1–365, default 30) | `AnalyticsScreen` |
| Exists | GET | `/dashboard/analytics/pnl` | P&L summary (`start_date` / `end_date` or camelCase) | Finance tab |
| Exists | GET | `/dashboard/analytics/:segment` | Web-parity analytics (see table below) | Analytics sub-screens |
| Exists | GET/POST/DELETE | `/dashboard/analytics/scheduled-reports` | Scheduled exports | Reports settings |

#### Analytics suite (web parity)

Base path: `/api/v1/mobile/dashboard/analytics/{segment}` — Bearer required (`tenant_admin` + `tenant_staff`).

| Segment | Query params | Purpose |
|---------|--------------|---------|
| `overview` | — | High-level counts + cache (30s) |
| `revenue` | `startDate`/`start_date`, `endDate`/`end_date`, `groupBy` | Revenue trends |
| `sales` | date range | Sales by product/category |
| `customers` | date range | Acquisition, LTV, top customers |
| `inventory` | `lowStockThreshold` | Stock summary + alerts |
| `geographic` | date range | Sales by country/state/city |
| `conversion-funnel` | date range | Funnel + abandonment rates |
| `product-performance` | date range | Per-product metrics |
| `refunds` | date range | Refund rate + trends |
| `realtime` | — | Live visitors + recent orders |
| `realtime/poll` | — | Lightweight poll payload |
| `compare` | `startDate1`/`endDate1` (+ optional period 2) | Period-over-period growth |
| `traffic-sources` | date range | UTM / referrer breakdown |
| `export` | `type`, `format=csv\|json`, date range | CSV download or JSON rows (`?raw=1` skips envelope) |

**Scheduled reports:** `GET` lists; `POST` body `{ reportType, frequency, emailRecipients, format }` (camelCase accepted); `DELETE ?id=`.

#### Trial days remaining (same logic as web dashboard home)

On **web**, the tenant dashboard home banner uses:

- `price_plans.trial_days` (e.g. `14`)
- `tenants.start_date` (set at registration)
- **Formula:** `trialDaysRemaining = trial_days - floor((now - start_date) / 1 day)`; `null` when trial is over or the plan has no trial.

The **subscription** page also shows trial copy when `daysUntilRenewal` (ceil days until `expire_date`) is `> 0` and `<= trial_days`. At signup, `expire_date` is set to `now + trial_days`, so both views usually agree.

**Mobile:** read `data.subscription` from **`GET /api/v1/mobile/dashboard/overview`** (no extra call):

```json
"subscription": {
  "status": "active",
  "planId": "…",
  "planName": "Basic",
  "trialDays": 14,
  "trialDaysRemaining": 9,
  "inTrial": true,
  "startDate": "2026-05-01T00:00:00.000Z",
  "expireDate": "2026-05-15T00:00:00.000Z",
  "daysUntilExpire": 9
}
```

| Field | Use in Flutter |
|-------|----------------|
| `trialDaysRemaining` | Show “**N** days left in trial” when non-null and `> 0` (same as web home). |
| `inTrial` | Convenience flag (`trialDaysRemaining > 0`). |
| `daysUntilExpire` | Renewal / expiry countdown after trial (subscription page style). |
| `trialDays` | Plan trial length from pricing (`0` or `null` = no trial). |

```dart
final sub = overview['subscription'] as Map<String, dynamic>?;
final days = sub?['trialDaysRemaining'] as int?;
if (days != null && days > 0) {
  // "$days day(s) left in trial"
}
```

Refresh on pull-to-refresh or when returning to the dashboard; no client-side date math required.

---

### Orders

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/orders` | Paginated list, `search`, `status`, `payment_status` | `OrdersListScreen` |
| Exists | GET | `/dashboard/orders/:id` | Order detail | `OrderDetailScreen` |
| Exists | PATCH | `/dashboard/orders/:id` | Order `status`, `notes`; **not** `payment_status` for Tumizi | Order detail actions |
| Exists | POST | `/dashboard/orders/:id/cancel` | Cancel + optional refund flag; restores inventory | Order detail |
| Exists | GET | `/dashboard/orders/:id/tumizi/sync-payment` | Poll Tumizi + update `payment_status` | Tumizi order detail |
| Exists | POST | `/dashboard/orders/:id/tumizi/initiate-payment` | Resend STK / initiate Tumizi customer payment | Tumizi order detail |
| Partial | POST | `/dashboard/orders/:id/notes` | Prefer **PATCH** with `notes` | Order notes |
| Optional | GET | `/dashboard/orders/:id/packing-slip` | PDF or print URL | Print packing slip |

---

## Tumizi orders (merchant app)

There is **no separate Flutter customer/storefront app** in this product. Customers pay on the **web storefront** (tenant host). The **shop-owner Flutter app** only **views and fulfills** those orders and configures Tumizi for the store.

Tumizi checkout on the web creates orders with:

| Field | Typical value |
|-------|----------------|
| `payment_gateway` | `"tumizi"` |
| `payment_status` | `"pending"` until M-Pesa succeeds |
| `payment_track` | Tumizi `external_reference` (e.g. `order-{uuid}-{timestamp}`) |

Payment status is updated **on the server** — not by staff tapping “Mark paid” in the app.

### How payment status is updated (server-side)

| Mechanism | Purpose |
|-----------|---------|
| **Tumizi webhook** | `POST /api/tumizi/webhook` (configured in Tumizi settings; token in URL) |
| **Sync from Tumizi API** | Polls `GET` Tumizi partner `customer-payments/{externalReference}` and writes DB |
| **Cron backup** | `GET /api/admin/integrations/tumizi/sync-pending-payments` (host cron; not called from Flutter) |

The Flutter app must **display** the latest `payment_status` and may **request a sync**; it must **not** call Tumizi partner APIs or store `TUMIZI_PARTNER_API_KEY`.

### Core rules for Flutter

| Do | Don't |
|----|--------|
| Read `payment_gateway`, `payment_status`, `transaction_id` from order APIs | `PATCH` with `payment_status` when `payment_gateway === "tumizi"` |
| Show “Awaiting M-Pesa (Tumizi)” while `pending` | Treat `pending` as paid for fulfillment |
| Call **sync** endpoint (below) or poll **GET order** while detail is open | Use manual M-Pesa “verify transaction ID” UX for Tumizi |
| `PATCH` **order status** (`processing`, `shipped`, …) when appropriate | Call Tumizi partner API from the device |

**Blocked mobile update** — `PATCH /dashboard/orders/:id` with `payment_status` returns **`400`** when `payment_gateway` is `tumizi`:

```json
{
  "success": false,
  "error": {
    "code": "BAD_REQUEST",
    "message": "Tumizi payment status is synced automatically from Tumizi. Refresh payment status instead of updating manually."
  }
}
```

### Detecting a Tumizi order

```dart
bool isTumiziOrder(Map<String, dynamic> order) =>
    order['payment_gateway'] == 'tumizi';

bool isTumiziPaymentPending(Map<String, dynamic> order) =>
    isTumiziOrder(order) && order['payment_status'] == 'pending';
```

`GET /dashboard/orders` and `GET /dashboard/orders/:id` already expose `payment_gateway` and `payment_status` (camelCase in mobile envelope: `paymentGateway`, `paymentStatus` — confirm your client’s JSON mapping).

### Order list UI

- Badge **Tumizi + pending** → e.g. “Awaiting M-Pesa (Tumizi)”.
- Badge **Tumizi + paid** → “Paid via Tumizi”.
- Badge **Tumizi + failed** → “Payment failed”.
- No “Mark as paid” swipe/action on Tumizi rows.
- Use `GET /notifications/list` — `pending_payment` notifications still apply.

### Order detail UI

1. **Hide** manual payment-status dropdown when `paymentGateway == tumizi`.
2. Show short copy: *Payment is confirmed automatically when the customer completes M-Pesa on their phone.*
3. While **Tumizi + pending**:
   - Waiting indicator.
   - **Refresh from Tumizi** button → `GET .../tumizi/sync-payment`.
   - Optional: poll every **5s** for up to **~2 minutes** while the screen is visible, then stop.
4. When `paymentStatus` becomes `paid`, refresh UI and allow normal fulfillment (`PATCH` **status** only).
5. Do **not** show M-Pesa manual verification fields for Tumizi (those are for `payment_gateway === "mpesa"` manual flow).

### Mobile Tumizi order APIs

Bearer routes under `/api/v1/mobile/dashboard/orders/:id/...` (order id or `order_number`).

#### Sync payment status

```http
GET /api/v1/mobile/dashboard/orders/{orderId}/tumizi/sync-payment
Authorization: Bearer <accessToken>
```

**When:** User taps “Refresh from Tumizi”, or automatic poll on order detail while pending.

**Success (example):**

```json
{
  "success": true,
  "data": {
    "synced": true,
    "paymentStatus": "paid",
    "tumiziStatus": "successful",
    "reason": null
  }
}
```

| Field | Meaning |
|-------|---------|
| `synced` | Server called Tumizi and applied result |
| `paymentStatus` | Updated order status (`pending` \| `paid` \| `failed`) — snake_case `payment_status` also returned in some payloads |
| `tumiziStatus` | Raw status string from Tumizi |
| `reason` | e.g. `already_final`, `missing_external_reference` if no change |

**Errors:** `404` order not found; `400` not a Tumizi order.

#### Initiate / resend customer payment

```http
POST /api/v1/mobile/dashboard/orders/{orderId}/tumizi/initiate-payment
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "phoneNumber": "254712345678",
  "amount": 1500,
  "narration": "Payment for order ORD-123"
}
```

| Field | Required | Notes |
|-------|----------|--------|
| `phoneNumber` | Yes | Kenya MSISDN (`254...`) |
| `amount` | No | Defaults to order total |
| `narration` | No | STK description |

Mirrors web `POST /api/orders/:id/tumizi/initiate-payment`. Use when staff must resend the STK push.

### Polling pattern (order detail)

```dart
// Pseudocode — run only while Tumizi + pending and screen is mounted
Timer.periodic(const Duration(seconds: 5), (_) async {
  final res = await api.get(
    '/dashboard/orders/$orderId/tumizi/sync-payment',
  );
  final status = res.data['payment_status'] as String?;
  if (status == 'paid' || status == 'failed') {
    cancelTimer();
    updateLocalOrder(paymentStatus: status);
  }
});
```

On the **orders list**, rely on pull-to-refresh, returning from detail, or push notifications — avoid background polling every order.

### Push notifications

When Tumizi payment completes, tenants may receive notifications via `GET /notifications/list`. On tap, open order detail and call **sync** or **GET order** once to show final `payment_status`.

### PATCH body reminder (non-Tumizi only)

For **cash** or **manual M-Pesa** orders, `payment_status` via PATCH is still allowed:

```json
{
  "payment_status": "paid",
  "transaction_id": "optional",
  "notes": "optional"
}
```

For **Tumizi**, send only `status` / `notes` / tracking fields.

### Related docs

| Doc | Content |
|-----|---------|
| [tumizi/TUMIZI_MOBILE_AND_SETTINGS.md](./tumizi/TUMIZI_MOBILE_AND_SETTINGS.md) | Enable Tumizi, wallet, settings parity |
| Web storefront checkout | Customers use `payment_method: "tumizi"` on tenant website (not documented here as a Flutter app) |

### Tumizi orders — implementation checklist

1. Map `paymentGateway` / `paymentStatus` on order models.
2. Branch order detail UI: hide manual payment editor for Tumizi.
3. Add **Refresh from Tumizi** → `GET .../tumizi/sync-payment`.
4. Poll sync or GET order while Tumizi + pending on detail screen.
5. Handle `400` if legacy UI still sends `payment_status` PATCH for Tumizi.
6. Optional: resend STK via `POST .../tumizi/initiate-payment`.
7. Do not embed Tumizi partner API keys in the app.

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
| Exists | GET | `/dashboard/media` | Media library gallery | Media picker |
| Exists | PUT/PATCH | `/dashboard/media/:id` | Update `title`, `altText` | Media detail |
| Exists | DELETE | `/dashboard/media/:id` | Delete file from storage + DB | Media library |

**Media list query:** `limit` (default 50), `offset`, `search`, `sync=true` (force Supabase sync).

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
| PUT/PATCH | `/dashboard/expense-categories/:id` | Update category name/slug/description |
| DELETE | `/dashboard/expense-categories/:id` | Delete category if unused |

#### Suggested Flutter files

Add or update these files in the Flutter app:

| File | Change |
|------|--------|
| `lib/features/expenses/models/expense_category.dart` | Add `ExpenseCategory` model |
| `lib/features/expenses/models/expense.dart` | Add `categoryId` and `categoryDetails` |
| `lib/features/expenses/data/expense_api.dart` | Add expense category CRUD methods |
| `lib/features/expenses/repositories/expense_repository.dart` | Expose category list/create/update/delete |
| `lib/features/expenses/widgets/expense_category_picker.dart` | Dropdown/search picker backed by API data |
| `lib/features/expenses/screens/create_expense_screen.dart` | Send `category_id` |
| `lib/features/expenses/screens/edit_expense_screen.dart` | Allow category update via `category_id` |
| `lib/features/expenses/screens/expense_categories_screen.dart` | Optional management screen for custom categories |

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
  "href": "/dashboard/products",
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
| Exists | PUT/PATCH | `/dashboard/customers/:id` | Update name, address, mobile, etc. (email not writable) | Customer editor |
| Exists | DELETE | `/dashboard/customers/:id` | Hard delete — **`tenant_admin` only** | Customer detail |
| Exists | GET | `/dashboard/customers/export` | CSV export; `?search=` / `?email=` filters; `?format=csv` for file download | Export action |

**Update body (camelCase or snake_case):** `name`, `username`, `mobile`, `company`, `address`, `city`, `state`, `country`, `postalCode`/`postal_code`, `image`.

---

### Inventory

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/inventory` | Paginated stock list + stats | `InventoryScreen` |
| Exists | POST | `/dashboard/inventory/adjust` | Adjust one product or variant | Stock editor |
| Exists | POST | `/dashboard/inventory/bulk` | Batch adjustments | Bulk update |
| Exists | GET | `/dashboard/inventory/history` | Audit log (`productId`, `variantId`, `adjustmentType`) | History tab |
| Exists | GET/PUT | `/dashboard/inventory/settings` | Read/write low-stock threshold | Settings |
| Exists | GET | `/dashboard/inventory/alerts` | Low-stock products + variants | Alerts widget |

**Adjust body:** `{ productId?, variantId?, adjustmentType, quantity, reason?, notes? }` — exactly one of `productId` or `variantId`.

**Bulk body:** `{ updates: [{ productId?, variantId?, adjustmentType, quantity, reason? }] }`.

Writes blocked when subscription expired (`canEditData`).

---

### Settings / store configuration

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/settings` | Read snapshot (`tenant_admin` + `tenant_staff`) | `SettingsScreen`, dedicated editors |
| Exists | PATCH | `/dashboard/settings` | Partial update — **`tenant_admin` only**; body keys mirror GET (`store`, `countries`, `currency`, `pickup`, `shipping`, `payment`, `tax`) | `SettingsScreen` |
| Exists | GET/POST | `/dashboard/delivery-zones` | List + create (**admin** for POST) | `ManageZonesScreen` |
| Exists | PUT/PATCH/DELETE | `/dashboard/delivery-zones/:id` | **Admin only** | `DeliveryZoneEditorScreen` |
| Parity | POST | `/dashboard/settings/delete-account` | Account deletion (see parity checklist) | `StoreIdentityScreen` |

### Subscription & billing

Mirror the **web** dashboard subscription page: four sections — **Overview**, **Usage & limits**, **Plans & pricing**, **Billing history** — plus grace-period banners and pay/renew CTAs.

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/subscription` | Full snapshot — see below | `SubscriptionScreen` (all tabs) |
| Exists | GET | `/dashboard/referrals` | Referral subdomain + referral progress summary | `ReferralScreen` / loyalty section |
| Exists | GET | `/dashboard/subscription/billing` | Billing history + renewal flags | Billing tab (or lazy-load) |
| Exists | POST | `/dashboard/subscription/activate` | **Admin** — free activation / schedule downgrade | Downgrade confirm, free plans |
| Exists | POST | `/dashboard/subscription/mpesa/initiate` | **Admin** — STK `{ planId, phoneNumber }` | M-Pesa checkout (Kenya) |
| Exists | GET | `/dashboard/subscription/mpesa/status` | Poll `?checkoutRequestId=` | After STK |
| Exists | GET | `/dashboard/subscription/pesapal/config` | Yearly discount % (public) | Payment sheet |
| Exists | POST | `/dashboard/subscription/pesapal/initiate` | **Admin** — returns `redirectUrl` | PesaPal WebView |

**Roles:** `tenant_staff` and `tenant_admin` can **view** subscription + billing. Only **`tenant_admin`** can activate plans or initiate payment.

**Plan catalog:** `availablePlans` lists **every** `price_plans` row with `status: active` (same as web). If the tenant current plan is inactive, it is still included so the UI never shows an empty catalog when a plan is assigned.

---

#### `GET /dashboard/subscription` — primary screen payload

```http
GET /api/v1/mobile/dashboard/subscription
Authorization: Bearer <token>
```

**Key `data` fields (camelCase):**

| Field | Web parity / Flutter use |
|-------|--------------------------|
| `summary` | Top summary card (plan name, price, renewal date, status) |
| `currentPlan` | Resolved monthly price in tenant currency (`price`, `currencySymbol`) |
| `availablePlans[]` | Plan cards; each has `changeType`, `featureHighlights`, `isCurrentPlan`, `isFree` |
| `usage` / `usageDetails[]` | Usage tab progress bars (`percentage`, `nearLimit`, `atLimit`, `unlimited`) |
| `planLimits` | `maxProducts`, `maxOrders`, `maxPages`, `maxBlogs`, `maxCustomers`, `maxStorageMb` |
| `accessRestriction` | Banner when `level` is `read-only` or `restricted` |
| `needsRenewalPayment` | Show **Pay now** / **Renew now** when true (expired or <=7 days left) |
| `isExpired`, `isExpiringSoon`, `inTrial`, `daysUntilRenewal` | Status chips and countdown |
| `scheduledDowngrade` | `{ fromPlanName, toPlanName, effectiveDate }` when downgrade scheduled |
| `capabilities.paymentMethods` | Kenya: `mpesa` + `pesapal`; otherwise `pesapal` only |
| `pesapal.yearlyDiscountPercent` | Yearly billing discount in payment sheet |

**`availablePlans[].changeType`:** `upgrade` (paid checkout), `downgrade` (confirm + POST activate), `same` (current plan button disabled), `activation` (no current plan).

**Status badges** — map `accessRestriction.level`:

| `level` | Badge |
|---------|-------|
| `full` | Active (green) |
| `read-only` | Expired grace period (yellow) |
| `restricted` | Suspended (red) |
| `blocked` | Deleted |

When `summary.statusLabel` is `expired_grace_period`, show grace banner even if `subscriptionStatus` is still `active`.

**Flutter layout (match web tabs):**

1. Summary card from `summary` + `daysUntilRenewal` badge when `isExpiringSoon`.
2. Access banner when `accessRestriction.level != full` with **Renew now**.
3. Renewal CTA when `needsRenewalPayment`.
4. Tabs: Overview, Usage & limits (`usageDetails`), Plans (`availablePlans`), Billing (`GET …/billing`).

---

#### `GET /dashboard/subscription/billing`

Returns `billingHistory[]` plus `needsRenewalPayment`, `isExpired`, `isExpiringSoon`, `daysUntilRenewal`, and dual-currency `currentPlan` (`price`, `priceUsd`, `priceKes`, `currencySymbol`). Show pay/renew row at top when `needsRenewalPayment` is true.

---

#### Payment flows (**tenant_admin** only)

**PesaPal:** `POST …/pesapal/initiate` body `{ planId, billingInterval: monthly|yearly }` → open `data.redirectUrl` in WebView → refresh `GET /dashboard/subscription`.

**M-Pesa (Kenya):** `POST …/mpesa/initiate` body `{ planId, phoneNumber }` → poll `GET …/mpesa/status?checkoutRequestId=` until `status: completed`.

**Downgrade / free:** `POST …/activate` body `{ planId }` — response `changeType`, `effectiveDate` for scheduled downgrades.

**Grace period:** Payment allowed (`canPayForSubscription`); plan activation blocked until renewed (`canActivatePlans` false when read-only).

Use **`GET /dashboard/overview`** → `data.subscription` for home trial banner only; use **`GET /dashboard/subscription`** for the full screen.

**Paid upgrade:** M-Pesa → initiate + poll until completed, then refresh. PesaPal → WebView + refresh. **Downgrade:** `POST …/activate` only.

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
| Exists | GET/POST | `/dashboard/blogs/categories` | List / create blog categories | Category picker |
| Exists | GET/PUT/PATCH/DELETE | `/dashboard/blogs/categories/:id` | Category CRUD | Category editor |
| Exists | GET/POST | `/dashboard/pages` | List / create pages | `PageEditorScreen` |
| Exists | GET/PUT/PATCH/DELETE | `/dashboard/pages/:id` | Page CRUD; hero/home = edit **`home`** page **`content`** JSON | `PageEditorScreen`, `HeroSectionEditorScreen` |
| Exists | GET/POST | `/dashboard/forms` | Form builder list / create | `FormsListScreen` |
| Exists | GET/PUT/PATCH/DELETE | `/dashboard/forms/:id` | Form CRUD (`fields` JSON array) | `FormEditorScreen` |
| Exists | GET | `/dashboard/forms/:id/submissions` | Paginated submissions | Submissions inbox |

---

### Themes

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/themes` | Theme catalog (`?status=`, `?is_premium=`) | Theme picker |
| Exists | GET | `/dashboard/themes/current` | Active theme + customizations | Theme editor |
| Exists | PUT/PATCH | `/dashboard/themes/current` | Update colors, logo, meta, CSS/JS | Customization panel |
| Exists | GET | `/dashboard/themes/installed` | Map of installed theme IDs → active flag | Theme picker badges |
| Exists | GET | `/dashboard/themes/:id` | Single theme detail | Theme preview |
| Exists | POST | `/dashboard/themes/install` | Install/activate theme (+ optional demo content) | Theme install flow |

**Install body:** `{ themeId, includeDemoContent?, includeDemoAttributes?, businessType? }` (snake_case aliases accepted). Response mirrors web: `homepageCreated`, `additionalPagesCreated`, demo counts, etc.

---

### Promotions / sales

| Status | Method | Path | Purpose | Flutter surface |
|--------|--------|------|---------|-----------------|
| Exists | GET | `/dashboard/sales` | Paginated list + filters | Sales list |
| Exists | POST | `/dashboard/sales` | Create | `SalesEditorScreen` |
| Exists | GET | `/dashboard/sales/:id` | Detail + embedded products | `SalesEditorScreen` |
| Exists | GET | `/dashboard/sales/:id/products` | Product assignments list | `SalesEditorScreen` |
| Exists | POST | `/dashboard/sales/:id/products` | Add product to sale | `SalesEditorScreen` |
| Exists | PUT/PATCH | `/dashboard/sales/:id/products` | Update sale price / sort order | `SalesEditorScreen` |
| Exists | DELETE | `/dashboard/sales/:id/products` | Remove product (`?productId=`) | `SalesEditorScreen` |
| Exists | PUT/PATCH | `/dashboard/sales/:id` | Update sale metadata | `SalesEditorScreen` |
| Exists | DELETE | `/dashboard/sales/:id` | Delete sale | `SalesEditorScreen` |

**Product assignment example:**

```json
POST /api/v1/mobile/dashboard/sales/{saleId}/products
{ "productId": "…", "salePrice": 999, "orderIndex": 0 }
```

List response items use camelCase: `salePrice`, `discountPercent`, `orderIndex`, nested `product.price`, etc.

Sales list query also supports `featured`, `sortBy`, `sortOrder` (snake_case aliases accepted).

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
3. **Order mutations + Tumizi sync routes** — Fulfillment `PATCH` status; **`GET/POST .../orders/:id/tumizi/*`** available on mobile for payment refresh (see [Tumizi orders](#tumizi-orders-merchant-app)).
4. **Product PATCH/DELETE** — Complete operational flows from list/detail screens.
5. **Customers** — Replace `demo_data`.
6. **Categories & attributes** — Replace in-memory repositories.
7. **Analytics, CMS, Sales** — Align with web surface area.

---

## References in repo

| Resource | Location |
|----------|----------|
| Mobile API client (current methods) | `lib/core/api/api_client.dart` |
| Overview + checklist parsing | `lib/features/dashboard/screens/dashboard_screen.dart` |
| Local step completions (until server is source of truth) | `lib/features/dashboard/providers/dashboard_local_onboarding_provider.dart` |
| Pagination contract (orders/products) | [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md) |
