-- 040_review_fixes.sql
--
-- Fixes from the 2026-07-13 max-effort code review of the overnight-work
-- branch (§3.14/§4.1 + 8 follow-on items).
--
-- 1) action_items (migration 039) shipped with no RLS at all — every other
--    new table this session (029, 031, 032) enables it. Live-audited: zero
--    policies existed, relrowsecurity was false. Matches the single
--    "authenticated full access" policy shape used by 032
--    (timeline_event_ratings) rather than cost_estimate_items' four-policy
--    split, since action_items has no need for asymmetric access.
ALTER TABLE action_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated full access" ON action_items;
CREATE POLICY "Authenticated full access" ON action_items
  FOR ALL TO public USING (auth.role() = 'authenticated');

-- 2) checklists.linked_section (and checklist_templates.linked_section) is
-- report_section_enum — a pre-existing enum from §"report section remarks"
-- (033), reused as the §4.4 auto-tick key. It has no 'attendance' value,
-- so case_completeness.dart's required 'attendance' completeness key
-- (present since §4.3) could never be matched by any checklist item, even
-- though 3 existing template rows are unambiguously about attendance being
-- recorded. Additive, backwards-compatible enum extension — existing rows
-- using other values are untouched.
ALTER TYPE report_section_enum ADD VALUE IF NOT EXISTS 'attendance';
