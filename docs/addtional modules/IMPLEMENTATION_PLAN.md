# Additional Modules — Implementation Plan

**Branch:** `feature/additional-modules`
**Date:** 2026-07-21
**Author:** Planning pass (Claude) for Pierre-Louis Constant
**Scope:** Turn the four specs in `docs/addtional modules/` into a build plan grounded in the *actual* codebase, sequenced so each phase ships something usable.
**Grounded against:** `origin/main` @ `0152aac` (the 2026-07-21 publish). This branch was rebased onto it and every code anchor below re-verified at that commit.

Governing spec: `Survey_Module_Architecture_Preface_v2.docx` (two-axis model).
Module specs: `CS_AHTS_Integration.docx`, `DP_Trials_Integration_Design (1).docx`, `PI_Survey_Module_Specification_Oceanoservices (1).docx`.

> **Read §1 and §2 first.** The specs were written against an idealised description of the platform. The code has, in several places, already moved past what they assume — and in a couple of places it does *less* than they assume. §2 reconciles the two; every phase below depends on those corrections.

> **Re-grounding note (2026-07-21).** First drafted against `3c3b0eb`, then re-verified against the `0152aac` publish (~335 files / +41k lines ahead). What changed vs. the first draft: **(a)** migrations now run to `062` — next is `064`, not `027` (main later took `063`); **(b)** **multi-tenancy / org-scoped RLS is now live** (migrations 044–048) — new tables must be org-reachable from day one (§2.7); **(c)** a generic `CaseContextBuilder` already exists — the C&S/DP "context builder" is an *extension*, not new build (§2.8); **(d)** a cleaner register pattern (`action_items`/`interviews`) supersedes the damage register as the F1 template (§2.9). The architecture verdicts (hub hardcoded, exporter switch-based, `cs_sections` unused, AI chokepoint intact) all held.

---

## 1. Decisions for you (they change the plan's shape)

The preface (§7–§8) left a set of decisions open. **D1–D6 are now resolved** (confirmed by PLC, 2026-07-21); D7–D8 remain to action during the P&I phase. Status column records the resolution.

| # | Decision | Status → resolution |
|---|----------|---------------------|
| **D1** | Axis-1 enum name (`case_type` vs `matter_type`) and H&M value | **✅ RESOLVED — decided in code.** `enum CaseType` exists at [case_model.dart:7](../../lib/features/cases/models/case_model.dart#L7): `hm, pi, cs, dpTrials, mws, deficiency, consulting`. Enum is `case_type`, H&M is `hm`. New-case screen already iterates `CaseType.values`. **Action: update the three module docs to these values.** |
| **D2** | Which enum value each module maps to | **✅ RESOLVED.** **C&S-AHTS = `cs`**; **AHTS is a `vessel_type`/template dimension, not a case type** (build the common §1–9 core once, swap the §10/§11 supplement per vessel type). **`mws` is a *different, future* deliverable** — Marine Warranty operation-approval (a specific tow/load-out/installation → Certificate of Approval), whose unit is an *operation*, not a vessel's condition; kept reserved, not used by C&S. **Preliminary Deficiency List = an *output type* of a `cs` case** (reuses the `deficiency` concept), not a separate case type. See §4 preamble for the domain note. |
| **D3** | Foundation-first vs module-first | **✅ RESOLVED — foundation-first** (goal: minimise later rework; H&M now nearly frozen removes the refactor risk). Build F1–F5 **before** C&S so each module is thin config, not re-hardcoding paid three times. **Safety mechanism: an H&M golden-file test** (snapshot current `.docx` output; assert byte-equivalence after the F3 exporter refactor) lets us refactor the near-frozen H&M path safely. See §3 preamble. |
| **D4** | Offline field capture for registers | **✅ RESOLVED — online-only now** (new registers follow the direct-Supabase damage pattern; no SQLite). Full offline capture deferred to the other workstation as a separate project that also benefits H&M's damage register. **The migration is documented in §10 so it's turnkey later.** |
| **D5** | Module order | **✅ RESOLVED — C&S — AHTS → DP Trials → P&I.** Rationale in §8. |
| **D6** | Existing C&S scaffolds | **✅ RESOLVED — build on `cs_sections`, don't supersede.** Keep `cs_sections` ([SCHEMA.md:251](../SCHEMA.md), currently unused in Dart) as the **section-level** record (per-§ narrative + summary rating) and add **child** `cs_template`/`cs_template_item`/`cs_inspection_item`/`cs_recommendation`/`cs_certificate` tables around it. Reuse `checklist_templates` ([cases_provider.dart:108](../../lib/features/cases/providers/cases_provider.dart#L108)) to seed the skeleton. See §4. |
| **D7** | Case Analyst AI path & Annexure I | ⏳ **Open — action in P&I phase.** The field chat logs to `analyst_usage`, **not** `ai_generation_log` ([index.ts](../../supabase/functions/case-analyst/index.ts)). Align the Edge Function to also write `ai_generation_log` (P&I is where AI scrutiny is highest). |
| **D8** | Legal claims (P&I) | ⏳ **Open — gate on external review.** Preface §8 (GPN-EXPT, privilege, P&I-Club distribution). Confirm with a lawyer **before** shipping P&I. |

---

## 2. Reality check — the specs vs. the current code

The specs describe an idealised "shared spine." Here is what's actually there, with the deltas that matter.

### 2.1 What the specs got right (reuse is real)
- **Case discriminator exists**: `CaseType` enum + `caseType` field on `CaseModel` ([case_model.dart:7-22](../../lib/features/cases/models/case_model.dart#L7)). New-case screen already offers it as a dropdown ([new_case_screen.dart](../../lib/features/cases/screens/new_case_screen.dart)). Today `caseType` is read for its `.label` in a few display spots and drives exactly **one** piece of logic — checklist-template cloning ([cases_provider.dart:126-131](../../lib/features/cases/providers/cases_provider.dart#L126), `.eq('case_type', caseType.value)`). It gates **no** module visibility or report layout. So it's a live discriminator we can hang F2/F3 off, not dead metadata.
- **AI audit chokepoint exists**: every Claude call through [claude_api.dart:108-149](../../lib/core/api/claude_api.dart#L108) auto-logs to `ai_generation_log` via [ai_log_service.dart:25](../../lib/core/services/ai_log_service.dart#L25) (SHA-256 of prompt included). New AI features pass `case_id` + `call_type` in Dio `extra` and are logged **for free** — and untagged calls now attribute via an ambient Zone key (`aiTaskCaseIdZoneKey`) too. ✅ Spec claim holds (strengthened).
- **In-house OOXML engine exists**: [docx_builder.dart](../../lib/core/docx/docx_builder.dart) — no template dependency; `addTable/addShadedBlock/addSignOffBlock/addImage`. ✅
- **Clause library exists**: `clause_library` table, selected by `format_type` ([report_provider.dart:848](../../lib/features/reports/providers/report_provider.dart#L848)). ✅ Still 3 `OutputFormat` values (abl/nordic/oceano).
- **Sign-off + export gates exist**: hard gate in [export_button.dart:52-62](../../lib/features/reports/widgets/export_button.dart#L52) (`signOffBlocked` + `aiReviewBlocked`); soft warnings in [export_validation.dart:17](../../lib/features/reports/utils/export_validation.dart#L17). ✅
- **Photo-linking is polymorphic**: `photos.linked_to_type` + `linked_to_id` ([photo_model.dart](../../lib/features/photos/models/photo_model.dart)) — new registers link photos with zero new machinery. ✅

### 2.2 ⚠️ Correction: the app is **online-first**, not offline-first (for registers)
The SQLite layer ([app_database.dart](../../lib/core/database/app_database.dart), **v16**) mirrors **only** `photos`, `correspondence`, `surveyor_notes` — every later migration is an `ALTER TABLE` on those three. The damage register — and any new register — is **online-only**: `DamageNotifier` calls `SupabaseService.client.from(...)` directly ([damage_provider.dart](../../lib/features/survey/providers/damage_provider.dart), no sqflite import). The specs' "rides the existing offline-sync pattern, no new sync machinery" is **inaccurate**. → See **D4**. New registers follow the online-Supabase pattern; genuine offline field capture is separate new work (§10).

### 2.3 ⚠️ Correction: the case hub is **hardcoded**, not data-driven
Every case renders the same modules regardless of `caseType`. Module surfaces are two hardcoded lists: nav rail `_SurveyNavRail` [case_home_screen.dart:322](../../lib/features/cases/screens/case_home_screen.dart#L322) (9 fixed `_NavItem`s) and section cards `_sections(...)` [case_home_screen.dart:910](../../lib/features/cases/screens/case_home_screen.dart#L910) (the `CaseModel` is passed in but `caseType` is never read for gating; header comment: "format differences handled at report builder stage"). The two-axis "case_type switches which modules appear" is **new work** (F2) — no registry abstraction exists yet.

### 2.4 ⚠️ Correction: the report layout is **hardcoded per output type**, not a section library
[docx_export_service.dart](../../lib/features/reports/services/docx_export_service.dart) renders via `switch (output.outputType)` + a linear sequence of `renderTextSection(SectionType.x, …)` calls. There **is** an ordered `SectionType` enum ([report_provider.dart:54](../../lib/features/reports/providers/report_provider.dart#L54)) + `oceanoSectionOrder` list ([report_provider.dart:96](../../lib/features/reports/providers/report_provider.dart#L96)) — but still **only one** format's list (no `nordicSectionOrder`/`ablSectionOrder` yet), and `OutputType` is still just `preliminary/advice/final_`. That per-format ordered list is the **intended extension seam**; the "toggleable section library ordered per profile" from the preface is **aspirational** and is a real refactor (F3). → See **D3**.

### 2.5 Existing scaffolds to reconcile
- `cs_sections` table (minimal C&S) — [SCHEMA.md:251](../SCHEMA.md); has an RLS policy (migration 045) but **no `CREATE TABLE` migration** (created out-of-band) and **zero Dart references** — still an unused scaffold. → **D6.**
- `checklists` + `checklist_templates` (per-case-type, auto-cloned at case creation) — overlaps the graded-checklist skeleton. Reuse as the seeding mechanism.

### 2.6 Migrations
Numbered `NNN_snake_case.sql` in [docs/migrations/](../migrations/), idempotent (`ADD COLUMN IF NOT EXISTS`), "Run in Supabase SQL editor." **Latest = `062`** (with historical duplicate numbers at 053/054/055 and gaps at 060/061). **New work starts at `064_…`.** Keep the sqflite `_onUpgrade` in sync *only* if a new table is offline-cached (it won't be — D4).

### 2.7 ⚠️ New since first draft: multi-tenancy / RLS is now **live**
Migrations 044–048 built org scoping. The column is **`organisation_id`** (not `org_id`): `cases.organisation_id` is `NOT NULL` with a `current_org_id()` helper (`044_org_scoping_foundation.sql`), carried on the model ([case_model.dart:176](../../lib/features/cases/models/case_model.dart#L176)), and enforced by live org-scoped RLS policies across many tables (`045_org_scoped_rls.sql`, "Org members full access"). **Implication for every new module table:** it must be org-reachable from day one — either carry `organisation_id` directly, or reach it via `case_id → cases.organisation_id` (the majority pattern) — and ship with a matching RLS policy in its migration. The C&S spec's "nothing here requires the multi-tenancy work" is now moot: it's built, and new tables inherit the requirement.

### 2.8 New since first draft: a generic `CaseContextBuilder` already exists
[case_context_builder.dart](../../lib/core/services/case_context_builder.dart) — `CaseContextBuilder.build(...)` assembles all loaded case data into the Claude system-prompt text block; called from the Analyst chat ([case_analyst_screen.dart](../../lib/features/analyst/screens/case_analyst_screen.dart)). It's **generic in structure** (each section null-guards and drops out when absent) but **H&M-shaped in content** (damage register, occurrences, repair accounts, cost estimate) — and it already grew a section to ingest interviews. So the C&S/DP "context builder" work (A5, DP-P4) is **extending this file with new sections**, following the interviews precedent — not building a parallel builder.

### 2.9 New since first draft: a cleaner register pattern to mirror than the damage register
The publish added `action_items`, `interviews`, and `detentions` as registers using a **simpler, newer shape** than the heavy `DamageState` aggregate: an `AsyncNotifierProviderFamily<Notifier, List<Model>, String>` keyed by `caseId` over **one** table, with direct-Supabase CRUD + optimistic local patching (e.g. [action_items_provider.dart:99](../../lib/features/action_items/providers/action_items_provider.dart#L99)). **F1 should template on `action_items`/`interviews`, not the damage register** — same idea, less baggage. (`detentions` is the vessel-scoped variant; `ai_tasks` is *not* a register — global in-memory task tracker — don't mirror it.)

---

## 3. Shared foundation (before/under the modules)

**Foundation-first (D3).** Goal: minimise later rework. Every module built on hardcoded scaffolding is hub-gating and report-branching logic paid **three times**, then extracted by touching all three modules at once. Building F1–F5 **once**, up front, makes each module thin config. This is now viable because H&M is nearly frozen — the one risk it removes.

**F0 — H&M golden-file guard (do first, enables the rest).** Before touching the exporter (F3), snapshot the current H&M `.docx` output for 1–2 representative cases and add a test asserting byte/structure-equivalence. This is the safety net that lets F3 refactor the near-frozen H&M path without fear of silent regressions.

| ID | Foundation item | What it is | Touches | Size |
|----|-----------------|-----------|---------|------|
| **F0** | **H&M golden-file regression test** | Snapshot current H&M export bytes/structure; assert unchanged after F3. The precondition that makes refactoring a near-frozen H&M path safe. | new `test/` golden fixtures; [docx_export_service.dart](../../lib/features/reports/services/docx_export_service.dart) | S |
| **F1** | **Generic register primitive** | Factor the **modern** register shape — `AsyncNotifierProviderFamily<Notifier, List<Model>, String>` keyed by `caseId` over one table, direct-Supabase CRUD, optimistic patching, photo-link, AI-draft feed — into a reusable template the C&S inspection register, DP test register and P&I opinion-points all instantiate. **Template on `action_items`/`interviews` (§2.9), not the heavier damage aggregate.** | [action_items_provider.dart:99](../../lib/features/action_items/providers/action_items_provider.dart#L99) as reference; new `lib/shared/register/*` | M |
| **F2** | **Data-driven hub gating** | Make the nav rail + section cards in `case_home_screen.dart` conditional on `caseType` (today it gates nothing — §2.3). Introduce a small `moduleSetFor(CaseType)` map so each survey type declares its nav items + section cards once. | [case_home_screen.dart:322,910](../../lib/features/cases/screens/case_home_screen.dart#L322) | S |
| **F3** | **Section-set per profile in the exporter** | Turn the hardcoded `switch`+linear render into a per-(caseType×format) ordered `SectionType` list the exporter iterates — the seam the code comment at [report_provider.dart:96](../../lib/features/reports/providers/report_provider.dart#L96) already anticipates ("Other formats will have their own ordered lists"). Each `SectionType` renders itself; new report shape = new ordered list + any new table primitive, not surgery on the H&M path. **Guarded by F0.** | [report_provider.dart:54](../../lib/features/reports/providers/report_provider.dart#L54), [docx_export_service.dart](../../lib/features/reports/services/docx_export_service.dart) | L |
| **F4** | **Generic findings/recommendations primitive** | C&S recommendations, DP A/B/C findings and P&I opinion-points are the *same shape* (classified item + status + link back to a register row). Build once (preface open-decision #2). | new `lib/shared/register/findings.dart` | M |
| **F5** | **Export-gate = profile setting** | Extend the gate so *block vs. warn* is per-profile, not a constant (needed for P&I "privileged draft is terminal"). Keep GPN-AI review gate always-on. | [export_button.dart:45](../../lib/features/reports/widgets/export_button.dart#L45), [export_validation.dart](../../lib/features/reports/utils/export_validation.dart) | S |
| **F6** | **Clause-library seeds per module** | Add rows (grading definitions, IMCA boilerplate, privilege banner, terminal-draft stamp) via migrations — no code. | migrations | S per module |

> **F7 (offline register capture) is deferred to the other workstation** — documented in §10. Not a foundation item for this branch; the new registers ship online-only (D4).

---

## 4. Module A — C&S — AHTS (build first)

Graded item-by-item inspection → suitability verdict + gating recommendations. Full detail in `CS_AHTS_Integration.docx`.

**Domain note (D2):** the case type is **`cs`** (Condition & Suitability). **AHTS is a `vessel_type` dimension**, not a case type — so a later PSV/barge/DP C&S reuses §1–9 and swaps only the §10/§11 supplement. Do **not** confuse with **`mws`** (Marine Warranty Survey), which is a separate future deliverable: approval of a specific *operation* (tow / load-out / installation) ending in a Certificate of Approval — its unit is an operation, not a vessel's condition. The **Preliminary Deficiency List is an output type** of a `cs` case (reuses the `deficiency` concept), not its own case type.

**Data model — build on the existing `cs_sections` scaffold (D6), don't supersede it.** `cs_sections` (currently unused in Dart) stays as the **section-level** record; new **child** tables hang off it. Every table below reaches org scope via `case_id → cases.organisation_id` and ships with a "Org members full access" RLS policy in its migration (§2.7). Migration `064_cs_ahts.sql`:
- **`cs_sections`** *(existing — extend)*: one row per §-section on a case — keep `section_type`, `narrative`, and the summary `rating`; add `template_section_ref` and `vessel_type`. This is the section header + rolled-up verdict.
- **`cs_template`** *(new)*: versioned AHTS skeleton (`vessel_type='ahts'`, `version`).
- **`cs_template_item`** *(new)*: every Ref/Item row (`section 1.0–11.0`, `parent_item`, `label`, `guidance_text`, `grade_applicable`, `gt_threshold`).
- **`cs_inspection_item`** *(new — the register)*: the surveyor's finding per item (`case_id`, `section_id` → `cs_sections`, `template_item_id`, `grade` enum, `remark`, `is_na`).
- **`cs_recommendation`** *(new)*: §1.13 gating list (`ref_no`, `text`, `source_item_id`, `status open/closed`) — instantiates **F4**.
- **`cs_certificate`** *(new)*: §3.0 register (`cert_type`, `issued/expiry`, `status`).

Grade enum: `SATISFACTORY / GOOD / UNSATISFACTORY / N_A`. All carry `sync_status`/timestamps per convention even though online-only initially (D4) — so the §10 offline migration needs no schema change later.

**Phases** (each independently useful):
- **A1 — case type + skeleton.** `cs` case type already exists; seed `cs_template`/`cs_template_item` for AHTS §1.0–11.0, seeding via the `checklist_templates` mechanism ([cases_provider.dart:108](../../lib/features/cases/providers/cases_provider.dart#L108)); hub shows C&S module set (needs **F2**).
- **A2 — inspection capture.** Section-by-section screen (grade + remark + photo per item) — the one genuinely-new screen; instantiate **F1**. `UNSATISFACTORY → offer linked `cs_recommendation`` (**F4**). Reuse Photos/voice/Vault as-is.
- **A3 — Preliminary Deficiency List output.** Short numbered-findings `.docx` + on-the-day surveyor+Master sign-off. **Shippable win on its own** — replaces the hand-written Broome-style list. (This is the `deficiency` output type — D2.)
- **A4 — full Suitability Report.** §1.0–11.0 Ref/Item/Remarks layout + Appendices A–E (Photos gallery + tagged Vault docs) + Exec-summary verdict. Needs **F3**.
- **A5 — AI + compliance.** Extend `CaseContextBuilder` (§2.8) with C&S sections (grades-by-count, open recommendations, cert expiries); exec-summary/recommendation drafting prompts (via existing `claude_api` `extra` tags); C&S export rules (every UNSATISFACTORY has a recommendation).

**First milestone = A1–A3**: create a C&S-AHTS case, grade the vessel, generate a signed Preliminary Deficiency List. Self-contained, low H&M risk.

---

## 5. Module B — DP Annual Trials (FMEA-based)

Witnessed test campaign; core new objects = **test register** + **A/B/C findings**. Full detail in `DP_Trials_Integration_Design (1).docx`. Grounded in IMCA M190 Rev 3.2 (2024).

**Enum:** `dpTrials` (`dp_trials`) already exists. **New tables** (next free migration, e.g. `064_dp_trials.sql`; org-scoped via `case_id` per §2.7): `trial_programmes` (one per case, `overall_result`), `tests` (the register — `test_no`, `test_type` enum `annual/incremental/rolling/pm_credit` ← **compliance key**, `fmea_reference`, `method_steps`/`expected_results`/`observed_results` jsonb, `result_status`, `pm_evidence_doc_id`), `findings` (`category A/B/C`, `status`). **Extend** `vessel_particulars` with DP fields (`dp_equipment_class`, `wcfdi_statement`, `redundancy_concept`, `fmea_doc_ref`); `signoffs.role` gains `witness`/`trials_coordinator` + `witness_accreditation_no`. Register providers template on `action_items` (§2.9); P4 extends `CaseContextBuilder` (§2.8).

**Phases:** P0 case-type branch + vessel DP fields → P1 `tests`+`findings` register (instantiate **F1**/**F4**) → P2 repeating **test-sheet block** in the exporter (the single largest new front-end effort; needs **F3**) → P3 compliance gates (test-type declared, PM-credit evidenced, witness sign-off, open-A warning — via **F5**) → P4 AI comments/findings drafting + Case-Analyst context → P5 **FMEA → proposed programme** generator (flagship differentiator) → P6 test-matrix view + appendices.

**MVP = P0–P3.** P5 is the demo headliner if you want a pitch feature.

---

## 6. Module C — P&I / Expert & Litigation

The module that *forced* the two-axis model: **almost no new register** — it's mostly new **report sections** + a **legal/privilege layer** + a **config/process layer**. Full detail in `PI_Survey_Module_Specification_Oceanoservices (1).docx`.

**Enum:** `pi` exists (single value). P&I sub-variation (incident / expert / liability) is **profile/section-toggle work, not new case types** — which is exactly why the code's single `pi` is already correct.

**New report sections** (six + Harmonised-Code additions): Expert CV (surveyor-profile level), Disclosure/Independence declaration, Facts & Documents Relied Upon (renders Vault subset), Opinion/Conclusions (own AI prompt profile — reasoned/hedged, distinct from causation), Interviews rendering (wire existing Interviews data), Medical/Injured Parties. Plus GPN-EXPT/Harmonised-Code cl.3 items (acknowledgment clause, "all inquiries made" declaration, "opinion not concluded" qualifier, "questions I was asked" field, instructions annexure).

**Legal/privilege layer** (clause-library rows + one pipeline change): privilege banner, terminal-draft stamp (every page), instructing-representative block, reserved-position waiver variant; **invert the export gate** for litigation (warn-not-block, draft is terminal) — this is **F5**. Front-of-document AI disclosure paragraph (GPN-AI) + align Case-Analyst to `ai_generation_log` (**D7**).

**Config/process layer:** 5-question intake questionnaire → selects profile; per-instructing-party format profiles (extend the existing `format_type` mechanism — a Club/law-firm is one more saved profile); section toggles; freeform escape hatch.

**Build order:** matter-type profiles → litigation export behaviour (**F5**) → CV/disclosure/facts-relied-upon sections → opinion section + prompt → interviews/medical rendering → per-party profiles. First two items are mostly configuration on existing architecture.

**⚠️ Gate on D8 (legal review) before shipping.**

---

## 7. Cross-cutting

- **AI:** all new drafting routes through [claude_api.dart](../../lib/core/api/claude_api.dart) with `case_id`+`call_type` in Dio `extra` → free Annexure I logging. New prompts only; no new infra. Analyst context = **extend `CaseContextBuilder`** (§2.8), not a new builder. Fix the Case-Analyst chat path to also log `ai_generation_log` (D7).
- **Compliance:** each module adds *rules* to the existing gates, never a new gate (F5). GPN-AI review gate stays always-on.
- **Multi-tenancy (§2.7):** every new table is org-reachable via `case_id → cases.organisation_id` and ships a "Org members full access" RLS policy in its migration. Non-negotiable now that RLS is live.
- **Migrations:** number sequentially from **`064`** (C&S), then DP, then P&I. Idempotent, Supabase SQL editor. Update `docs/SCHEMA.md` after each.
- **Docs hygiene:** update the three module `.docx` (or supersede with `.md`) to the real enum values (D1) and to the §2.7–§2.9 corrections.

---

## 8. Recommended sequencing

```
FOUNDATION        F0 H&M golden-file guard → F1 register primitive · F2 hub gating ·
(build once,          F3 section-library refactor · F4 findings primitive · F5 gate-as-profile
 up front)        ▼
MODULE A (C&S)    A1 skeleton → A2 capture → A3 Preliminary Deficiency List   ◀── first shippable win
     │            → A4 Suitability Report → A5 AI/compliance
     ▼
MODULE B (DP)     P0 → P1 register → P2 test-sheet layout → P3 gates → P4/P5 AI (FMEA→programme)
     ▼
MODULE C (P&I)    profiles → invert gate → new sections → opinion+prompt → per-party profiles
                  ⚠ legal review (D8) before ship
```

**Why foundation-first (D3):** with H&M nearly frozen, building F1–F5 once — guarded by the F0 golden-file test — means C&S, DP and P&I are each thin configuration rather than three rounds of hardcoding that must later be unpicked together. That is the minimum-total-work path given your objective.

**Why this module order:** C&S exercises the full common core (§1–9 of a C&S report) and delivers a standalone win (A3). DP then reuses the register+findings+section-library machinery C&S proved, adding only its test-sheet layout and IMCA gates. P&I is last because it's the most configuration-heavy, leans hardest on the section-library, and carries legal risk needing external sign-off.

---

## 9. Consolidated decisions

| # | Decision | Status |
|---|----------|--------|
| D1 | Enum name + H&M value | ✅ Use existing `CaseType`/`hm`; update docs |
| D2 | `cs` vs `mws`; Deficiency as case-type vs output-type | ✅ `cs` case; AHTS = vessel-type; `mws` = separate future op-approval module; Deficiency = output type |
| D3 | Foundation-first vs module-first | ✅ Foundation-first (F0 golden-file guard → F1–F5), then modules as thin config |
| D4 | Offline register capture | ✅ Online-only now; full offline deferred to other workstation (§10) |
| D5 | Module order | ✅ C&S → DP → P&I |
| D6 | Reuse `cs_sections`/`checklists` scaffolds | ✅ Build on `cs_sections` (section-level) + child tables; reuse `checklist_templates` seeding |
| D7 | Case-Analyst → `ai_generation_log` | ⏳ Action in P&I phase |
| D8 | Legal review of P&I claims | ⏳ Required before P&I release |
| D9 | Shared findings UI primitive (F4) | ✅ Build once, shared |

---

## 10. Deferred: full offline register capture (other workstation)

**Decision (D4):** the new registers ship **online-only** — direct Supabase, mirroring the damage register. This section documents what the *later* offline migration entails so it's turnkey when done on the other workstation. It is **not** on this branch's critical path, and it benefits H&M's damage register too (which is also online-only today).

**Current state.** SQLite ([app_database.dart](../../lib/core/database/app_database.dart), **v16**) mirrors only `photos`, `correspondence`, `surveyor_notes`. Registers (damage, and the new `cs_inspection_item`/`tests`) are online-only. The write-queue convention already exists and is documented at the top of `app_database.dart`: `sync_status ∈ {synced, pending_upsert, pending_delete}`.

**What the migration would take (per register table):**
1. **Schema is already ready** — every new register table carries `sync_status` + timestamps from day one (see §4/§5), so **no Supabase migration is needed** to go offline; the columns exist.
2. **Add a local mirror** — a `CREATE TABLE` for the register in `_onCreate`, plus an `if (oldVersion < N)` block in `_onUpgrade`; bump the sqflite `version` (currently 16).
3. **Route reads/writes through the cache** — change the register's provider (e.g. `CsInspectionNotifier`) from direct `SupabaseService.client.from(...)` to *SQLite-first, Supabase-in-background*, the pattern the photos/correspondence providers already use. Writes set `pending_upsert`/`pending_delete` locally, then a sync pass reconciles.
4. **Add the register to the sync pass** — wherever the existing offline tables are drained to Supabase, add the new table with the same last-write-wins reconciliation (Supabase timestamp vs local).
5. **Conflict rule** — reuse the existing rule (per `offline_sync_plan.md`); no per-module invention.

**Scope note.** Because the registers were designed with the sync columns present, offline is a **client-side-only** change later (SQLite mirror + provider routing) — no data migration, no report/exporter change. That is exactly why shipping online-only now costs nothing later. Do it once, generically, and it covers damage + C&S + DP registers together.

---

*This plan reconciles the four specs against the code as of commit `0152aac` on `main` (the 2026-07-21 publish). Where a spec and the code disagree, §2 records the code as the source of truth. D1–D6 resolved 2026-07-21; D7–D8 to action in the P&I phase. Foundation (F0–F5) begins once H&M's last bugs are closed.*
