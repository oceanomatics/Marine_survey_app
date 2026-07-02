-- Migration 012: Condition/Status, third-party confirmation, and 3-way
-- average status for damage items.
--
-- Implements Section 7 (Damage Description) spec in
-- docs/report_builder_editor_notes.md. Additive only — is_concerning_average
-- and condition_found are kept as-is; new report/docx code prefers the new
-- fields when present and falls back to the old ones otherwise.
--
-- Run in Supabase SQL editor

ALTER TABLE damage_items
  ADD COLUMN IF NOT EXISTS condition_status       text,   -- 'confirmed' | 'probable' | 'potential' | 'unrelated'
  ADD COLUMN IF NOT EXISTS confirmed_by            text[],
  ADD COLUMN IF NOT EXISTS confirmation_date       date,
  ADD COLUMN IF NOT EXISTS confirmation_method     text,
  ADD COLUMN IF NOT EXISTS average_status          text,   -- 'yes' | 'no' | 'partial'
  ADD COLUMN IF NOT EXISTS average_partial_detail  text;
