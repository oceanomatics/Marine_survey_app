-- 019_other_matters_notes.sql
--
-- "Other Matters of Relevance" keeps the ticked-clause list
-- (other_matters_clause_ids, see 018_other_matters_clauses.sql) as the
-- primary report source, but per surveyor direction also needs a free-text
-- field for additional notes/clarifications (contractual points, etc.) that
-- aren't covered by the standard legal clauses — rendered after the ticked
-- clause text in the same report section. This is distinct from the
-- case-wide context cue register (surveyor_notes, report_section =
-- 'other_matters'), which stays reference-only for this section.

alter table cases
  add column if not exists other_matters_notes text;
