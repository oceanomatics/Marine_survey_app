-- 027_vessel_breadth_draft_variants.sql
--
-- §2.17 finding #12 (docs/TODO.md Phase 0.1 row 12): the old single
-- breadth/breadth_qualifier and max_draft/draft_qualifier pair forced the
-- surveyor to pick one qualifier and lose the others, even though moulded
-- breadth / extreme breadth / beam (OA) — and load line draft / max draft —
-- are genuinely different physical measurements that get collected from
-- different documents at different times.
--
-- Additive only: new nullable columns, existing breadth/breadth_qualifier/
-- max_draft/draft_qualifier columns are untouched and continue to be
-- populated (derived from these new fields, priority order) so the report
-- builder's Dimensions row and AI-extraction round-trip keep working
-- unchanged. See vessel_particulars_screen.dart's Dimensions tab.
--
-- Applied directly via Supabase Management API 9 July 2026 (see
-- docs/TODO.md live progress log for the exact statement run).

ALTER TABLE vessels
  ADD COLUMN IF NOT EXISTS breadth_moulded double precision,
  ADD COLUMN IF NOT EXISTS breadth_extreme double precision,
  ADD COLUMN IF NOT EXISTS beam_oa double precision,
  ADD COLUMN IF NOT EXISTS draft_load_line double precision,
  ADD COLUMN IF NOT EXISTS draft_max double precision;
