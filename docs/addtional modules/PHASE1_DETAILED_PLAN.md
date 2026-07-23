# Phase 1 — Detailed Build Plan (Foundation F1/F2 + C&S A1)

**Branch:** `feature/additional-modules` · **Base:** `origin/main` @ `0152aac`
**Companion to:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) (the high-level plan). This doc is the file-by-file, task-level design for the **first executable slice**.

> **Why this slice first.** F1 (register primitive), F2 (hub gating) and C&S **A1** (case-type wiring + skeleton) are all **H&M-independent** — they touch *no* exporter or H&M code, so they can start **now**, before H&M's last bugs are closed. F0 (golden-file guard) and F3 (exporter refactor) wait for the H&M freeze and are **out of scope here**; so are C&S A2+ (capture UI) and the DP/P&I modules.

**Definition of done for Phase 1:** you can create a `cs` case, its home shows the C&S module set (not the H&M one), the AHTS section skeleton is seeded per case, and the C&S inspection register reads/writes to Supabase through a provider built on the shared register primitive. No report output yet (that's A3/A4).

---

## 0. Order of work

```
T1  Migration 064 — C&S schema (template + per-case tables, org-scoped correctly)
T2  Seed data — AHTS §1–11 skeleton into cs_template / cs_template_item
T3  F1  — shared register primitive (light: template + shared widgets + F4 findings)
T4  C&S register — models + providers instantiating F1 (cs_inspection_item, cs_recommendation)
T5  F2  — data-driven hub gating (moduleSetFor(CaseType))
T6  C&S A1 — case-type wiring: seed-on-create, C&S module set, route stubs
```
T1→T2 are backend; T3→T4 the register; T5→T6 the hub. T3 (F1) and T5 (F2) are the two reusable pieces every later module inherits.

---

## 1. T1 — Migration `064_cs_ahts.sql`

Follows the house convention: `NNN_snake_case.sql`, idempotent, "run in Supabase SQL editor" ([039_action_items.sql](../migrations/039_action_items.sql) is the table template; [045_org_scoped_rls.sql](../migrations/045_org_scoped_rls.sql) the RLS template). **Note the PK convention: `cases(case_id)`, not `id`.**

**The org-scoping split (critical — from 045's own header):** reference/template content is shared across orgs and is **deliberately NOT org-scoped** (045 says so for `checklist_templates` + `clause_library`). Per-case data **is** org-scoped via `case_id → cases.organisation_id`. So:

| Table | Kind | RLS |
|-------|------|-----|
| `cs_template` | shared reference (the AHTS skeleton) | **un-scoped** — mirror `checklist_templates` posture (authenticated read) |
| `cs_template_item` | shared reference | **un-scoped** — same |
| `cs_sections` *(exists)* | per-case | already org-scoped in 045 — just ADD COLUMNs, no policy change |
| `cs_inspection_item` | per-case register | **org-scoped** via `case_id` (045 pattern) |
| `cs_recommendation` | per-case | **org-scoped** via `case_id` |
| `cs_certificate` | per-case | **org-scoped** via `case_id` |

**Section rating derivation (resolved — PLC, 2026-07-21).** A section's overall rating is **auto-derived from its item grades, with manual override**. The section-level scale is its OWN three states — *not* the item grades — reflecting the surveyor's real rollup:

| Item grades in the section (N/A ignored) | Section rating |
|---|---|
| none unsatisfactory (all satisfactory/good) | **GOOD** |
| a minority unsatisfactory (a few findings) | **SATISFACTORY_WITH_ISSUES** |
| half-or-more unsatisfactory | **UNSATISFACTORY** |

So `cs_sections.rating` stores this derived-but-overridable value (enum `GOOD / SATISFACTORY_WITH_ISSUES / UNSATISFACTORY`), plus a `rating_overridden boolean` so a manual value isn't clobbered when items change. The minority/half boundary is the assumed default — see §8 Q2 for the open tweak (e.g. a critical-item rule).

SQL sketch (abbreviated — real file adds indexes + comments):

```sql
-- 064_cs_ahts.sql — C&S — AHTS data model (Module A). See IMPLEMENTATION_PLAN §4.
-- Template tables: shared reference, un-scoped (like checklist_templates).
-- Per-case tables: org-scoped via case_id -> cases.organisation_id (045 pattern).

-- ── shared reference: the AHTS skeleton ──────────────────────────────────
CREATE TABLE IF NOT EXISTS cs_template (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         text NOT NULL,
  vessel_type  text NOT NULL DEFAULT 'ahts',
  version      int  NOT NULL DEFAULT 1,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS cs_template_item (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  template_id   uuid NOT NULL REFERENCES cs_template(id) ON DELETE CASCADE,
  section       text NOT NULL,            -- '1.0' .. '11.0'
  parent_item   uuid REFERENCES cs_template_item(id),
  ref_no        text,                     -- Ref column in the report
  label         text NOT NULL,            -- Item column
  guidance_text text,
  grade_applicable boolean NOT NULL DEFAULT true,
  gt_threshold  numeric,                  -- applicability by GT, nullable
  sort_order    int NOT NULL DEFAULT 0
);
-- (mirror checklist_templates RLS: authenticated read; no org scope)

-- ── per-case: extend the existing cs_sections scaffold ───────────────────
ALTER TABLE cs_sections ADD COLUMN IF NOT EXISTS template_section_ref text;
ALTER TABLE cs_sections ADD COLUMN IF NOT EXISTS vessel_type          text;
-- section rating: auto-derived from child item grades, override allowed.
-- Own 3-state scale (GOOD | SATISFACTORY_WITH_ISSUES | UNSATISFACTORY),
-- distinct from the item grades. rating_overridden guards a manual value.
ALTER TABLE cs_sections ADD COLUMN IF NOT EXISTS rating_overridden boolean NOT NULL DEFAULT false;
-- (existing `rating` column reused; app writes the derived value unless overridden)
-- cs_sections already has the 045 org policy — nothing else to do.

-- ── per-case: the inspection register (F1 instance) ──────────────────────
CREATE TABLE IF NOT EXISTS cs_inspection_item (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id          uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  section_id       uuid REFERENCES cs_sections(section_id) ON DELETE SET NULL,
  template_item_id uuid REFERENCES cs_template_item(id),
  grade            text,                  -- SATISFACTORY|GOOD|UNSATISFACTORY|N_A
  remark           text,
  is_na            boolean NOT NULL DEFAULT false,
  sort_order       int NOT NULL DEFAULT 0,
  sync_status      text NOT NULL DEFAULT 'synced',  -- offline-ready (§10), unused now
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cs_inspection_item_case ON cs_inspection_item(case_id);

CREATE TABLE IF NOT EXISTS cs_recommendation (
  id             uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id        uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  ref_no         text,
  text           text NOT NULL,
  source_item_id uuid REFERENCES cs_inspection_item(id) ON DELETE SET NULL,
  status         text NOT NULL DEFAULT 'open',  -- open|closed
  close_date     date,
  sync_status    text NOT NULL DEFAULT 'synced',
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cs_recommendation_case ON cs_recommendation(case_id);

CREATE TABLE IF NOT EXISTS cs_certificate (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id      uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  cert_type    text NOT NULL,
  issued_date  date, issued_place text, expiry_date date,
  status       text,
  document_id  uuid,                      -- optional link to Vault
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cs_certificate_case ON cs_certificate(case_id);

-- ── RLS: enable + 045-style org policy on the three per-case tables ──────
ALTER TABLE cs_inspection_item ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Org members full access" ON cs_inspection_item
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_inspection_item.case_id AND c.organisation_id = current_org_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM cases c WHERE c.case_id = cs_inspection_item.case_id AND c.organisation_id = current_org_id()));
-- (repeat for cs_recommendation, cs_certificate)
```

**Acceptance:** migration runs clean twice (idempotent); an authenticated session in org A cannot select another org's `cs_inspection_item` rows (test with the `SET LOCAL request.jwt.claim.*` method documented in 045's header).

---

## 2. T2 — Seed the AHTS skeleton

The §1.0–11.0 Ref/Item rows from the reference template (Normand Scorpion AHTS) become `cs_template` (1 row) + `cs_template_item` (many rows). Two seeding options:

- **Option A (recommended): a seed SQL** (`065_cs_ahts_seed.sql` or appended to 064) `INSERT`ing the AHTS rows. Deterministic, versioned, matches how `018/020` seed clause_library.
- Option B: seed via the existing `checklist_templates` mechanism ([cases_provider.dart:126](../../lib/features/cases/providers/cases_provider.dart#L126) `_cloneChecklistTemplate`) — reuse if we want C&S items to also appear in the Checklist module. Decide in T6.

**Content source:** extract the §1–11 Ref/Item list from `CS_AHTS_Integration.docx` §3.2 + the reference report. This is data-entry, not code — can be done incrementally (start with §1–9 common core, add §10/§11 supplements after).

**Acceptance:** `SELECT count(*) FROM cs_template_item WHERE section LIKE '5.%'` returns the Hull items; the skeleton is queryable in template order via `sort_order`.

---

## 3. T3 — F1: the register primitive (keep it light)

**Recommendation: do NOT build a heavy generic base class.** The modern register ([action_items_provider.dart](../../lib/features/action_items/providers/action_items_provider.dart)) is already ~200 lines of clean, idiomatic Riverpod; forcing it behind a generic `Notifier<T>` fights the codegen ergonomics and buys little. Instead F1 = **three concrete, shared things**:

1. **A documented copy-template** — a short `lib/shared/register/README.md` capturing the canonical shape so every register is written the same way: `AsyncNotifierProviderFamily<Notifier, List<Model>, String>` keyed by `caseId`; `build(caseId) => _fetch`; direct `SupabaseService.client.from(table)` CRUD; optimistic `_patch`; models with `fromJson`/`copyWith`; enums as `(value, label)` records with a `fromValue` fallback. (All lifted verbatim from `action_items`.)
2. **Shared UI widgets** — `lib/shared/register/register_list_scaffold.dart` (list + empty-state + add-FAB), `register_item_tile.dart`, `add_item_sheet.dart` — the parts genuinely identical across C&S items, DP tests, P&I points. Photo-attach reuses the existing `photos.linked_to_type/linked_to_id` pattern.
3. **F4 findings primitive (real shared code)** — `lib/shared/register/findings.dart`: a `ClassifiedFinding` model + provider template where a register row spawns a classified, closeable child (`category` + `status` + `source_item_id`). This is genuinely shared: **C&S recommendation**, **DP A/B/C finding**, **P&I opinion point** are the same shape. Build once here.

**Acceptance:** the C&S register (T4) is written *using* the template + shared widgets, and the README example compiles.

---

## 4. T4 — C&S register: models + providers

New feature dir `lib/features/cs/` mirroring `features/action_items`:

- `lib/features/cs/models/cs_models.dart` — `CsGrade` enum (`SATISFACTORY/GOOD/UNSATISFACTORY/N_A`, `(value,label)`), `CsInspectionItemModel`, `CsRecommendationModel`, `CsSectionModel`, `CsTemplateItemModel`.
- `lib/features/cs/providers/cs_inspection_provider.dart` — `csInspectionProvider = AsyncNotifierProviderFamily<..., List<CsInspectionItemModel>, String>` (caseId). CRUD on `cs_inspection_item`. **The one clever bit (spec §5.2):** `setGrade(id, UNSATISFACTORY)` offers to spawn a linked `cs_recommendation` (via the F4 primitive) carrying the item's section + remark.
- `lib/features/cs/providers/cs_recommendation_provider.dart` — instantiates F4 findings.
- `lib/features/cs/providers/cs_template_provider.dart` — reads the shared `cs_template_item` skeleton (cache-friendly; not case-scoped).

**Acceptance:** unit tests (mirror [action_items_provider_test.dart](../../test/features/action_items/providers/action_items_provider_test.dart)) — fetch, add, setGrade→recommendation-spawn, delete; a `fake_cs_inspection_notifier.dart` in `test/support/fakes/` for widget tests.

---

## 5. T5 — F2: data-driven hub gating

Today the hub is two hardcoded surfaces; both already receive the `CaseModel`, so `survey.caseType` is in scope — we just branch on it.

- **Nav rail** `_SurveyNavRail` ([case_home_screen.dart:322](../../lib/features/cases/screens/case_home_screen.dart#L322)) — the 9 `_NavItem`s become a list built from a **module-set map**.
- **Section cards** `_sections(...)` ([case_home_screen.dart:910](../../lib/features/cases/screens/case_home_screen.dart#L910)) — currently one flat `List<_SectionCard>`; split into per-module builders selected by case type.

**Design — `lib/features/cases/case_modules.dart`:**
```dart
/// Declares, per survey type, which hub modules show and in what order.
/// The hub renders from this instead of a hardcoded list.
enum HubModule { attendance, certificates, timeline, occurrence, background,
  damage, causation, repairs, accounts, /* H&M */
  csInspection, csRecommendations, csCertRegister /* C&S */ }

const Map<CaseType, List<HubModule>> moduleSetFor = {
  CaseType.hm: [ /* the current H&M list, unchanged */ ],
  CaseType.cs: [ HubModule.attendance, HubModule.certificates,
                 HubModule.csInspection, HubModule.csRecommendations,
                 HubModule.csCertRegister, /* + shared spine */ ],
  // dpTrials, pi added by their modules later
};
```
`_sections()` becomes: `moduleSetFor[survey.caseType] ?? moduleSetFor[CaseType.hm]!` → map each `HubModule` to its `_SectionCard` builder. **H&M's list is reproduced exactly** (regression-safe: same cards, same order — `CaseType.hm` maps to today's literal sequence). Nav rail does the same for its items.

**Acceptance:** an `hm` case renders byte-identical hub to today (the `moduleSetFor[hm]` list *is* the current order); a `cs` case shows the C&S set and hides damage/accounts. Widget test per case type.

---

## 6. T6 — C&S A1: case-type wiring

- **Seed-on-create:** in `CasesNotifier.createCase()` ([cases_provider.dart:49](../../lib/features/cases/providers/cases_provider.dart#L49)), when `caseType == CaseType.cs`, provision the case's `cs_sections` rows from the active `cs_template` (parallel to the existing `_cloneChecklistTemplate` call at line 80). Factor a `_seedCsSections(caseId)` alongside it.
- **Routes:** add `/cases/:id/cs/inspection`, `/cases/:id/cs/recommendations` route stubs in [app_router.dart](../../lib/core/config/app_router.dart) → screens that render the F1 `register_list_scaffold` (capture UI proper is A2). Wire the C&S nav items / section cards' `onOpen` to them.
- **New-case screen:** no change needed — it already iterates `CaseType.values`.

**Acceptance:** create a case with type C&S → its home shows the C&S modules, the AHTS section rows exist for that case, and tapping Inspection opens the (stub) register screen backed by the real provider.

---

## 7. Explicitly NOT in this slice (deferred)

| Deferred | Why | Gate |
|----------|-----|------|
| **F0** golden-file guard | Only needed to protect the F3 exporter refactor | Start when H&M frozen |
| **F3** section-library refactor + any `.docx` output | Touches the in-use H&M exporter | H&M freeze + F0 in place |
| **C&S A2** full inspection capture UI (grade/remark/photo per item) | The one big new screen; build after the register plumbing (T4) is proven | After T4 |
| **C&S A3/A4** Preliminary Deficiency List / Suitability Report | Report output = needs F3 | After F3 |
| **DP / P&I** modules | Sequenced after C&S | Per IMPLEMENTATION_PLAN §8 |

---

## 8. Decisions for this slice (resolved 2026-07-21)

1. ✅ **T2 seeding route** — standalone seed SQL; C&S inspection form kept separate from the existing Checklist module. *(Developer's call.)*
2. ✅ **`cs_sections` rating** — **auto-derived from item grades, override allowed**, on its own three-state scale `GOOD / SATISFACTORY_WITH_ISSUES / UNSATISFACTORY` (see §1 derivation table). **Open tweak:** the minority↔half boundary — default is *minority unsatisfactory = with-issues, half-or-more = unsatisfactory*; PLC to confirm whether a **critical-item override** applies (any critical item failing → whole section unsatisfactory regardless of count).
3. ✅ **F1 altitude** — light (template + shared widgets + F4). *(Developer's call.)*
4. ✅ **AHTS content** — extract the §1–11 Ref/Item list from `CS_AHTS_Integration.docx` (+ reference report). Start with the §1–9 common core, add §10/§11 supplements after.

---

*Phase 1 is the H&M-independent foundation + C&S skeleton. It builds the two pieces (F1 register primitive, F2 hub gating) every later module reuses, and leaves the H&M exporter untouched until the freeze. Start at T1.*
