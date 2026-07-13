-- 050_companion_apps_schema.sql
--
-- Schema prep for the two companion apps flagged 13 July 2026 (see
-- docs/TODO.md §4.2 and §4.8, and docs/companion_apps_backend.md for the
-- full reference): the office-manager app (case + reviewer allocation)
-- and the vendor/subscription console. Additive only — every new column
-- is nullable or has a safe default, so the existing field-survey app
-- is completely unaffected.

-- ── §4.2 Office-manager app: reviewer allocation ────────────────────────
-- Mirrors the existing assigned_surveyor pattern (uuid -> auth.users,
-- not surveyor_profiles -- a companion app joins to surveyor_profiles via
-- user_id when it needs display name/qualifications, same as it already
-- would for assigned_surveyor). This is a real *assignment* made before
-- review happens; signed_off_reviewing_name (free text) stays as-is,
-- capturing who actually signed at the moment they did -- the two are
-- deliberately different (an assignment can change hands before sign-off;
-- the sign-off record should reflect who actually signed, not who was
-- originally assigned).
ALTER TABLE cases ADD COLUMN IF NOT EXISTS reviewing_surveyor_id uuid REFERENCES auth.users(id);

-- ── §4.2 Office-manager app: role model ─────────────────────────────────
-- Minimal two-role model: 'admin' can allocate cases/reviewers and see
-- every case in the org; 'surveyor' is field-work-only. Backfilled to
-- 'admin' for the existing single user (the firm's principal/owner).
CREATE TYPE surveyor_role_enum AS ENUM ('admin', 'surveyor');
ALTER TABLE surveyor_profiles ADD COLUMN IF NOT EXISTS role surveyor_role_enum NOT NULL DEFAULT 'surveyor';
UPDATE surveyor_profiles SET role = 'admin' WHERE user_id = '23cc31d5-5864-41ae-ba79-34e23393e6e3';

-- ── §4.8 Vendor console: subscription status on organisations ──────────
-- plan_tier is free text, not an enum -- plan names/tiers are a business
-- decision likely to change shape before this console is actually built,
-- and a text column avoids a migration just to add a new plan name.
-- Backfilled to 'active'/'solo' for the existing real org -- it's in
-- actual production use, not a trial.
CREATE TYPE subscription_status_enum AS ENUM ('trialing', 'active', 'past_due', 'cancelled');
ALTER TABLE organisations ADD COLUMN IF NOT EXISTS subscription_status subscription_status_enum NOT NULL DEFAULT 'trialing';
ALTER TABLE organisations ADD COLUMN IF NOT EXISTS plan_tier text;
ALTER TABLE organisations ADD COLUMN IF NOT EXISTS max_surveyors int;
ALTER TABLE organisations ADD COLUMN IF NOT EXISTS subscription_started_at timestamptz;

UPDATE organisations
SET subscription_status = 'active', plan_tier = 'solo', subscription_started_at = created_at
WHERE id = '6b43bb24-432f-4616-9b86-334107bc1660';
