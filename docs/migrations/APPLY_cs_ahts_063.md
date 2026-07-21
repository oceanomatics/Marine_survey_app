# DB upgrade — C&S — AHTS (migrations 063, 063b)

**For:** the workstation with Supabase admin access.
**Branch:** `feature/additional-modules`.
**What it adds:** the C&S — AHTS data model (Module A) + the AHTS section skeleton. Additive only — it does **not** touch any existing H&M table, column, policy, or the `cases` schema.

---

## Apply, in this order

Run each in the **Supabase SQL editor** (Dashboard → SQL Editor → New query → paste → Run). Both are **idempotent** — safe to re-run; re-running the seed is a no-op.

| # | File | What it does |
|---|------|--------------|
| 1 | [`063_cs_ahts.sql`](063_cs_ahts.sql) | Creates the tables + RLS. Shared reference (`cs_template`, `cs_template_item`, not org-scoped); per-case, org-scoped via `case_id` (`cs_inspection_item`, `cs_recommendation`, `cs_certificate`); extends the existing `cs_sections` scaffold with 3 columns. |
| 2 | [`063b_cs_ahts_seed.sql`](063b_cs_ahts_seed.sql) | Seeds the AHTS §1.0–11.0 section skeleton into `cs_template` / `cs_template_item`. Starter granularity (see note below). |

> Run **063 before 063b** — the seed inserts into tables 063 creates.

---

## Verify it worked

After both, run:

```sql
-- expect: 1 template, ~40 items
select
  (select count(*) from cs_template  where vessel_type = 'ahts') as templates,
  (select count(*) from cs_template_item) as items;

-- expect: RLS enabled on the per-case tables
select relname, relrowsecurity
from pg_class
where relname in ('cs_inspection_item','cs_recommendation','cs_certificate');

-- expect: an "Org members full access" policy on each per-case table
select tablename, policyname from pg_policies
where tablename in ('cs_inspection_item','cs_recommendation','cs_certificate');
```

In the app: create a case with **Survey Type = C&S**. Its home should show the **Inspection** + **Recommendations** cards (not the H&M ones), and the **Inspect** screen should list the §1–11 sections. If the inspection screen says *"No AHTS template seeded yet"*, migration 063b did not run.

---

## Notes

- **Assumes two base-schema objects already exist** (they power existing triggers/PKs): the `set_updated_at()` trigger function and the `uuid_generate_v4()` extension. Both are already used by prior migrations, so no action needed — but if 063 errors on `uuid_generate_v4`, run `create extension if not exists "uuid-ossp";` first.
- **The seed is a starter skeleton** — the 11 sections plus sub-group headers from `CS_AHTS_Integration.docx` §3.2, not the full authoritative per-row Ref/Item list. The full list drops in later as additional `INSERT`s against the same template (no schema change). This is intentional and flagged in `063b`'s header.
- **No local SQLite migration** is needed — the new registers are online-only (Supabase direct), consistent with the damage register. Offline is a later, client-only change (see `IMPLEMENTATION_PLAN.md` §10).
- **Rollback** (if ever needed): `drop table if exists cs_certificate, cs_recommendation, cs_inspection_item, cs_template_item, cs_template cascade;` then drop the 3 added `cs_sections` columns. Leaves the pre-existing `cs_sections` scaffold intact.
