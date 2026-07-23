-- 065_cases_case_year.sql
--
-- Explicit case year for the Google Drive folder name ("Year - TechNo - Vessel").
-- Previously the year was DERIVED at render time (date_of_first_attendance →
-- instruction_date → created_at → now), so a case opened in 2026 for a 2025
-- matter got a "2026 …" folder. This makes the year an explicit, safe field:
-- suggested at case creation (defaults to the current year), editable on the
-- case data screen. `driveFolderName` prefers case_year when set, falling back
-- to the old derivation otherwise. Nullable — existing cases keep deriving.

ALTER TABLE cases
  ADD COLUMN IF NOT EXISTS case_year int;
