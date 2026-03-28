# Mobile API: Store Context & Pagination

This document describes the **current** mobile contract for DukaNest / StoreFlow. **Multi-store selection** (one login, many tenants) stays deferred until there is product demand.

## Current scope: one store per tenant (no store picker)

**Product decision:** The domain model is **one store per tenant**. A shop-owner account maps to a single tenant; the app does **not** show a store selector.

- After login, tenant context comes from the authenticated user: Supabase `user_metadata.tenant_id` and/or the `tenants` row linked by `user_id` (see mobile auth).
- Mobile dashboard endpoints scope data with that **`user.tenant_id`** from the Bearer session. **No `X-Tenant-Id` header is required** in this phase.
- Additional stores for the same login (if ever created in the DB) are **out of scope** for v1 mobile UX; we do not implement picker or header-based switching yet.

Flutter can proceed **without** `stores[]` in auth responses and **without** sending `X-Tenant-Id`.

---

## Orders & products pagination (active contract)

The Flutter app should use backend-driven pagination, filtering, and search for orders and products.

### Endpoints

- `GET /api/v1/mobile/dashboard/orders`
- `GET /api/v1/mobile/dashboard/products`

### Query parameters

Common:

- `page` (int, default `1`)
- `limit` (int, default `20`, max `100`)
- `search` (string, optional)

Orders:

- `status` (optional): `pending | processing | shipped | delivered | cancelled | refunded` (order lifecycle)
- `payment_status` (optional): `pending | paid | failed | refunded` — use this for “paid”, not `status`

Products:

- `status` (optional): `active | inactive | draft | archived`

### Response shape

```json
{
  "success": true,
  "data": {
    "items": []
  },
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 123,
    "totalPages": 7
  }
}
```

Notes:

- `data.items` is required (array).
- `pagination.page`, `pagination.limit`, `pagination.total`, `pagination.totalPages` are required when lists are paginated.
- Tenant scoping uses the session’s tenant (see above); no header required in the one-store phase.
- Search is case-insensitive where the backend applies `insensitive` matching.
- Out-of-range `page` should return empty `items` with valid pagination metadata (not an error).

### Backend checklist (pagination — largely done)

- [x] Support `page`, `limit`, `search`, and filters on `/api/v1/mobile/dashboard/orders` and `.../products`
- [x] Return `success`, `data.items`, and `pagination` as above
- [ ] Add/verify DB indexes as needed (tenant + `created_at`, tenant + `status`, searchable fields)
- [ ] Optional: endpoint tests for pagination boundaries and filters

---

## Store registration: realtime subdomain availability (Flutter + web)

Use the **same public endpoint** as the web register page for “as you type” checks before `POST /api/tenants/register`.

### Endpoint

`GET /api/tenants/check-subdomain?subdomain=<value>`

| | |
|--|--|
| **Auth** | None (public) |
| **Base URL** | Same API host as registration (e.g. Vercel deployment), **not** `https://{subdomain}.yourdomain.com` |

The server trims and lowercases `subdomain` (`src/app/api/tenants/check-subdomain/route.ts`).

### Responses

**200 OK** — format and reserved-word checks passed:

```json
{
  "available": true,
  "subdomain": "my-store"
}
```

or

```json
{
  "available": false,
  "subdomain": "taken-name"
}
```

(`available` is `false` when that subdomain is already used by a tenant.)

**400 Bad Request** — missing/invalid subdomain (format, reserved list, etc.):

```json
{
  "available": false,
  "message": "Human-readable reason"
}
```

**500** — generic failure; treat as “could not verify”.

Response includes `Cache-Control: no-store`.

### Flutter implementation notes

1. **Debounce** input (~300–500 ms) before calling the API (web uses ~350 ms).
2. **Cancel or ignore stale requests** when the user keeps typing so old results don’t flash for a new string.
3. **Optional:** cache `subdomain → available` in memory for the current session (same idea as web’s register page cache).
4. **UI:** loading state while fetching; map `available: true` / `false` / `400 message` to messages.
5. **Source of truth on submit:** `POST /api/tenants/register` can still return **409** if the subdomain was taken between check and submit — handle like the web.

### Related code

- API: `src/app/api/tenants/check-subdomain/route.ts`
- Validation rules: `src/lib/subdomain-validation.ts`
- Web usage (debounce + fetch): `src/app/register/page.tsx`

---

## Store registration: submit (mobile + web)

There is **`no`** `POST /api/v1/mobile/auth/register` route. The native app uses the **same public API** as the marketing/register website.

### Endpoint

`POST /api/tenants/register`

| | |
|--|--|
| **Auth** | None (public) |
| **Base URL** | Same host as `check-subdomain` (e.g. Vercel API root) |
| **Response shape** | **Not** the `{ success, data, error }` mobile envelope—see below (web-style JSON) |

### Request body (core fields)

Validated by `registerTenantSchema` in `src/app/api/tenants/register/route.ts`:

| Field | Required | Notes |
|-------|----------|--------|
| `name` | Yes | Store display name |
| `subdomain` | Yes | Lowercase `a-z`, digits, hyphens; must pass `GET .../check-subdomain` before submit |
| `adminEmail` | Yes | Owner login email |
| `adminPhone` | Yes | Valid for `adminPhoneCountry` (libphonenumber); becomes store contact / SMS context |
| `adminPhoneCountry` | No | ISO 3166-1 alpha-2; defaults to `KE` if omitted |
| `adminPassword` | For email sign-up | Min 8 chars when using email auth (see `authProvider`) |
| `adminName` | No | |
| `authProvider` | No | `email` (default) or `google` |
| `contactEmail` | No | |
| `planId`, `themeId` | No | UUIDs when applicable |
| `businessType`, `selling` | No | Onboarding |
| `starterPackJobId` | No | If using async starter pack |
| `includeDemoContent`, `includeDemoAttributes` | No | Booleans |

**Google-driven registration** on web merges additional server logic; for a minimal Flutter MVP, prefer **`authProvider: "email"`** with `adminPassword` unless you replicate the web Google + register flow.

### Success (201)

```json
{
  "success": true,
  "message": "Tenant registered successfully",
  "tenant": { "id": "…", "name": "…", "subdomain": "…" },
  "loginUrl": "…",
  "demoContentCreated": false,
  "…": "other optional fields"
}
```

Use the returned `tenant` as context for UI if needed; then sign the user in with **`POST /api/v1/mobile/auth/login`** using the same email/password (and MFA if enabled)—same as any returning merchant.

### Errors

- **400** — validation: `{ "message": "Validation failed", "errors": [{ "field", "message" }] }` or field-specific payloads (e.g. invalid phone).
- **409** — subdomain already taken: `{ "message": "…", "errors": [{ "field": "subdomain", … }] }`.
- **500** — registration failure.

### Flutter notes

1. Call **`check-subdomain`** while the user types; call **`register`** once on submit.
2. Implement a **second JSON parser** for this route (do not assume `data` wrapper like `/api/v1/mobile/*`).
3. Ensure **HTTPS** and correct **CORS** if you ever call from a web build; native iOS/Android direct to API usually avoids browser CORS.

---

## Future: multi-store (deferred)

If we later support **one login, multiple stores**, we would add something like:

- `stores` / `memberships` on `POST /api/v1/mobile/auth/login` and `POST /api/v1/mobile/auth/mfa/verify` (and optionally `GET /api/v1/mobile/auth/me`)
- **`X-Tenant-Id`** on mobile requests, with server checks that the user may act on that tenant
- Explicit error codes (e.g. tenant selection / access denied) in the mobile error envelope

That work is **not** part of the current milestone. Revisit **`API_MULTI_STORE_CHANGES.md`** (this file) or a dedicated spec when there is committed demand.

### Previously drafted ideas (reference only)

<details>
<summary>Deferred multi-store sketch</summary>

- Auth responses could include:

```json
"stores": [
  { "id": "tenant_uuid_1", "name": "Main Store", "subdomain": "main-store" }
]
```

- All mobile endpoints would honor `X-Tenant-Id` and validate membership.
- Recommended codes (would extend `MobileErrorCode`): `TENANT_SELECTION_REQUIRED`, `TENANT_ACCESS_DENIED`, `TENANT_NOT_FOUND`.

</details>

---

## Optional (still nice-to-have, not multi-store specific)

### `GET /api/v1/mobile/auth/me`

Useful to restore session after app relaunch with user + **`tenant_id`** (single store). Does **not** require a `stores` list in the one-store model.

`POST /api/v1/mobile/auth/google` is **not implemented** yet; track separately if/when Google Sign-In ships for mobile.