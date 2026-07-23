# Windows workstation — setup & build brief

**Purpose:** a **third** workstation — a Windows machine for **your own hands-on
testing on real data**. Human-operated (not autonomous). Independent of the dev
box that builds the survey modules.

**Data:** points at **prod** (`mgftoofmcnxfshtailgn`) — same as the Linux machine.
Because it's human-operated, holding the prod app keys is fine (that's the
ENVIRONMENT.md rule: humans use prod, agents don't). **Do not run a full-auto
agent against prod from this box.**

---

## 0. What works vs. what's pending on Windows (set expectations)

With the committed `sqflite` desktop fix, the **data + report half works now**;
the **capture/Google half needs the desktop-plugin engineering** (in progress on
the Linux box, lands incrementally — pull to pick it up).

| Works today | Pending (desktop plugin work) |
|---|---|
| Cases, vessels, occurrences, damage, repairs | Camera capture |
| Checklists, **report builder**, house-style, clauses | ML Kit document scanner |
| Accounts, local DB (sqflite ffi) | Gmail / correspondence inbox (google_sign_in) |
| Pick existing photo/file (once wired) | Google Photos import, Drive |
|  | Biometric lock (until Windows Hello wired) |

---

## 1. Prerequisites (install once)

1. **Windows 10/11 (x64).**
2. **Git for Windows** — https://git-scm.com/download/win
3. **Visual Studio 2022** (Community is fine) with the **"Desktop development with
   C++"** workload — this provides the MSVC toolchain + CMake that Flutter Windows
   builds require. (Visual Studio *Code* is not enough; you need the C++ build
   tools.)
4. **Flutter SDK** — https://docs.flutter.dev/get-started/install/windows/desktop
   - Unzip, add `flutter\bin` to `PATH`.
   - `flutter config --enable-windows-desktop`
   - `flutter doctor` — resolve everything except Android/iOS (not needed here).
     "Visual Studio - develop Windows apps" must show a ✓.

---

## 2. Get the app

```powershell
git clone git@github.com:oceanomatics/Marine_survey_app.git
cd Marine_survey_app
```

If the `windows\` folder is already committed (it should be), skip the scaffold.
Otherwise run once:
```powershell
flutter create --platforms=windows .
```

---

## 3. Credentials — prod `.env` (app-runtime keys ONLY)

Create `.env` in the repo root (it's gitignored — never commit it). Put **only
what the app needs to run** — the account-wide `SUPABASE_ACCESS_TOKEN` is NOT
required to run the app and should **not** be placed here (least privilege):

```
SUPABASE_URL=https://mgftoofmcnxfshtailgn.supabase.co
SUPABASE_ANON_KEY=<prod anon key — from Supabase dashboard → Project Settings → API>
Client ID google : 890122120238-f60sd6lc6lkmfth15mtu8i6e3c6rkqhl.apps.googleusercontent.com
```

Grab the prod anon key from the Supabase dashboard (it's the public client key,
safe on a client machine). The Linux box's `.env` has it if you need a reference.

---

## 4. Run it

```powershell
flutter pub get
flutter run -d windows
```

You should get the app window pointing at prod. Create/verify cases, drive the
report builder, etc. Capture/Gmail features will error until the desktop-plugin
work lands — that's expected (see §0).

---

## 5. Build a deployable

```powershell
flutter build windows --release
# output: build\windows\x64\runner\Release\  (marine_survey_app.exe + DLLs — ship the whole folder)
```

Packaging as a single installer (MSIX / Inno Setup) is a later step; the Release
folder runs as-is on another Windows machine with the VC++ runtime.

---

## 6. The "all functions" work (tracked, not on this box)

Getting camera / scanner / Gmail / Photos / Drive working on Windows is
**cross-platform Dart engineering done on the Linux box** and delivered via git:

- **Desktop Google OAuth** (browser-loopback, replaces `google_sign_in`) — unlocks
  Gmail + Photos + Drive together. **Needs a "Desktop app" OAuth client ID
  registered in Google Cloud Console** (distinct from the Android client above) —
  see `docs/google_signin_setup.md` for the existing Android setup as a template.
- **Biometric** → `local_auth_windows` (Windows Hello).
- **Camera / scanner** → desktop file-import fallbacks.

As each lands on `main`, `git pull` on this box and rebuild. Track status in
`docs/OUTSTANDING.md`.

---

*Related: `docs/ENVIRONMENT.md` (environment model), `docs/google_signin_setup.md`
(OAuth client registration). Prod ref `mgftoofmcnxfshtailgn`; do NOT point
autonomous runs here.*
