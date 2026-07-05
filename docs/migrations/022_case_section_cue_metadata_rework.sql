-- 022_case_section_cue_metadata_rework.sql
--
-- Part of the context-cue-system review (docs/context_cue_system_review.md).
-- Two changes bundled together since both touch surveyor_notes and are being
-- done in the same pass:
--
-- 1. `report_section` was misnamed — it allocates a cue to a case-screen
--    section, not a report section (of 14 tag values, only 5 are ever read
--    by the report builder). Renamed to `case_section`. This also sets up
--    the eventual distinction from a real `report_section` concept once
--    multi-format support needs an explicit case_section -> report_section
--    mapping per output format.
--
-- 2. Cue metadata rework: `category` (NoteCategory: Observation, Measurement,
--    Follow-up, Interview, Technical, Operations, Previous Works, Policy,
--    Invoicing, General) wasn't earning its keep and is retired, replaced by
--    two independent axes (`nature_of_content`, `evidentiary_weight`) plus a
--    new `origin` field (who the cue's content comes from). `resolved_at`
--    was a vestigial field from an earlier intent — repurposed into
--    `lost_relevance_at`, auto-set when a cue's priority is set to
--    'ignored' rather than being a separately-tracked state.
--
-- Only 1 row exists in surveyor_notes at the time of this migration (still
-- single-user testing) — clean cutover, no attempt to preserve old
-- `category` values into the new columns.

ALTER TABLE surveyor_notes RENAME COLUMN report_section TO case_section;
ALTER TABLE surveyor_notes RENAME COLUMN resolved_at TO lost_relevance_at;
ALTER TABLE surveyor_notes DROP COLUMN category;

ALTER TABLE surveyor_notes ADD COLUMN nature_of_content text;
ALTER TABLE surveyor_notes ADD COLUMN evidentiary_weight text;
ALTER TABLE surveyor_notes ADD COLUMN origin text;
