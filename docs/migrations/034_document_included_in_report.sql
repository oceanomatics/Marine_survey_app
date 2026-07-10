-- 034_document_included_in_report.sql
--
-- TODO.md §3.4 / §2.15 — Documentation: distinguish "enclosed in the
-- exported report" from "retained on file but not enclosed". Both
-- currently collapse into DocAvailability.enclosed, which the case-home
-- Documentation card and the report's K-1 "Documents Retained on File"
-- section both read without being able to tell them apart.
--
-- Chosen design (surveyor's explicit choice, 10 July 2026): keep
-- DocAvailability exactly as it is — do not add a new enum value — and
-- add a separate boolean instead. Only meaningful when
-- availability == 'enclosed'; ignored (but harmless) for requested/
-- not_available/tbc docs, which were never in the report's document list
-- to begin with.
--
-- Defaults to true so existing data's report output is unchanged by this
-- migration: every doc currently marked 'enclosed' is, today, already
-- rendered in the report's Documents Retained on File section — that
-- must keep being true until the surveyor explicitly un-enrols one via
-- the new toggle.

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS included_in_report boolean NOT NULL DEFAULT true;
