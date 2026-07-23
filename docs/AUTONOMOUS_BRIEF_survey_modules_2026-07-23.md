# Autonomous task brief — new survey-type modules (DP FMEA / P&I / C&S)

**For:** the full-auto agent on the **dev workstation**.
**Created:** 23 July 2026. **Read `docs/ENVIRONMENT.md` first — §3 and §6 are binding.**

---

## 0. Hard safety rules (violating any of these is a failed run)

1. **DB target is DEV ONLY** — project ref `jcuwfjyyqsjnmqxpqlbt`. **NEVER** touch
   prod ref `mgftoofmcnxfshtailgn`. Never run `supabase link` against prod, never
   use the Management API (it needs the account-wide token, which this box must
   not hold).
2. Apply migrations to dev via the direct DB URL only:
   `psql "$DEV_DB_URL" -f <migration>` or `supabase db push --db-url "$DEV_DB_URL"`.
   `$DEV_DB_URL` comes from this box's `.env` (staged from `dev.env`). If `.env`
   is missing or lacks `DEV_DB_URL`, **stop and ask** — do not proceed blind.
3. **Never touch prod credentials.** This box's `.env` has dev-only keys and no
   `SUPABASE_ACCESS_TOKEN`. Keep it that way. `.env` stays gitignored.
4. **Git:** work on a dated branch `auto/survey-modules-YYYYMMDD`, tag the pre-run
   state (`git tag pre-auto-$(date +%s)`), commit per self-contained unit
   (`feat(pi): …`, `feat(db): …`, `test: …`), run tests before committing, never
   push to `main`, never amend/force-push. Keep commits `git revert`-able.
5. **Schema changes are additive only** — `ADD COLUMN IF NOT EXISTS`, new tables,
   new enum values. No drops, no destructive renames. Every change is a numbered
   migration file in `docs/migrations/` (continue the existing convention;
   highest is currently 063) committed alongside code.

---

## 1. First step — locate and confirm the module documentation

All domain documentation for these modules is **already on this machine** (the
surveyor said so). Before building anything:

- Search the filesystem for the DP FMEA / P&I / Condition & Suitability specs
  (try `~`, `~/Documents`, `~/Desktop`, and inside the repo `docs/`). Match on
  "FMEA", "DP", "IMCA", "P&I", "Condition", "Suitability", etc.
- **Report what you found** (paths + a one-line summary of each) and confirm it's
  the right spec set **before** designing data models or report shapes. If you
  cannot find them, stop and ask — do not invent scope.

---

## 2. What already exists (verified 23 July against current code)

Good news — the plumbing is generic; only the *domain content* is missing.

- **Survey type is `CaseType`** (`lib/features/cases/models/case_model.dart:7-22`),
  stored in `cases.case_type` (DB enum). Values **already include** `pi`, `cs`,
  `dp_trials` (also `hm`, `mws`, `deficiency`, `consulting`).
- It already flows, unchanged, through: the New Case "Survey Type" dropdown
  (`new_case_screen.dart:42-48`, iterates `CaseType.values`), Edit Case
  (`edit_case_screen.dart:173-183`), title composition (`case_title.dart:14-27`),
  and **checklist cloning** (`cases_provider.dart:125-149`, selects
  `checklist_templates.eq('case_type', …)` — fully generic).
- **Report format is a separate, orthogonal axis** — `OutputFormat`
  (`case_model.dart:39-50`: `abl`/`nordic`/`oceano_services`), stored in
  `cases.output_format`, keys `clause_library(format_type, clause_type)` for house
  style. **Do not conflate `case_type` (what you survey) with `output_format`
  (report house style).**
- **P&I checklist content already seeded**: MM09 58-item attendance list under
  `case_type='pi'` (`docs/migrations/043_mm09_checklist_content.sql`).
- **Scaffold data tables already in the DB (RLS-protected, zero app code — the
  intended seams):**
  - `cs_sections` (`case_id`, `section_type`, `rating`, `narrative`,
    `photos_linked jsonb`) — generic section/rating/narrative shape, the natural
    home for **C&S**.
  - `trials_tests` (FK `case_id`) — the natural home for **DP FMEA** trial/test items.
  - `work_orders` (FK `case_id`).
  - ⚠️ `docs/SCHEMA.md` is a **partial** dump — **dump these three tables' real
    column sets from the live dev DB** (`psql "$DEV_DB_URL" -c "\d+ cs_sections"`
    etc.) before designing against them.

## 3. What's missing — the actual work

Everything currently renders the **H&M** shape, unconditional on `case_type`:

- **Case workspace** `lib/features/cases/screens/case_home_screen.dart:900-1118`
  is a flat, case_type-blind list of `_SectionCard`s (Attendance, Certificates,
  Occurrence, Damage, Repairs, Accounts…).
- **Report sections** are one hard-coded H&M list: `SectionType` enum
  (`report_provider.dart:54-91`) + `oceanoSectionOrder`
  (`report_provider.dart:96-123`) + an in-memory, hard-coded assembler
  (`report_provider.dart:1201-1300+`). The only `case_type` branch is a trailing
  sentence at `:2626-2631`. The code comment at `:93-95` already anticipates
  per-variant ordered lists.
- Editor/preview consume that single order (`report_builder_screen.dart:460-463`,
  `report_preview.dart:165+`).

## 4. Extension pattern (keep H&M the untouched default)

For **each** survey type, follow this tiered pattern — least disruption first:

1. **Enum + checklist (mostly already done):** the `CaseType` value exists (for
   DP FMEA decide: reuse `dp_trials` or add a sibling `dp_fmea` value — if adding,
   update both `case_model.dart:7-14` **and** the DB `case_type` enum via
   migration). Seed its checklist with a `checklist_templates` insert migration
   (mirror `043`); `_cloneChecklistTemplate` handles the rest — no Dart change.
2. **Domain data:** back the module with the generic scaffold tables — **C&S →
   `cs_sections`**, **DP FMEA → `trials_tests`** — adding columns additively if
   needed. Only create new tables if the generic shape genuinely can't hold the
   data. New feature module under `lib/features/<survey>/` with a provider
   mirroring `damage_provider.dart` / `vessel_provider.dart` patterns.
3. **Workspace + report shape (the real work):**
   - Wrap `case_home_screen.dart`'s card list in a `switch (survey.caseType)` so
     each type shows its own cards; **H&M path stays exactly as-is** (default).
   - Add a per-type section-order list beside `oceanoSectionOrder` and branch the
     assembler (`report_provider.dart:1201+`) and the editor's ordered keys
     (`report_builder_screen.dart:460`) on `case_type`, **defaulting to the
     existing H&M path** so H&M is never disturbed.

## 5. Definition of done (per module)

A new case of that type → tailored workspace cards → its checklist auto-clones →
domain data is captured and persists to dev → the report builder produces a
coherent report in that shape → widget/unit tests cover the new provider + section
assembly → `flutter analyze` clean (no new categories) → committed on the dated
branch. **Regression guard:** creating an H&M case must be byte-for-byte unchanged.

## 6. Suggested sequence

P&I first (checklist already seeded, lowest new-data need) → C&S (use `cs_sections`)
→ DP FMEA (use `trials_tests`, most domain-specific). Commit each module as its own
group of commits so the surveyor can review/merge them independently. Surface any
scope question or ambiguity in the module docs rather than guessing.

---

*Environment reference: `docs/ENVIRONMENT.md`. Architecture anchors above verified
23 July 2026. Dev = `jcuwfjyyqsjnmqxpqlbt`, prod (DO NOT TOUCH) =
`mgftoofmcnxfshtailgn`.*
