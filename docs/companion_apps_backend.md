# Companion Apps — Backend Reference

**Purpose of this file:** everything needed to build the two companion apps flagged 13 July 2026 — the **office-manager app** (§4.2: case + reviewer allocation, team oversight) and the **vendor/subscription console** (§4.8: manage which organisations are subscribed) — without re-deriving the schema, the RLS model, or the business logic from scratch. All three apps (this field-survey app plus the two companion apps) share **one Supabase project**.

If something here looks wrong, the migration files in `docs/migrations/` are the ground truth — this doc is a snapshot as of migration `050_companion_apps_schema.sql` (13 July 2026). Re-verify against the live schema before building on anything below; don't trust this file blindly once weeks have passed.

---

## 1. Which Supabase key each app should use

| App | Persona | Key | Why |
|---|---|---|---|
| Field-survey app (this repo) | Surveyor, in their own org | `anon` key + user JWT (`authenticated` role) | Every table's RLS policy scopes to the caller's own org via `current_org_id()` — this is the whole point, a surveyor must never see another org's data. |
| Office-manager app (§4.2) | Manager/admin, within **one** org | `anon` key + user JWT (`authenticated` role), same as above | A manager only ever needs to see/allocate within their own firm — normal RLS-scoped access is correct here too. The only new requirement is a `surveyor_profiles.role = 'admin'` check in the app's own UI/logic to gate who can allocate (RLS doesn't enforce this distinction today — see §4 below). |
| Vendor console (§4.8) | You, across **all** orgs | `service_role` key (bypasses RLS entirely) | The console's entire purpose is cross-tenant visibility (which firms are subscribed, usage across all of them) — that's incompatible with per-org RLS by definition. Get the `service_role` key from Supabase Dashboard → Project Settings → API → `service_role` secret. **Never ship this key in a client-distributed app** — the vendor console should be a server-side or trusted-desktop tool, not something installed on arbitrary devices. |

There is no service-role key checked into this repo's `.env` (only `SUPABASE_ANON_KEY` and a management-API `SUPABASE_ACCESS_TOKEN`, which is for schema/migration work via `api.supabase.com`, not data access) — fetch the `service_role` key fresh from the dashboard when building the vendor console.

---

## 2. Multi-tenancy / RLS — how it actually works

Built and live-verified 13 July 2026 (migrations `044`–`048`). See [[project_multitenancy_night_2026_07_13]] memory / `docs/TODO.md` Phase 2 for the narrative; this is the reference version.

### The anchor

- `cases.organisation_id` (NOT NULL) is the root of every scoping decision. Every case belongs to exactly one org.
- `surveyor_profiles.organisation_id` + `surveyor_profiles.user_id` is how a logged-in user's org is resolved.
- A Postgres helper function does this resolution for every RLS policy:
  ```sql
  CREATE OR REPLACE FUNCTION current_org_id() RETURNS uuid
  LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = public
  AS $$
    SELECT organisation_id FROM surveyor_profiles WHERE user_id = auth.uid() LIMIT 1;
  $$;
  ```
  If you build a new table and need it org-scoped, use `current_org_id()` in its policy — don't re-derive org membership by hand.

### Scoping patterns, by table shape

| Pattern | How it's scoped | Example tables |
|---|---|---|
| Direct `case_id` | `EXISTS (SELECT 1 FROM cases c WHERE c.case_id = t.case_id AND c.organisation_id = current_org_id())` | `documents`, `photos`, `correspondence`, `occurrences`, `damage_items`, `checklists`, `action_items`, and ~30 more |
| Own `organisation_id` column | `t.organisation_id = current_org_id()` directly, no join | `cases` itself, `vessels`, `principals_clients`, `token_usage` |
| One hop via a case-scoped parent | `EXISTS (... JOIN <parent> ... JOIN cases ...)` | `invoice_line_items` (via `invoices`), `repair_damage_items`/`repair_damage_links` (via `repairs`/`damage_items`), `repair_assignments` (via `damage_items`) |
| One hop via `vessels.organisation_id` | `EXISTS (SELECT 1 FROM vessels v WHERE v.vessel_id = t.vessel_id AND v.organisation_id = current_org_id())` | `machinery`, `vessel_components`, `class_conditions`, `psc_deficiencies` |
| Two hops via `report_outputs` → `cases` | `EXISTS (... JOIN report_outputs ... JOIN cases ...)` | `report_sections`, `report_versions` |
| User-scoped, not org-scoped | `user_id = auth.uid()` | `profiles` (per-user API keys), `external_accounts` (Equasis creds), `connected_accounts` |
| Global, no scoping at all | permissive for every authenticated user, shared across every org | `checklist_templates`, `clause_library` |

**Why join-based instead of denormalized `organisation_id` everywhere:** avoids a copy of the org id drifting out of sync with the real owner (the exact bug class a code-review pass found elsewhere in this app the same day), and means only `cases` (plus `vessels`/`principals_clients`, which legitimately aren't case-scoped — a vessel or client can be referenced by multiple cases) needed a real app-code write-path change. Everything else inherits its org from its case automatically.

**Why `vessels`/`principals_clients` are different:** a vessel or a client/principal contact can legitimately be referenced by more than one case (the same ship surveyed twice, the same P&I correspondent across many jobs), so they can't inherit their org purely from "the one case that references them" — they carry their own `organisation_id`, set at creation time.

### Testing methodology — reuse this for anything new

You can verify any RLS policy without running the app at all, by simulating a real authenticated session in raw SQL:

```sql
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '<user-uuid>';
SET LOCAL request.jwt.claim.role = 'authenticated';
SELECT count(*) FROM <table>;  -- or any query
```

**Both claims are required.** `auth.uid()` reads `request.jwt.claim.sub`; `auth.role()` reads `request.jwt.claim.role` — separately. Missing either makes any policy touching `auth.role()` (including ones on tables you're only joining through, like `cases`) silently deny everything with no error, which looks exactly like a real RLS bug until you notice the missing claim. This tripped up the first real-data pilot during the 13 July build.

To find any table with more than one active policy (a red flag — Postgres ORs permissive policies together, so an old leftover policy can silently reopen a hole a newer one was supposed to close):
```sql
SELECT tablename, count(*), array_agg(policyname)
FROM pg_policies GROUP BY tablename HAVING count(*) > 1;
```
And to check RLS is actually *enabled* at the table level (a policy can exist and do nothing if this is off):
```sql
SELECT relname FROM pg_class
WHERE relnamespace = 'public'::regnamespace AND relkind = 'r' AND relrowsecurity = false;
```
Both of these caught real, silent leaks during the 13 July build — run them after any RLS change, not just once.

---

## 3. Core schema reference

### `organisations` — the tenant

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `name`, `abn`, `address`, `phone`, `email`, `website` | text | Firm identity |
| `primary_colour`, `secondary_colour`, `logo_storage_path`, `logo_storage_paths` (array) | text | Branding, used in report letterhead |
| `wp_header_text`, `wp_cover_text`, `wp_cost_section_text`, `wp_footer_text`, `disclaimer_text`, `waiver_text` | text | Report boilerplate text, per-firm |
| `subscription_status` | enum: `trialing`\|`active`\|`past_due`\|`cancelled` | **New 13 July 2026**, default `trialing`. The one real org today is backfilled to `active`. |
| `plan_tier` | text, nullable | **New 13 July 2026.** Free text on purpose (not an enum) — plan naming is a business decision likely to change before the vendor console is actually built. Today: `'solo'` for the one real org. |
| `max_surveyors` | int, nullable | **New 13 July 2026.** Seat limit; null = unlimited. Not enforced anywhere yet — no code checks this. |
| `subscription_started_at` | timestamptz, nullable | **New 13 July 2026.** |

One row exists today (`6b43bb24-432f-4616-9b86-334107bc1660`, "OceanoServices").

### `surveyor_profiles` — org membership + role

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `organisation_id` | uuid → `organisations.id` | |
| `user_id` | uuid → `auth.users.id` | One row per (user, org) — today's schema doesn't support one user belonging to multiple orgs, hasn't been tested either way |
| `full_name`, `title`, `qualifications`, `email`, `phone` | text | Shown in reports (surveyor signature block) |
| `signature_storage_path` | text | |
| `role` | enum: `admin`\|`surveyor` | **New 13 July 2026**, default `surveyor`. `admin` = can allocate cases/reviewers, sees the whole org. **Not enforced by RLS today** — every org member can currently read/write every row org-wide (see the `surveyor_profiles` RLS policy: `organisation_id = current_org_id()`, no role check). The office-manager app must enforce the admin-only allocate action **in its own UI/query logic**, not assume the database blocks a non-admin. |

One row exists today, for the current single user, `role = 'admin'`.

### `cases` — the core entity

Full column list is long (49 columns as of migration 050) — the ones relevant to the two companion apps:

| Column | Type | Notes |
|---|---|---|
| `case_id` | uuid | PK |
| `organisation_id` | uuid → `organisations.id`, NOT NULL | Tenant anchor |
| `technical_file_no`, `title`, `claim_reference` | text | Case identity |
| `case_type` | enum: `hm`\|`pi`\|`cs`\|`dp_trials`\|`deficiency`\|`consulting` | |
| `status` | enum: `open`\|`prelim_issued`\|`advice_issued`\|`final_issued`\|`closed` | Case lifecycle — an office-manager dashboard's natural status filter |
| `assigned_surveyor` | uuid → `auth.users.id`, nullable | The attending surveyor. **Set once, at case creation, to whoever created it** (`createCase()` hardcodes it to the creating user) — there is no reassignment UI or API anywhere today. An office-manager app reassigning this needs to write it directly; nothing else in the app does. |
| `reviewing_surveyor_id` | uuid → `auth.users.id`, nullable | **New 13 July 2026.** The surveyor assigned to QC/review the case, meant to be set *before* review happens. Nothing sets or reads this yet except the schema/model — this is the office-manager app's primary allocation target. |
| `signed_off_attending` / `signed_off_reviewing` | bool | Dual sign-off gate for Final Report export — a case can't export "final" until both are true |
| `signed_off_reviewing_name` / `_at` / `_sig_path` | text/timestamptz/text | **Free text**, captured at the *moment* sign-off actually happened — deliberately not the same thing as `reviewing_surveyor_id` (an assignment can change hands before the review actually occurs; the sign-off record should reflect who actually signed, not who was assigned at some earlier point) |
| `client_id` / `principal_id` | uuid → `principals_clients.principal_id` | The instructing client/principal contact |
| `vessel_id` | uuid → `vessels.vessel_id` | |
| `instruction_date`, `date_of_first_attendance` | date | |

### `vessels` / `principals_clients` — org-owned, not case-owned

Both gained `organisation_id` (NOT NULL) on 13 July 2026 (migration 044), backfilled for existing rows. A vessel or client can be referenced by multiple cases within the same org — there's no cross-org sharing (each org has its own copy even if surveying the same real-world ship, by design, not yet revisited).

**No insert call site exists anywhere in the app for `principals_clients`** — it's only ever read via joins today. The first "add a new client" feature (wherever it lands) needs to set `organisation_id` on insert, same as `createCase()`/`createVessel()` already do (see `cases_provider.dart`, `vessel_provider.dart`).

---

## 4. §4.2 Office-manager app — case & reviewer allocation

**What already works, read-only:** `cases.assigned_surveyor` and the new `reviewing_surveyor_id` are both plain nullable uuid columns — an office-manager app can `UPDATE cases SET assigned_surveyor = ?, reviewing_surveyor_id = ? WHERE case_id = ?` today with zero new schema work, as an authenticated user whose `surveyor_profiles.role = 'admin'`.

**What's not enforced, and must be enforced in the app itself:**
- Nothing in the database stops a `role = 'surveyor'` user from reassigning cases via a direct API call — the RLS policy on `cases` only checks org membership, not role. If this matters (e.g., a rogue field surveyor reassigning cases), it needs either a stricter RLS policy (`organisation_id = current_org_id() AND (select role from surveyor_profiles where user_id = auth.uid()) = 'admin'` for UPDATE specifically, SELECT can likely stay open to all org members) or app-level trust that only the manager app's users touch this field. Not decided — flag for whoever scopes this properly.
- Workload visibility (how many open cases each surveyor has) is a `SELECT count(*) FROM cases WHERE assigned_surveyor = ? AND status != 'closed'` query away — no new schema needed, but no aggregation view exists yet either.

**Genuine gaps, need schema/decisions before building further:**
- No notion of "capacity" or "workload limit" per surveyor — `surveyor_profiles` has nothing like a max-concurrent-cases field.
- No audit trail of *who* reassigned a case or *when* — if that matters for a manager's oversight, it needs its own table (e.g. `case_assignment_history`), not built.
- Cross-surveyor QC/report-pipeline oversight and team-level KPIs (from the original §4.2 ask) have no data model at all yet beyond what's listed above — genuinely unscoped.

---

## 5. §4.8 Vendor console — subscription & usage

**What already works, read-only, via `service_role`:**
- `SELECT * FROM organisations` — every tenant, their `subscription_status`/`plan_tier`/`max_surveyors`, bypassing RLS entirely (since `service_role` ignores RLS by design).
- `SELECT * FROM surveyor_profiles WHERE organisation_id = ?` — the roster/seat count per org, to check against `max_surveyors`.
- `SELECT organisation_id, sum(cost_usd) FROM token_usage GROUP BY organisation_id` — real per-org AI cost, live and populated today (91 of 96 historical rows had no `case_id` but all have `organisation_id` as of migration 048). This is the closest thing to real usage data that exists.

**Billing model context (decided 8 July 2026, unchanged):** flat fee per case charged to the firm, **not** metered pass-through billing on token usage — `token_usage`/`cost_usd` is cost-tracking/insight for you as the operator, not the customer-facing bill itself. A subscription console showing "this org cost $X in AI usage this month" is an internal-margin view, not an invoice.

**Genuinely not built, need real decisions first:**
- No payment/invoicing integration exists (Stripe or equivalent) — no research done, same "don't commit to a provider blind" caution as §4.5's accounting-platform question.
- `profiles.anthropic_api_key` is per-**user** today, not per-org. If a subscription console should let you (the vendor) manage one billing-relevant API key per firm, this needs to move to `organisations` — open decision, affects both this console and the AI Cost Attribution work in Phase 2. Don't build the console's key-management screen against the current per-user shape without resolving this first, or it'll need rework.
- `analyst_usage` table exists (schema: `case_id, user_id, org_id, model, input_tokens, output_tokens, created_at`) but has **zero rows and nothing writes to it** — it's not a source of real data today despite matching what a usage report might want to query. Use `token_usage` instead; it's the one that's actually live.
- No role/permission model distinguishes "you, the vendor" from anyone else — the console's own auth (probably just you logging in with the `service_role` key locally, or a single hardcoded admin account) needs to be entirely separate from `surveyor_profiles.role`, which is scoped *within* an org, not across them.

---

## 6. Connected accounts (tangential, but touches both companion apps if they ever need it)

`connected_accounts` (migration 049) records which external account (Google/Microsoft) a surveyor has connected for which purpose (`correspondence`/`photos`/`documents`). User-scoped (`user_id = auth.uid()`), one row per (user, purpose). **Not wired into the app's actual Google Sign-In behavior yet** (see `docs/TODO.md` Phase 2) — a companion app should treat this as a record of intent, not a live session indicator. If the office-manager app ever needs to show "is this surveyor's mailbox connected," this table has the answer; the vendor console has no obvious use for it today.

---

## 7. Migration file index (source of truth)

Everything above is derived from these — read them directly if in doubt:

| File | What it did |
|---|---|
| `044_org_scoping_foundation.sql` | `current_org_id()` helper, `cases.organisation_id` → NOT NULL, `vessels`/`principals_clients.organisation_id` added + backfilled |
| `045_org_scoped_rls.sql` | The bulk RLS rewrite across ~50 tables |
| `046_rls_cleanup_leftover_policies.sql` | Fixed `case_nature_of_repairs` (RLS disabled at table level) + dropped 14 tables' worth of leftover permissive policies |
| `047_rls_cleanup_round2.sql` | Second sweep — 3 more genuine leaks, 2 harmless-but-redundant policies removed |
| `048_token_usage_org_scoping.sql` | `token_usage.organisation_id` (denormalized — no case-join path works for its many null-`case_id` rows) |
| `049_connected_accounts.sql` | The connected-accounts table itself |
| `050_companion_apps_schema.sql` | `cases.reviewing_surveyor_id`, `surveyor_profiles.role`, `organisations` subscription fields |
