# Google Sign-In setup — fixing `ApiException: 10`

**Status (2026-07-16):** action pending — the Android OAuth client below must be
created in the Google Cloud Console before Google Sign-In will work on-device.
This is a **console-only** fix; there is no code change to make.

## Symptom

On the tablet, tapping "Sign in with Google" (which gates Correspondence,
Photos, and Action Items — all the Google Workspace integrations) fails with:

```
PlatformException / ApiException: 10   (DEVELOPER_ERROR)
```

## Root cause

`GoogleSignIn` in [lib/core/services/google_auth_service.dart](../lib/core/services/google_auth_service.dart)
is constructed with **only `scopes`** — no `serverClientId`, no `clientId` — and
there is **no `android/app/google-services.json`**. So the native Google Sign-In
SDK resolves the OAuth client purely by matching the running app's
**(package name + signing-certificate SHA-1)** against an **Android OAuth client**
registered in a Google Cloud project.

No such Android OAuth client exists yet, so the match fails → `ApiException: 10`.
Nothing in the Dart/Android code is wrong; the registration is simply missing.

## The fix — register an Android OAuth client

1. Open **Google Cloud Console** → **the project whose OAuth consent screen
   already carries the app's scopes** (Drive `drive.readonly` + `drive.file`,
   Gmail `gmail.readonly` + `gmail.send`, Photos `photoslibrary.appendonly` +
   `photoslibrary.sharing`). It **must be that same project** — a different one
   will not resolve the sign-in.
2. **APIs & Services → Credentials → + Create Credentials → OAuth client ID**.
3. **Application type: Android.** Fill in:

   | Field | Value |
   |---|---|
   | **Package name** | `com.example.marine_survey_app` |
   | **SHA-1 fingerprint** | `51:AF:5C:AD:44:97:8D:19:D7:3B:C5:1A:8C:2D:80:AA:30:62:8F:72` |

   (SHA-256, if ever prompted: `AC:19:F1:5E:F9:AD:A2:78:E9:4C:F4:36:14:54:6E:77:6E:66:2E:B1:56:45:00:04:96:74:6C:12:09:57:FE:81`)
4. **Save.** Propagation takes ~5 minutes. Then re-launch the app and sign in.

The SHA-1 above is this machine's **debug** keystore
(`~/.android/debug.keystore`, alias `androiddebugkey`). Because the `release`
build type is currently signed with the debug key too
([android/app/build.gradle.kts:32](../android/app/build.gradle.kts#L32)), this
**one fingerprint covers both `flutter run` (debug) and `flutter run --release`**
right now.

### Regenerating the SHA-1 (e.g. on another machine)

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android \
  | grep -E "SHA1|SHA-1"
```

Each developer machine has its **own** debug keystore, so each dev's SHA-1 must
be added to the same Android OAuth client (an OAuth client accepts multiple
fingerprints).

## Two follow-ups before release (do NOT block on these now)

1. **Package name is still the Flutter default** `com.example.marine_survey_app`.
   Google Play rejects `com.example.*`, so before store submission rename it to a
   real reverse-domain ID (e.g. `au.com.oceanomatics.marinesurvey`). That touches
   the Android namespace/`applicationId`, the manifest, and the iOS bundle ID —
   and it means creating a **new** Android OAuth client for the new package
   (re-registering package + SHA-1). Register the `com.example` client now to
   unblock; do the rename + re-register together at release-prep time so we only
   churn the OAuth client once.

2. **Real release keystore.** When a proper Play release keystore replaces the
   debug key, add that keystore's SHA-1 **and** the **Play App Signing** SHA-1
   (from Play Console → Setup → App signing) as additional fingerprints on the
   same Android OAuth client — otherwise Play-distributed builds hit
   `ApiException: 10` again.

## References

- Sign-in construction: [lib/core/services/google_auth_service.dart:26](../lib/core/services/google_auth_service.dart#L26)
- Signing config: [android/app/build.gradle.kts:28](../android/app/build.gradle.kts#L28)
- Walkthrough audit that surfaced this as the outstanding blocker:
  [docs/WALKTHROUGH_AUDIT_2026-07-16.md](WALKTHROUGH_AUDIT_2026-07-16.md)
