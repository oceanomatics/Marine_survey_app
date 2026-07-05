-- 017_case_advice_fields.sql
--
-- Relocates several report-output-scoped "Advice Summary" fields to the
-- case level, per surveyor direction (4 July 2026): "generally speaking...
-- I would like to have all the data input in the case page. The report
-- builder is only for drafting the paragraphs." These are facts about the
-- case (current cost estimate, whether a follow-up attendance is needed),
-- not things that should vary by which report is currently open — the
-- old per-report_output columns (report_outputs.advice_cost_amount etc.)
-- are left in place (unused going forward) rather than dropped, since
-- already-issued reports may reference them.
--
-- Additive only: nullable columns, no existing rows touched.

ALTER TABLE cases ADD COLUMN IF NOT EXISTS cost_includes_general_expenses boolean;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS cost_includes_towing text; -- 'yes' / 'no' / 'n_a'
ALTER TABLE cases ADD COLUMN IF NOT EXISTS survey_fee_reserve_hours numeric;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS survey_fee_reserve_expenses numeric;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS follow_up_required boolean;
ALTER TABLE cases ADD COLUMN IF NOT EXISTS follow_up_detail text;
