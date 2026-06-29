# Offline Sync Plan

## Goal
Allow specific cases to be pinned for offline use so the surveyor can work in the field without internet.

## Architecture: Case Snapshot Pattern

### What's already offline-capable
- **Photos** — stored on disk, metadata in SQLite `photos` table
- **Correspondence** — cached in SQLite `correspondence` table
- **Surveyor notes** — dual-stored in SQLite + Supabase with write queue (`sync_status`)

### What needs to be added

#### 1. Offline trigger
- **Manual toggle** in Settings (plus optional auto-detect via `connectivity_plus`)
- Stored in `SharedPreferences` as `offline_mode: bool`

#### 2. "Pin for offline" per case
- Button in the case list / case home screen
- Downloads all case-related Supabase rows into new SQLite snapshot tables
- Also downloads document and audio files to local storage

#### 3. New SQLite snapshot tables (prefix `snap_`)
These mirror Supabase tables for a specific case:
```
snap_cases
snap_vessels
snap_principals_clients
snap_case_background
snap_case_parties
snap_occurrences
snap_damage_items
snap_repairs
snap_repair_assignments
snap_repair_damage_links
snap_repair_periods
snap_timeline_events
snap_attendees
snap_survey_attendances
snap_interviews
snap_checklists
snap_documents        (metadata; file downloaded to cases/{id}/documents/)
snap_voice_notes      (metadata + transcript; audio downloaded to cases/{id}/audio/)
snap_quick_captures
```

Plus a control table:
```sql
offline_cases (
  case_id TEXT PRIMARY KEY,
  pinned_at TEXT,
  last_synced_at TEXT,
  sync_status TEXT  -- 'syncing' | 'ready' | 'error'
)
```

#### 4. Provider routing
Each Riverpod provider checks an `offlineModeProvider`:
- **Online** → read/write Supabase (current behaviour)
- **Offline** → read from `snap_*` tables; writes queued in SQLite with `sync_status = 'pending_upsert'`

#### 5. Write queue + sync
- Offline writes tagged `pending_upsert` or `pending_delete` in snapshot tables
- On connectivity restore (or manual "Sync now"), flush queue to Supabase
- Surveyor notes already follow this pattern — extend to other tables

#### 6. File downloads when pinning
- Photos: already local, skip
- Documents: download from Supabase Storage `documents` bucket → `cases/{id}/documents/`
- Voice notes: download from `audio` bucket → `cases/{id}/audio/`
- Update `local_path` in snapshot table after download

## Implementation Steps (in order)

- [ ] Extend SQLite schema (v11 migration): add `offline_cases` + all `snap_*` tables
- [ ] `OfflineCaseService` — `pinCase()`, `unpinCase()`, `syncCase()`, `flushWriteQueue()`
- [ ] `offlineModeProvider` (SharedPreferences-backed) + `offlineCasesProvider`
- [ ] Provider routing layer — each feature provider reads `offlineModeProvider` and switches data source
- [ ] Write queue extension — apply `pending_upsert` pattern to all snapshot tables
- [ ] File download on pin (documents + audio)
- [ ] UI: pin button in case list, offline badge in app bar, "Sync now" in Settings
- [ ] Conflict resolution strategy (last-write-wins for now; flag conflicts for review later)

## Decisions Made
- **Trigger:** Manual toggle (with future auto-detect option)
- **Scope:** DB records + files (documents + audio downloaded locally)
- **Write mode:** Read + write with offline queue, synced on reconnect

## Related
- Existing write queue pattern: `lib/core/database/app_database.dart` (surveyor_notes sync_status)
- Connectivity: `connectivity_plus` already in pubspec
- File storage root: `getApplicationDocumentsDirectory()/cases/{case_id}/`
