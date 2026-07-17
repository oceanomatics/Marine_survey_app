-- 062_repair_period_sea_trial.sql
--
-- Post-repair sea trial (16 July 2026 sweep — surveyor: "we have not managed
-- a post repair seatrial entry").
--
-- Adds a single optional sea-trial record per repair period, stored as JSONB
-- so the shape can evolve without further DDL. Shape (all keys optional):
--   {
--     "date": "2026-07-14",           -- ISO date the trial was run
--     "duration_hours": 3.5,          -- trial duration in hours
--     "location": "Off Fremantle",    -- where the trial took place
--     "parameters": [                 -- observed parameters
--       {"label": "Engine load", "value": "85 %"},
--       {"label": "RPM",         "value": "750 rpm"},
--       {"label": "Speed",       "value": "14.2 kn"}
--     ],
--     "satisfactory": true,           -- overall outcome yes/no
--     "notes": "…"                    -- free-text outcome / observations
--   }
--
-- The budget-estimate quantity/unit/unit_rate breakdown added in the same
-- sweep needs NO migration: budget_items is already a JSONB column and the
-- new keys are additive within each element.
--
-- NOT YET RUN.

ALTER TABLE repair_periods
  ADD COLUMN IF NOT EXISTS sea_trial jsonb;

COMMENT ON COLUMN repair_periods.sea_trial IS
  'Optional post-repair sea trial record (date, duration_hours, location, '
  'parameters[], satisfactory, notes). Single object per period. Added '
  '2026-07-16, migration 062.';
