-- 063_table_lead_in_clauses.sql
--
-- House-style: several report tables must be introduced by a lead-in sentence
-- (docs/house_style.md). These are format-specific wording, so they live in
-- clause_library keyed by (format_type, clause_type) like every other
-- house-style clause, resolved at render time via
-- AssembledReportData.clauseByType() (see TableLeadIns in report_provider.dart)
-- and shown in the Editor reference panel, the Preview tab and the Word export
-- alike.
--
-- Only FOUR tables needed a new clause here — Machinery, Certificates,
-- Conditions of Class and Damage Schedule previously had no lead-in anywhere.
-- The other introduced tables already had (and reuse) existing clauses / render
-- paths:
--   * Attending Representatives -> lead-in is built into buildAttendanceBlocks
--     (section_table_rows.dart), already shown in all three surfaces.
--   * Repair Times             -> existing clause `repair_times_guidance`.
--   * Documents Retained        -> existing clause `documents_on_file_header`.
-- Those existing clauses already render in the docx export; the code change in
-- this changeset additionally surfaces them in the Preview tab and Editor.
-- Vessel's Particulars deliberately has NO lead-in (bare table, house_style.md §3).
--
-- Seeded identically across oceano_services / abl / nordic for now (each format
-- can be refined independently later without a code change). Format-level,
-- locked (not per-case editable).
--
-- NOTE: clause_type is a Postgres enum (clause_type_enum). ADD VALUE must be
-- committed BEFORE the INSERT can reference it, so this is applied in two
-- passes (enum values, then rows).

-- ── Pass 1: new clause_type enum values ─────────────────────────────────────
ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'machinery_lead_in';
ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'certificates_lead_in';
ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'conditions_of_class_lead_in';
ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'damage_schedule_lead_in';

-- ── Pass 2: seed the lead-in wording for every format ───────────────────────
INSERT INTO clause_library
  (format_type, clause_type, clause_label, clause_text, is_locked, editable_by, version)
SELECT f.format_type::output_format_enum, c.clause_type::clause_type_enum,
       c.clause_label, c.clause_text, true, 'admin_only'::clause_editable_enum, 1
FROM (VALUES
  ('machinery_lead_in',
   'Table lead-in — Machinery Particulars',
   'The particulars of the machinery forming the subject of this claim are as follows:'),
  ('certificates_lead_in',
   'Table lead-in — Certificates',
   'The vessel''s certification was reviewed and is summarised below:'),
  ('conditions_of_class_lead_in',
   'Table lead-in — Conditions of Class',
   'The following Conditions of Class were recorded against the vessel:'),
  ('damage_schedule_lead_in',
   'Table lead-in — Damage Schedule',
   'The damage established on inspection is summarised in the schedule below:')
) AS c(clause_type, clause_label, clause_text)
CROSS JOIN (VALUES ('oceano_services'), ('abl'), ('nordic')) AS f(format_type)
ON CONFLICT DO NOTHING;
