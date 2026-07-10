-- 033_report_section_remarks.sql
--
-- TODO.md §2.18 — Section Editor: Auto-Populated, Edit-at-Source Redesign.
--
-- For the section types being converted to auto-populated/read-only (Vessel
-- Particulars, Attendees, Machinery Particulars, Accounts, Repair Times,
-- Documents on File — the six types where `report_sections.content` was
-- confirmed dead weight or drifting in the real docx export), the surveyor
-- loses the free-text `content` box as an override, but keeps a genuine
-- free-text `remarks` field for section-specific commentary that doesn't
-- belong on the underlying case screen. Additive, nullable — no backfill,
-- no impact on any existing row or the other (unconverted) section types.

ALTER TABLE report_sections ADD COLUMN IF NOT EXISTS remarks text;
