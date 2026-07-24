-- 066: cue "content date" — the date of the SOURCE document a cue was
-- imported from (email sent date / report date), distinct from created_at
-- (when the cue was imported into the case). Nullable; null for cues typed
-- straight into the app. Mirrors the SQLite cache migration (app_database
-- schema version 17).
ALTER TABLE surveyor_notes ADD COLUMN IF NOT EXISTS content_date date;
