-- 067_pi_injured_party.sql — P&I / Expert: Medical / Injured Parties register
--
-- Spec §4.6: a structured block recording the medical condition of injured
-- parties, for matters involving personal injury or loss of life. Off by
-- default; activated per case. Case-scoped, org-scoped via case_id (045
-- policy), update_updated_at trigger. Idempotent.

CREATE TABLE IF NOT EXISTS pi_injured_party (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id      uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  person_role  text,                    -- crew | passenger | third party | …
  person_name  text,                    -- nullable — may be withheld/anonymised
  condition    text,                    -- description of the medical condition
  info_source  text,                    -- where the information came from (cl. provenance)
  sort_order   int NOT NULL DEFAULT 0,
  sync_status  text NOT NULL DEFAULT 'synced',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pi_injured_party_case ON pi_injured_party(case_id);

ALTER TABLE pi_injured_party ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org members full access" ON pi_injured_party;
CREATE POLICY "Org members full access" ON pi_injured_party
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = pi_injured_party.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = pi_injured_party.case_id AND c.organisation_id = current_org_id()));

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_pi_injured_party_updated_at ON pi_injured_party;
    CREATE TRIGGER trg_pi_injured_party_updated_at BEFORE UPDATE ON pi_injured_party
      FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
END $$;
