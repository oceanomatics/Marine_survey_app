-- 064_cs_ahts.sql — C&S — AHTS data model (Module A)
--
-- See docs/addtional modules/IMPLEMENTATION_PLAN.md §4 and PHASE1_DETAILED_PLAN.md §1.
-- Run in the Supabase SQL editor. Idempotent (safe to re-run).
--
-- Two table kinds, two RLS postures (following migration 045's own rule):
--   * TEMPLATE tables (cs_template, cs_template_item) are SHARED REFERENCE
--     content — the AHTS skeleton, identical across orgs — so they are NOT
--     org-scoped, exactly like checklist_templates / clause_library which 045
--     deliberately leaves alone. Authenticated full access.
--   * PER-CASE tables (cs_inspection_item, cs_recommendation, cs_certificate)
--     hold one surveyor's findings and ARE org-scoped via
--     case_id -> cases.organisation_id, using the current_org_id() helper and
--     the exact "Org members full access" policy shape from migration 045.
--
-- cs_sections already exists (a minimal scaffold) and already carries the 045
-- org policy — here we only ADD COLUMNs to it.
--
-- Section rating (cs_sections.rating): auto-derived from the child
-- cs_inspection_item grades, with manual override (rating_overridden). Its
-- scale is its OWN three states — GOOD / SATISFACTORY_WITH_ISSUES /
-- UNSATISFACTORY — distinct from the item grades. Derivation lives in the app,
-- not a trigger, so it stays overridable. (PLC's rollup, 2026-07-21.)

-- ─────────────────────────────────────────────────────────────────────────
-- SHARED REFERENCE: the AHTS skeleton (not org-scoped)
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cs_template (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         text NOT NULL,
  vessel_type  text NOT NULL DEFAULT 'ahts',
  version      int  NOT NULL DEFAULT 1,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cs_template_item (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  template_id      uuid NOT NULL REFERENCES cs_template(id) ON DELETE CASCADE,
  section          text NOT NULL,                       -- '1.0' .. '11.0'
  parent_item      uuid REFERENCES cs_template_item(id) ON DELETE CASCADE,
  ref_no           text,                                -- "Ref" column in the report
  label            text NOT NULL,                       -- "Item" column
  guidance_text    text,
  grade_applicable boolean NOT NULL DEFAULT true,       -- false = header/narrative-only row
  gt_threshold     numeric,                             -- applicability by GT (nullable)
  sort_order       int NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_cs_template_item_template ON cs_template_item(template_id);
CREATE INDEX IF NOT EXISTS idx_cs_template_item_section  ON cs_template_item(template_id, section);

-- Reference-table RLS: any authenticated user reads/writes the shared skeleton
-- (mirrors the pre-045 "Authenticated full access" posture kept for
-- checklist_templates / clause_library).
ALTER TABLE cs_template      ENABLE ROW LEVEL SECURITY;
ALTER TABLE cs_template_item ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated full access" ON cs_template;
CREATE POLICY "Authenticated full access" ON cs_template
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Authenticated full access" ON cs_template_item;
CREATE POLICY "Authenticated full access" ON cs_template_item
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────
-- PER-CASE: extend the existing cs_sections scaffold
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE cs_sections ADD COLUMN IF NOT EXISTS template_section_ref text;
ALTER TABLE cs_sections ADD COLUMN IF NOT EXISTS vessel_type          text;
-- rating (existing text column) now holds the derived section rating:
--   GOOD | SATISFACTORY_WITH_ISSUES | UNSATISFACTORY
ALTER TABLE cs_sections ADD COLUMN IF NOT EXISTS rating_overridden boolean NOT NULL DEFAULT false;
-- cs_sections already has the 045 org policy — nothing else to do here.

-- ─────────────────────────────────────────────────────────────────────────
-- PER-CASE: the inspection register (the F1 register instance)
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cs_inspection_item (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id          uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  section_id       uuid REFERENCES cs_sections(section_id) ON DELETE SET NULL,
  template_item_id uuid REFERENCES cs_template_item(id) ON DELETE SET NULL,
  grade            text,                     -- SATISFACTORY | GOOD | UNSATISFACTORY | N_A
  remark           text,
  is_na            boolean NOT NULL DEFAULT false,
  sort_order       int NOT NULL DEFAULT 0,
  sync_status      text NOT NULL DEFAULT 'synced',   -- offline-ready (plan §10); unused while online-only
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cs_inspection_item_case    ON cs_inspection_item(case_id);
CREATE INDEX IF NOT EXISTS idx_cs_inspection_item_section ON cs_inspection_item(section_id);

-- ─────────────────────────────────────────────────────────────────────────
-- PER-CASE: §1.13 gating recommendations (the F4 findings instance)
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cs_recommendation (
  id             uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id        uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  ref_no         text,
  text           text NOT NULL,
  source_item_id uuid REFERENCES cs_inspection_item(id) ON DELETE SET NULL,
  status         text NOT NULL DEFAULT 'open',   -- open | closed
  close_date     date,
  sort_order     int NOT NULL DEFAULT 0,
  sync_status    text NOT NULL DEFAULT 'synced',
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cs_recommendation_case ON cs_recommendation(case_id);

-- ─────────────────────────────────────────────────────────────────────────
-- PER-CASE: §3.0 certificate register
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cs_certificate (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id      uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  cert_type    text NOT NULL,
  issued_date  date,
  issued_place text,
  expiry_date  date,
  status       text,                     -- e.g. valid | expired | n/a
  document_id  uuid,                      -- optional link to a Document Vault row
  sort_order   int NOT NULL DEFAULT 0,
  sync_status  text NOT NULL DEFAULT 'synced',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cs_certificate_case ON cs_certificate(case_id);

-- ─────────────────────────────────────────────────────────────────────────
-- RLS on the three per-case tables — the exact 045 "Org members full access"
-- shape (case_id -> cases.organisation_id = current_org_id()).
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE cs_inspection_item ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org members full access" ON cs_inspection_item;
CREATE POLICY "Org members full access" ON cs_inspection_item
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_inspection_item.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_inspection_item.case_id AND c.organisation_id = current_org_id()));

ALTER TABLE cs_recommendation ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org members full access" ON cs_recommendation;
CREATE POLICY "Org members full access" ON cs_recommendation
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_recommendation.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_recommendation.case_id AND c.organisation_id = current_org_id()));

ALTER TABLE cs_certificate ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Org members full access" ON cs_certificate;
CREATE POLICY "Org members full access" ON cs_certificate
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_certificate.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_certificate.case_id AND c.organisation_id = current_org_id()));

-- ─────────────────────────────────────────────────────────────────────────
-- updated_at triggers (mirror the existing trg_*_updated_at convention, e.g.
-- trg_cs_sections_updated_at). Assumes the shared set_updated_at() function
-- already exists in this database (it powers the other *_updated_at triggers).
-- ─────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
    DROP TRIGGER IF EXISTS trg_cs_inspection_item_updated_at ON cs_inspection_item;
    CREATE TRIGGER trg_cs_inspection_item_updated_at BEFORE UPDATE ON cs_inspection_item
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
    DROP TRIGGER IF EXISTS trg_cs_recommendation_updated_at ON cs_recommendation;
    CREATE TRIGGER trg_cs_recommendation_updated_at BEFORE UPDATE ON cs_recommendation
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
    DROP TRIGGER IF EXISTS trg_cs_certificate_updated_at ON cs_certificate;
    CREATE TRIGGER trg_cs_certificate_updated_at BEFORE UPDATE ON cs_certificate
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
