-- 047_rls_cleanup_round2.sql
--
-- Second sweep after 046 — checked every remaining multi-policy table's
-- actual qual (not just its name) before deciding drop vs. keep:
--
-- Genuine leaks (qual = literal `true` for any authenticated user),
-- dropped:
--   - case_cost_estimate_items: 4 leftover cost_estimate_items_* policies
--   - interviews: "Authenticated users manage interviews"
--   - timeline_events: "auth users can manage timeline_events"
--
-- Redundant but NOT a leak (already correctly scoped to auth.uid() =
-- user_id, functionally identical to the new "Own rows only" policy),
-- dropped anyway for one source of truth per table:
--   - external_accounts: "Users can manage their own external accounts"
--   - profiles: "Users can manage their own profile"
--
-- Deliberately left alone (not leaks, different-but-legitimate scoping):
--   - ai_generation_log: "Users manage their own AI log" scopes via
--     cases.assigned_surveyor = auth.uid() — narrower than org-scoping,
--     not a hole; revisit if/when "assigned surveyor" becomes a real
--     per-user distinction within a multi-surveyor org (currently no
--     UI ever sets assigned_surveyor to anyone but the creating user)
--   - analyst_usage: "service role only" has qual = false — grants
--     nothing to anyone, harmless no-op
--   - clause_library: "Anyone can read clauses" / "Admin can modify
--     clauses" — intentionally global shared reference content, not
--     per-tenant data (same as checklist_templates)
DROP POLICY IF EXISTS "cost_estimate_items_select" ON case_cost_estimate_items;
DROP POLICY IF EXISTS "cost_estimate_items_insert" ON case_cost_estimate_items;
DROP POLICY IF EXISTS "cost_estimate_items_update" ON case_cost_estimate_items;
DROP POLICY IF EXISTS "cost_estimate_items_delete" ON case_cost_estimate_items;

DROP POLICY IF EXISTS "Authenticated users manage interviews" ON interviews;

DROP POLICY IF EXISTS "auth users can manage timeline_events" ON timeline_events;

DROP POLICY IF EXISTS "Users can manage their own external accounts" ON external_accounts;
DROP POLICY IF EXISTS "Users can manage their own profile" ON profiles;
