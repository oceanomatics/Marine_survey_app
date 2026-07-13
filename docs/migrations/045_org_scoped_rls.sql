-- 045_org_scoped_rls.sql
--
-- Phase 2 multi-tenancy — replaces every "Authenticated full access"
-- (auth.role() = 'authenticated', i.e. any logged-in user sees every org's
-- data) policy with real org-scoped isolation, using the current_org_id()
-- helper + cases.organisation_id anchor from migration 044.
--
-- Testing methodology (validated live before this migration, on vessels
-- and certificates as pilots): simulate a real authenticated session via
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claim.sub = '<user-uuid>';
--   SET LOCAL request.jwt.claim.role = 'authenticated';
-- (both the sub AND role claims are required — auth.role() reads
-- request.jwt.claim.role specifically, auth.uid() reads .sub; missing
-- either makes a pre-existing 'authenticated'-role-checking policy on a
-- joined table, e.g. cases, silently deny everything with no error, which
-- is exactly what happened on the first certificates pilot attempt before
-- this was caught.)
--
-- Scoping patterns, by table:
--   1. Direct case_id -> EXISTS via cases.organisation_id (the majority)
--   2. Own organisation_id column (vessels done in 044; principals_clients
--      here) -- vessels/clients aren't case-scoped, they can legitimately
--      be referenced by multiple cases
--   3. One hop via a case_id-bearing parent (repair_assignments,
--      repair_damage_items, repair_damage_links, invoice_line_items)
--   4. One hop via vessels.organisation_id (machinery, vessel_components,
--      class_conditions, psc_deficiencies)
--   5. Two hops via report_outputs -> cases (report_sections,
--      report_versions)
--   6. User-scoped, not org-scoped (profiles, external_accounts — these
--      hold per-user API keys / Equasis credentials, an org-mate should
--      NOT see another member's keys)
--   7. The org entity itself (organisations, surveyor_profiles)
--   8. Already had org_id directly (analyst_usage)
--   9. cases itself, the root anchor
--
-- Deliberately NOT touched: checklist_templates, clause_library — shared
-- reference content across all orgs, not per-tenant data.

DROP POLICY IF EXISTS "Authenticated full access" ON account_lines;
CREATE POLICY "Org members full access" ON account_lines
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = account_lines.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = account_lines.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON action_items;
CREATE POLICY "Org members full access" ON action_items
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = action_items.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = action_items.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON ai_generation_log;
CREATE POLICY "Org members full access" ON ai_generation_log
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = ai_generation_log.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = ai_generation_log.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON assured_contacts;
CREATE POLICY "Org members full access" ON assured_contacts
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = assured_contacts.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = assured_contacts.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON attendances;
CREATE POLICY "Org members full access" ON attendances
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = attendances.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = attendances.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON attendees;
CREATE POLICY "Org members full access" ON attendees
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = attendees.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = attendees.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON case_background;
CREATE POLICY "Org members full access" ON case_background
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = case_background.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = case_background.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON case_cost_estimate_items;
CREATE POLICY "Org members full access" ON case_cost_estimate_items
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = case_cost_estimate_items.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = case_cost_estimate_items.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON case_nature_of_repairs;
CREATE POLICY "Org members full access" ON case_nature_of_repairs
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = case_nature_of_repairs.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = case_nature_of_repairs.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON case_parties;
CREATE POLICY "Org members full access" ON case_parties
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = case_parties.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = case_parties.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON checklists;
CREATE POLICY "Org members full access" ON checklists
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = checklists.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = checklists.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON correspondence;
CREATE POLICY "Org members full access" ON correspondence
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = correspondence.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = correspondence.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON cs_sections;
CREATE POLICY "Org members full access" ON cs_sections
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_sections.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_sections.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON damage_items;
CREATE POLICY "Org members full access" ON damage_items
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = damage_items.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = damage_items.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON deficiency_items;
CREATE POLICY "Org members full access" ON deficiency_items
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = deficiency_items.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = deficiency_items.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON documents;
CREATE POLICY "Org members full access" ON documents
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = documents.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = documents.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON email_attachments;
CREATE POLICY "Org members full access" ON email_attachments
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = email_attachments.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = email_attachments.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON emails;
CREATE POLICY "Org members full access" ON emails
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = emails.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = emails.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON expenses;
CREATE POLICY "Org members full access" ON expenses
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = expenses.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = expenses.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON interviews;
CREATE POLICY "Org members full access" ON interviews
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = interviews.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = interviews.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON invoices;
CREATE POLICY "Org members full access" ON invoices
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = invoices.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = invoices.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON occurrences;
CREATE POLICY "Org members full access" ON occurrences
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = occurrences.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = occurrences.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON photos;
CREATE POLICY "Org members full access" ON photos
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = photos.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = photos.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON quick_captures;
CREATE POLICY "Org members full access" ON quick_captures
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = quick_captures.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = quick_captures.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON repair_documents;
CREATE POLICY "Org members full access" ON repair_documents
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = repair_documents.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = repair_documents.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON repair_periods;
CREATE POLICY "Org members full access" ON repair_periods
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = repair_periods.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = repair_periods.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON repair_records;
CREATE POLICY "Org members full access" ON repair_records
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = repair_records.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = repair_records.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON repairs;
CREATE POLICY "Org members full access" ON repairs
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = repairs.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = repairs.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON report_outputs;
CREATE POLICY "Org members full access" ON report_outputs
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = report_outputs.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = report_outputs.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON storage_folders;
CREATE POLICY "Org members full access" ON storage_folders
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = storage_folders.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = storage_folders.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON survey_attendances;
CREATE POLICY "Org members full access" ON survey_attendances
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = survey_attendances.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = survey_attendances.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON surveyor_notes;
CREATE POLICY "Org members full access" ON surveyor_notes
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = surveyor_notes.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = surveyor_notes.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON time_entries;
CREATE POLICY "Org members full access" ON time_entries
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = time_entries.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = time_entries.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON timeline_event_ratings;
CREATE POLICY "Org members full access" ON timeline_event_ratings
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = timeline_event_ratings.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = timeline_event_ratings.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON timeline_events;
CREATE POLICY "Org members full access" ON timeline_events
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = timeline_events.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = timeline_events.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON token_usage;
CREATE POLICY "Org members full access" ON token_usage
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = token_usage.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = token_usage.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON trials_tests;
CREATE POLICY "Org members full access" ON trials_tests
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = trials_tests.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = trials_tests.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON voice_notes;
CREATE POLICY "Org members full access" ON voice_notes
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = voice_notes.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = voice_notes.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON work_orders;
CREATE POLICY "Org members full access" ON work_orders
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = work_orders.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = work_orders.case_id AND c.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON principals_clients;
CREATE POLICY "Org members full access" ON principals_clients
  FOR ALL TO authenticated
  USING (organisation_id = current_org_id())
  WITH CHECK (organisation_id = current_org_id());

DROP POLICY IF EXISTS "Authenticated full access" ON repair_assignments;
CREATE POLICY "Org members full access" ON repair_assignments
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM damage_items p JOIN cases c ON c.case_id = p.case_id
    WHERE p.damage_id = repair_assignments.damage_id AND c.organisation_id = current_org_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM damage_items p JOIN cases c ON c.case_id = p.case_id
    WHERE p.damage_id = repair_assignments.damage_id AND c.organisation_id = current_org_id()
  ));

DROP POLICY IF EXISTS "Authenticated full access" ON repair_damage_links;
CREATE POLICY "Org members full access" ON repair_damage_links
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM repairs p JOIN cases c ON c.case_id = p.case_id
    WHERE p.repair_id = repair_damage_links.repair_id AND c.organisation_id = current_org_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM repairs p JOIN cases c ON c.case_id = p.case_id
    WHERE p.repair_id = repair_damage_links.repair_id AND c.organisation_id = current_org_id()
  ));

DROP POLICY IF EXISTS "Authenticated full access" ON invoice_line_items;
CREATE POLICY "Org members full access" ON invoice_line_items
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM invoices p JOIN cases c ON c.case_id = p.case_id
    WHERE p.invoice_id = invoice_line_items.invoice_id AND c.organisation_id = current_org_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM invoices p JOIN cases c ON c.case_id = p.case_id
    WHERE p.invoice_id = invoice_line_items.invoice_id AND c.organisation_id = current_org_id()
  ));

DROP POLICY IF EXISTS "Authenticated full access" ON repair_damage_items;
CREATE POLICY "Org members full access" ON repair_damage_items
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM repairs r JOIN cases c ON c.case_id = r.case_id
            WHERE r.repair_id = repair_damage_items.repair_id AND c.organisation_id = current_org_id())
    OR EXISTS (SELECT 1 FROM damage_items d JOIN cases c ON c.case_id = d.case_id
               WHERE d.damage_id = repair_damage_items.damage_id AND c.organisation_id = current_org_id())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM repairs r JOIN cases c ON c.case_id = r.case_id
            WHERE r.repair_id = repair_damage_items.repair_id AND c.organisation_id = current_org_id())
    OR EXISTS (SELECT 1 FROM damage_items d JOIN cases c ON c.case_id = d.case_id
               WHERE d.damage_id = repair_damage_items.damage_id AND c.organisation_id = current_org_id())
  );

DROP POLICY IF EXISTS "Authenticated full access" ON machinery;
CREATE POLICY "Org members full access" ON machinery
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = machinery.vessel_id AND v.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = machinery.vessel_id AND v.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON vessel_components;
CREATE POLICY "Org members full access" ON vessel_components
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = vessel_components.vessel_id AND v.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = vessel_components.vessel_id AND v.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON class_conditions;
CREATE POLICY "Org members full access" ON class_conditions
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = class_conditions.vessel_id AND v.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = class_conditions.vessel_id AND v.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON psc_deficiencies;
CREATE POLICY "Org members full access" ON psc_deficiencies
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = psc_deficiencies.vessel_id AND v.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = psc_deficiencies.vessel_id AND v.organisation_id = current_org_id()));

DROP POLICY IF EXISTS "Authenticated full access" ON report_sections;
CREATE POLICY "Org members full access" ON report_sections
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM report_outputs ro JOIN cases c ON c.case_id = ro.case_id
    WHERE ro.output_id = report_sections.output_id AND c.organisation_id = current_org_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM report_outputs ro JOIN cases c ON c.case_id = ro.case_id
    WHERE ro.output_id = report_sections.output_id AND c.organisation_id = current_org_id()
  ));

DROP POLICY IF EXISTS "Authenticated full access" ON report_versions;
CREATE POLICY "Org members full access" ON report_versions
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM report_outputs ro JOIN cases c ON c.case_id = ro.case_id
    WHERE ro.output_id = report_versions.output_id AND c.organisation_id = current_org_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM report_outputs ro JOIN cases c ON c.case_id = ro.case_id
    WHERE ro.output_id = report_versions.output_id AND c.organisation_id = current_org_id()
  ));

DROP POLICY IF EXISTS "Authenticated full access" ON profiles;
CREATE POLICY "Own rows only" ON profiles
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Authenticated full access" ON external_accounts;
CREATE POLICY "Own rows only" ON external_accounts
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Authenticated full access" ON organisations;
CREATE POLICY "Own org only" ON organisations
  FOR ALL TO authenticated
  USING (id = current_org_id())
  WITH CHECK (id = current_org_id());

DROP POLICY IF EXISTS "Authenticated full access" ON surveyor_profiles;
CREATE POLICY "Org members full access" ON surveyor_profiles
  FOR ALL TO authenticated
  USING (organisation_id = current_org_id())
  WITH CHECK (organisation_id = current_org_id());

DROP POLICY IF EXISTS "Authenticated full access" ON analyst_usage;
CREATE POLICY "Org members full access" ON analyst_usage
  FOR ALL TO authenticated
  USING (org_id = current_org_id())
  WITH CHECK (org_id = current_org_id());

DROP POLICY IF EXISTS "Authenticated full access" ON cases;
CREATE POLICY "Org members full access" ON cases
  FOR ALL TO authenticated
  USING (organisation_id = current_org_id())
  WITH CHECK (organisation_id = current_org_id());
