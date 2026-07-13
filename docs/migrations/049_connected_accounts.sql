-- 049_connected_accounts.sql
--
-- Phase 2 — data layer only (see docs/TODO.md Phase 2 "Connected
-- Accounts" section for the full picture). Lets a surveyor connect
-- separate external accounts per purpose — the concrete problem that
-- triggered this: professional Gmail for correspondence, a different
-- personal Google account for phone photos, with SharePoint/Outlook
-- planned later.
--
-- Deliberately user-scoped, not org-scoped — even within a multi-surveyor
-- firm, each surveyor connects their own accounts, they aren't shared
-- org-wide (unlike organisations/vessels/cases).
--
-- oauth_client_id is a per-surveyor "bring your own OAuth client"
-- override, nullable (default: use the app's one shared client).
-- Confirmed constraint (13 July 2026): google_sign_in's Android plugin
-- resolves its client entirely from google-services.json at build time —
-- this column can only be honoured on iOS/web with the current plugin.
--
-- NOT wired into google_auth_service.dart / gmail_service.dart /
-- google_photos_service.dart yet — those still use the single shared
-- sign-in exactly as before. The native google_sign_in plugin (Android
-- and iOS both) is architected around ONE active session per app
-- process; whether a second simultaneous Google session is even
-- achievable without a custom OAuth flow needs testing on a real device
-- with the surveyor present, not built blind unattended. This migration
-- only adds the place to record which account is connected for which
-- purpose — the actual account-switching behavior is the next step.
CREATE TYPE account_provider_enum AS ENUM ('google', 'microsoft');
CREATE TYPE account_purpose_enum AS ENUM ('correspondence', 'photos', 'documents');

CREATE TABLE IF NOT EXISTS connected_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider account_provider_enum NOT NULL,
  purpose account_purpose_enum NOT NULL,
  account_email text NOT NULL,
  oauth_client_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, purpose)
);

ALTER TABLE connected_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Own rows only" ON connected_accounts
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
