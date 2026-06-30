-- Migration 006: fix class_conditions RLS — add missing write policies
-- Run in Supabase SQL editor

DROP POLICY IF EXISTS "class_conditions_select" ON class_conditions;
DROP POLICY IF EXISTS "class_conditions_insert" ON class_conditions;
DROP POLICY IF EXISTS "class_conditions_update" ON class_conditions;
DROP POLICY IF EXISTS "class_conditions_delete" ON class_conditions;

CREATE POLICY "class_conditions_select"
  ON class_conditions FOR SELECT TO authenticated USING (true);

CREATE POLICY "class_conditions_insert"
  ON class_conditions FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "class_conditions_update"
  ON class_conditions FOR UPDATE TO authenticated USING (true);

CREATE POLICY "class_conditions_delete"
  ON class_conditions FOR DELETE TO authenticated USING (true);
