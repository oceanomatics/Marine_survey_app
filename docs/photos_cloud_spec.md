# Photos cloud model — corrected spec (17 July 2026)

Clarified during the manual sweep. Supersedes the old "sync photos to a shared
Google Photos album" feature, which nobody asked for and which caused the
403 saga (insufficient/deprecated `photoslibrary.sharing` scope).

## What the surveyor actually wants

1. **Backup → Google Drive, per attendance.** Photos saved into the case's
   Drive folder under a subfolder per attendance (or per set — e.g. a
   third-party batch from divers/crew). **This already exists** and runs on
   photo-add: `photo_provider` → `DriveStorageService.uploadCaseFile(category:
   photos, subFolders: [attendance label])`, taxonomy
   `Cases/{case}/Photos/{attendance label}/`.

2. **Import ← Google Photos.** Pull pictures *from* the surveyor's Google
   Photos into the case (phone shots, or a third-party set shared to their
   Photos). This does **not** exist yet (known gap).

## Build checklist

### Drop the unwanted export
- [ ] Remove `_syncToGooglePhotos` (shared-album export) from the Photos
      screen; remove `GooglePhotosService.shareAlbum` / album-share code.
- [ ] Drop the `photoslibrary.appendonly` + `photoslibrary.sharing` scopes from
      `GoogleAuthService` (no longer needed once export is gone). The
      16 Jul `ensureScopes(photosScopes)` guard becomes moot — remove/retarget.

### Repoint the cloud button to Drive
- [ ] The app-bar "cloud" action should **back up to Drive** — upload any photo
      with `driveFileId == null` into its per-attendance Drive folder (retry of
      the best-effort on-add upload, which silently skips when offline/not
      configured). Reuse `DriveStorageService.uploadCaseFile`.
- [ ] Thumbnail cloud badges should reflect **Drive** upload state
      (`driveFileId` present) rather than the old Google-Photos `syncStatus`.

### Add Google Photos import (Picker API)
- [ ] Use the **Google Photos Picker API** (the post-March-2025 sanctioned
      path): create a picking session, open Google's picker (webview/browser),
      poll for the selected `mediaItems`, download the bytes, add them as case
      photos (then they back up to Drive per the normal path).
- [ ] Scope: `https://www.googleapis.com/auth/photospicker.mediaitems.readonly`
      (Picker API), NOT the old `photoslibrary.readonly` (restricted in 2025).
- [ ] On import, let the surveyor assign the set to an attendance / mark it as
      a third-party set (ties into the grouping rework below).

### Related (from the 16 Jul Photos reports)
- [ ] Drop the **By Visit / By Inspection** tabs (redundant). Instead group /
      differentiate photos by **surveyor's own vs third-party** (divers, crew,
      etc.), possibly a manually-added set/period. Third-party sets are a
      natural fit for the import-from-Google-Photos path.
- [ ] A photo field duplicates the caption ("already submitted, same as
      caption") — dedupe.

## Notes
- Dropping Google Photos export removes all dependence on the deprecated
  Photos Library write/sharing scopes — only the Picker API (import) remains,
  which is the supported 2025 path.
- `e184217` (readable API errors) stays; `9b18200` (ensureScopes for Photos
  export) is superseded by this rework.
