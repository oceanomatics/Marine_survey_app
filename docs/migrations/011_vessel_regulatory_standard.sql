-- Migration 011: Regulatory Standard selector + AMSA Vessel Use Class /
-- Service Category structured fields for DCV vessels.
--
-- Implements Section 3 spec (Vessel's Particulars) in
-- docs/report_builder_editor_notes.md — "Construction Standards" free text
-- is being replaced in the UI by a Regulatory Standard dropdown; the
-- construction_standard column itself is left untouched (existing data
-- preserved, just no longer surfaced for editing).
--
-- Run in Supabase SQL editor

ALTER TABLE vessels
  ADD COLUMN IF NOT EXISTS regulatory_standard      text,  -- 'convention' | 'dcv'
  ADD COLUMN IF NOT EXISTS amsa_vessel_use_class     text,  -- '1' | '2' | '3' | '4'
  ADD COLUMN IF NOT EXISTS amsa_service_category     text,  -- 'a' | 'b' | 'c' | 'd' | 'e'
  ADD COLUMN IF NOT EXISTS hull_material             text,  -- 'steel' | 'aluminium' | 'grp' | 'frp' | 'timber'
  ADD COLUMN IF NOT EXISTS unique_vessel_identifier  text,
  ADD COLUMN IF NOT EXISTS survey_certificate_no     text,
  ADD COLUMN IF NOT EXISTS equipment_survey_due      date,
  ADD COLUMN IF NOT EXISTS hull_survey_due           date,
  ADD COLUMN IF NOT EXISTS tail_shaft_survey_due     date;
