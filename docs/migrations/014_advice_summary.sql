-- Migration 014: Advice Summary (Page 2 structured table) — per-report-output
-- fields for the Advice Summary spec in docs/report_builder_editor_notes.md
-- ("Section: Executive Summary (Advice Summary Table)"). TODO.md §2.6.
--
-- Advice Summary is per report_output (not per case) because several fields
-- (status of repairs, cost figures) legitimately change across successive
-- reports on the same case (Preliminary -> Progress -> Final).
--
-- Run in Supabase SQL editor / Management API.

-- NOTE: no separate "UCR / Reference" column here — that row in the
-- rendered Advice Summary table reuses the existing case-level
-- `cases.claim_reference` field (already editable in Edit Case Details as
-- "Claim Reference") rather than duplicating it per report-output. An
-- `advice_ucr_reference` column was briefly added and then dropped in this
-- same session once the duplication was noticed.
ALTER TABLE report_outputs
  ADD COLUMN IF NOT EXISTS advice_nature_of_casualty      text,
  ADD COLUMN IF NOT EXISTS advice_description_of_damage   text,
  ADD COLUMN IF NOT EXISTS advice_nature_of_repairs       text,
  ADD COLUMN IF NOT EXISTS advice_status_of_repairs       text,   -- 'complete'|'ongoing'|'awaiting'|'deferred'|'not_commenced'
  ADD COLUMN IF NOT EXISTS advice_status_of_repairs_detail text,
  ADD COLUMN IF NOT EXISTS advice_cost_amount             numeric,
  ADD COLUMN IF NOT EXISTS advice_cost_currency           text,
  ADD COLUMN IF NOT EXISTS advice_cost_includes_general_expenses boolean,
  ADD COLUMN IF NOT EXISTS advice_cost_includes_towing    text,   -- 'yes'|'no'|'n_a'
  ADD COLUMN IF NOT EXISTS advice_fee_reserve_hours       numeric,
  ADD COLUMN IF NOT EXISTS advice_fee_reserve_expenses    numeric,
  ADD COLUMN IF NOT EXISTS advice_follow_up_required      boolean,
  ADD COLUMN IF NOT EXISTS advice_follow_up_detail        text,
  ADD COLUMN IF NOT EXISTS advice_remarks                 text,
  ADD COLUMN IF NOT EXISTS advice_confirmed               boolean NOT NULL DEFAULT false;
