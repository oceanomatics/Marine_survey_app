-- 018_other_matters_clauses.sql
--
-- "Other Matters of Relevance" as a legal-clause ticklist (4 July 2026, per
-- surveyor direction): this section previously listed freeform surveyor_
-- notes tagged `other_matters`, but for the time being should instead list
-- optional standard legal clauses the surveyor ticks to include (e.g.
-- retention of damaged parts for analysis, prudent uninsured notice) — the
-- kind of standing legal statement that "could not be lodged somewhere
-- else." Section is omitted entirely from the rendered report when
-- nothing is ticked.
--
-- clause_type is a real Postgres enum (clause_type_enum) — new values must
-- be added via their own committed ALTER TYPE statement before they can be
-- used in an INSERT (same requirement noted for allegation_type_enum in an
-- earlier migration).

ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'other_matters_retain_damaged_parts';
ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'other_matters_prudent_uninsured';

-- Run as a separate statement/transaction from the ALTER TYPE above —
-- Postgres does not allow a newly-added enum value to be used in the same
-- transaction that added it.
INSERT INTO clause_library (format_type, clause_type, clause_label, clause_text, is_locked, editable_by)
VALUES
  ('abl', 'other_matters_retain_damaged_parts', 'Other Matters — Retention of Damaged Parts',
   'The damaged parts and components have been retained on board / ashore for further analysis and inspection, pending instructions from Underwriters.',
   true, 'admin_only'),
  ('abl', 'other_matters_prudent_uninsured', 'Other Matters — Prudent Uninsured',
   'The Assured is advised to act as a prudent uninsured in all respects pending confirmation of cover and further instructions from Underwriters.',
   true, 'admin_only');

-- Case-level tick list — which of the candidate "other matters" clauses
-- are included in this case's report. Additive, nullable, no data touched.
ALTER TABLE cases ADD COLUMN IF NOT EXISTS other_matters_clause_ids uuid[];
