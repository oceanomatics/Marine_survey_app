-- Migration 015: Attendee ordering (TODO.md §3.1 "Attendance Editor —
-- Attendee Ordering"). Adds a manual sort position so the surveyor can
-- drag-to-reorder attendees within an attendance record, instead of the
-- fixed role-based sort that was the only ordering available before.
--
-- Run in Supabase SQL editor / Management API.

ALTER TABLE attendees ADD COLUMN IF NOT EXISTS sort_order integer;

-- Backfill existing rows in insertion order, scoped per (case, attendance) —
-- matches "Default order: insertion order" in TODO.md §3.1.
WITH ranked AS (
  SELECT attendee_id,
         row_number() OVER (
           PARTITION BY case_id, attendance_id
           ORDER BY created_at
         ) AS rn
  FROM attendees
)
UPDATE attendees a
SET sort_order = ranked.rn
FROM ranked
WHERE a.attendee_id = ranked.attendee_id
  AND a.sort_order IS NULL;
