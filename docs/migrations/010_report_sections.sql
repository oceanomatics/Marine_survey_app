-- Migration 010: wire up section persistence on the existing (unused)
-- report_sections table.
--
-- Fixes Critical Gap #1 in docs/report_builder_editor_notes.md — section
-- edits and GPN-AI review status were previously held only in memory and
-- lost on app restart.
--
-- report_sections already existed in the live DB (0 rows, orphaned —
-- provisioned early in the project, never wired to any Flutter code) with
-- a schema built around a 12-label report_section_enum and no surveyor
-- review field. The app's SectionType has 21 values, so the enum is
-- widened to plain text rather than extended label-by-label. Scoping is
-- output_id only (no case_id column) — report_outputs.case_id is
-- reachable via output_id if ever needed.
--
-- Run in Supabase SQL editor

ALTER TABLE report_sections
  ALTER COLUMN section_type TYPE text;

ALTER TABLE report_sections
  ADD COLUMN IF NOT EXISTS surveyor_review text;

ALTER TABLE report_sections
  ADD CONSTRAINT report_sections_output_section_uq
    UNIQUE (output_id, section_type);
