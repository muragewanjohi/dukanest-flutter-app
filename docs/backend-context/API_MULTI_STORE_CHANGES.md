# Mobile API: Store Context & Pagination

This document describes the **current** mobile contract for DukaNest / StoreFlow and defers **multi-store selection** until there is product demand.

## Current scope: one store per user (no store picker)

**Product decision:** We treat each shop-owner account as managing **one tenant / one store**. The app does **not** show a store selector.

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

### Preferred for Flutter — mobile envelope

`POST /api/v1/mobile/auth/register`

| | |
|--|--|
| **Auth** | None (public) |
| **Body** | Same JSON as `POST /api/tenants/register` (see table below) |
| **Response** | `{ "success": true, "data": { "message", "tenant", "loginUrl?", … } }` on **201**; `{ "success": false, "error": { "code", "message", "details?" } }` on errors (`VALIDATION_ERROR`, `CONFLICT`, etc.) |

Server implementation delegates to the web register handler (`src/app/api/v1/mobile/auth/register/route.ts`).

### Web / alternate — raw JSON

`POST /api/tenants/register`

| | |
|--|--|
| **Auth** | None (public) |
| **Response shape** | Web-style JSON (top-level `success`, `tenant`, `message`—not the `data` wrapper) |

### Web parity note (important)

`POST /api/v1/mobile/auth/register` and `POST /api/tenants/register` use the **same registration logic** on the server.

If a newly created store is empty (no products/categories/sales/blogs), this is typically a **request payload** issue, not a different endpoint issue.

Starter/demo content generation depends on onboarding fields in the body (see **Starter content trigger checklist** below).

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
| `supabaseAccessToken` | Optional (Google) | Existing Supabase access token for the same Google user (equivalent to Authorization Bearer token) |
| `googleIdToken` | Optional (Google) | Google OIDC id_token; server can exchange via Supabase when no Supabase token is provided |
| `googleAccessToken` | Optional (Google) | Companion access token for id_token flows that include `at_hash` |

### Starter content trigger checklist (for non-empty new stores)

To match the web onboarding behavior (AI/starter-pack flow), send these fields on registration:

- `includeDemoContent: true`
- `includeDemoAttributes: true` (recommended when demo content is on)
- `businessType`: non-empty string
- `selling`: non-empty string

If those are missing/false, registration still succeeds, but store content seeding may be skipped and the store can start empty.

#### Minimal example payload for Flutter (email sign-up)

```json
{
  "name": "My Store",
  "subdomain": "my-store",
  "adminEmail": "owner@example.com",
  "adminPassword": "your-strong-password",
  "adminPhone": "+254700000000",
  "adminPhoneCountry": "KE",
  "businessType": "Fashion",
  "selling": "Clothes and accessories",
  "includeDemoContent": true,
  "includeDemoAttributes": true
}
```

For `authProvider: "google"`, server validates identity via either:
- `Authorization: Bearer <supabase_access_token>` or `supabaseAccessToken`, or
- `googleIdToken` (+ optional `googleAccessToken`) exchanged server-side through Supabase.

### Success (201)

**Web** (`POST /api/tenants/register`) returns a flat JSON body (no `data` wrapper). **Mobile** (`POST /api/v1/mobile/auth/register`) wraps the same fields inside **`data`**.

Shared fields include:

| Field | Description |
|-------|-------------|
| `tenant` | `{ id, name, subdomain }` |
| `loginUrl` | Tenant admin login page, e.g. `https://{subdomain}.{base}/dashboard/login` — use this after registration when opening the dashboard in a browser (WebView / external browser). |
| `storeUrl` | Public storefront root (optional in some clients) |
| `demoContentCreated`, … | Other optional telemetry fields |

Example (web-style top-level keys):

```json
{
  "success": true,
  "message": "Tenant registered successfully",
  "tenant": { "id": "…", "name": "…", "subdomain": "…" },
  "loginUrl": "https://mystore.example.com/dashboard/login",
  "demoContentCreated": false
}
```

#### Post-registration redirect (web + Flutter)

1. **Web** (`src/app/register/page.tsx`): redirects to **`loginUrl`** (tenant **`/dashboard/login`**).
2. **Flutter (browser / WebView):** After **201**, open **`data.loginUrl`** so the merchant signs in on the tenant host (same as web).
3. **Flutter (API-only app):** You may ignore **`loginUrl`** and sign in with **`POST /api/v1/mobile/auth/login`** using the same email/password; that path is unchanged.

**Supabase configuration:** **Authentication → URL Configuration → Redirect URLs** should still allow tenant OAuth and callback URLs (e.g. `https://*.yourdomain.com/auth/callback**`, tenant login flows). See `.env.example` under Supabase.

Use the returned `tenant` as context for UI if needed. For returning merchants, **`POST /api/v1/mobile/auth/login`** with email/password (and MFA if enabled) is unchanged.

### Errors

- **400** — validation: `{ "message": "Validation failed", "errors": [{ "field", "message" }] }` or field-specific payloads (e.g. invalid phone).
- **409** — subdomain already taken: `{ "message": "…", "errors": [{ "field": "subdomain", … }] }`.
- **500** — registration failure.

### Flutter notes

1. Call **`check-subdomain`** while the user types; call **`POST /api/v1/mobile/auth/register`** (or web register) on submit.
2. If you use the **mobile** register URL, parse the usual **`data`** envelope like other `/api/v1/mobile/*` routes.
3. **After successful registration:** when opening the tenant admin in a browser, use **`data.loginUrl`** (see **Post-registration redirect** above). Keep **`POST /auth/login`** for in-app token-based sessions.
4. **CORS (Flutter Web):** In production set **`MOBILE_CORS_ORIGINS`** to your app origins (comma-separated). In **development** any `Origin` is reflected for mobile + registration paths. Native Android/iOS does not use CORS.

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

## Session restore (single-store)

### `GET /api/v1/mobile/auth/me`

| | |
|--|--|
| **Auth** | `Authorization: Bearer <accessToken>` |
| **Roles** | Returns **`403`** if `tenant_admin` / `tenant_staff` but tenant context is missing; **`200`** with `tenant: null` for other roles (e.g. landlord). |

**Success (`200`):** `{ "success": true, "data": { "user": { "id", "email", "role", "tenantId" }, "tenant": { "id", "name", "subdomain", "status", "domain" } | null } }`.

Use after app relaunch to confirm the token and load **tenant** summary without a `stores[]` list. See [flutter_apis.md](./flutter_apis.md).

### `POST /api/v1/mobile/auth/google` (shop-owner mobile)

| | |
|--|--|
| **Auth** | None (public) |
| **Body** | `{ "idToken": string, "accessToken"?: string }` — `idToken` is the Google OIDC JWT from native `google_sign_in`. Pass `accessToken` if the ID token includes `at_hash` (Supabase requirement). |
| **Behavior** | `signInWithIdToken` via Supabase; then **same** tenant/role checks and **email OTP MFA** as `POST /api/v1/mobile/auth/login`. |
| **Success** | Same JSON as mobile login: either `requiresMfa: true` + `tempSession`, or `requiresMfa: false` + `accessToken` / `refreshToken` (landlord). |

**Flutter:** Configure the same Supabase project and Google provider as the web app. You may still use `signInWithIdToken` client-side only; this endpoint exists when you prefer server-side exchange and identical MFA behavior to password login.

**Supabase dashboard:** Enable Google provider and use the same Web / iOS / Android OAuth client IDs as documented for Supabase.
