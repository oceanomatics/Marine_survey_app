-- 027_repair_period_phase.sql
--
-- Adds a formal repair-phase concept (preliminary / temporary / permanent)
-- to repair_periods, flagged as a gap in docs/context_cue_system_review.md
-- §3.1 and confirmed needed by the surveyor (docs/TODO.md Phase 0.1 row 25,
-- 8 July 2026 walkthrough). Additive only — nullable, no backfill required.
--
-- Applied directly via the Supabase Management API on 9 July 2026.

ALTER TABLE repair_periods ADD COLUMN IF NOT EXISTS repair_phase TEXT;
