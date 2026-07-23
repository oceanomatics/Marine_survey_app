-- 068_pi_relied_upon.sql — P&I / Expert: Facts & Documents Relied Upon (§4.3)
--
-- The structured list of the specific facts / documents the expert relied upon
-- (GPN-EXPT 5.2, Harmonised Code cl.3(d)/(g)). Each row is a free-text item
-- optionally soft-linked to a Document Vault entry (document_id — no FK, the
-- documents PK is non-standard and this is a selection, mirroring the
-- photos.linked_to_id soft-reference pattern). Case-scoped, org-RLS, trigger.
-- Idempotent.

CREATE TABLE IF NOT EXISTS pi_relied_upon (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id      uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  description  text NOT NULL,            -- the fact/document relied upon
  reference    text,                     -- doc reference / date, where relevant
  document_id  uuid,                     -- optional soft link to a Vault document
  sort_order   int NOT NULL DEFAULT 0,
  sync_status  text NOT NULL DEFAULT 'synced',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pi_relied_upon_case ON pi_relied_upon(case_id);

ALTER TABLE pi_relied_upon ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org members full access" ON pi_relied_upon;
CREATE POLICY "Org members full access" ON pi_relied_upon
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = pi_relied_upon.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = pi_relied_upon.case_id AND c.organisation_id = current_org_id()));

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_pi_relied_upon_updated_at ON pi_relied_upon;
    CREATE TRIGGER trg_pi_relied_upon_updated_at BEFORE UPDATE ON pi_relied_upon
      FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
END $$;
