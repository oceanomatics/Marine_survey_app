-- 046_rls_cleanup_leftover_policies.sql
--
-- Follow-up to 045 — full verification (simulated real user vs. simulated
-- unrelated user, across every affected table) caught two classes of gap
-- that 045's "DROP POLICY IF EXISTS \"Authenticated full access\"" missed,
-- because both predate that policy-naming convention and never got
-- cleaned up when it was introduced:
--
-- 1. case_nature_of_repairs had ROW LEVEL SECURITY disabled at the table
--    level entirely (relrowsecurity = false) — no policy, old or new,
--    was ever being enforced on it regardless of what existed in
--    pg_policies.
-- 2. 14 tables carry one or more EXTRA permissive policies under
--    different historical names (e.g. "auth_all", "auth users full
--    access", per-command "authenticated users can select/insert/..."
--    splits, table-specific names like "class_conditions_select") that
--    045's targeted DROP didn't match. Postgres ORs multiple permissive
--    policies together, so these leftover wide-open policies were still
--    granting full cross-org access even after 045's new restrictive
--    policy was added alongside them.
ALTER TABLE case_nature_of_repairs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own account_lines" ON account_lines;

DROP POLICY IF EXISTS "authenticated users can select assured_contacts" ON assured_contacts;
DROP POLICY IF EXISTS "authenticated users can insert assured_contacts" ON assured_contacts;
DROP POLICY IF EXISTS "authenticated users can delete assured_contacts" ON assured_contacts;

DROP POLICY IF EXISTS "authenticated users can upsert parties" ON case_parties;
DROP POLICY IF EXISTS "authenticated users can update parties" ON case_parties;
DROP POLICY IF EXISTS "authenticated users can select parties" ON case_parties;

DROP POLICY IF EXISTS "class_conditions_delete" ON class_conditions;
DROP POLICY IF EXISTS "class_conditions_update" ON class_conditions;
DROP POLICY IF EXISTS "class_conditions_select" ON class_conditions;
DROP POLICY IF EXISTS "class_conditions_insert" ON class_conditions;

DROP POLICY IF EXISTS "auth users manage organisations" ON organisations;

DROP POLICY IF EXISTS "auth users full access" ON repair_assignments;

DROP POLICY IF EXISTS "auth_all" ON repair_damage_items;

DROP POLICY IF EXISTS "Users can manage their own repair_documents" ON repair_documents;

DROP POLICY IF EXISTS "auth users full access" ON repair_periods;

DROP POLICY IF EXISTS "auth_all" ON repairs;

DROP POLICY IF EXISTS "authenticated users can insert attendances" ON survey_attendances;
DROP POLICY IF EXISTS "authenticated users can delete attendances" ON survey_attendances;
DROP POLICY IF EXISTS "authenticated users can select attendances" ON survey_attendances;

DROP POLICY IF EXISTS "auth users manage surveyor_profiles" ON surveyor_profiles;

DROP POLICY IF EXISTS "auth users can manage token_usage" ON token_usage;
DROP POLICY IF EXISTS "auth_select" ON token_usage;
DROP POLICY IF EXISTS "auth_insert" ON token_usage;

DROP POLICY IF EXISTS "Authenticated users can manage vessel_components" ON vessel_components;
