-- 025_drive_base_folder.sql
-- Adds a per-user configurable Google Drive base folder (root under which
-- Cases/ and Admin/ live). NULL means "directly under My Drive root".
-- Part of the Drive-backed unified storage work (docs/context_cue_system_review.md
-- successor — Google Workspace integration).

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS drive_base_folder TEXT;
