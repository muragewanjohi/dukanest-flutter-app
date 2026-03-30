# Flutter shop-owner app: tenant / web parity test checklist

Use this checklist to verify that a **tenant** (shop owner or staff) can run their store from the Flutter app in line with the web dashboard, for the **MVP mobile surface** backed by `/api/v1/mobile/*`.

**Related docs:** [API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md), [MOBILE_PROJECT_CONTEXT.md](./MOBILE_PROJECT_CONTEXT.md), [mobile-first-flutter-roadmap.md](./mobile-first-flutter-roadmap.md).

---

## Tenant and session

- [ ] **Single store per login** — After login, all dashboard data matches the same tenant as the web session (no store picker in the one-store phase; no `X-Tenant-Id` header required per current contract).
- [ ] **Session restore** — Cold start with stored tokens: `GET /api/v1/mobile/auth/me` (if implemented) restores user + `tenant_id` and lands on the correct home state.
- [ ] **Staff vs admin** — If `tenant_staff` is supported, allowed actions match web RBAC for that role.

---

## Authentication and account (Bearer token parity)

- [ ] **Email/password login** — Success path: tokens stored securely (`flutter_secure_storage`); all `/api/v1/mobile/*` requests send `Authorization: Bearer <accessToken>`.
- [ ] **Token lifecycle** — On access expiry, refresh runs; on **401**, one retry after refresh; failed refresh clears session and returns to login without showing stale authenticated UI.
- [ ] **MFA** — When enabled for the account: login → MFA step → full session; invalid codes and edge cases handled like web.
- [ ] **Google Sign-In** — Where implemented: native Google → `POST /api/v1/mobile/auth/google` → same MFA/token flow as email. If not shipped yet, document as out of scope ([API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md)).
- [ ] **Forgot password** — Flow reachable and completes (parity with web tenant reset).
- [ ] **Logout** — Calls mobile logout as applicable; clears secure storage; no further authenticated API calls until login again.

---

## Create store (register) — parity with web `POST /api/tenants/register`

- [ ] **Subdomain check** — `GET /api/tenants/check-subdomain?subdomain=...`: debounce (~300–500 ms), cancel/ignore stale responses, loading and error states; UI maps `available`, `available: false`, and **400** messages.
- [ ] **Submit registration** — `POST /api/tenants/register` parsed as **web-style JSON** (not assumed `{ success, data }` mobile envelope for this route). **201** success; **400** validation; **409** if subdomain taken between check and submit.
- [ ] **Post-register sign-in** — After **201**, user signs in with `POST /api/v1/mobile/auth/login` using the same credentials, then MFA if required.
- [ ] **Phone / country** — `adminPhone`, optional `adminPhoneCountry`, validation and defaults match server (e.g. libphonenumber / default `KE`).

---

## Dashboard home

- [ ] **Overview** — `GET /api/v1/mobile/dashboard/overview`: metrics and **recent orders** match web for the same tenant.
- [ ] **Quick actions** — Shortcuts (orders, add product, inventory, etc.) match merchant-critical web entry points.

---

## Orders

- [ ] **List and pagination** — `GET .../dashboard/orders` with `page`, `limit`, `search`; out-of-range `page` returns empty `items` with valid `pagination` metadata (not a hard error).
- [ ] **Filters** — `status` uses order lifecycle (`pending`, `processing`, `shipped`, `delivered`, `cancelled`, `refunded`). **Paid** filtering uses `payment_status` (`pending`, `paid`, `failed`, `refunded`), not `status`.
- [ ] **Detail** — Line items, customer, totals, status/timeline consistent with web for the same order id.
- [ ] **Actions** — Status updates (and any quick actions) persist and respect server-valid transitions.
- [ ] **Contact actions** — Call, WhatsApp, share (where implemented) behave consistently with web mobile UX.

---

## Products

- [ ] **List and pagination** — `GET .../dashboard/products` with `page`, `limit`, `search`; same pagination shape as orders.
- [ ] **Status filter** — `status`: `active | inactive | draft | archived`.
- [ ] **Search** — Behavior matches backend (case-insensitive where documented).
- [ ] **CRUD** — Create, edit, archive/inactivate rules match web for the tenant.
- [ ] **Media** — Upload via mobile media endpoint; images visible on web after save and vice versa when applicable.

---

## Customers

- [ ] **List and detail** — Data scoped to tenant; search/navigation works.
- [ ] **Order history / totals** — If displayed, figures align with web for the same customer.

---

## Inventory

- [ ] **Views and adjustments** — Stock levels and low-stock signals match web for the same SKUs (allowing normal cache/sync delay if offline features exist).

---

## Sales and analytics (if in MVP build)

- [ ] **Analytics** — e.g. `GET .../dashboard/analytics?days=...` matches web summaries for the same period where the same metrics are exposed.
- [ ] **Sales** — Any sales/promotions surfaces on mobile match web data for the same endpoints.

---

## Settings

- [ ] **Read/update** — Exposed settings fields match what merchants expect from web for the same tenant.
- [ ] **Delete account** — `POST .../dashboard/settings/delete-account` with body `{ "confirmation": "DELETE {subdomain}", "reason"?: string }` matches web soft-delete behavior and error responses.

---

## Notifications

- [ ] **Device registration** — `POST .../notifications/register-device` with FCM token; device receives tenant-relevant pushes.
- [ ] **List and preferences** — In-app list and preference toggles persist correctly.
- [ ] **Deep links** — Notification tap opens order detail, product, or other correct screen.

---

## M-Pesa (shop-owner subscription)

- [ ] **Initiate** — `POST .../mpesa/initiate` from app.
- [ ] **Status** — Poll `GET .../mpesa/status` until terminal state; success, failure, and timeout UX match expectations established on web.

---

## API contract and resilience

- [ ] **Mobile envelope** — Success: `success: true`, `data`, optional `pagination`. Error: `success: false`, `error.code`, `error.message`, optional `details`.
- [ ] **Loading and errors** — Every critical async screen has loading and user-visible error handling; lists support pull-to-refresh where applicable.
- [ ] **Offline (if implemented)** — Offline banner, queued actions, pending sync indicators; no silent loss of user actions.

---

## UX / non-functional

- [ ] **360px width** — Core flows usable without horizontal scroll; minimum ~44×44 touch targets on primary controls.
- [ ] **Performance** — Cold start and list scroll acceptable on a representative low/mid Android device (primary market per roadmap).

---

## Out of scope / not full web parity

The web dashboard includes many areas (full catalog admin, marketing, content, support, landlord tools, etc.). **MVP mobile parity** is the scope in [MOBILE_PROJECT_CONTEXT.md](./MOBILE_PROJECT_CONTEXT.md): onboarding/auth, home, orders, products, customers, inventory, notifications, settings, M-Pesa subscription.

- [ ] **Document gaps** — Any feature that still opens in-browser or is web-only is listed in app help or release notes so QA and support expectations stay clear.

---

## Revision

Update this file when the mobile API adds endpoints, changes filters (e.g. multi-store and `X-Tenant-Id`), or when MVP scope expands.
