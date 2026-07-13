-- 041_checklist_attendance_retag.sql
--
-- Follow-up to 040 — a newly-added enum value can't be used in the same
-- transaction/migration call that adds it (Postgres restriction), hence
-- the separate file. Retags the only checklist_templates rows whose
-- item_text is unambiguously "attendance was recorded" so §4.4 auto-tick
-- can match case_completeness.dart's 'attendance' key. See 040 for why
-- the remaining unmatched completeness keys (occurrence, sign_off,
-- certificates, repair_periods, documentation, report_output) are
-- deliberately left unmapped rather than force-fit onto unrelated content.
UPDATE checklist_templates
SET linked_section = 'attendance'
WHERE item_text IN (
  'All attendees recorded',
  'All attendees recorded (name, company, rank, role)',
  'Attendees table complete and correct'
);
