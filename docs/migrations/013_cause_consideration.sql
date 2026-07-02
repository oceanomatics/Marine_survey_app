-- Migration 013: Cause Consideration — three-voice separation + certainty level.
--
-- Implements Section 10 spec in docs/report_builder_editor_notes.md.
-- allegation_type_enum and clause_type_enum are real Postgres enums — the
-- ADD VALUE statements MUST be applied and committed before the statements
-- that follow (a freshly-added enum value can't be used in the same
-- transaction it was added in). Apply this file in two separate calls:
--
--   Call 1 — run only the two ALTER TYPE statements, then confirm they
--            committed (e.g. a fresh connection/call) before Call 2.
--   Call 2 — everything from the ALTER TABLE onward.
--
-- Run in Supabase SQL editor

ALTER TYPE allegation_type_enum ADD VALUE IF NOT EXISTS 'informal_allegation';
ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'cause_standard_remarks';

-- ── Call 2 (after the above has committed) ──────────────────────────────

ALTER TABLE occurrences
  ADD COLUMN IF NOT EXISTS owners_stated_cause        text,
  ADD COLUMN IF NOT EXISTS owners_stated_cause_source text,
  ADD COLUMN IF NOT EXISTS third_party_findings       jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS surveyors_assessment        text,
  ADD COLUMN IF NOT EXISTS certainty_level              text;

INSERT INTO clause_library (format_type, clause_type, clause_label, clause_text, is_locked, editable_by)
VALUES
  ('abl', 'cause_standard_remarks', 'ABL Internal — Standard Remarks (Consistent with Allegation)',
   'It is the opinion of the Undersigned that the damages detailed above may reasonably be attributed to a casualty of the nature of that alleged.', true, 'admin_only'),
  ('nordic', 'cause_standard_remarks', 'Nordic — Standard Remarks (Consistent with Allegation)',
   'It is the opinion of the Undersigned that the damages detailed above may reasonably be attributed to a casualty of the nature of that alleged.', true, 'admin_only'),
  ('oceano_services', 'cause_standard_remarks', 'Oceanoservices — Standard Remarks (Consistent with Allegation)',
   'It is the opinion of the Undersigned that the damages detailed above may reasonably be attributed to a casualty of the nature of that alleged.', true, 'admin_only');
