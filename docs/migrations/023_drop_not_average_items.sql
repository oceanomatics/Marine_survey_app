-- 023_drop_not_average_items.sql
--
-- Work Not Concerning Average reintegrated into the unified context-cue
-- system (docs/context_cue_system_review.md §3.1, 5 July 2026) — cues
-- tagged CaseSection.notAverage, optionally linked to a repair period via
-- the existing linked_to_type/linked_to_id columns on surveyor_notes,
-- replace the bespoke per-period `not_average_items` jsonb list. Confirmed
-- zero repair periods had any items in this column at the time of this
-- migration — clean cutover, no data to migrate.

ALTER TABLE repair_periods DROP COLUMN IF EXISTS not_average_items;
