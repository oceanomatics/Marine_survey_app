-- 069_dp_trial_programme.sql — DP FMEA: trial-programme record + vessel DP fields
--
-- One programme-level record per dp_trials case (overall result, operating
-- modes, the rules/IMCA basis, and the programme revision), plus the DP
-- context fields on the vessel. All additive. Case-scoped record is org-scoped
-- via case_id (045 policy) with the update_updated_at trigger. Idempotent.

-- ── programme record (one per case) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS trial_programmes (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id          uuid NOT NULL UNIQUE REFERENCES cases(case_id) ON DELETE CASCADE,
  applicable_rules text,                    -- class rules + IMCA refs used as basis
  operating_modes  text,                    -- e.g. "4-split, 2-split"
  overall_result   text,                    -- compliant | compliant_with_findings | non_compliant
  revision         int NOT NULL DEFAULT 0,
  sync_status      text NOT NULL DEFAULT 'synced',
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_trial_programmes_case ON trial_programmes(case_id);

ALTER TABLE trial_programmes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org members full access" ON trial_programmes;
CREATE POLICY "Org members full access" ON trial_programmes
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = trial_programmes.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = trial_programmes.case_id AND c.organisation_id = current_org_id()));

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_trial_programmes_updated_at ON trial_programmes;
    CREATE TRIGGER trg_trial_programmes_updated_at BEFORE UPDATE ON trial_programmes
      FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
END $$;

-- ── DP context on the vessel (additive columns; no UI change to the H&M
--    vessel screen — surfaced in the DP Programme screen) ─────────────────
ALTER TABLE vessels ADD COLUMN IF NOT EXISTS dp_equipment_class text;   -- 1 | 2 | 3
ALTER TABLE vessels ADD COLUMN IF NOT EXISTS wcfdi_statement    text;   -- worst-case failure design intent
ALTER TABLE vessels ADD COLUMN IF NOT EXISTS redundancy_concept text;
ALTER TABLE vessels ADD COLUMN IF NOT EXISTS fmea_doc_ref       text;
ALTER TABLE vessels ADD COLUMN IF NOT EXISTS fmea_revision      text;
