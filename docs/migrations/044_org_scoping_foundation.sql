-- 044_org_scoping_foundation.sql
--
-- Phase 2 multi-tenancy — foundation. Live-audited 13 July 2026 (see
-- docs/TODO.md Phase 2): cases.organisation_id already existed but was
-- NULL on 3 of 4 existing cases (backfilled live to the one existing org
-- before this migration, since there was no ambiguity — only one org
-- exists). surveyor_profiles (organisation_id + user_id) already existed
-- too, but had zero rows — backfilled live for the current single user.
--
-- Chose a join-based RLS approach (checking org via cases.organisation_id)
-- rather than denormalizing organisation_id onto every one of the ~50
-- case-scoped tables — far less schema churn, no risk of a denormalized
-- copy drifting from the real owner, and only cases.organisation_id
-- itself needs an app-code write path (createCase()), not every provider's
-- insert call.
--
-- vessels and principals_clients are the exception: they're NOT
-- case-scoped (a vessel or client can legitimately be referenced by
-- multiple cases), so they get their own organisation_id column here.

-- Now safe to enforce — backfilled live immediately before this file ran.
ALTER TABLE cases ALTER COLUMN organisation_id SET NOT NULL;

-- Single source of truth for "the calling user's org" — used by every RLS
-- policy touching org-scoped data. SECURITY DEFINER + stable so it's cheap
-- to call repeatedly inside a policy predicate.
CREATE OR REPLACE FUNCTION current_org_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT organisation_id FROM surveyor_profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

ALTER TABLE vessels ADD COLUMN IF NOT EXISTS organisation_id uuid REFERENCES organisations(id);
ALTER TABLE principals_clients ADD COLUMN IF NOT EXISTS organisation_id uuid REFERENCES organisations(id);

-- Backfill — only one org exists today, so every existing row belongs to
-- it, no ambiguity. A future second org means new vessels/clients that
-- org creates get its own id going forward (app-code write path needed —
-- see docs/TODO.md), existing rows are unaffected.
UPDATE vessels SET organisation_id = '6b43bb24-432f-4616-9b86-334107bc1660'
  WHERE organisation_id IS NULL;
UPDATE principals_clients SET organisation_id = '6b43bb24-432f-4616-9b86-334107bc1660'
  WHERE organisation_id IS NULL;

ALTER TABLE vessels ALTER COLUMN organisation_id SET NOT NULL;
ALTER TABLE principals_clients ALTER COLUMN organisation_id SET NOT NULL;
