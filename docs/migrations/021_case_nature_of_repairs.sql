-- 021_case_nature_of_repairs.sql
--
-- "Nature of the Repairs" — a new case-screen section presented just
-- before "Repair Periods" (§11.1 in the report, ahead of §11.2 Repair
-- Periods), per surveyor direction (5 July 2026): a set of early
-- indicator questions plus a free addable "anticipated sequence of
-- repairs" bullet list, usable from the very first attendance before any
-- repair period exists — "if we attend a vessel right after the
-- incident... there are at least some indications of where this claim is
-- going, and the extent of the general services that are predictably
-- needed."
--
-- One row per case (like case_background) rather than columns on `cases`
-- directly — 5 flag/comment pairs plus a jsonb list is enough fields that
-- a dedicated table keeps `cases` from growing further.

CREATE TABLE IF NOT EXISTS case_nature_of_repairs (
  case_id uuid PRIMARY KEY REFERENCES cases(case_id) ON DELETE CASCADE,
  drydocking_required boolean NOT NULL DEFAULT false,
  drydocking_comment text,
  assured_plan_formulated boolean NOT NULL DEFAULT false,
  assured_plan_comment text,
  further_inspections_planned boolean NOT NULL DEFAULT false,
  further_inspections_comment text,
  parts_long_lead_time boolean NOT NULL DEFAULT false,
  parts_lead_time_comment text,
  foreseeable_difficulties boolean NOT NULL DEFAULT false,
  foreseeable_difficulties_comment text,
  sequence_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);
