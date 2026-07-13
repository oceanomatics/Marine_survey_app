-- 037_photo_register_fields.sql
--
-- TODO.md §2.4 — Photo Register + Annexure E. Spec §4.8 requires Annexure E
-- to open with a register table (Photo No. | Location/Component |
-- Direction/Context | Date | Significance) followed by full-size captioned
-- photos — neither existed in the docx export before this (only inline
-- damage-item photos were ever rendered). These three fields are the
-- register's free-text columns not already covered by an existing field
-- (`taken_at` already supplies Date; `caption` is a separate free-text field
-- some existing photos already use and is kept as a fallback, not replaced).
ALTER TABLE photos
  ADD COLUMN IF NOT EXISTS location_component text,
  ADD COLUMN IF NOT EXISTS direction_context text,
  ADD COLUMN IF NOT EXISTS significance_to_claim text;
