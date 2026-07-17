-- Migration 055: detentions table
-- Port State Control / statutory detentions for a vessel. Listed on the
-- Certificates & Class screen; typically sourced from the Equasis report
-- (manual entry for now, auto-populate is a follow-up).
-- Run in Supabase SQL editor.

CREATE TABLE IF NOT EXISTS detentions (
  detention_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vessel_id     uuid NOT NULL REFERENCES vessels(vessel_id) ON DELETE CASCADE,
  detained_date date,
  released_date date,
  port          text,
  authority     text,
  reason        text,
  resolved      boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS detentions_vessel_id_idx
  ON detentions (vessel_id);

-- RLS: mirror the policy pattern used by class_conditions (migration 006).
ALTER TABLE detentions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "detentions_select" ON detentions;
DROP POLICY IF EXISTS "detentions_insert" ON detentions;
DROP POLICY IF EXISTS "detentions_update" ON detentions;
DROP POLICY IF EXISTS "detentions_delete" ON detentions;

CREATE POLICY "detentions_select"
  ON detentions FOR SELECT TO authenticated USING (true);

CREATE POLICY "detentions_insert"
  ON detentions FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "detentions_update"
  ON detentions FOR UPDATE TO authenticated USING (true);

CREATE POLICY "detentions_delete"
  ON detentions FOR DELETE TO authenticated USING (true);
