# ENVIRONMENT.md — Database & Autonomy Architecture

> Drop this file at the repo root of each project. It defines the target
> dev/prod architecture, gives an inspection checklist to audit the project's
> current state, and sets the rules an autonomous agent (Claude Code in
> full-auto) must follow when touching the database.
>
> Fill in the `<< ... >>` placeholders per project.

---

## 1. Project identity

| Field | Value |
|---|---|
| App name | `marine_survey_app` |
| Repo | `github.com/oceanomatics/Marine_survey_app` |
| Stack | Flutter / Supabase / Riverpod / GoRouter / FCM |
| Current phase | `pre-production` (pre-production \| production) |

> **Concrete setup (filled in 23 July 2026):** dev/prod split is now live. See the
> resolved table in §2 and the "current state" note below it.

---

## 2. Environment model

The rule is **one Supabase project per environment**, never two databases
inside a single project. Isolation on Supabase lives at the *project* level:
each project is its own Postgres instance with its own keys and API surface.
Two databases in one project share the same service-role key, so a full-auto
agent holding that key can reach both — which defeats the isolation.

| Environment | Supabase project | Who touches it | Keys the agent may hold |
|---|---|---|---|
| **dev** | `Marine Survey App - dev` — ref `jcuwfjyyqsjnmqxpqlbt` | Agent runs full-auto: migrations, reshaping, seeding | dev anon + dev service-role + dev DB URL (throwaway data only) |
| **prod** | `Marine Survey App` — ref `mgftoofmcnxfshtailgn` | Humans apply reviewed migrations only | **none** — agent never holds the account-wide access token |

> **Current state (23 July 2026):** Both projects live in the same org
> (`oceanomatics's dev team`, Free plan), ap-southeast-2, both PostgreSQL 17.6.
> Dev was created as an **exact schema clone** of prod via `pg_dump -n public
> --schema-only` → `psql` (verified identical: 63 tables, 42 enums, 33 functions,
> 68 RLS policies, 25 triggers). Dev tables are **empty** — no real client data
> crossed over (data isolation preserved); the autonomous agent seeds its own
> throwaway data.
>
> **Isolation model chosen: same-account + discipline** (not a separate account).
> The Supabase access token is account-wide, so isolation is *procedural*: the dev
> workstation's `.env` carries **dev-only** credentials (dev URL, dev anon key, dev
> service-role, dev DB URL) and **never** the `SUPABASE_ACCESS_TOKEN`. The
> autonomous agent applies migrations to dev via `psql "$DEV_DB_URL"` or
> `supabase db push --db-url "$DEV_DB_URL"` — never via the Management API (which
> needs the account-wide token and would reach prod). **Never `link`/point a
> full-auto run at `mgftoofmcnxfshtailgn`.**
>
> Prod's case/vessel data was wiped to a clean slate for workflow verification on
> 23 July (kept: `clause_library`, `checklist_templates`, `organisations`,
> `surveyor_profiles`, `profiles`, `external_accounts`, `connected_accounts`).
> Backup: `/home/pilou/marine_survey_backups/prod_public_20260723_095006.dump`.

Notes:
- While in **pre-production**, `myapp-dev` is the *only* project. The prod
  project is created at launch, not before — this defers its per-project
  compute cost and keeps the setup free for now.
- Billing/plan is **per organization**, and a Pro project and a Free project
  cannot share an org. If prod later goes on Pro while dev stays Free to save
  cost, they must sit in **separate orgs** — and Free projects auto-pause after
  ~1 week of inactivity, which is painful for a database built against daily.
  For active dev work, keep dev on Pro alongside prod in the same org.

---

## 3. Credential rules (read before any autonomous run)

The whole point of the environment split is that the `.env` the agent can see
unlocks **only throwaway data**. Enforce this:

- The only Supabase keys present in any `.env` the agent reads are **dev keys**.
- The **prod service-role key never touches this repo, this shell, or any
  `.env` the agent can read.** It bypasses row-level security — it is god-mode
  on the database.
- `.env`, `.env.*`, and any key/credential files are **gitignored** (see §7)
  so the per-commit history never bakes a secret in.
- Google OAuth tokens and any third-party credentials in Supabase follow the
  same rule: dev/test accounts for the agent, real accounts human-held.

Verify before an unattended session:
```
grep -rn "service_role\|SERVICE_ROLE" .env* 2>/dev/null   # should show dev only
git check-ignore .env                                     # should print ".env"
```

---

## 4. Schema-as-code — the discipline that makes this work

Every schema change is a **versioned migration file** in `supabase/migrations/`,
committed to git alongside code. This is what lets dev and prod stay in sync and
makes "create the prod project later" a five-minute job instead of a manual
rebuild.

**Golden rule: never change a remote database directly.** Editing the remote via
the Dashboard SQL editor or Table Editor bypasses the migration history and makes
`db push` fail with sync errors. All remote schema changes go through migration
files only. The Dashboard/Table Editor is fine for the **local** database, then
captured with `db diff`.

### First-time setup (once per project)
```
supabase init                       # creates supabase/ — safe to commit
supabase login                      # stores personal access token
supabase link --project-ref <dev-ref>
supabase db pull                    # capture any existing remote schema as a migration
git add supabase/ && git commit -m "chore: init supabase migrations, capture current schema"
```
The `db pull` step matters if the dev project already has tables made through
the Dashboard — it captures them as `supabase/migrations/<ts>_remote_schema.sql`
so your baseline is under version control before any new change.

### Making a schema change (every time)
```
supabase migration new <descriptive_name>     # creates supabase/migrations/<ts>_<name>.sql
# write the SQL (or make it locally in Studio, then: supabase db diff -f <name>)
supabase db reset                             # rebuild LOCAL db from all migrations — verify it applies clean
supabase db push                              # apply pending migrations to linked dev project
git add supabase/migrations && git commit -m "feat(db): <what changed>"
```

### Inspecting state / recovering from drift
```
supabase migration list        # shows applied local vs remote, and divergence
supabase db push --dry-run     # preview what would apply, without applying
supabase db pull               # pull remote back into a migration if it drifted
supabase migration repair      # mark a migration applied/reverted without running it (last resort)
```

### Promoting to prod (at launch, human-run)
```
supabase link --project-ref <prod-ref>
supabase db push --dry-run     # review every statement first
supabase db push               # apply the SAME reviewed migration history to prod
```
Same migration files, different project. No re-doing, no drift.

---

## 5. Inspection checklist — audit a project's current state

Run through this to see how far a given project is from the target, before
preparing a migration. Tick what's true.

**Environment split**
- [ ] This project has a dedicated **dev** Supabase project.
- [ ] Prod is a **separate** project (or explicitly "not created yet — pre-prod").
- [ ] No environment shares a project with another.

**Credentials**
- [ ] `.env` contains **dev** keys only; no prod service-role key anywhere in repo.
- [ ] `.env` / key files are gitignored and not in git history.
- [ ] Google / third-party tokens the agent can reach are test accounts.

**Schema-as-code**
- [ ] `supabase/` exists and is committed.
- [ ] Current remote schema is captured as a migration (`db pull` run).
- [ ] `supabase migration list` shows local and dev remote **in sync**.
- [ ] No schema changes have been made directly on remote since last migration.

**Autonomy safety (see §6)**
- [ ] Full-auto runs happen on a dated branch, not `main`.
- [ ] A pre-run tag/checkpoint exists for instant rollback.
- [ ] Per-unit commit discipline is in `CLAUDE.md`.

Anything unticked is the work-list to get this project "migration-safe."

---

## 6. Autonomy rules (full-auto / skip-permissions runs)

When the agent runs with permissions bypassed:

- Work on a **dated branch**, never commit to `main` directly:
  `git checkout -b auto/<task>-$(date +%Y%m%d)`
- Tag the pre-run state first for instant rollback:
  `git tag pre-auto-$(date +%s)`
- **Commit after each self-contained working unit** (module, function group,
  passing test). Format: `feat(scope): …` / `fix:` / `refactor:` / `test:` /
  `feat(db): …` for migrations.
- Run tests before committing; don't commit failing code unless marked WIP.
- Never amend or force-push. Keep commits small enough to `git revert` cleanly.
- DB work = writing/applying migrations **against dev only**. Never point a
  full-auto run at prod.
- For genuinely unattended overnight runs, prefer a **container** with only the
  repo and placeholder/dev env mounted — no host filesystem, no path to prod.

---

## 7. `.gitignore` baseline

```
.env
.env.*
!.env.example
*.key
*.pem
service-account*.json
supabase/.temp/
```

---

## 8. Quick reference

| I want to… | Command |
|---|---|
| See applied vs pending migrations | `supabase migration list` |
| Preview a push without applying | `supabase db push --dry-run` |
| New migration file | `supabase migration new <name>` |
| Capture local Studio changes as a migration | `supabase db diff -f <name>` |
| Rebuild local db from migrations | `supabase db reset` |
| Apply pending migrations to linked project | `supabase db push` |
| Pull remote schema into a migration (fix drift) | `supabase db pull` |
| Switch which project is linked | `supabase link --project-ref <ref>` |
