# Deployment / scale-readiness reference

Everything that must be reviewed, changed, or signed off **before** shipping the
app to real customers at scale (public Play Store / App Store release, multiple
paying orgs). This is a living checklist — update the **Status** column as items
land. It is deliberately standalone; link fixes back here rather than scattering
notes.

Last reviewed: **2026-07-16**. Current build target: internal / dev tablets only
(`com.example.marine_survey_app`, debug-signed).

**Legend** — Effort: S ≤½ day · M ~1–3 days · L ~1–2 weeks · XL multi-week/external.
Blocker = release cannot ship without it.

---

## 0. The short version (highest-impact, longest lead-time first)

1. **Google OAuth restricted-scope verification + CASA security assessment** (§4)
   — the single biggest cost and lead time. Gmail + Drive read scopes are
   *restricted*; Google requires app verification **and** an annual third-party
   security assessment (CASA) before the consent screen can go to Production for
   users outside your own domain. Start this **first** — it can take weeks and
   costs money.
2. **Android app identity + signing** (§1) — rename off `com.example.*`, real
   release keystore + Play App Signing, re-register the OAuth client.
3. **iOS is greenfield** (§2) — there is no `ios/` project at all today. If iPad
   is a target, the entire Apple pipeline (bundle ID, signing, provisioning,
   Info.plist usage strings, App Store review) is net-new work.
4. **Privacy policy, Terms, Play Data Safety, Google Limited-Use disclosure**
   (§5) — legally required and gate both store submission and OAuth verification.
5. **Multi-tenancy RLS live-verification against the real app** (§6) — RLS is
   built and JWT-simulated but never exercised by the running client across two
   real orgs. Must be proven before onboarding a second paying customer.

---

## 1. Android app identity & signing — Effort M · Blocker

| Item | Current state | Needed |
|---|---|---|
| `applicationId` / `namespace` | `com.example.marine_survey_app` (Flutter default) | Real reverse-domain, e.g. `au.com.oceanomatics.marinesurvey`. Play rejects `com.example.*`. Touches `android/app/build.gradle.kts` (both `namespace` + `applicationId`) and the manifest. |
| Release signing | `release` build type signs with the **debug** key (`build.gradle.kts:32`) | Generate a real upload keystore; configure `signingConfigs.release` via `android/key.properties` (gitignored). Enrol in **Play App Signing**. |
| OAuth client after rename | Android OAuth client registered for `com.example…` + debug SHA-1 (see [google_signin_setup.md](google_signin_setup.md)) | After the package rename **and** real keystore, register a **new** Android OAuth client for the real package + the release SHA-1 **and** the Play App Signing SHA-1. Old `com.example` client can be deleted. |
| App display name | `android:label="marine_survey_app"` (raw slug) | Set to "Marine Survey" (a proper label; `AppConfig.appName` already = "Marine Survey"). |
| Launcher icon / splash | **Default Flutter icon** (`ic_launcher.png` present; neither `flutter_launcher_icons` nor `flutter_native_splash` configured) | Add branded adaptive icon + splash; the default Flutter logo must not ship. |
| `minSdk` / `targetSdk` | Inherited defaults (`= flutter.minSdkVersion` / `flutter.targetSdkVersion`; `compileSdk = 36`) | Pin explicit values; `targetSdk` must meet Play's current minimum for new submissions; confirm `minSdk` satisfies `local_auth`/media plugins. |
| R8 / shrinking | **No explicit `isMinifyEnabled`** → not shrinking for release | Enable minify + resource shrinking for release; add ProGuard keep-rules for any plugin that needs them; smoke-test a release build (reflection-based crashes only surface in release). |

## 2. iOS / iPadOS — Effort XL (if targeted) · Not a blocker for Android-only launch

There is **no `ios/` project in the repo today.** If Apple devices are a target,
all of this is net-new: `flutter create` the iOS platform, bundle ID, Apple
Developer account, signing certs + provisioning profiles, `Info.plist` usage
descriptions (camera, microphone, photo library, location, Face ID — the app
requests all of these), a separate Google OAuth **iOS** client + `URL scheme`,
and App Store review (stricter than Play). Decide early whether iPad is in scope;
it roughly doubles the store-submission surface.

## 3. Android runtime permissions & justification — Effort S · Blocker (Data Safety)

Declared in the manifest and each needs a Play Data Safety declaration + an
in-app rationale where sensitive:

- `RECORD_AUDIO` (interviews / voice notes), `CAMERA` (survey photos),
  `ACCESS_FINE/COARSE_LOCATION`, `READ_MEDIA_IMAGES/VIDEO`, legacy
  `READ/WRITE_EXTERNAL_STORAGE` (scoped to old SDKs), `USE_BIOMETRIC`.
- Confirm each is actually used; drop any that aren't (unused sensitive
  permissions trigger Play review pushback).
- Location in particular: if only used opportunistically, confirm it's worth the
  Data Safety disclosure and prominent-consent burden.

## 4. Google OAuth — verification & security assessment — Effort XL · Blocker

**This is the big one.** Requested scopes (`google_auth_service.dart:26`):

| Scope | Google tier | Consequence |
|---|---|---|
| `gmail.readonly` | **Restricted** | App verification **+ annual CASA** security assessment |
| `gmail.send` | **Restricted** | Same |
| `drive.readonly` | **Restricted** | Same |
| `drive.file` | Non-sensitive (per-file) | No assessment for this one alone |
| `photoslibrary.appendonly` | Sensitive | Verification, no CASA |
| `photoslibrary.sharing` | Sensitive | Verification, no CASA |

While the consent screen is in **Testing**, only explicitly-added test users can
sign in (fine for now). To let arbitrary customers sign in, the screen must go to
**Production**, which requires:

- OAuth app **verification** (privacy policy URL, homepage, verified domain
  ownership, app logo, scope justifications, a demo video).
- For the restricted Gmail/Drive scopes: a **CASA (Cloud Application Security
  Assessment)** by a Google-approved third-party assessor — **annual, paid,
  multi-week**.
- Compliance with the **Google API Services User Data Policy / Limited Use**
  requirements (see §5): user data from these scopes can't be used to train
  generalised AI models, must be limited to providing the user-facing feature,
  etc. — this interacts with how correspondence/photos feed the AI features.

**Mitigation to evaluate:** can the feature set survive on **narrower** scopes?
e.g. `drive.file` (already requested) instead of `drive.readonly` avoids one
restricted scope; a Gmail send-only integration is lighter than full read. Every
restricted scope removed shrinks the CASA scope. Worth a deliberate scope audit
before committing to the assessment.

## 5. Legal / privacy / store compliance — Effort M · Blocker

- **Privacy Policy** + **Terms of Service** hosted at stable URLs — required by
  Play, App Store, *and* OAuth verification.
- **Play Data Safety** form — declare collection/handling of: audio, photos,
  precise location, email content (Gmail), files (Drive), contacts/stakeholder
  PII, and any diagnostics.
- **Google Limited Use disclosure** — explicit statement of how Gmail/Drive/Photos
  data is used, in both the privacy policy and (often) in-app.
- **Australian Privacy Act / APPs** (and GDPR if any EU data) — the app stores
  substantial client PII and case data; document lawful basis, retention,
  deletion/export on request.
- **Data residency** — Supabase project region vs. any client contractual
  requirement (also relevant to the STT vendor choice, see voice strategy notes).

## 6. Backend / Supabase production hardening — Effort M · Partial

- **Multi-tenancy RLS live-verification** — RLS is built and verified via
  simulated JWTs across 58 tables, but **never exercised by the real running
  app** with two distinct orgs. Prove cross-org isolation end-to-end from the
  client before a second paying customer. (See multi-tenancy night notes.)
- **`connected_accounts` not wired to `google_auth_service`** — built but not
  connected; confirm the intended account-linking path before relying on it.
- **Management token hygiene** — `SUPABASE_ACCESS_TOKEN` (full Management API,
  can run arbitrary SQL) lives in local `.env` only; confirmed **not** referenced
  in `lib/` and **not** bundled (`.env` is gitignored and not a Flutter asset).
  Keep it that way; rotate periodically; never add `.env` to `pubspec` assets.
- **Production DB config** — backups / PITR, connection pooling, rate limits,
  monitoring/alerting, and a staging project separate from production.
- **Session settings** — already configured for long-lived sessions +
  biometric re-open (server timebox/inactivity/refresh rotation). Re-confirm
  values are appropriate for a multi-org production posture.

## 7. Secrets & AI-key architecture — Effort M · Review

- Supabase URL + anon key are compile-time (`app_config.dart`), with the anon key
  also hardcoded as a default. That's acceptable — the anon key is public and
  RLS-gated — but for a clean release, inject via `--dart-define` in CI rather
  than relying on the in-source default.
- **Anthropic / OpenAI / Google API keys load at runtime from the DB** (per
  `profiles`, changeable from the Account screen) — so **no AI key is baked into
  the binary** (good). But the raw key still reaches the client and is sent from
  the device. For scale, evaluate a **server-side proxy** (Supabase Edge
  Function) so the provider key never leaves the backend; this also centralises
  rate-limiting and billing attribution. `token_usage` (org-scoped) already
  exists to support per-org metering/quotas — decide the billing model (BYO-key
  vs. bundled-and-metered) before onboarding paying orgs.

## 8. Data hygiene / PII in the repo — Effort S · Blocker for public repo

- **`docs/HSE docs/`** contains **real staff PII** (names + phone numbers in an
  Emergency Response Readiness Plan). Deliberately **not committed**. Decide:
  scrub to a template, or host privately outside the repo. Never commit as-is.
- **Debug feedback button** (screenshot+draw+note → `debug_feedback` table) is
  **debug-build only** — confirm it's compiled out of release (it should be).

## 9. Release engineering & quality — Effort M · Recommended

- **Remove the default template test** — `test/widget_test.dart` "Counter
  increments smoke test" fails on an unmodified branch (it's the Flutter
  boilerplate). Delete/replace so a green suite means green.
- **Crash / error reporting** — no automatic crash reporting yet (Sentry /
  Crashlytics). Add before a wide rollout; you can't debug field crashes from
  verbal reports.
- **Versioning & staged rollout** — `pubspec` is `1.0.0+1`; define a
  version/build-number bump discipline and use Play's staged rollout + internal
  testing track first.
- **CI** — automate `flutter analyze` + `flutter test` + a release-mode build on
  every push so signing/minify regressions surface before submission.

## 10. Product items explicitly deferred by the surveyor (NOT deployment blockers)

Tracked elsewhere; listed so they're not mistaken for release gaps:
- §6 Causation second pass, §17 STT vendor / stylus, §20 HSE module —
  deferred by decision; do **not** build unilaterally as part of deployment prep.

---

## Related docs

- [google_signin_setup.md](google_signin_setup.md) — the current `ApiException: 10`
  fix + the SHA-1 / package-rename mechanics referenced in §1 and §4.
- [WALKTHROUGH_AUDIT_2026-07-16.md](WALKTHROUGH_AUDIT_2026-07-16.md) — feature
  completeness audit (separate from release-readiness).
- [companion_apps_backend.md](companion_apps_backend.md) — office-manager +
  vendor-console companion apps (their own future deployment surface).
