# Google Sign-In: Testing to Production Checklist (Flutter)

Use this checklist when promoting the Flutter shop-owner app Google Sign-In flow from test mode to production.

**Scope:** Android/iOS Flutter login with `google_sign_in`, backend exchange via `POST /api/v1/mobile/auth/google`, and Google Cloud OAuth setup.

---

## 1) Google Cloud OAuth credentials

- [ ] **Web OAuth client exists** (used as `GOOGLE_SERVER_CLIENT_ID`, ends with `.apps.googleusercontent.com`).
- [ ] **Android OAuth client exists** with:
  - [ ] Package name `com.dukanest.dukanest_app`
  - [ ] Correct SHA-1 for debug (for internal testing)
  - [ ] Correct SHA-1 for release keystore (for production build)
- [ ] **iOS OAuth client exists** (if shipping iOS) and is linked to the correct bundle id.
- [ ] OAuth clients are all created in the intended Google Cloud project (same project used by Supabase Google provider).

---

## 2) OAuth consent screen (required)

- [ ] Verify app branding, support email, and authorized domain(s) are complete.
- [ ] Add privacy policy URL and terms URL.
- [ ] Confirm only required scopes are requested (`email`, `profile`, `openid`).
- [ ] **Switch OAuth consent from Testing to Production.**
- [ ] If keeping in testing temporarily, ensure all QA accounts are listed in **Test users**.

---

## 3) Supabase Google provider alignment

- [ ] Supabase Auth Google provider uses the intended Google Cloud OAuth project credentials.
- [ ] Redirect URIs in Google Cloud include the Supabase callback URL in use.
- [ ] Verify tenant login via web still works after any credential updates.

---

## 4) Flutter app configuration

- [ ] `GOOGLE_SERVER_CLIENT_ID` points to the **Web OAuth client ID**.
- [ ] Local run config includes the define (for example in `.vscode/launch.json`).
- [ ] CI/CD release build includes the same define:
  - [ ] `flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=...`
  - [ ] `flutter build appbundle --dart-define=GOOGLE_SERVER_CLIENT_ID=...`
  - [ ] iOS equivalent if applicable.
- [ ] Confirm no client IDs are hardcoded incorrectly in source.

---

## 5) Android signing and fingerprints

- [ ] Decide production signing approach (Play App Signing or self-managed keystore).
- [ ] Register the release SHA-1 (and SHA-256 when needed) in Google Cloud Android OAuth client.
- [ ] If using Play App Signing, also register Play-provided app signing fingerprint.
- [ ] Re-test sign-in with a **release-signed** build (not only debug).

---

## 6) End-to-end validation before launch

- [ ] Fresh install -> Continue with Google succeeds.
- [ ] App receives `idToken` and backend `POST /api/v1/mobile/auth/google` succeeds.
- [ ] MFA continuation works when user requires MFA.
- [ ] Token refresh and logout still work.
- [ ] Error messages are user-friendly for:
  - [ ] canceled sign-in
  - [ ] network failure
  - [ ] backend auth rejection
- [ ] Consent screen no longer shows "app is in testing" for production users.

---

## 7) Operational readiness

- [ ] Add runbook entry for rotating OAuth credentials.
- [ ] Document where client IDs are stored (local config + CI secrets).
- [ ] Track Google auth failures in logs/analytics.
- [ ] Add support FAQ for common merchant login issues.

---

## 8) Post-release verification

- [ ] Verify sign-in success rate on production telemetry for first 24-72 hours.
- [ ] Monitor auth-related crashes and backend error codes.
- [ ] Validate at least one real merchant can log in on a production-signed app.

---

## Notes

- For Android with `google_sign_in` 7.x, `serverClientId` must be the **Web OAuth client ID**.
- Keep credential files/JSON out of git unless intentionally required and sanitized.
