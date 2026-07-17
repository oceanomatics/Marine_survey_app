-- Migration 053: add issued_date + status to class_conditions
-- Surfaces issued-on date and open/closed status on the class-condition card
-- (Certificates & Class enhancements, 16 July sweep).
-- Run in Supabase SQL editor.

ALTER TABLE class_conditions
  ADD COLUMN IF NOT EXISTS issued_date date,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open';

-- status is a free 'open' / 'closed' flag; keep it constrained.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'class_conditions_status_chk'
  ) THEN
    ALTER TABLE class_conditions
      ADD CONSTRAINT class_conditions_status_chk
      CHECK (status IN ('open', 'closed'));
  END IF;
END $$;
