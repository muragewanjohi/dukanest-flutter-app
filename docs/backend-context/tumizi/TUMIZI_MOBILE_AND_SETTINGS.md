# Tumizi: mobile app & settings parity (StoreFlow)

This guide maps **web** Tumizi behavior to what a **Flutter (or other) mobile** merchant app should mirror. It complements the low-level partner API doc: [TUMIZI_PARTNER_GATEWAY_API_GUIDE.md](./TUMIZI_PARTNER_GATEWAY_API_GUIDE.md).

---

## What Tumizi is in StoreFlow

- **Customer checkout:** “**M-Pesa via Tumizi**” — automatic STK-style flow; payment is tied to the order and confirmed via webhooks (`/api/tumizi/webhook`).
- **Merchant:** A **Tumizi merchant + wallet** is linked per tenant (`tenant_tumizi_integrations` + optional legacy JSON on `tenants.data`). Enabling Tumizi updates `static_options.payment_tumizi_enabled`.
- **Dashboard:** Two places matter on web:
  1. **Settings → Payments** — cash / M-Pesa toggles, **default payment method** (can be `tumizi` when offered), M-Pesa sub-options.
  2. **Settings → Tumizi** — **Tumizi wallet** switch (calls Tumizi APIs) and the embedded **Tumizi dashboard** (merchant profile, wallet balance, withdrawals, refunds).

---

## Readiness flags (mirror these in the app)

| Surface | Rule | Source |
|--------|------|--------|
| **Storefront checkout** — show Tumizi as a payment option | `payment_tumizi_ready === true` | `GET /api/checkout/settings` on the **store tenant host** (public). Server sets this when `getTumiziTenantConfigByTenantId`: `enabled && merchantExternalId`. |
| **Merchant “Tumizi is live”** | Same: integration **enabled** and **`merchantExternalId`** present | `GET /api/tumizi/settings` (dashboard auth). |
| **Static option “offered”** | `payment_tumizi_enabled` string `'true'` in `static_options` | Written when saving Tumizi via `POST /api/tumizi/settings`; also returned on web `GET /api/dashboard/settings` as boolean `payment_tumizi_enabled`. |

**Web validation (mirror in mobile UI):** Default payment method **`tumizi`** is only allowed if Tumizi is “offered” (`payment_tumizi_enabled` **or** integration live with merchant id). See `src/app/dashboard/settings/tenant-settings-client.tsx` (`tumiziOfferedForValidation`, `tumiziCheckoutReady`).

---

## Web API reference (same host as the tenant store / dashboard)

All paths below are on the **tenant’s app origin** (e.g. `https://{subdomain}.example.com`), unless you proxy them from your API gateway.

### Tumizi integration (enable / disable / create merchant)

| Method | Path | Auth | Role |
|--------|------|------|------|
| `GET` | `/api/tumizi/settings` | Session (`requireAuth`) | `tenant_admin` **or** `tenant_staff` (read) |
| `POST` | `/api/tumizi/settings` | Session | **`tenant_admin` only** |

**`POST` body** (`src/app/api/tumizi/settings/route.ts`):

- `enabled` (boolean, required)
- `merchantExternalId` (optional string) — defaults / generated when creating merchant
- `createMerchantIfMissing` (optional boolean, default `false`) — when `true` and enabling, may call Tumizi **create merchant** + wallet bootstrap

**Response:** `{ success, data }` with `TumiziTenantConfig`-shaped fields (`enabled`, `merchantExternalId`, `walletAccountNumber`, `walletCurrency`, …).

### Merchant profile & wallet actions (dashboard “Tumizi” tab)

| Method | Path | Auth | Notes |
|--------|------|------|--------|
| `GET` | `/api/tumizi/merchant` | Session | Merchant + wallet snapshot from Tumizi |
| `PATCH` | `/api/tumizi/merchant` | Session | Update merchant/owner/wallet fields (`updateMerchantSchema`) |
| `GET` | `/api/tumizi/wallet` | Session | Wallet read |
| `POST` | `/api/tumizi/wallet` | Session | Withdrawal create (body per route) |
| `GET` | `/api/tumizi/refunds` | Session | Refund list for tenant |

Implementation entry: `src/app/dashboard/tumizi/tumizi-dashboard-client.tsx` (fetch calls to the routes above).

### General tenant settings (includes payment flags, not full Tumizi object)

| Method | Path | Auth |
|--------|------|------|
| `GET` | `/api/dashboard/settings` | Session; **`tenant_admin`** only in route |
| `PUT` | `/api/dashboard/settings` | Session; **`tenant_admin`** |

Relevant fields in the flat `settings` object include:

- `payment_cash_enabled`, `payment_mpesa_enabled`, `payment_tumizi_enabled`
- `payment_method` / `default_payment_method` — enum includes **`tumizi`**
- `payment_timing` — affects M-Pesa verification behavior on checkout (see web checkout)

### Staff-initiated Tumizi payment for an existing order (web-only)

| Method | Path | Auth |
|--------|------|------|
| `POST` | `/api/orders/:id/tumizi/initiate-payment` | Session; `tenant_admin` / `tenant_staff` |

Body: `phoneNumber` (required), optional `amount`, `narration`. Used from the **order detail** flow on web.

**DukaNest Flutter:** out of scope. The merchant app manages Tumizi configuration, merchant details, wallet withdrawals, and refunds; it does **not** initiate customer payments.

### Storefront (no session)

| Method | Path | Notes |
|--------|------|--------|
| `GET` | `/api/checkout/settings` | Includes `payment_tumizi_ready` |
| `POST` | `/api/checkout` | `payment_method: "tumizi"` only if Tumizi live; Kenya M-Pesa phone rules on shipping contact |

---

## Mobile app: native Tumizi routes

### 1) Authenticated mobile Tumizi APIs = **Bearer token**

Native Flutter screens should call the mobile dashboard Tumizi proxy routes with:

```text
Authorization: Bearer <accessToken>
```

Routes:

| Method | Path | Role |
|--------|------|------|
| `GET` | `/api/v1/mobile/dashboard/tumizi/settings` | `tenant_admin`, `tenant_staff` |
| `POST` | `/api/v1/mobile/dashboard/tumizi/settings` | **`tenant_admin` only** |
| `GET` | `/api/v1/mobile/dashboard/tumizi/merchant` | `tenant_admin`, `tenant_staff` |
| `PATCH` | `/api/v1/mobile/dashboard/tumizi/merchant` | **`tenant_admin` only** |
| `GET` | `/api/v1/mobile/dashboard/tumizi/wallet` | `tenant_admin`, `tenant_staff` |
| `POST` | `/api/v1/mobile/dashboard/tumizi/wallet/withdrawals` | **`tenant_admin` only** |
| `GET` | `/api/v1/mobile/dashboard/tumizi/refunds` | `tenant_admin`, `tenant_staff` |

The backend resolves `tenant_id` and `merchant_external_id` server-side, reads the Tumizi partner API key from server env, calls `https://app.tumizi.africa/api/partner/v1/...` through `tumiziClient`, and returns the standard mobile envelope. Flutter must never store or send the Tumizi partner API key.

### 2) Mobile registration / onboarding flow

Use the Tumizi settings endpoint **after** registration and login, not inside the public registration request. The app needs a tenant admin Bearer token before it can provision Tumizi safely.

Recommended Flutter flow when the merchant selects Tumizi:

1. Register the store:

```text
POST /api/v1/mobile/auth/register
```

2. Login with the same credentials and store `data.accessToken`:

```text
POST /api/v1/mobile/auth/login
```

3. Enable/provision Tumizi:

```http
POST /api/v1/mobile/dashboard/tumizi/settings
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "enabled": true,
  "createMerchantIfMissing": true
}
```

4. Make Tumizi available in checkout/payment settings:

```http
PATCH /api/v1/mobile/dashboard/settings
Authorization: Bearer <accessToken>
Content-Type: application/json
```

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

Skip steps 3-4 when the merchant does not choose Tumizi. They can enable it later from the native Tumizi settings screen using the same routes.

### 3) Mobile settings coverage

`GET/PATCH /api/v1/mobile/dashboard/settings` now exposes payment parity fields:

- `payment.tumiziEnabled` (maps to `payment_tumizi_enabled`)
- `payment.paymentMethod` (maps to `payment_method`, supports `cash | mpesa | tumizi`)
- `payment.defaultMethod` (backward-compatible key, also supports `tumizi`)

Use the `/dashboard/tumizi/*` routes above for the Tumizi integration snapshot, wallet, withdrawals, and refunds.

### 4) Storefront checkout (customer app)

- Host: **storefront tenant domain** (same as web checkout).
- Read **`payment_tumizi_ready`** from `GET /api/checkout/settings`.
- If offering Tumizi, collect a **valid Kenya M-Pesa MSISDN** on shipping/contact (see `normalizeKenyaMsisdnForTumizi` usage in `src/app/api/checkout/route.ts` and checkout client).

---

## UX checklist (merchant app)

| Web | Mobile should |
|-----|----------------|
| Settings → Payments: enable/disable cash / M-Pesa / Tumizi + default method | `GET/PATCH /api/v1/mobile/dashboard/settings` (`payment.cashEnabled`, `payment.mpesaEnabled`, `payment.tumiziEnabled`, `payment.paymentMethod/defaultMethod`) |
| Payments: default method `tumizi` only when offered | Same guard as `tumiziOfferedForValidation` |
| Settings → Tumizi: master switch | `GET/POST /api/v1/mobile/dashboard/tumizi/settings` `{ enabled, createMerchantIfMissing? }` — **admin only for POST** |
| Tumizi tab: merchant / wallet / refunds | Native Bearer routes: `GET/PATCH /api/v1/mobile/dashboard/tumizi/merchant`, `GET /api/v1/mobile/dashboard/tumizi/wallet`, `POST /api/v1/mobile/dashboard/tumizi/wallet/withdrawals`, `GET /api/v1/mobile/dashboard/tumizi/refunds` |
| Order detail: initiate Tumizi payment | Web-only / out of scope for the Flutter merchant app |

---

## Related code (for engineers)

| Area | Path |
|------|------|
| Tumizi tenant config | `src/lib/tumizi/config.ts` |
| Checkout gate + initiate | `src/app/api/checkout/route.ts`, `src/lib/tumizi/initiate-order-payment.ts` |
| Web settings + Tumizi tab | `src/app/dashboard/settings/tenant-settings-client.tsx` |
| Tumizi dashboard | `src/app/dashboard/tumizi/tumizi-dashboard-client.tsx` |
| Mobile Tumizi API routes | `src/app/api/v1/mobile/dashboard/tumizi/*` |
| Webhook | `src/app/api/tumizi/webhook/route.ts` |

---

## Summary

- **Checkout readiness** for customers = **`payment_tumizi_ready`** (`GET /api/checkout/settings`).
- **Merchant configuration** = **`/api/tumizi/settings`** + **Payments** block in **`/api/dashboard/settings`**.
- **Native mobile** can mirror Tumizi payment toggles/default from **`/api/v1/mobile/dashboard/settings`** and Tumizi settings/merchant/wallet/refunds from **`/api/v1/mobile/dashboard/tumizi/*`** with the existing mobile Bearer token.
