-- 026_photos_correspondence_supabase.sql
-- Photos and Correspondence were 100% local-only SQLite (per-device), so
-- metadata (captions, allocations, damage-item links, extracted summaries)
-- never left the device that created it. This mirrors them to Supabase,
-- matching the existing `documents` pattern (Supabase row = canonical
-- metadata; the actual file bytes live in Google Drive via drive_file_id).
--
-- Local SQLite keeps `local_path`/`thumbnail_path` (per-device cache) and
-- `sync_status` (per-device upload bookkeeping) — those are NOT mirrored
-- here since they're meaningless cross-device.

-- The pre-existing `photos` table (photo_id/file_path/tag_category/
-- report_section/use_in_report/damage_id schema) is confirmed orphaned —
-- zero app code references it (see project_photos_table_unused memory) and
-- it has 0 rows. Dropping it to recreate with the schema the app actually
-- needs, rather than shoehorning the new design onto unused prior art.
DROP TABLE IF EXISTS photos;

CREATE TABLE IF NOT EXISTS photos (
  id                TEXT PRIMARY KEY,
  case_id           UUID NOT NULL,
  caption           TEXT,
  photo_allocation  TEXT,
  linked_to_type    TEXT,
  linked_to_id      TEXT,
  attendance_id     UUID,
  taken_at          TIMESTAMPTZ NOT NULL,
  file_size_kb      NUMERIC,
  placement_mode    TEXT,
  photo_source      TEXT,
  drive_file_id     TEXT,
  thumbnail_drive_file_id TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated full access" ON photos
  FOR ALL TO public USING (auth.role() = 'authenticated');

CREATE TABLE IF NOT EXISTS correspondence (
  id              TEXT PRIMARY KEY,
  case_id         UUID NOT NULL,
  title           TEXT NOT NULL,
  sender          TEXT,
  recipient       TEXT,
  corr_date       DATE,
  file_type       TEXT NOT NULL DEFAULT 'pdf', -- 'eml' | 'pdf'
  summary         TEXT,
  body_text       TEXT,
  parties_json    TEXT,
  actions_json    TEXT,
  key_dates_json  TEXT,
  status          TEXT NOT NULL DEFAULT 'pending',
  file_size_kb    NUMERIC,
  drive_file_id   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE correspondence ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated full access" ON correspondence
  FOR ALL TO public USING (auth.role() = 'authenticated');
