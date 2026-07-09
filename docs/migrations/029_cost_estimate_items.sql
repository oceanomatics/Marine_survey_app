-- 027_cost_estimate_items.sql
--
-- Accounts — Cost Estimate redesign (§3.12 item 42, scope added 8 July
-- 2026): replaces the single "Estimated Cost" figure + yes/no "Cost
-- Inclusions" chips (General expenses / Towing costs) with editable line
-- items — category + free-text description + amount — so the estimate is
-- itemised/explainable, plus a free-text caveat/comment box.
--
-- `cases.cost_includes_general_expenses` / `cases.cost_includes_towing`
-- are deliberately NOT removed here — still read by the Advice Summary
-- card/rows (advice_summary_card.dart, advice_summary_rows.dart) in the
-- Report Builder. Only the Accounts screen's yes/no chip UI is retired.
--
-- `cases.estimated_repair_cost` is also kept (still read directly by
-- report_provider.dart `_buildCostStatusText` and docx_export_service.dart's
-- REPAIR COSTS block) — the app now keeps it in sync as the sum of this
-- new table's line items instead of a manually-typed figure, so those
-- report call sites need no changes.

CREATE TABLE IF NOT EXISTS case_cost_estimate_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  category text NOT NULL DEFAULT 'general_expenses',
  description text,
  amount numeric NOT NULL DEFAULT 0,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cost_estimate_items_case_id
  ON case_cost_estimate_items(case_id);

ALTER TABLE case_cost_estimate_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cost_estimate_items_select" ON case_cost_estimate_items;
DROP POLICY IF EXISTS "cost_estimate_items_insert" ON case_cost_estimate_items;
DROP POLICY IF EXISTS "cost_estimate_items_update" ON case_cost_estimate_items;
DROP POLICY IF EXISTS "cost_estimate_items_delete" ON case_cost_estimate_items;

CREATE POLICY "cost_estimate_items_select"
  ON case_cost_estimate_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "cost_estimate_items_insert"
  ON case_cost_estimate_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "cost_estimate_items_update"
  ON case_cost_estimate_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "cost_estimate_items_delete"
  ON case_cost_estimate_items FOR DELETE TO authenticated USING (true);

-- Free-text caveat/comment under the line items (e.g. "estimate still
-- dependent on drydock quote") — single value per case, plain column.
ALTER TABLE cases ADD COLUMN IF NOT EXISTS cost_estimate_comment text;
