# Context Cue System — Architecture Review & Working Base

Started 5 July 2026. This is the working reference for an in-progress redesign of the
context-cue allocation system — from AI extraction / manual entry, through the cue
manager, to each case-screen section, to the report builder.

## Implementation status

**Step 1 (rename + metadata rework) — done, 5 July 2026.** Migration
`022_case_section_cue_metadata_rework.sql` applied. `ReportSection` renamed
`CaseSection` everywhere (Dart identifiers + the `surveyor_notes.report_section` DB
column, now `case_section`). `NoteCategory` retired, replaced by `NatureOfContent` +
`EvidentiaryWeight` (two independent axes) plus a new `origin` field
(`CueOrigin`: Assured/Owner, Third Party, Surveyor). `resolvedAt` renamed/repurposed to
`lostRelevanceAt`, auto-set by the provider when a cue's priority flips to Ignored.
Priority moved to the top of every cue add/edit sheet. Background's bespoke duplicate
panel replaced with the shared `ContextCuesPanel` widget (one implementation, not two).
`flutter analyze` clean across the whole project. Full file list and design notes are in
git history for this change; the sections below (§3.1–§3.6) describe what was decided,
most of which (§3.2–§3.6) is now live — §3.1's two-level allocation model (WNCA/General
Expenses reintegration) is **not yet built**, tracked as the next step.

**Step 2 (two-level allocation model) — done, 5 July 2026.** `CaseSection.
isRepairPeriodScoped` (true for `notAverage`/`generalExpenses`). `linked_to_type`/
`linked_to_id` vocabulary extended with `'repair_period'` (`repairPeriodLinkType`
constant in `context_cues_panel.dart`) — no schema change, reused the existing
polymorphic link. `ContextCuesPanel` gained an optional `periodScope` param
(`RepairPeriodScope.forPeriod(id)` / `.unassigned()`); the unassigned bucket shows a
"Not allocated to a period" pill. New shared `RepairPeriodScopedCuesScreen` (replaces
the old bespoke `wnca_screen.dart`) renders an Unassigned register + one register per
repair period + an inline "+ New Repair Period" quick-create
(`quick_create_repair_period.dart`, `RepairPeriodsNotifier.addPeriod()` now returns the
created model). Used for both `/wnca` and the new `/general-expenses` route — General
Services & Access got its case-home card back, but repair-period-scoped instead of the
old flat register. WNCA's bespoke `NotAverageItem`/`not_average_items` (model, provider
methods, DB column) fully retired — confirmed zero existing data first — and
`buildWncaItems()` now reads from `CaseSection.notAverage`-tagged cues instead. The
global Context Cues screen's editor sheet gained a cascading "Repair Period" chip-row
(shown only when the chosen case section `isRepairPeriodScoped`), including the same
inline quick-create. New shared `CueSectionCard` widget (title+hint header wrapping a
panel) extracted to `context_cues_panel.dart` and reused by both Additional Information
and the new repair-period-scoped screen. `flutter analyze` clean across the whole
project.

**Step 3 (orphaned-tag re-embeds) — done, 5 July 2026.** All 5 previously-orphaned tags
now have a `ContextCuesPanel`: Occurrence, Attendance & Representatives, Case Timeline,
Extent of Damage (each wrapped their existing screen body in a `Column` + `Expanded` to
append the panel), and Repair Times (a second panel stacked under the existing
`repairs`-tagged one in `repair_periods_screen.dart`, added an `initiallyExpanded` param
to `ContextCuesPanel` so both don't default open at once and overwhelm the screen).

**Step 4 (case-screen quick summary) — done, 5 July 2026.** New
`ClaudeApi.draftCueQuickSummary()` — short single-sentence synopsis, explicitly *not*
report content (separate prompt/guardrails from the report-drafting functions).
`ContextCuesPanel` generates it only while collapsed and only when the active-cue set
has changed since the last summary (signature = note ids + updatedAt), shown as a second
line under the collapsed header in place of the old plain count. Collapsed height grows
from 44→62 to fit it.

**Step 5 (AI-extraction auto-classification) — done, 6 July 2026.** Added
`SurveyorNote.pendingReview` (migration `024_cue_pending_review.sql` + SQLite v13) — true
for an unconfirmed AI-suggested allocation; `editNote()` always clears it (any explicit
save = human review), and `confirmAllocation(noteId)` does a one-tap clear from the
"Suggested" tab. `add()` takes an optional `pendingReview` param.
`ClaudeApi.extractDocument()`'s `context_findings` schema now asks for a `case_section`
(the 14 `CaseSection.ordered` machine values) and an `origin`
(`assured_owner`/`third_party`/`surveyor`) guess per finding, with rules telling the model
to make its best guess rather than omit — a human confirms or corrects regardless.
`document_provider.dart`'s extraction parsing and both of `document_vault_screen.dart`'s
parsing sites (`_parsePhotoExtraction`, `reapplyExtraction`) carry the new fields through
as parallel `findingCaseSections`/`findingOrigins` lists on `DocExtractionResult`; the
single `notesNotifier.add(...)` call site that creates cues from extraction results
(`_ExtractionResultSheet._apply()`) now passes `caseSection`/`origin` (via
`CaseSection.fromValue`/`CueOrigin.fromValue`) and `pendingReview: true` unconditionally —
including when the model didn't offer a section guess, so an unclassified extracted cue
still lands in review rather than silently as "retained." `surveyor_notes_screen.dart`
gained a 4th "Suggested" tab (`priority != ignored && pendingReview == true`, badge count
in `AppColors.midBlue`); the Retained/Unallocated partitions now also require
`pendingReview == false`. Each `_NoteCard` in that tab shows a "Suggested" meta chip and a
quick check-circle icon (next to the existing edit/delete menu) calling
`confirmAllocation(noteId)`. `report_provider.dart`'s 10 AI-draft cue filters (the 5
case-build blocks × first-build and manual-redraft paths) all gained `&&
n['pending_review'] != true` — the actual safety guarantee behind the whole feature, now
shipped together with the rest of step 5 as required. `flutter analyze` clean; app
smoke-tested launching on Chrome with no startup errors (full click-through + a live
extraction-API test not yet done — left for the user to verify manually).

**Not started:** nothing — steps 1–5 are all complete. See §4 for the handful of
explicitly-deferred/out-of-scope follow-ons (per-format section mapping, formal
repair-phase concept) that were never in scope for this pass.

---

## 1. Terminology

`ReportSection` (Dart enum), the `surveyor_notes.report_section` DB column, and
`SurveyorNote.reportSection` are misnamed: of the 14 tag values that exist, only 5 are
ever read by the report builder to produce report content. The rest allocate a cue to a
**case-screen section**, not a report section. Decision: **rename now** (§4.4).

---

## 2. Gap analysis (current state, as found)

### 2.1 Three coexisting allocation paradigms

1. **Generic flat cue tag** — `SurveyorNote.reportSection` + the shared `ContextCuesPanel`
   widget. One flat tag per note, no sub-structure.
2. **Bespoke per-parent-item structured list** — Work Not Concerning Average's
   `NotAverageItem`, keyed to a specific `repair_period_id`. The only place that already
   does instance-scoped allocation, but as a one-off outside the cue system entirely.
3. **Bespoke fixed-field structured data** — Nature of the Repairs (5 booleans+comments)
   and Advice to Assured (clause ticklist+notes). Not cue-driven; an extracted cue can
   never land here automatically.

### 2.2 Case-section coverage matrix

| Case-home section | Tag exists? | Front-end cue entry? | Feeds report content? | Paradigm |
|---|---|---|---|---|
| Attendance & Representatives | `attendance` | ❌ none | ❌ | orphaned tag |
| Certificates & Class | — | ❌ | — (built from structured cert/class data) | no tag needed |
| Case Timeline | `timeline` | ❌ none | ❌ | orphaned tag |
| Occurrence | `occurrence` | ❌ none | ❌ | orphaned tag |
| Background | `background` | ✅ bespoke *private* widget (not the shared one) | ❌ reference-only | inconsistent impl. |
| Allegation / Causation | `causation` | ✅ shared `ContextCuesPanel` | ❌ reference-only | reference-only |
| Extent of Damage | `damage` | ❌ none | ❌ | orphaned tag |
| Nature of the Repairs | — | n/a | — | bespoke fields, disconnected |
| Repair Periods | `repairs`, `repairTimes` | ✅ `repairs` only; `repairTimes` has zero embed | `repairs`: ❌ reference-only; `repairTimes`: orphaned | mixed |
| Work Not Concerning Average | `notAverage` (dead) | ❌ removed 5 Jul | starved of new cues | bespoke per-period list |
| Accounts | — | ❌ | — | no tag exists |
| Documentation | — | ❌ | — | no tag exists |
| Additional Information | `previousWorks`, `extraExpenses`, `contractualHire`, `otherMatters`, `generalExpenses` (dead) | ✅ all 4 live ones | ✅ all 4 live ones AI-drafted | fully wired, flat siblings |
| Report Status | — | n/a | — | administrative, no cues needed |

### 2.3 AI-extraction doesn't allocate

`document_vault_screen.dart`'s extraction-import path calls `notesNotifier.add(...)` with
a `category` and a `source` string, but never a `reportSection`. Every AI-extracted cue
lands unallocated by construction. Manual in-section entry already auto-allocates
correctly (fixed `section` param on `ContextCuesPanel`); AI extraction does not.

### 2.4 No general hierarchy/sub-allocation capability

Nothing in the cue system supports "pick a section, then a dependent second choice."
WNCA's repair-period link is the only precedent, and it's a special-case data model
bolted on outside the unified system.

---

## 3. Questions asked and decisions made

### 3.1 Allocation model & WNCA — **DECIDED: generalize + reintegrate**

> Should case-section cue allocation gain a general two-level capability (parent section
> + conditional sub-target), with WNCA's bespoke per-period list reintegrated into the
> cue system as its first real instance — or should WNCA stay separate?

**Decision: Generalize + reintegrate WNCA.** Build the two-level model as a real,
reusable capability (parent case-section tag + optional conditional sub-target), and
migrate WNCA's `NotAverageItem` mechanism onto it rather than keeping it bespoke. This is
the biggest-scope option and sets the pattern any future instance-scoped section will
reuse (e.g., a cue scoped to a specific damage item, a specific occurrence, etc.).

**✅ Resolved — sub-target data shape, requirement, and picker UX:**
- `linked_to_type`/`linked_to_id` are **not unused** — confirmed by grep they're already
  live (a note can link to a `repair_document` in the Accounts/invoice-detail flow, and
  Photos use the identical pattern for `damage_item`/`occurrence`/`machinery_nameplate`/
  etc.). This is an established generic polymorphic link, not a blank field — the right
  move is extending its vocabulary with a new `'repair_period'` type, not adding columns.
- **Sub-target is optional, not mandatory.** WNCA and General Expenses stay selectable
  as case-sections even with zero repair periods. A cue allocated to either without a
  period gets a clearly visible "not allocated to a period" flag/pill rather than being
  hidden or blocked.
- **Picker UX: two-step.** Pick the case-section first; a second picker for the repair
  period appears only if that section supports one. Generalizes to any future
  instance-scoped section, not just these two.
- **The unallocated-period state should resolve itself quickly, not linger:**
  - During AI extraction, if content references a repair period that doesn't exist yet
    (e.g. "temporary repairs at Singapore"), the extraction flow should create that
    repair period rather than leaving the cue in limbo.
  - Independent of extraction, the surveyor should be able to create a new repair period
    inline from the cue editor itself — no need to leave the cue, go to Repair Periods,
    create one, come back.
  - **Architecture check (done):** confirmed feasible. `RepairPeriodModel` only strictly
    requires `periodId`/`caseId`/`periodNo` — every other field (title, dates, location,
    services, etc.) is optional/nullable, and `RepairPeriodsNotifier.addPeriod()` just
    inserts whatever's passed. A minimal "quick-create" (auto-assigned next `periodNo`,
    no title/dates yet, filled in later from the Repair Periods screen) requires no
    schema changes — just a lightweight creation path reachable from the cue editor.
  - **Flagged gap, not blocking:** there's no existing structured "preliminary /
    temporary / permanent" repair-phase concept in the data model — only
    `PortContext.planned`/`diversion` (whether the port call itself was planned), a
    different axis entirely. Quick-created periods get an auto-generated title (e.g.
    "Repair Period N") for the surveyor to rename; a formal phase field is a possible
    future refinement, not attempted in this pass.

### 3.2 Orphaned/dead tags — **DECIDED: give them real embeds**

> 7 tags have no front-end entry point and feed no report content (Occurrence,
> Attendance, Timeline, Extent of Damage, Repair Times — never had one; Work Not
> Concerning Average, General Expenses — had one, removed). What should happen?

**Decision: Give them real embeds.** Add a `ContextCuesPanel` (or, for WNCA, the new
two-level equivalent from §3.1) to each relevant screen, so every case section has a
consistent cue-entry point — Occurrence, Attendance & Representatives, Case Timeline,
Extent of Damage, Repair Periods (for `repairTimes`).

**✅ Resolved — General Expenses does *not* get a flat re-embed.** Confirmed reasoning:
General Services & Access isn't really a case-level concept at all — it belongs to
whichever repair period it occurs in, exactly like WNCA. In practice there are two
states:

1. **No repair period exists yet** — anticipated general services (drydocking, staging,
   gas freeing, etc.) belong in **Nature of the Repairs**, as anticipated/predictable
   service needs — alongside the existing anticipated-sequence bullet list.
2. **A repair period is confirmed** — general services are attached to *that specific
   period*, which is exactly what the existing services/hot-work checklist in
   `repair_periods_screen.dart` already captures (`_buildServicesAndHotWorkText`).

So General Expenses is **not an exception to exclude** — it's a second confirmed instance
of the §3.1 two-level pattern (parent tag + repair-period sub-target), with an added
twist: the "no parent instance exists yet" case routes to Nature of the Repairs instead
of sitting unallocated. `SectionType.generalServices`/`ReportSection.generalExpenses` as
a flat, independent tag should be retired once §3.1's model absorbs it, not re-embedded
as-is.

**✅ Resolved — dedicated structured checklist.** Nature of the Repairs gets its own
"anticipated general services" checklist mirroring the confirmed per-repair-period one
(same item set: drydocking, staging, gas freeing, hot work certification, crane hire,
diving, etc.), captured before any repair period exists. Symmetric with the confirmed
state, and the anticipated selections can pre-fill the real per-period checklist once a
period is created.

### 3.3 Reference-only cues (Background/Causation/Repairs) — **DECIDED: hybrid, generalize the split**

> Should Background/Causation/Repairs cues stay reference-only, or start feeding an AI
> draft like Additional Information's subtypes do?

**Decision (verbatim rationale):** *"The current implementation is a leftover of the
early development of the system, that I would like now to be generalised. It sort of
works for me though as I have access to summaries before I engage with the vessel
representative during attendance. I still think we need a short AI drafted summary for
the purpose of the presentation view in the case screen, but the real narrative section
within the report builder will not depend on this and will use all the language and
writing rules, and create the full paragraph."*

This is a **new, generalized two-purpose model**, not a pick from the original options:

1. **Case-screen quick summary** (new capability) — a short AI-drafted synopsis of a
   section's cues, shown *in the case-screen presentation* (e.g., inside or above the
   `ContextCuesPanel`), for the surveyor's own situational awareness/prep before
   attending the vessel. This should be **generalized uniformly** across cue-holding
   sections — not just Background.
2. **Report builder narrative** — stays fully decoupled from #1. It continues to be
   built via its own dedicated, spec-compliant drafting pipeline (full writing-style
   guardrails, structured case data, the works) — exactly the existing pattern for
   Additional Information's 4 subtypes and `draftCauseConsideration`. The quick summary
   text is never substituted in as report content.

**✅ Resolved — collapsed-state preview only.** The quick summary replaces the current
plain count badge shown when a `ContextCuesPanel` is collapsed — it's a substitute for
"N cues" in the collapsed header, and disappears once the panel is expanded to show the
actual cue list. Applies uniformly to every cue-holding section, not a subset.

**Design not yet settled:**
- What triggers (re)generation — on-demand, auto-refresh when cues change, or cached
  until manually refreshed. Given it's collapsed-state-only, regenerating on every cue
  add/edit while the panel happens to be collapsed is the simplest default; revisit if
  it proves too chatty on API calls.
- Cost/attribution: this generates a new AI call per section per view. Per
  `project_commercial_deployment` — AI cost attribution isn't built yet and the app is
  still single-user testing, so this is fine for now, but flag it as a line item for the
  eventual multi-tenant cost-tracking work.

### 3.4 Naming rename — **DECIDED: rename now**

> Rename `ReportSection` → something like `CaseSection` to match what it actually is?

**Decision: Rename now.**

**Scope of the rename (Dart-side, confirmed by grep):**
- `lib/features/surveyor_notes/models/surveyor_note_model.dart` — the `ReportSection`
  enum itself, `fromValue`, `value`, `label`/`shortLabel`, `ordered`.
- `lib/shared/widgets/context_cues_panel.dart` — `section` param, `_sectionColor` switch.
- `lib/features/surveyor_notes/screens/surveyor_notes_screen.dart` — duplicate
  `_sectionColor` switch, section picker, tab grouping.
- `lib/features/surveyor_notes/providers/surveyor_notes_provider.dart` — `forSection()`.
- Every screen embedding `ContextCuesPanel`/reading `.reportSection`: `background_screen.dart`,
  `causation_screen.dart`, `repair_periods_screen.dart`, `additional_information_screen.dart`.
- `lib/features/reports/providers/report_provider.dart` — all `n['report_section'] == '...'`
  reads.

**✅ Resolved — the database column is renamed too**
(`surveyor_notes.report_section` → `case_section`), not just the Dart-side identifiers.
Confirmed rationale: this distinction becomes load-bearing once multi-format support is
built out properly — a **case section** (stable, format-independent: where a cue is
allocated on the case screen) is a genuinely different concept from a **report section**
(format-dependent: which numbered section of the *selected output format's* report a
piece of content ends up in). The same case section may map to a different report
section — different heading, different number, sometimes no equivalent at all — depending
on whether the case is `abl`, `oceano_services`, or `nordic`. Keeping both named
"report section" today actively hides that distinction.

**Forward-looking implication (not in scope now, noted for later):** this points toward
an eventual explicit `case_section → report_section` mapping, keyed by output format —
i.e. a small per-format lookup table/config rather than the current implicit 1:1 assumed
by `SectionType`/`oceanoSectionOrder` (which is already Oceanoservices-specific per its
own doc comment). Out of scope for this pass, but the rename is a prerequisite for it to
even be expressible cleanly.

**Migration requirement:** `ALTER TABLE surveyor_notes RENAME COLUMN report_section TO
case_section` plus updating every `.eq('report_section', ...)` / `n['report_section']`
map-key read across `report_provider.dart`, the providers, and the `toMap`/`fromMap` on
`SurveyorNote` — no data loss, straightforward rename, but touches more call sites than
the enum-only version would have.

### 3.5 AI-extraction auto-allocation — **DECIDED: auto-classify + mandatory review tab**

> Should AI document extraction auto-assign a case-section tag, or keep requiring manual
> triage?

**Decision: Add auto-classification, with mandatory surveyor review via a new tab in the
Context Cue Manager.** Extraction guesses a case-section tag per cue (and, once §3.1
lands, potentially a sub-target too), but nothing is treated as allocated until a human
confirms it — a new tab (distinct from Retained/Unallocated/Ignored) holds
auto-classified-but-unreviewed cues for the surveyor to confirm or correct.

**Design not yet settled** — needs a follow-up pass before implementation:
- Tab name/placement in `surveyor_notes_screen.dart` (e.g. "Suggested" or "Needs Review").
- Where the classification step runs — as part of `extractDocument()` in `claude_api.dart`
  (one extra field in the same extraction call) vs. a separate classification pass
  afterwards.
- Whether a cue in this new tab is excluded from feeding an AI-drafted report section
  (§2.3 risk) until confirmed — should be yes, to avoid an unreviewed guess silently
  reaching report content.

### 3.6 SurveyorNote metadata rework — **DECIDED: new Origin field, Category split into two axes, Priority repositioned, resolvedAt repurposed**

> The existing `NoteCategory` doesn't earn its keep unless it's genuinely useful for
> sorting/grouping; `CuePriority` mostly works but ignoring a cue should mean it no
> longer needs allocating anywhere; `resolvedAt` is a vestigial field from an earlier
> intent; and there's no way to record *who* a cue's content comes from.

**Decision — new `origin` field.** Every cue should record whether it originates from
**Assured/Owner**, **Third Party**, or **Surveyor** (comment/statement). Visible and
editable in the cue editor, not just informal free text (distinct from the existing
`source` field, which stays as-is — free-text provenance like "Document Title (2/3)").

**Decision — `NoteCategory` retired, replaced by two independent axes** (both wanted,
not a choice between them):

- **Nature of content** — what kind of information it is:
  `Observation/Finding` (factual observation or measurement) · `Recommendation` (advice
  on what should be done) · `Follow-up / Open Question` (needs further action or an
  answer before it can be finalized) · `Background/Reference` (contextual, no action
  needed).
- **Evidentiary weight** — how much weight the content carries:
  `Fact` (directly observed/verified by the surveyor) · `Opinion` (surveyor's
  professional judgement) · `Allegation` (a party's claim, not independently verified) ·
  `Hearsay` (secondhand/unverified report).

These are orthogonal to `origin` and to the case-section tag — e.g. "Owner alleges the
crew reported unusual noise before the incident" is Origin: Assured/Owner, Nature:
Follow-up/Open Question, Evidentiary Weight: Hearsay.

**Decision — Priority repositioned + Ignored excludes from allocation.** The
Priority selector moves to the **top** of the cue add/edit sheet — first decision, not
buried. If Priority = Ignored, the case-section (and sub-target, once §3.1 lands) picker
becomes moot: an ignored cue doesn't need allocating anywhere. Reinforces the existing
"Ignored" tab in the Context Cue Manager as the correct home for these.

**Decision — `resolvedAt` reworked, not retired.** Repurposed into a timestamp tracking
**when a cue lost relevance** (e.g. a point raised early in the survey, superseded or
answered later) — natural trigger is auto-setting it when Priority flips to Ignored
(cleared if un-ignored), rather than being a separately toggled third state. Rename
recommended for clarity — `resolvedAt` → `lostRelevanceAt` — bundled with the §3.4
renaming pass since both are "fix a stale/misleading name" work.

**Proposed `SurveyorNote` field summary after this rework:**

| Field | Status | Notes |
|---|---|---|
| `content` | unchanged | |
| `caseSection` (was `reportSection`) | renamed per §3.4 | where it's allocated |
| `natureOfContent` (new) | new — replaces `category` | Observation/Finding, Recommendation, Follow-up/Open Question, Background/Reference |
| `evidentiaryWeight` (new) | new — replaces `category` | Fact, Opinion, Allegation, Hearsay |
| `origin` (new) | new | Assured/Owner, Third Party, Surveyor |
| `priority` | unchanged enum, repositioned in UI | important / normal / ignored |
| `lostRelevanceAt` (was `resolvedAt`) | renamed + repurposed | auto-set when ignored |
| `linkedToType` / `linkedToId` | unchanged, likely reused | candidate for §3.1's sub-target |
| `source` | unchanged | free-text provenance (document/extraction batch) |
| `createdAt` / `updatedAt` | unchanged | |

**Design not yet settled:**
- Backfill/default strategy for `origin`, `natureOfContent`, `evidentiaryWeight` on
  existing rows — the app is still single-user testing per
  `project_commercial_deployment`, so a clean cutover (no attempt to preserve old
  `NoteCategory` values) is likely acceptable; confirm before implementing.
- Whether `natureOfContent`/`evidentiaryWeight` get their own colour-coding in the UI
  (mirroring the case-section colours) or a simpler badge/text treatment — the tile view
  would otherwise carry 4 separate colour-coded attributes (section, nature, weight,
  origin), which risks visual clutter.
- Cue add/edit sheet layout given the now-larger field set (Priority top, then content,
  then case-section/sub-target, then Origin/Nature/Evidentiary Weight) — needs a design
  pass, this is a meaningfully bigger form than today's.
- Synergy to note for §3.5: AI extraction could plausibly guess `origin` too (an email
  from the owner → Assured/Owner; a class report → Third Party; the surveyor's own
  dictation → Surveyor), alongside the case-section guess, landing in the same review tab.

---

## 4. Open items carried forward (not yet decided)

All of §3.1–§3.3's design questions were resolved by inline follow-up questions (see
those sections). What's left:

1. New review-tab name/placement and where the AI-extraction classification step runs
   (§3.5) — implementation detail, will decide pragmatically when built.
2. Once the rename and hierarchy model are settled, revisit `AUDIT_delta.md`/`TODO.md`
   staleness for this area (per standing note: those docs drift from code, verify before
   trusting).
3. (Future, explicitly out of scope now) the per-format `case_section → report_section`
   mapping hinted at by the DB rename decision (§3.4).
4. Backfill strategy, colour-coding, and add/edit sheet layout for the new
   `origin`/`natureOfContent`/`evidentiaryWeight` fields (§3.6) — implementation detail,
   will decide pragmatically when built (clean cutover, no attempt to preserve old
   `NoteCategory` values, given single-user testing).
5. Formal repair-phase concept (preliminary/temporary/permanent) — flagged as a gap in
   §3.1, not modeled today, not attempted this pass.

---

## 5. Sequencing — status

1. ✅ **Done.** Rename (§3.4, including the DB column) + `SurveyorNote` metadata rework
   (§3.6).
2. ✅ **Done.** Two-level allocation capability (§3.1) — WNCA + General Expenses
   reintegrated (§3.1, §3.2).
3. ✅ **Done.** Re-embedded the remaining orphaned flat tags (§3.2: Occurrence,
   Attendance, Timeline, Extent of Damage, Repair Times).
4. ✅ **Done.** Case-screen quick-summary feature (§3.3).
5. ✅ **Done.** AI-extraction auto-classification, including the report-drafting
   exclusion safety guarantee (§3.5).

## 6. Follow-on work — not attempted this pass

Everything in the original plan (§5, steps 1–5) is built. What's left is exactly the
items §4 already called out as deferred/out-of-scope, plus one verification gap:

1. **Live end-to-end verification of step 5** — import a real test document, confirm
   extracted cues land in "Suggested" (not "Retained"), confirm one, verify it now counts
   toward its case section's AI draft. Not done yet because it requires a real (paid)
   Claude extraction call; `flutter analyze` is clean and the app was smoke-tested
   launching without errors, but the actual extraction → Suggested → confirm → report-draft
   round-trip hasn't been exercised against live data.
2. Per-format `case_section → report_section` mapping (§3.4's forward-looking note) —
   explicitly out of scope, would only matter once a second output format ships.
3. Formal repair-phase concept (preliminary/temporary/permanent), flagged as a gap in
   §3.1 — not modeled today, no immediate need identified.
