-- 048_token_usage_org_scoping.sql
--
-- token_usage (the live AI-usage-dashboard table — usage_tracker.dart /
-- usage_screen.dart; NOT the same as the unused analyst_usage table) has
-- no user_id column and case_id is null on 91 of 96 existing rows (calls
-- not tied to a specific case). 045's case-join RLS policy correctly
-- excludes null-case_id rows from any EXISTS match, which is technically
-- sound SQL but wrong here — it hid 91 legitimate rows from their own
-- org's Usage dashboard, confirmed via live simulated-user verification
-- after 045/046/047 landed. There is no relational path from a null
-- case_id back to an org, so (unlike every other table in this batch)
-- token_usage needs its own denormalized organisation_id column.
ALTER TABLE token_usage ADD COLUMN IF NOT EXISTS organisation_id uuid REFERENCES organisations(id);

UPDATE token_usage SET organisation_id = '6b43bb24-432f-4616-9b86-334107bc1660'
  WHERE organisation_id IS NULL;

ALTER TABLE token_usage ALTER COLUMN organisation_id SET NOT NULL;

DROP POLICY IF EXISTS "Org members full access" ON token_usage;
CREATE POLICY "Org members full access" ON token_usage
  FOR ALL TO authenticated
  USING (organisation_id = current_org_id())
  WITH CHECK (organisation_id = current_org_id());
