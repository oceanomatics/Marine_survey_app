-- 066_pi_opinion.sql — P&I / Expert: the Opinion/Conclusions register (Module C)
--
-- The genuinely-new data object for the P&I / expert module (spec §4.4): a
-- case has multiple discrete, reasoned opinion points, each tied back to its
-- basis (assumptions/material facts) and carrying the GPN-EXPT / Harmonised
-- Code cl.3 qualifiers (outside expertise; opinion not concluded for want of
-- data). Distinct from the existing factual `causation` — this is the reserved,
-- first-person professional opinion that fires only for the P&I matter type.
--
-- Case-scoped, org-scoped via case_id -> cases.organisation_id (the exact 045
-- "Org members full access" policy). updated_at via this DB's update_updated_at()
-- trigger fn (verified name, same as cs_sections/damage_items). Idempotent.

CREATE TABLE IF NOT EXISTS pi_opinion (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id           uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  heading           text,
  opinion_text      text NOT NULL,
  basis             text,                         -- assumptions / material facts relied on (cl.3(d))
  outside_expertise boolean NOT NULL DEFAULT false, -- cl.3(f) qualifier
  not_concluded     boolean NOT NULL DEFAULT false, -- cl.3(k) — insufficient data to conclude
  qualifier_note    text,                         -- cl.3(j) any other qualification on the opinion
  source_refs       jsonb NOT NULL DEFAULT '[]'::jsonb, -- optional ids of supporting observations/damage items
  sort_order        int NOT NULL DEFAULT 0,
  sync_status       text NOT NULL DEFAULT 'synced',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pi_opinion_case ON pi_opinion(case_id);

ALTER TABLE pi_opinion ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org members full access" ON pi_opinion;
CREATE POLICY "Org members full access" ON pi_opinion
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = pi_opinion.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = pi_opinion.case_id AND c.organisation_id = current_org_id()));

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_pi_opinion_updated_at ON pi_opinion;
    CREATE TRIGGER trg_pi_opinion_updated_at BEFORE UPDATE ON pi_opinion
      FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
END $$;
