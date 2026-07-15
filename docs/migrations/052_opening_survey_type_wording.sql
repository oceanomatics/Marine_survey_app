-- 052_opening_survey_type_wording.sql
--
-- Surveyor flagged (14 July 2026) that the §1 opening paragraph reads
-- awkwardly: "This survey was conducted as a hull and machinery damage
-- survey." repeats "survey" twice in one sentence. He explicitly authorized
-- minor wording changes for readability as long as the same legal content
-- stays present (this is not one of the locked/verbatim legal clauses like
-- WP/waiver — just a factual statement of survey type).

UPDATE clause_library
SET clause_text = 'This was a hull and machinery damage survey.'
WHERE clause_type = 'survey_type_hull_and_machinery'
  AND format_type IN ('abl', 'oceano_services');
