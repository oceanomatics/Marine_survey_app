-- 020_other_matters_clauses_oceano.sql
--
-- 018_other_matters_clauses.sql only seeded the two "Other Matters of
-- Relevance" candidate clauses for format_type = 'abl' — every other
-- comparable clause_type in clause_library exists for both 'abl' and
-- 'oceano_services' (the two actively-used formats; 'nordic' is a stub
-- with only 7 rows total and is left alone here). Cases using
-- 'oceano_services' saw "No candidate clauses configured" as a result.

INSERT INTO clause_library (format_type, clause_type, clause_label, clause_text, is_locked, editable_by)
VALUES
  ('oceano_services', 'other_matters_retain_damaged_parts', 'Other Matters — Retention of Damaged Parts',
   'The damaged parts and components have been retained on board / ashore for further analysis and inspection, pending instructions from Underwriters.',
   true, 'admin_only'),
  ('oceano_services', 'other_matters_prudent_uninsured', 'Other Matters — Prudent Uninsured',
   'The Assured is advised to act as a prudent uninsured in all respects pending confirmation of cover and further instructions from Underwriters.',
   true, 'admin_only')
ON CONFLICT DO NOTHING;
