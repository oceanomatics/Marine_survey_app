# Report Builder — Editor Implementation Notes

---

## Current Implementation Status (as at handoff)

This section reconciles the spec below against the actual codebase per `REPORT_BUILDER_OVERVIEW.md`. The spec below remains the target architecture; this section identifies what already exists, what deviates, and what still needs to be built.

### Architecture Delta

**What is built:** Flutter + Riverpod + Supabase stack. `assembledDataProvider` fans out ~12 parallel queries per case (case row, vessel, occurrences, damage_items, attendees, certificates, repair_periods, survey_attendances, clause_library, repair_documents with nested account_lines, timeline_events, surveyor_notes, machinery, class_conditions, documents, org config, AI generation log, all report outputs). `sectionDraftProvider.buildSections()` assembles 21 in-memory `ReportSection`s from that data. Three-tab UI: Editor / Preview / Postprocessing. Docx export via in-house OOXML builder (raw XML strings, no template library).

**What deviates from the spec below:**

| Spec section (below) | Actual `SectionType` in code | Notes |
|---|---|---|
| Executive Summary | `executiveSummary` | Placeholder template with `[bracketed prompts]` — always needs manual editing; explicitly built "last conceptually" per surveyor request |
| Section 1 (Introduction) | `opening` | Locked clause with client name / first-attendance date+location / survey-type substituted in |
| Section 2 (Attending Representatives) | `attendees` | Attendee title field (Mr./Ms./Capt.) exists; grouped per attendance |
| Section 3 (Vessel's Particulars) | `vesselParticulars` + `classStatutory` (split) | Class & Statutory is a separate section from vessel particulars in current implementation |
| Section 4 (Movements & Events) | `timeline` (auto-table, no text section) | Rendered directly at export from `timeline_events` — not a text section |
| Section 5 (Brief Technical Description) | `machineryParticulars` | Conditional — section omitted entirely if no machinery rows |
| Section 6 (Background) | `background` | Narrative field on occurrences table; AI-draftable code path exists but is not wired to any UI trigger |
| Section 7 (Damage Description) | `occurrence` + `damageDescription` (split) | Occurrence brief + vessel-status-at-casualty + aftermath clauses render as `occurrence`; damage items render as `damageDescription`. Damage Schedule is a separate auto-table |
| Section 8 (Repairs) | `repairs` + `generalServices` (split) | Repairs narrative from `repair_periods` (not `repair_records` — that's legacy dead data). `generalServices` section exists in the enum but has **no input screen** — always empty placeholder |
| Section 9 (Other Matters of Relevance) | `surveyorNotes` | Freeform tagged notes, often voice-transcribed |
| Section 10 (Cause Consideration) | `allegation` + `causation` (split) | Two mutually exclusive locked allegation clauses (formal / none raised) as `allegation`; cause narrative + AI-drafting code path as `causation` |
| Section 11 (Repair Costs) | `accounts` + `repairTimes` (split) | Cost-estimate-status selector drives locked clause; full apportionment (underwriters/owner split, FX, per-invoice clauses H-1 through H-6) computed in docx export step, not section text. Repair Times as separate auto-table |
| Section 12 (Available Information) | `informationSources` + `documentsOnFile` + `documentsRequested` (split three ways) | Grouped by `doc_category`; requested docs have a `requested_date` |
| Section 13 (Waiver) | `waiver` + `closing` | Waiver text resolved in order: org override → clause_library → hardcoded fallback |
| — | `surveyorNotes` | Freeform notes throughout the survey — maps to Section 9 |
| — | *"principal dates" section* | **Not implemented** — a code comment claims auto-render at export but no such code exists in `docx_export_service.dart` |

### Clause Library — Already Built

The spec below repeatedly proposes "locked clauses" for legal wording. This is **already implemented** as the `clause_library` table (`ClauseModel`), keyed by `(format_type, clause_type)`. Currently only `'abl'` format is seeded and used. Clauses with `{PLACEHOLDER}` tokens are filled by simple `.replaceAll()` on upstream field values (`{CURRENCY_CODE}`, `{ESTIMATED_COST}`, `{CLASS_SOCIETY}`, `{DOC_ISSUER}` etc.). Sections built from a clause are marked `isLocked: true` and rendered read-only with a purple "LOCKED" badge. See `docs/legal_clauses.md` for the full mapping.

**Implication:** the "locked text" references throughout the spec below (WP clauses, standard remarks, waiver text, allegation clauses, cost-approval statements) do not need to be built — they need to be added as rows in `clause_library` with the right `clause_type` key and any placeholders wired to upstream fields.

### GPN-AI Compliance Gate — Already Built

The spec references GPN-AI (Federal Court AI-disclosure practice note) requirements. This is **enforced in `ExportButton`**: any section marked `aiDrafted: true` with no `surveyorReview` set is a hard block on export. The three review chips **ACCEPTED / AMENDED / MY OWN** map to the `SurveyorReview` enum and are the only way past the gate. Annexure I (AI Generation Record table) is reserved at the end of the docx.

### Cover Photo — Already Built

Single case-wide cover photo, not per-report-output. Photo allocation to `PhotoAllocation.coverPage` from any screen writes to the same case-level flag with uniqueness enforcement. Rendered `BoxFit.contain` (never auto-cropped). Consistent with the spec's Executive Summary / cover page architecture.

### Critical Gaps to Address

These are the deviations from the spec that need work before the spec can be considered implemented:

| # | Gap | Impact | Priority | Status |
|---|-----|--------|----------|--------|
| 1 | **Section drafts are not persisted** — no `report_sections` table exists. `ReportSection.sectionId` on the model is never set. Every mount rebuilds sections fresh from case data; any surveyor edits in a section text box are lost on app restart, unless the report has been exported first. `SurveyorReview` status is similarly ephemeral. | Data loss risk. GPN-AI review chips reset on restart. | Critical | ✅ Done — `report_sections` turned out to already exist in Supabase (0 rows, orphaned scaffolding from early project setup, never wired to any Flutter code — built around a 12-label `report_section_enum` and no review field, incompatible with the app's 21-value `SectionType`). Adapted it rather than creating a new table: `docs/migrations/010_report_sections.sql` widens `section_type` to `text`, adds `surveyor_review text`, adds `UNIQUE(output_id, section_type)`; the unrelated-and-still-unused `report_versions` table was left untouched. `sectionDraftProvider` rekeyed to `(caseId, outputId)`, scoped by `output_id` only (table has no `case_id` column), content debounce-persisted / review persisted immediately, hydrated back into `buildSections()`. Migration applied directly to Supabase via the Management API. |
| 2 | **`aiDraft` hardcoded to `false`** at the only call site (`report_builder_screen.dart`). AI-drafting code paths for `background` and `causation` exist and work but are unreachable from UI. | Two AI-drafting features present but not usable. | High | ✅ Done — added `SectionDraftNotifier.draftSectionWithAi()` + a "Draft with AI" button in `SectionEditor`, shown for empty background/causation sections. **3 July 2026 — superseded per explicit surveyor request:** manual per-section clicking wasn't the desired UX; `aiDraft` is now passed as `true` on the very first build of a report (`report_builder_screen.dart`), so Background/Causation/General Services auto-draft from available data and context cues without a click. Made safe against repeat API calls on every mount by fetching `report_sections` (persisted rows) *before* the draft attempts and gating each on `!persisted.containsKey(type)` — and by persisting the result (success **or** failure placeholder) immediately after building, so a failed attempt doesn't retry forever. The manual "Draft with AI" button still exists for re-drafting later (e.g. once more cues arrive after the first empty attempt). Verified live: fixed a genuine bug found on-device where a tall Advice Summary card (see gap below) pushed the whole section-by-section editor list out of view — restructured `_EditorTab` from a `Column`+`Expanded(ListView)` into one `ListView.builder` covering everything, so nothing can starve the section list of height again. Also verified via direct DB query that persistence happens correctly (one row written after first attempt, not one per mount). **Not done in this pass:** for *successive* (Progress/Interim/Final) reports, the auto-draft always starts from a blank prompt — it does not yet feed the prior report's approved section text back in to be amended rather than regenerated from scratch. This was explicitly requested and is flagged as a distinct, not-yet-scoped follow-up. |
| 3 | **`repair_records` table is dead** — no writer UI. Some export code (Repair Times table) still reads from it. Active table is `repair_periods`. | Stale references produce wrong output if the two tables diverge. | High | ✅ Done — docx Repairs/Repair Times tables and the repairs/repairTimes section narratives now read `repair_periods`; `repairRecords` field and query removed entirely. |
| 4 | **ISM/Class incident flags edited from two screens** to same DB columns (`ism_incident_reported`, `class_incident_reported`): a `SwitchListTile` pair in `vessel_compliance_screen.dart` and a tri-state `_TriStateRow` pair in `vessel_particulars_screen.dart`. Different null-handling. | User confusion, inconsistent data. | Medium | ✅ Done — extracted `TriStateRow` to `lib/shared/widgets/tri_state_row.dart`; `vessel_compliance_screen.dart` now uses it with nullable fields (no more `null → false` coercion). |
| 5 | **Preview and docx are independent rendering paths** on the same data. They've drifted before (cover-photo-not-updating bug). | Silent drift possible after any change. | Medium | ✅ Done — fixed a real bug where `\n`-joined bullet lines collapsed to one run in Word (`ooxml_helpers.dart` `_para`), and extracted shared `splitSectionParagraphs()` (`lib/features/reports/utils/section_text.dart`) used by both renderers. Cover-photo byte-level rendering intentionally left as two paths (Flutter widget vs OOXML) — different rendering targets, selection is already shared via `PhotoListX.coverPhoto`. |
| 6 | **`generalServices` section has no input screen** — always empty in export. Spec Section 8 relies on this being populated via context cues. | Section 8.4 in spec unreachable. | Medium | ✅ Done — no new screen needed: the section was already a normal editable `SectionEditor` text box, it just never persisted (same root cause as #1). Resolved by #1's persistence fix. **3 July 2026: context-cue-driven AI drafting also added** — `generalServices` is now in `_aiDraftableTypes` (`report_builder_screen.dart`); the "Draft with AI" button only appears when at least one `surveyor_notes` cue tagged `general_expenses` exists (`ReportSection.generalExpenses` in `surveyor_note_model.dart`); `ClaudeApi.draftGeneralServices()` composes the prose paragraph from those cues, explicitly instructed not to mention costs. Extra Expenses (8.5) and WNCA (8.6) subsections — see Section 8 table below — remain unwired: they're meant to render as subsections of the shared `repairs` text box, but that box already has non-empty auto-built narrative content from `repair_periods` at all times, so the existing "Draft with AI only shown when content is empty" gating pattern doesn't fit them without further design (appending AI content into a box the surveyor may already be editing risks clobbering their work). Flagged, not attempted this pass. |
| 7 | **"Principal dates" section documented in code comment but not implemented anywhere** — code comment in `report_provider.dart` claims auto-render at export; no matching code in `docx_export_service.dart`. Spec Section 4 uses timeline auto-table instead. | Dead-comment maintenance debt. | Low | ✅ Done — removed the misleading comment; the `SectionType` enum comment now correctly notes it's unimplemented. |
| 8 | **`selfReviewed` status exists in `ReportStatus` enum but is not in the active stepper.** | Enum drift. | Low | ✅ Done — stepper now goes `draft → selfReviewed → submittedQc → …`. |
| 9 | **Report format hardcoded to `'abl'`** — scaffolding exists for multi-format (`outputFormat` field, per-format clause lookup) but only one section order/layout implemented. | Not a bug — a growth path when other formats needed. | Low (future) | Accepted — no action (by design; revisit when a second format is actually needed). |
| 10 | **Successive-report carry-forward not implemented** — flagged 3 July 2026. Every report build (Preliminary, Progress, Interim, Final) currently generates each narrative section from scratch (deterministic fields + one-shot AI draft); there is no mechanism that feeds the prior `report_outputs` version's approved section text back in as a base to be *amended* with new information, which several places in the spec below assume (e.g. Background/Damage/Repairs "successive report behaviour" notes). | Successive reports on the same case don't build on prior narrative; surveyor must manually copy/extend text across versions. | High (explicitly requested) | ✅ **Done 4 July 2026 — see the dedicated "Successive-Report Carry-Forward — Implementation & Testing" section immediately below this table for the full design, scope decisions, and a step-by-step manual test procedure.** Summary: scoped to exactly two section types (`background`, `generalServices`) after determining that every other narrative section (`occurrence`, `damageDescription`, `repairs`, `allegation`, `causation`, `surveyorNotes`) is deterministically rebuilt from scratch each time from shared, case-level tables that already accumulate old + new data regardless of which report is open — carrying forward for those would duplicate content, not preserve it. New `report_sections.carried_forward_content` column (migration `016_carried_forward_content.sql`) + `ReportSection.carriedForwardContent`/`fullContent`. Prior output resolved via `supersedes_version` (not `sequence_no`, which is scoped per output *type*). AI drafting prompts (`ClaudeApi.draftOccurrenceNarrative`/`draftGeneralServices`) extended with an optional `priorApprovedText` param so "Draft with AI" amends rather than redrafts from scratch. Editor shows the carried-forward text read-only/greyed above the editable new-content box; every renderer (docx, Preview) reads the new `ReportSection.fullContent` getter, which joins carried-forward + new content with no visible marker. |
| 11 | **Preview tab / docx do not enforce the Writing Style Rulebook or section-specific suggested layouts** — flagged 3 July 2026. Sections render as free-form surveyor/AI text; nothing in the editor or renderers checks for the "Reportedly" rule, voice-separation, prohibited language, or the many section-by-section suggested visual layouts documented below (e.g. Vessel's Particulars two-column no-border key:value, per-attendance blocks for Attending Representatives). | Output may not match the legal-writing and presentation conventions this whole document exists to capture. | High (explicitly requested) | **Further progress 3 July 2026 (writing-style done; presentation layouts started).** Writing-style half: added `lib/features/reports/utils/writing_style_lint.dart` — a pure, non-blocking lint pass flagging prohibited/emotive phrases and a "Reportedly" attribution check for `background`/`occurrence`/`executiveSummary`; surfaced in `SectionEditor` and rolled into `export_validation.dart`; guardrail instructions added to all four AI narrative-drafting prompts in `claude_api.dart` (background prompt also now forbids diary-style writing and stating a cause). Presentation half: discovered the Preview tab and docx export had **already drifted apart** on Vessel's Particulars, Attending Representatives, and Class & Statutory Certification — docx independently built these as structured tables straight from `assembled` data, while Preview still rendered the *section's free-text content* as flat paragraphs, ignoring the table layout entirely. Fixed by extracting shared row-builders into `lib/features/reports/utils/section_table_rows.dart` (`buildVesselParticularsRows`, `buildCertificateRows`, `buildClassConditionRows`, `buildAttendeesRows` — same shared-builder convention as `advice_summary_rows.dart`), used by both `docx_export_service.dart` and new `_KeyValueTable`/`_RegisterTable` widgets in `report_preview.dart`. Also fixed a genuine bug found in the process: the Class & Statutory Certification section's narrative clause text (`SectionType.classStatutory`) was built and reviewable in the Editor tab but was **never rendered in the exported docx at all** — added a `renderTextSection`-equivalent block ahead of the certificates/conditions tables. Attending Representatives then taken further, same session: replaced the flat register with the spec's **per-attendance block layout** — `buildAttendanceBlocks()` in `section_table_rows.dart` groups `attendees` by `attendance_id` against the ordered `survey_attendances` list, emitting one `AttendanceBlock` per attendance (auto-selected intro line based on whether a location is recorded, Date/Location/Purpose lines — Purpose reuses the existing attendance "Brief summary" field, there being no dedicated purpose/attendance-type column — and a Name/Company/Function attendee table). Attendees with no `attendance_id` (legacy rows, or cases with no `survey_attendances` records at all) fall into a trailing "Other Attendees" block, or render as the sole unlabelled block for fully legacy cases (preserving the old flat-register look where no attendance linkage exists). No "locked surveyor row" needed — the attending surveyor is already just a normal attendee with `role_type = 'surveyor'`, sorted last by the existing `AttendeeRole.sortOrder`. Rendered in both `docx_export_service.dart` (bold block label + italic intro paragraph + detail lines + table) and `report_preview.dart` (new `_AttendanceBlocksView` widget, reusing `_RegisterTable` per block). **Not done (as at 3 July):** three-voice separation as structured input for Cause Consideration (still one narrative field, see Section-Level Gaps below) — the only other named example in this gap's original description, now otherwise substantially addressed. **Further progress 4 July 2026 — remaining suggested layouts (Executive Summary through Waiver, spec lines 486–1852) worked through systematically.** Confirmed already-compliant: Executive Summary Advice Summary table (all fields present, incl. WP label swap and Survey Fee Reserve). Newly added, all via new builders in `section_table_rows.dart` shared by `report_preview.dart` + `docx_export_service.dart` (same convention as above), plus a new read-only `SectionReferencePanel` (`lib/features/reports/widgets/section_reference_panel.dart`) surfacing the same structured data in the **Editor tab** (previously editor-side presentation was untouched — free-text box only, no matter how structured the underlying data): (1) §1 Introduction — Occurrence No./Date/Title table (`buildOccurrenceRows`), now covering every occurrence rather than just `occurrences.first`; found and fixed a real bug in the process — docx read a non-existent `occurrence_date` column instead of `date_time`, so the cover-page casualty date was always blank. (2) §4 Movements & Events — Chronology of Events table: discovered it wasn't a `SectionType` at all (auto-table from `timeline_events`) and so, unlike docx, was **never rendered anywhere in the Preview tab**; now shared via `buildChronologyRows` and attached after §6 Available Information in both renderers. (3) §5 Brief Technical Description — machinery now renders as one bordered key:value block per claim object (`buildMachineryBlocks`) instead of docx's old flat 4-column table, matching the spec layout, with `Not Confirmed` placeholders per spec ("never leave blank") for any unset field; Preview previously had no handler for this section at all (silent drift, same class of bug as the others in this gap). (4) §8.6 Work Not Concerning Average — the fixed locked opening clause + bullet list now render in both docx and Preview whenever `repair_periods.not_average_items` is non-empty (`buildWncaItems`/`wncaOpeningClause`); this data already existed on the model, only the rendering was missing. (5) §10 Cause Consideration — added a Third-Party Findings register + Certainty Level line alongside (not replacing) the free-text narrative, so the voice-separated structured fields are visible as data, not just baked into editable prose. (6) §11 Repair Costs — Preview previously showed a bare "Supplier: amount / Total: amount" list with no Without-Prejudice line; now renders the same per-invoice line-item table + "Sum Approved Without Prejudice" phrase as docx (`buildAccountSummaries`/`buildAccountTotalsRows`). Also fixed a real bug found in the process: `_buildCostSummaryText` in `report_provider.dart` returned `''` whenever there were no repair documents yet, **discarding the Clause G-1 estimate-caveat text** ("no repair accounts have been received…") that's supposed to appear on Preliminary/Progress reports — docx was unaffected (it computes cost text independently) but the Editor/Preview showed a blank Repair Costs section. (7) §12 Available Information — added the spec's preferred MINRES BALDER Document\|Status table (`buildAvailableInformationRows`), alongside the existing flat bullet-list sections (kept, since that's still a valid alternate format and already carries surveyor-edited text). (8) §13 Waiver — added a sign-off block (`ReportSignOff`/`buildReportSignOff`) distinct from the existing internal attending/reviewing QC authentication block: "Yours faithfully" + surveyor name/title/company/mobile/email/website from `surveyor_profiles` (falls back to bracketed placeholders — no profile has been populated on any case yet), plus a signature-image fetch in docx export (mirrors the logo-fetch pattern; currently always empty since the signature-upload flow itself doesn't exist yet, so it correctly falls back to a text placeholder). **Not done:** Background-link toggle on Available Information (no such column exists yet — see Section-Level Gaps); signature image upload flow (no screen writes `signature_storage_path` yet, so the docx fetch path is always a no-op); Cause Consideration's three-voice separation is still presented as reference data alongside free text rather than as separate structured *inputs* replacing the merged narrative (unchanged from 3 July — a larger redesign, not a presentation-layer fix). **Correction, same day:** the first pass at the above left the Page 2 layout non-compliant — surveyor feedback was "Advice summary and table and then executive summary and then some[more] text," i.e. duplicated content. Root cause: this app had historically built the Advice Summary table (matching the spec table) *and* kept a separate pre-table `SectionType.executiveSummary` free-text placeholder section (noted in the Current Implementation Status table at the top of this doc as "explicitly built 'last conceptually' per surveyor request") rendered as a second "EXECUTIVE SUMMARY" heading + prose directly under the table, in both docx and Preview. But the spec section is literally titled "Section: Executive Summary (Advice Summary Table)" — the table *is* the executive summary; its suggested layout has no second free-text block. Fixed by: removing the duplicate heading/free-text render from both `docx_export_service.dart` and `report_preview.dart`, and removing `SectionType.executiveSummary` from the Editor tab's per-section list (the `AdviceSummaryCard` already is its editor — no schema/enum change, so no persisted data is lost, it's just no longer surfaced anywhere). Also implemented the two Page 2 blocks that precede the table per the "Page 2 Legal Designations — Architecture" section of this doc, previously entirely unbuilt: (a) Legal Designations (WP/Confidentiality/Copyright, sourced from `clause_library` `page2_*` types with the spec's verbatim text as fallback — new shared file `lib/features/reports/utils/page2_legal_text.dart`) and (b) the AI Usage Declaration using the spec's actual paragraph text (previously docx had a differently-worded ad hoc fallback, and Preview didn't render this block at all), suppressed entirely with no data when no AI calls are on record. Page 2 order in both renderers is now, top to bottom: vessel/assured/report-type banner → Legal Designations → AI Usage Declaration (conditional) → Advice Summary table → Document Control. Also tightened the Advice Summary table's border in Preview to the spec's "full-width outer border, horizontal rules between rows only" (was a full grid border) — the docx table border was left as the standard grid, since changing it would affect `DocxBuilder`'s shared table primitive used by every other table in the export, not just this one. **Further refinement, same day, per direct surveyor feedback:** (1) the title block (Vessel Name / Assured / Report Type) is now rendered as an actual bordered table cell in both docx and Preview, not floating centred text — matches the boxed outline drawn in the spec's suggested-layout ASCII literally. Required adding a `cellAlign` parameter to `DocxBuilder.addTable()`/`_table()` (`docx_builder.dart`/`ooxml_helpers.dart`) so table cell text can be centred — previously every table cell was hard-left-aligned; this is additive and defaults to left, so no other table in the app is affected. (2) Legal Designations and the AI Usage Declaration now render *after* the Advice Summary table rather than before it (still page 2) — order is now: title block table → Advice Summary table → Legal Designations → AI Usage Declaration → Document Control. **Further refinement, same day:** in the Preview tab, Legal Designations/AI Usage Declaration are now pinned to the bottom of page 2 (a `Spacer()` between the Advice Summary table and the legal block, inside the fixed-height A4 page's `Expanded` — required removing the `SingleChildScrollView` wrapper that page previously used, since `Spacer` needs a bounded-height parent; consistent with how every other body page in this file already renders as a plain, non-scrolling `Column` and accepts minor overflow as approximate-preview behaviour, per `_paginateSections`'s own doc comment). **Not done in docx:** bottom-pinning content in a flowing Word document isn't a reliable operation without fixed-height frames (Word reflows content top-to-bottom; there's no page-relative "anchor to bottom" in the OOXML this builder emits) — attempting it would mean guessing blank-paragraph padding calibrated to content length, which breaks the moment any section above it changes length. docx keeps Legal Designations/AI Usage Declaration immediately following the Advice Summary table (same relative order as Preview, just not pinned to the page bottom). |

### Successive-Report Carry-Forward — Implementation & Testing (4 July 2026)

Full design and a manual test procedure for gap #10, above. This feature has no automated test coverage (the project has no test suite for the reports feature — or indeed anywhere beyond the default `flutter create` stub — so this section *is* the test plan).

#### What it does

When a new report output (Progress / Interim / Supplementary / Final) is built on a case that already has an earlier report, the **Background** and **General Services & Access** sections now start with the prior report's approved text frozen at the top (read-only, greyed, labelled "Carried forward from prior report"), with an empty box below it for the surveyor to add what's new. The exported docx and the Preview tab both show the two pieces joined into one seamless paragraph flow — no heading, marker, or visual break between old and new. If the surveyor clicks "Draft with AI" (or it auto-drafts on first build), the AI is prompted to write *only* the incremental narrative — new developments since the prior text — not a restatement of it.

Everything else (Attending Representatives, Vessel Particulars, Machinery, Chronology, Damage Description, Repairs, Cause Consideration, Documents, Repair Costs) already "carries forward" for free, because that data lives in shared, case-level tables (`occurrences`, `damage_items`, `repair_periods`, `survey_attendances`, `surveyor_notes`, `documents`) that every report build reads fresh and in full — old rows never disappear when a new report is opened. Background and General Services & Access were the only two sections whose actual displayed text is *per-report-output* free prose with a blank/AI-drafted-once default and no underlying accumulating table to fall back on — meaning the surveyor's approved wording for report N was genuinely unrecoverable once report N+1 started, which is the literal problem gap #10 describes. Applying the same carry-forward mechanism to the other sections would have caused duplication (old content appearing both frozen at the top *and* baked into the fresh full-table rebuild below it) rather than fixing anything — see the doc comment on `SectionDraftNotifier.carryForwardEligibleTypes` in `report_provider.dart` for the itemised reasoning per section type.

#### How "prior report" is resolved

Via `report_outputs.supersedes_version` — set automatically when a new output is created, to the version code (`R001`, `R002`…) of whatever was the most recent output on the case at that moment (`ReportOutputsNotifier.createOutput`). This is deliberately *not* `sequence_no` (which is scoped per output *type* — "Advice No. 2" has `sequence_no = 2` independent of how many Preliminary/Final reports exist) and not raw `created_at` ordering (which doesn't capture which report a new one is actually meant to continue from — a Supplementary report might be created after a Final one, for example, without continuing from it). `SectionDraftNotifier._priorOutputId()` matches the current output's `supersedesVersion` against the computed version code of every other output on the case (`allReportOutputs`) to find its `output_id`.

#### Files changed

- `docs/migrations/016_carried_forward_content.sql` — additive `report_sections.carried_forward_content text` column. Applied directly to Supabase via the Management API (same convention as prior migrations in this doc).
- `report_provider.dart` — `ReportSection.carriedForwardContent` (frozen prior text) + `ReportSection.fullContent` getter (seamless join, what every renderer should display); `_PersistedSection.carriedForwardContent`/`fullContent` (same shape, for reading a row from `report_sections`); `_fetchPersistedFor(outputId)` generalises the old `_fetchPersisted()` so a *different* output's rows can be read; `_priorOutputId()` / `_rawVersionCode()` resolve the predecessor; `carryForwardEligibleTypes` constant with the full reasoning in its doc comment; `buildSections()` now takes a required `output` param and, for `background`/`generalServices` only, checks for a prior output's approved text before falling back to the existing from-scratch logic; the persisted-overlay loop and the "persist newly drafted sections" loop both updated to read/write `carried_forward_content` too; `draftSectionWithAi()` (the manual per-section "Draft with AI" button handler) passes the existing `carriedForwardContent` through as `priorApprovedText` so manual re-drafts also amend rather than restart.
- `claude_api.dart` — `draftOccurrenceNarrative()` / `draftGeneralServices()` gain an optional `priorApprovedText` param; when set, the prompt includes the prior text verbatim with an explicit instruction not to repeat it and to draft only the continuation (or return an empty string if there's genuinely nothing new).
- `report_builder_screen.dart` — `_buildDraft()` now takes the full `ReportOutput` (was just the `outputId` string) so it can pass it through to `buildSections()`.
- `section_editor.dart` — new read-only block above the text field showing `carriedForwardContent` when present, visually distinct (grey background, "Carried forward from prior report — read only" label, muted text colour) from the editable new-content box below it.
- `docx_export_service.dart` / `report_preview.dart` — the generic `renderTextSection()` helper (docx) and `_SectionBody` (Preview) both read `section.fullContent` instead of `section.content` now, so every section renders the seamless join automatically (a no-op for every section type other than the two carry-forward-eligible ones, where `fullContent` just equals `content`).

#### Manual test procedure

This requires a real (or disposable test) case with at least two report outputs, since the whole feature is about the relationship *between* two outputs on the same case.

1. **Set up report N.** Open a case, create a Preliminary report (or use an existing one). In the Editor tab, write or AI-draft some Background text — anything distinctive and easy to recognise, e.g. "TEST-BACKGROUND-N — vessel departed port at 0900." Do the same for General Services & Access if the case has `general_expenses`-tagged surveyor notes (add one via a voice note or typed note tagged to that section if it doesn't already have one — otherwise this section will legitimately stay empty and there's nothing to carry forward, which is correct/expected). Mark both sections reviewed (ACCEPTED/AMENDED/MY OWN) and issue or otherwise finalise the report (the review/issue status doesn't gate carry-forward, but it's the realistic workflow).
2. **Create report N+1 on the same case** — e.g. a Progress or Final report, via the "+ New Report" flow. Confirm the new output's `supersedes_version` will point at report N's version code (this happens automatically — nothing to check manually beyond "it's the most recent report before this one").
3. **Open the Editor tab on the new report.** Expected: the Background section shows a grey read-only box containing your exact "TEST-BACKGROUND-N…" text, labelled "Carried forward from prior report — read only", with an empty editable box beneath it. Same for General Services & Access if it had content on report N.
4. **Type something new** in the editable box below the carried-forward block, e.g. "TEST-NEW-N+1 — repairs commenced 14 August." Let the debounced autosave fire (or navigate away and back).
5. **Check the Preview tab.** The Background section should read as one continuous paragraph flow: your original "TEST-BACKGROUND-N…" text immediately followed by "TEST-NEW-N+1…", with no heading, label, or visible seam between them.
6. **Export to docx** and confirm the same seamless join appears in the actual Word document (Preview and docx share the same `fullContent` getter, but only a real export confirms the OOXML paragraph/line-break handling didn't introduce anything visible).
7. **Reopen the report** (navigate away from the Report Builder screen and back, or restart the app) and confirm the carried-forward block and your new text are both still there exactly as before — this exercises the persisted round-trip (`report_sections.carried_forward_content` + `.content`), not just in-memory state.
8. **Test the AI-amend path**, if Claude API access is available: on a *third* report (N+2) with no Background typed yet, tag a new `general_expenses` surveyor note dated after report N+1's `issued_date`/`created_at`, then click "Draft with AI" (or let it auto-draft on first open). Expected: the AI draft contains only new material, not a restatement of the carried-forward text sitting above it. If the model has nothing new to say given the inputs, it should come back empty rather than paraphrasing the old text — check the surveyor_notes cue timestamps are genuinely after the cutoff if this doesn't hold.
9. **Regression-check the "no prior report" case** — build a brand-new Preliminary report on a case with no other outputs at all. Background/General Services & Access should build exactly as they did before this change (blank, or one-shot AI draft from scratch) — no carried-forward box should appear, since `_priorOutputId()` returns null when `supersedes_version` is null.
10. **Regression-check the untouched sections** — on report N+1 from step 2, confirm Occurrence, Damage Description, Repairs, Cause Consideration, and Surveyor's Notes still show their full up-to-date content exactly as before (rebuilt fresh from current case data, no carried-forward box, no duplication) — these were deliberately left out of scope.

### Section-Level Gaps From Spec Not Yet Implemented

Referenced under the section-specific "⚠️ App Changes Required" tables throughout the spec below. Highlights:

- **Regulatory Standard selector** (spec Section 3) — currently "Construction Standards" is a free-text field at the bottom of the vessel particulars screen. Needs to be replaced with a dropdown at the top of the identity tab (Convention Vessel / DCV — National Law), with field masking driven by the selection.
- **AMSA Vessel Class as structured field** (spec Section 3) — currently free text ("3B", "AMSA DCV – 3B" etc). Needs to be two dropdowns: Vessel Use Class (1–4) + Service Category suffix (A–E).
- **Service History sub-tab on claim objects** (spec Section 6) — pre-casualty maintenance history has no structured home. Needs repeating rows on machinery/claim object: Date / Yard/Contractor / Nature of work / Annexure ref.
- **Confirmed by field on damage items** (spec Section 7) — for third-party confirmation of damage. Multi-select + date + method.
- **Damage input axis reorganisation** (spec Section 7) — currently category-first (structural/mechanical/electrical/other → machinery → item). Needs to be claim-object-first with damage type as a tag.
- **Photo placement modes** (spec Section 7) — Inline / Section gallery / Annexure. Currently photos have `PhotoAllocation` but the three-way placement per-photo-per-report is not implemented.
- **Drawing Extract asset type** (spec Section 7) — separate from photos, supports PDF/PNG/SVG + markup.
- **Context cue tags for `general_services`, `extra_expenses`, `wnca`** (spec Section 8) — extends existing cue tagging taxonomy. Also `other_matters:*` sub-tags for Section 9 routing.
- **Repair Period diversion details, damage status dashboard, repair times auto-generation** (spec Section 8) — currently the diversion flag exists but doesn't feed the cost section; damage status dashboard doesn't exist as an internal tracking view.
- **Three-voice separation and certainty level selector on Cause Consideration** (spec Section 10) — ✅ Already implemented, confirmed 4 July 2026 (this bullet was stale). `causation_sheet.dart`/`causation_screen.dart` on the case page already capture allegation status, owner's stated cause + source, repeating third-party findings, surveyor's assessment, and a certainty-level selector with a live hedging-language preview — see the Section 10 "App Changes Done" table above. The report builder's `causation`/`allegation` sections compose these into the final narrative (report_provider.dart) and additionally surface the third-party findings + certainty level as a structured reference table alongside the free text (gap #11, 4 July). No further work identified this pass.
- **MINRES BALDER table format for Available Information** (spec Section 12) — ✅ Done 4 July 2026, see gap #11. Background-link toggle (auto-generating attribution sentences in Section 6) remains unimplemented — no such column exists on `documents` yet.

---

## Data Ownership: Case Screen vs Report Builder (4 July 2026)

Explicit architectural direction from the surveyor, recorded here because it governs where *any* future field belongs, not just the ones addressed in this pass: **"generally speaking, the way it is organised, I would like to have all the data input in the case page. The report builder is only for drafting the paragraphs etc."**

Rule of thumb going forward: if a field is a *fact about the case* (a number, a status, a Yes/No, a structured selection) it belongs on a case-page screen, sourced from a shared table that every report build reads fresh. If a field is *prose the surveyor is drafting for this specific report* (a narrative paragraph, AI-draftable, reviewed via the GPN-AI chips) it stays in the report builder. The Advice Summary card was the clearest violation of this — a "report output" screen that was actually collecting case facts — so it was the first thing fixed.

### What moved, and where

Triggered by a review of the report builder's Advice Summary card, which had six fields that were really case facts wearing a report-output costume:

| Field | Was | Now | Notes |
|---|---|---|---|
| Estimated Cost of Repairs, Currency, Cost Estimate Status | `report_outputs.advice_cost_amount`/`advice_cost_currency`, input in `AdviceSummaryCard` | `cases.estimated_repair_cost`/`base_currency`/`cost_estimate_status`, input in **`AccountsScreen`** (`_CostEstimateSelector`) | This one was *already* case-level and already had a case-screen input (`accounts_screen.dart`) — confirmed via code search before building anything new, per the surveyor's own caveat ("unless it's already managed differently from the case screen"). Only the two new fields below were actually missing. |
| Cost Inclusions (general expenses Y/N, towing Y/N/N/A) | `report_outputs.advice_cost_includes_general_expenses`/`advice_cost_includes_towing` | `cases.cost_includes_general_expenses`/`cost_includes_towing` — new columns, migration `017_case_advice_fields.sql` | Added to the same `AccountsScreen` cost-estimate area (`_YesNoChips`), directly under the existing cost estimate status/amount controls. |
| Survey Fee Reserve (hours + expenses) | `report_outputs.advice_fee_reserve_hours`/`advice_fee_reserve_expenses` | `cases.survey_fee_reserve_hours`/`survey_fee_reserve_expenses` — new columns, same migration | Same `AccountsScreen` area. |
| Follow-up Attendance Required + detail | `report_outputs.advice_follow_up_required`/`advice_follow_up_detail` | `cases.follow_up_required`/`follow_up_detail` — new columns, same migration | New `_FollowUpAttendanceCard` banner at the top of **`AttendancesScreen`** — it's inherently about attendance, so it lives there rather than getting its own screen. |
| Status of Repairs | `report_outputs.advice_status_of_repairs`/`advice_status_of_repairs_detail`, a manual dropdown | **Derived, not stored** — `deriveRepairStatus()` in `repair_period_model.dart`, computed from `repair_periods` start/end dates | Per surveyor direction: "status of repairs can be deducted from the repair periods... if there is a closing date existing for the last period." Logic: no periods → Not yet commenced; any started period with no end date → Ongoing; otherwise → Complete. The spec's "Awaiting [text]" / "Deferred to [date]" nuances aren't derivable from dates alone and were dropped rather than kept as a manual override — a pure read-only computed value, displayed in the Repairs section card on the case home screen and in the Advice Summary table. |
| Date and Nature of Casualty | `report_outputs.advice_nature_of_casualty`, a free-text duplicate of the occurrence title | **Removed entirely** — sourced directly from `occurrences.title` | This field was pure duplication; the occurrence already has a title, case-level, editable on the Occurrence screen. |
| General Services & Access / Extra Expenses to Reduce Delay / Work Not Concerning Average | Two placeholder section cards on the case home screen, both navigating (incorrectly, a copy/paste leftover) to `/damage`; the actual cue data (`surveyor_notes` tagged `general_expenses`/`extra_expenses`/`not_average`) had no dedicated place to view or add it — only reachable by going to the general Surveyor's Notes screen and filtering manually | One combined "Expenses & Work Not Concerning Average" section card → new **`ExpensesWncaScreen`** (`lib/features/survey/screens/expenses_wnca_screen.dart`, route `/cases/:caseId/expenses`) | Per surveyor direction: "General expenses section, extra expense, work not concerning the averages can [be] one section... which collects the context cues (and allow to input some manually)." Three sub-sections, each listing tagged `surveyor_notes` cues with a quick-add dialog. Deliberately a self-contained new screen rather than extracting/reusing `surveyor_notes_screen.dart`'s private `_NoteEditorSheet` — lower risk, and the existing screen is left completely untouched. |
| Description of Damage, Nature of Repairs, Remarks | `report_outputs.advice_*` | **Unchanged** — still per-report prose in `AdviceSummaryCard` | These are genuinely paragraphs being drafted for *this* report, not case facts — correctly stayed in the report builder. |
| Confirmed (sign-off checkbox) | `report_outputs.advice_confirmed` | **Unchanged** | A per-report sign-off flag, correctly report-scoped. |
| Cause Consideration (allegation type, owner's cause, third-party findings, surveyor's assessment, certainty level) | — | **No change needed** | Already fully case-level, via `causation_sheet.dart`/`causation_screen.dart` — confirmed by code search before assuming this needed building. See the corrected Section-Level Gaps bullet above. |

### Implementation notes

- Migration `docs/migrations/017_case_advice_fields.sql` — 6 new nullable columns on `cases`, additive only, applied live via the Supabase Management API.
- The old `report_outputs.advice_cost_amount`/`advice_status_of_repairs`/`advice_follow_up_required` etc. columns and their `ReportOutput` Dart model fields were **left in place, not dropped** — already-issued reports may still reference them, and removing them would be a larger, riskier change than this pass warranted. They're simply no longer read by `advice_summary_rows.dart` or written by `AdviceSummaryCard`. `advice_nature_of_casualty` is the one field that's now fully orphaned (nothing reads or writes it) — a candidate for an actual column drop in a future cleanup pass, once confirmed no historical report depends on it.
- `advice_summary_rows.dart` (shared by `report_preview.dart` and `docx_export_service.dart`, so both stay in sync automatically) now reads `assembled.caseData`/`assembled.occurrences`/`assembled.repairPeriods` for every relocated field instead of `output.advice_*`.
- `CaseModel`/`cases_provider.dart` (`updateCaseRefs`) gained the 6 new fields following the exact existing pattern (nullable named params, "only update if non-null" semantics — same as every other field on that method).
- Found and fixed a real naming collision while wiring `case_home_screen.dart`'s new Expenses card: `ReportSection` is the name of *two* unrelated things in this codebase — the surveyor-notes tag enum (`surveyor_note_model.dart`) and the report-content model class (`report_provider.dart`). Resolved with `import '...report_provider.dart' hide ReportSection;` in `case_home_screen.dart`, which only needs `ReportOutput` from that file.

### Manual test procedure

1. **Cost Estimate / Fee Reserve / Cost Inclusions** — open a case's Accounts screen (`/cases/:caseId/accounts`). Set a cost estimate status, an estimated amount, both Yes/No/N-A inclusion chips, and fee reserve hours + expenses. Open the Report Builder for that case and confirm the Advice Summary table shows all of these correctly under "Estimated Cost of Repairs" / "Survey Fee Reserve" — and that `AdviceSummaryCard` in the Editor tab shows them as the new read-only "Data now entered in the case screen" block, not as editable fields.
2. **Follow-up Attendance** — open Attendance (`/cases/:caseId/attendances`), set "Yes" and type a detail. Confirm it appears in both the Advice Summary table's Remarks row and the read-only block in `AdviceSummaryCard`.
3. **Status of Repairs** — on a case with no repair periods, confirm the Repairs section card and the Advice Summary table both read "Not yet commenced." Add a repair period with a start date and no end date — both should now read "Ongoing." Add an end date — both should read "Complete."
4. **Expenses & WNCA** — open the new combined section card from the case home screen, add a cue under each of the three sub-sections, confirm counts update on the card and in the screen, confirm deleting a cue works, and confirm these same cues appear in the report builder wherever `general_expenses`/`extra_expenses`/`not_average`-tagged notes are already consumed (General Services & Access AI-draft gating, WNCA subsection).
5. **Regression** — confirm the report builder's Editor tab no longer shows input fields for Nature of Casualty, Status of Repairs, cost amount/currency/inclusions, fee reserve, or follow-up — only Description of Damage, Nature of Repairs, Remarks, and the Confirmed checkbox remain editable there.

### Further update, same day: Other Matters of Relevance → legal clause ticklist, merged into "Additional Information"

Per surveyor follow-up: "we could include the Other matters of relevance in the Expenses and work not concerning average section (maybe rename this section... as 'Additional Information' for clarity)... this section should cover legal statements... that could not be lodged somewhere else (keep the damaged parts for analysis, act as a prudent uninsured)... for the time being I'd like this to list the legal clauses with a tick for inclusion, and if no inclusion omit the section entirely in the report builder."

- **Screen renamed and merged**: `expenses_wnca_screen.dart` → **`additional_information_screen.dart`** (`AdditionalInformationScreen`, still route `/cases/:caseId/expenses` — not renamed, low value churn for a route string). The separate "Other Matters of Relevance" stub card on the case home screen (previously routed to `/reports`, i.e. "draft in Report Builder" — never actually had a home) is gone; its function is now the 4th section of this screen, alongside General Services / Extra Expenses / WNCA. The case-home section card itself is renamed "Additional Information" and its count badge now sums cue count + ticked clause count.
- **Legal clause ticklist, new mechanism**: `docs/migrations/018_other_matters_clauses.sql` — two new `clause_type_enum` values (`other_matters_retain_damaged_parts`, `other_matters_prudent_uninsured`, seeded for the `abl` format) and a new `cases.other_matters_clause_ids uuid[]` column (the tick list, full-array-replace via `CasesNotifier.updateOtherMattersClauses()` — doesn't fit the usual `updateCaseRefs` "update if non-null" pattern since it's a toggle set, not a scalar). New `lib/features/survey/providers/other_matters_clauses_provider.dart` fetches the candidate clause rows — deliberately a hardcoded list of known `clause_type` values (`otherMattersClauseTypes`), not a dynamic `LIKE 'other_matters_%'` query, because (a) `clause_type` is a real Postgres enum so `LIKE` needs an explicit `::text` cast the Supabase REST client doesn't do implicitly, and (b) new enum values need their own migration to exist at all, so there's no real "dynamic discovery" being given up by hardcoding the list.
- **Report section rebuilt around the ticklist**: `SectionType.surveyorNotes` (Dart enum name kept for DB/historical continuity — it's Section 9 "Other Matters of Relevance" in the spec) now builds its content from `data.clauses.where(ticked).map(clauseText).join('\n\n')` instead of the old `_buildSurveyorNotesText(data.surveyorNotes)` (removed, now unreferenced). Marked `isLocked: true` when non-empty, same convention as other clause-composed sections (`opening`, etc.) — this is verbatim legal text, not surveyor prose.
- **Real bug found and fixed**: the docx export had an entirely independent "SURVEYOR'S NOTES" block (`docx_export_service.dart`) that dumped **every** `surveyor_notes` row verbatim regardless of tag, completely disconnected from `sections[SectionType.surveyorNotes]`'s own content — which was being built (via the now-removed `_buildSurveyorNotesText`) but **never actually rendered anywhere in docx**, only in Preview (via the generic `_SectionBody` mechanism). Classic drift bug, same class as several others found this week. Fixed by replacing the independent block with `renderTextSection(SectionType.surveyorNotes, 'OTHER MATTERS OF RELEVANCE')` — the same shared helper every other conditionally-empty section already uses, which is also what makes the "omit if nothing ticked" behaviour work automatically in docx.
- **Preview didn't actually omit anything, anywhere, ever** — found while making the ticklist's empty state behave correctly. `report_preview.dart`'s body-section list included every `SectionType` present in `sections` unconditionally, so an empty section always rendered its heading + a "[title — not yet completed]" placeholder rather than being skipped, unlike docx's `renderTextSection` which already skips empty sections. Fixed *only* for `SectionType.surveyorNotes` (a targeted filter in the `bodyTypes` computation) rather than changing this for every section type — the placeholder behaviour is still correct and intentional for sections the surveyor is expected to eventually fill in (Background, Causation, etc.); Other Matters is different because it's explicitly meant to disappear when nothing is ticked, per this specific instruction. **Not generalised** — other conditionally-empty sections (`generalServices`, `damageDescription` with no damage items, etc.) still show the placeholder in Preview rather than being omitted, which is a real inconsistency with what docx does for some of them, but out of scope for this pass.
- **Flagged, not fixed**: the surveyor separately noted "the context cues allocation will most probably need to be reviewed as the current schema does not really allow for allocation for clear allocation to the front end sections" — i.e. `surveyor_notes.report_section` is one flat tag per note, shared identically between what the report builder consumes (`general_expenses`/`extra_expenses`/`not_average`/etc.) and what any case-screen section would show, with no richer structure (e.g. no distinction between "this cue is fully resolved into the report" vs "still pending", no per-note ordering within a section, no sub-categorisation). Also, the case-home "Surveyor's Notes" section card still routes to `VoiceNoteScreen` (`/voice`) rather than the tag-filtered `SurveyorNotesScreen` (`/notes`) — a pre-existing mismatch noted by the surveyor, not touched this pass. Both are flagged for a future design pass rather than attempted blind, per the surveyor's own "will most probably need to be reviewed" framing.

### Further update, 5 July 2026: shared `ContextCuesPanel` on all four Additional Information sections; Extra Expenses wired; WNCA cues merged; Other Matters gets a notes field

Per surveyor direction: replace each section's bespoke mini add-flow with the same register presentation used elsewhere (Causation, Repairs, and the global Context Cues screen) — "a register to take notes... same sort of presentation as the Context Cues screen, pre-allocated to the section in consideration." Also resolved the terminology ambiguity flagged just above: the case-wide `surveyor_notes` table *is* the "context cue register" (manual + document-extracted cues, feeding AI drafting); "surveyor notes" as a name is a legacy leftover from the earlier London H&M format work, not a separate concept.

- **`additional_information_screen.dart`**: `_CueSection` (bespoke card + `AlertDialog` add flow) removed for General Services & Access / Extra Expenses / WNCA, replaced by a small title+hint header wrapped around the shared `ContextCuesPanel` (`lib/shared/widgets/context_cues_panel.dart`). `_OtherMattersSection` converted to a `ConsumerStatefulWidget`, now two stacked panels: (1) the clause ticklist unchanged, plus a new free-text "Additional Notes / Clarifications" field (autosave debounce, same pattern as `background_screen.dart`); (2) the `ContextCuesPanel` for `ReportSection.otherMatters`, explicitly labelled reference-only — per surveyor direction the clause ticklist stays the sole *report* mechanism for this section, the register is a private aid.
- **Other Matters notes now feed the report**: `docs/migrations/019_other_matters_notes.sql` adds `cases.other_matters_notes text`; `report_provider.dart`'s §15 build now joins the ticked-clause text with this free-text field (clause text first, notes after) rather than clause text alone. `CasesNotifier.updateOtherMattersNotes()` persists it.
- **Gap #6 closed for Extra Expenses**: new `SectionType.extraExpenses` (own top-level section, own persisted row — not nested inside `repairs` as the original spec ASCII suggested, since `repairs` always has non-empty auto-built content and the "AI-draft only when empty" gating other sections rely on doesn't fit a subsection of an always-full box). AI-drafted from `extra_expenses`-tagged cues via new `ClaudeApi.draftExtraExpenses()`, same first-build/carry-forward pattern as `generalServices`. Rendered in docx (`EXTRA EXPENSES TO REDUCE DELAY`, right after General Services & Access) and Preview (falls through to the generic prose path, no special-casing needed). **Note**: `draftExtraExpenses()` was written to exclude cost figures, mirroring `draftGeneralServices()`'s guardrail — this is a deliberate simplification per the surveyor's explicit "same approach as General Services & Access" instruction, but it diverges from this doc's own spec text further below (Category 2, line ~1512) which calls for *approximate* amounts flagged as estimates. Flagged, not reconciled this pass.
- **WNCA merge, not replace**: `buildWncaItems()` (`section_table_rows.dart`) now takes an optional second argument — freeform cues tagged `ReportSection.notAverage` — appended after the structured per-repair-period `not_average_items` bullets. All three renderers (`docx_export_service.dart`, `report_preview.dart`, `section_reference_panel.dart`) updated identically so they don't drift. The repair-period-scoped input UI (`repair_periods_screen.dart`'s `_NotAverageSection`) is untouched; the register is a case-level supplement, not a replacement.

### Correction, same day: WNCA reverted out of Additional Information into its own standalone, per-period screen

The flat case-level WNCA register above was live for under an hour before the surveyor flagged it as a regression: "I still want it split by repair periods... add item to this period" — a flat case-level list can't express that, whereas the pre-existing per-repair-period `not_average_items` mechanism already could. Reverted:

- `buildWncaItems()`'s cue-merge argument and all three renderer call sites removed — back to repair-period data only, exactly as before this day's earlier change.
- WNCA removed from `additional_information_screen.dart`'s `_cueSections` (now just General Services & Access + Extra Expenses).
- The per-period `_NotAverageSection` widget + its add-item dialog, previously private to `repair_periods_screen.dart` and embedded in each repair period's detail card, extracted to `lib/features/survey/widgets/not_average_section.dart` (public `NotAverageSection` + `showAddNotAverageItemDialog`) and **removed** from the repair period card — one canonical place now, not two.
- New standalone screen `lib/features/survey/screens/wnca_screen.dart` (route `/cases/:caseId/wnca`), reusing that same widget: one card per repair period, each with its own add/remove list. New case-home section card "Work Not Concerning Average", positioned directly under Repairs (not grouped with Additional Information), count badge = total items across all periods.
- Separately, found and fixed while investigating: the two "Other Matters of Relevance" candidate clauses (018_other_matters_clauses.sql) were only ever seeded for `format_type = 'abl'` — every other comparable clause_type has both `abl` and `oceano_services` rows. Cases on `oceano_services` (2 of the 3 live cases) saw "No candidate clauses configured." Fixed via `020_other_matters_clauses_oceano.sql`. `nordic` intentionally left unseeded — it's a 7-row stub format, not at feature parity with the other two.

### Same day: "Surveyor's Notes" case-home card removed; new "Nature of the Repairs" section (§11.1, ahead of Repair Periods §11.2)

Two further surveyor requests, same session:

- **"Surveyor's Notes" card removed** from the case-home screen — it routed to `VoiceNoteScreen` (`/voice`), a pre-existing mismatch (docs above already flagged it as not the tag-filtered `SurveyorNotesScreen`). Now that every report section surfaces its own context-cue register inline (Background, Causation, Repair Periods, General Services, Extra Expenses, Other Matters), a separate generic entry point was redundant. `_voiceContent`/`_StatPill` (now unreferenced) and the `voices`/`voiceNotesProvider` plumbing removed from `case_home_screen.dart`. The `/voice` route and `VoiceNoteScreen` themselves are untouched — only the case-home entry point is gone.
- **Case-home "Repairs" card renamed "Repair Periods"** (the screen's own AppBar already said this) — sets up the new distinction below.
- **New "Nature of the Repairs" section** (§11.1 in the report, immediately before §11.2 Repair Periods): "if we attend a vessel right after the incident, and no repair period is present... there are at least some indications of where this claim is going, and the extent of the general services that are predictably needed." New table `case_nature_of_repairs` (one row per case, like `case_background`) — 5 boolean+comment pairs (drydocking required, Assured's plan formulated, further inspections planned, parts with long lead time, foreseeable difficulties — comment box shown once ticked) plus a free addable `sequence_items` bullet list ("Anticipated Sequence of Repairs"). New screen `nature_of_repairs_screen.dart`, case-home card with `AppColors.teal`/`Icons.fact_check_outlined`, route `/cases/:caseId/nature-of-repairs`.
  - Report wiring: new `SectionType.natureOfRepairs`, inserted into `oceanoSectionOrder` right before `SectionType.repairs`. Not AI-drafted — surveyor-entered structured content only, rendered as one paragraph per ticked flag/comment plus a bullet-per-paragraph sequence list (`_buildNatureOfRepairsText` in `report_provider.dart`). Omitted entirely when empty, same convention as Other Matters/WNCA — added to `report_preview.dart`'s `omitWhenEmpty` set (previously only `surveyorNotes`).
- **Refactor while building this**: extracted the per-repair-period "addable bullet list" pattern (previously `repair_periods_screen.dart`'s private `_NotAverageSection`, embedded in each repair period's detail card) into a generic shared widget, `lib/shared/widgets/addable_bullet_list.dart` (`AddableBulletList` + `showAddBulletItemDialog`) — used by both `wnca_screen.dart` (WNCA items) and the new `nature_of_repairs_screen.dart` (anticipated repair sequence), rather than writing the same ~120 lines twice.

### Same day: General Services & Access retired from Additional Information; new "Previous Work on the Damaged Item" cue section

Per surveyor direction: "since the general services and access is already populated the front end entry is pretty much irrelevant now" — its content overlaps the services/hot-work checklist already captured per repair period (`repair_periods_screen.dart`, auto-built into the Repairs section via `_buildServicesAndHotWorkText`), so a second manual cue-entry point for the same concept was redundant. "But I would like to have a section to capture previous work carried out on the damaged item, because this is something that has not been treated yet" — prior repairs/interventions on the damaged item before the current incident, relevant to causation, had no capture point anywhere.

- New `ReportSection.previousWorks` (`previous_works`) added to `surveyor_note_model.dart` (`ReportSection.ordered`, `fromValue`, `value`, `label`/`shortLabel`) and its accent colour added to both duplicate `_sectionColor` switches (`context_cues_panel.dart` and `surveyor_notes_screen.dart` — these two have drifted into near-identical copies; not consolidated this pass).
- `additional_information_screen.dart`'s `_cueSections` swaps `generalExpenses` → `previousWorks` (same `ContextCuesPanel` presentation, first slot). `generalExpenses`'s own `SectionType`/AI-draft pipeline is deliberately left untouched (harmless if empty) rather than retired, in case any already-tagged cues exist from before this change.
- New `SectionType.previousWorks` (§12.4, between General Services §12 and Extra Expenses §12.5), same AI-draft/carry-forward pattern as Extra Expenses — new `ClaudeApi.draftPreviousWorks()`, factual-history-only prompt (explicitly told not to speculate on whether the prior work caused the current damage — that judgement stays in Cause Consideration). Wired into docx, the manual "Draft with AI" switch, and `_aiDraftableTypes` in `report_builder_screen.dart`.
- `case_home_screen.dart`'s Additional Information card tag set updated to `{previousWorks, extraExpenses}` (drops `generalExpenses`, matching the front-end swap).

### Same day: new "Contractual / Hire" cue section; "Other Matters of Relevance" split into a plain cue register + a renamed "Advice to Assured" ticklist

Per surveyor direction: add a "contractual/hire section... similarly managed as previous work and extra expense", and split "Other Matters of Relevance" — "a section just like above for other matters of relevance, managed as above, mainly as context cue holder, the tick box as the last section - name it 'Advice to Assured'... Remove the 'Other matters -' from the label of the tick boxes."

- **New `ReportSection.contractualHire`** (`contractual_hire`) — charter party terms, off-hire periods, contractual notices to owners/charterers. Same `ContextCuesPanel` + AI-draft + carry-forward pattern as Previous Work/Extra Expenses (new `ClaudeApi.draftContractualHire()`, factual-only guardrail — no legal opinion on contractual entitlement).
- **"Other Matters of Relevance" split in two**: it used to be one combined section — a clause ticklist + free notes (the actual report content) plus a reference-only cue register underneath. Now:
  - `ReportSection.otherMatters` cues drive a genuine AI-drafted narrative, new `SectionType.otherMatters` (§12.7), same pattern as the other three — new `ClaudeApi.draftOtherMatters()`. Presented as the 4th `_CueSectionCard` in `additional_information_screen.dart`, alongside Previous Work/Extra Expenses/Contractual-Hire.
  - The clause ticklist + its free-text notes field (docs/migrations/018 & 019) keep feeding `SectionType.surveyorNotes` exactly as before (enum name, DB columns, and `CasesNotifier` methods all unchanged — zero data migration) — just retitled "Advice to Assured" everywhere user-facing (front-end section title, docx heading, case-home badge label, code comments) and moved to the bottom of the Additional Information screen, after all four cue-register cards.
- **Clause labels fixed in the DB**: `clause_library.clause_label` for the two `other_matters_*` clause types (`018_other_matters_clauses.sql`) had "Other Matters — " prefixed onto the label (e.g. "Other Matters — Prudent Uninsured") — sensible when the ticklist lived inside "Other Matters of Relevance", stale now that it's its own "Advice to Assured" section. Updated in place via `UPDATE clause_library SET clause_label = replace(...)` (all 4 rows — both `abl` and `oceano_services` formats) — no new migration file, this was a data correction not a schema change.
- `_sectionColor` switches in `context_cues_panel.dart` and `surveyor_notes_screen.dart` both got the new `contractualHire` case — these two switches are near-identical copies that have now drifted twice; still not consolidated (flagged again).

---

## Reconciliation with Oceanoservices H&M Report Analysis (v2, June 2026)

The internal analysis document *Oceanoservices H&M Report Analysis v2* (reviewed by Andrew Marsh) sets out a **19-section unified structure** as the platform's target output format. That document, this spec, and the code's 21 `SectionType` values describe the same report from three different angles. The mapping is:

| Analysis doc (19-section) | Spec section (below) | Code `SectionType` |
|---|---|---|
| Cover Page (§8.1) | — (metadata + cover photo, no editor section) | Cover assembly at export time |
| Page 2 — Legal Designations + AI Declaration + Advice Summary (§8.2) | Executive Summary | `executiveSummary` |
| 1. Table of Contents | — (auto-generated at export) | Auto |
| 2. Introduction / Scope of Work | Section 1 | `opening` |
| 3. Attending Representatives | Section 2 | `attendees` |
| 4. Vessel's Particulars | Section 3 | `vesselParticulars` |
| 5. Machinery / Equipment Particulars | Section 5 (Brief Technical Description) | `machineryParticulars` |
| 6. Class & Statutory Certification | Section 3 (integrated) | `classStatutory` |
| 7. Available Information Sources | Section 12 (part) | `informationSources` |
| 8. Chronology of Events | Section 4 (auto-table) | `timeline` (auto-table) |
| 9. Background | Section 6 | `background` |
| 10. Damage Description | Section 7 | `occurrence` + `damageDescription` |
| 11. Cause Consideration | Section 10 | `allegation` + `causation` |
| 12. Repairs | Section 8 | `repairs` |
| 13. General Services & Access | Section 8 (subsection) | `generalServices` (no input screen) |
| 14. Repair Costs | Section 11 | `accounts` |
| 15. Repair Times | Section 8 (auto-table) | `repairTimes` (auto-table) |
| 16. Surveyor's Notes | Section 9 (Other Matters) | `surveyorNotes` |
| 17. Documents Retained on File | Section 12 (part) | `documentsOnFile` |
| 18. Documents Requested | Section 12 (part) | `documentsRequested` |
| 19. Principal Dates | — (not implemented; timeline auto-table covers this) | *(dead comment)* |
| 20. Waiver | Section 13 | `waiver` + `closing` |
| Annexure I — AI Audit Record | — (auto-generated at export) | Auto (built) |

**No structural conflicts** between the three views. The analysis doc emphasises platform architecture (§5 successive reporting, §6 AI governance, §10 implementation roadmap); this spec emphasises corpus-grounded editor UX and per-section rules; the code emphasises data-flow granularity. Read together.

### Elements from the analysis doc that reinforce this spec (already reflected):

- Three-voice separation in Cause Consideration (owner allegation / analysis / opinion)
- Successive reporting framework (Preliminary → Progress → Interim → Supplementary → Final) with platform-enforced gating
- Dual sign-off requirement (attending + reviewing surveyor)
- Without Prejudice notation at each cost approval, not only in the final waiver
- Chronology as tabular (Date | Time | Event), not narrative
- Explicit Available Information Sources section
- AI Audit Record annexure as the final annexure, one row per section where AI was engaged

### Elements from the analysis doc that extend this spec (integrated into the sections below):

- **Page 2 architecture** — legal designations block (WP + confidentiality + copyright), AI declaration paragraph, then Advice Summary. Currently the spec's Executive Summary block is the Advice Summary; the legal designations and AI declaration precede it. Added below.
- **Writing style rulebook** — the analysis doc has a consolidated language/tone guide (§9). Added below as its own reference section.
- **Photo caption format** — standardised as `[Photo No.] — [Component/Location] — [Direction/context] — [Date] — [Significance to claim]`. Referenced in Section 7 spec below.
- **Type-specific conditional sections** — e.g. Refloating for grounding, Pollution for fuel spill. Configurable per casualty type. Roadmap item.

---

## Writing Style Rulebook

This section consolidates the language, tone, and legal-drafting conventions that apply throughout the report. It exists as a standalone reference because these rules apply cross-cutting, not per-section — they are the input to any AI-drafting system prompt and the checklist for any surveyor review.

Source: Oceanoservices H&M Report Analysis §9 (June 2026) + Andrew Marsh's editorial input + Pat Cannie's review comments on MINRES BALDER Advice 2.

### Voice and Person

- The surveyor is always referred to in the third person as **"the Undersigned"** or **"the Undersigned Surveyor"** — never "I", "we", "the writer", or by name in body text. Full name appears only in the sign-off block.
- Passive or third-person construction is preferred throughout: *"the vessel was inspected"*, not *"we inspected the vessel"*.
- Convention derives from IIMS guidance and Lloyd's market practice — its purpose is to project independence and objectivity.

### Attribution — Non-Negotiable

Every factual statement in the report must be traceable to a source. Attribution phrases mark that source explicitly.

| Attribution phrase | Use when |
|--------------------|----------|
| *"According to the Master…"* / *"As reported by the owner…"* / *"The Chief Engineer stated that…"* | Information supplied verbally or in writing by vessel personnel |
| *"Upon inspection by the Undersigned…"* / *"The Undersigned observed…"* | Direct observation by the surveyor at attendance |
| *"It is understood that…"* / *"The Undersigned has been informed that…"* | Information received from third parties that the surveyor cannot independently verify |
| *"The [document name] dated [date] states that…"* | Information sourced from a document (linked to Available Information table) |
| *"Reportedly"* / *"it was reported that"* | Owner/crew account of events not directly witnessed |
| *"In the opinion of the Undersigned…"* / *"It is the view of the Undersigned that…"* | Surveyor's professional judgment or conclusion |

**The "Reportedly" rule** governs Background (Section 6), Movements & Events (Section 4), Executive Summary Description of Damage, and any AI-drafted paragraph based on owner-supplied information. Applied uniformly, it separates fact from allegation.

### Key Legal Phrases

Each of these phrases carries a specific legal function. They are not stylistic choices — misuse creates risk.

| Phrase | Legal purpose |
|--------|--------------|
| **"Without Prejudice"** | Preserves Underwriters' rights. Must appear at each cost approval, not only in the final Waiver. Four locations in the report: page footer, Page 2 legal designations, cost summary at each approval, Waiver section. |
| **"Owner alleges…"** / **"It is alleged by the Owner…"** | Attributes causation to the owner without the surveyor adopting it as established fact. |
| **"In the opinion of the Undersigned…"** | Introduces the surveyor's own technical judgment. Must be clearly separated from facts and from the owner's allegation. |
| **"It is understood that…"** | Introduces information received from others that the surveyor cannot independently verify. |
| **"Subject to Underwriters' approval"** | Applied to repair items where coverage is not yet confirmed or causation is disputed. |
| **"No formal written allegation of cause has been made…"** | Appropriate when the owner has not yet formally alleged a cause — preserves flexibility. |
| **"It is the opinion of the Undersigned that the damages detailed above may reasonably be attributed to a casualty of the nature of that alleged."** | Standard remarks clause — endorses damage pattern consistency with allegation without independently confirming cause. |

### Prohibited Language

- **Unquantified qualifiers**: "apparently", "seemingly", "obviously". State facts, or flag uncertainty explicitly with *"could not be determined without further inspection"*.
- **"Good condition"**, **"fair wear and tear"** — not quantifiable without a reference standard. Either state the standard being applied or describe the observed condition.
- **First person**: "I inspected", "we visited", "my opinion" — replace with "the Undersigned" formulations.
- **Emotive or speculative language**: "unfortunately", "clearly", "as anyone can see". Neutral, factual register throughout.
- **Company promotional language**: this is a legal document, not marketing collateral.

### Sentence Construction

- Prefer short, declarative sentences. Compound-complex sentences hide ambiguity.
- One idea per paragraph in narrative sections. Bullets for enumerable items (damage lists, repair scopes).
- Numbers under ten spelt out except in measurements, times, dates, technical specifications. *"three vessels"* / *"3 knots"* / *"0900 hours"*.
- Dates in unambiguous format throughout: *"14 August 2025"*, not "14/8/25" (ambiguous US/UK) or "8/14/25".
- Times in 24-hour format: *"1430 hours"*, not *"2:30pm"*.
- Metric units by default (metres, tonnes, litres). Imperial units only where equipment specification is imperial (e.g. shaft diameter in inches for US-built machinery).

### Common Drafting Errors — AI Guardrails

The AI drafting system must actively prevent the following errors. Each is a real error surveyors make; each has a specific structural remedy.

| Error | Why it matters | Structural remedy |
|-------|--------------|--------------------|
| Mixing owner's account with surveyor's findings in the same paragraph | Blurs the fact/allegation boundary — the report can be challenged as unreliable | Enforce three-voice separation (Section 10). AI draft flagged if attribution changes within a paragraph without an explicit marker. |
| Stating a cause in the Background section | Background is the owner's account; causation belongs in Section 10 | AI draft of Section 6 must not contain phrases like "the cause was…" / "this was caused by…". Flag on generation. |
| Using "good condition" or "fair wear and tear" without a reference standard | Not quantifiable — creates dispute | AI draft flagged if these phrases appear without a preceding reference to a standard or baseline. |
| Approving costs globally without identifying claim vs owner's items | Owner's items being approved on the claim = coverage error | Cost section AI draft must enumerate claim items and owner's items separately, always. Global "approved" statements blocked. |
| Omitting pre-existing conditions | Failure to note pre-existing damage creates disputes about what the casualty caused | Damage Description schema separates casualty damage from pre-existing conditions as a distinct sub-tab. |
| Providing a cost estimate without qualification | Estimates read as commitments if the caveat is missing | Preliminary/Progress cost sections wrap estimates in the standard caveat clause (see Section 11). AI cannot suppress this. |
| Missing "Without Prejudice" at each cost approval | Approvals given without WP at each occurrence expose Underwriters | Locked WP phrase inserted automatically at each cost approval line. Not editable, cannot be omitted. |
| Writing the report as a daily diary | The report should present findings, not log the surveyor's working day (Pat Cannie's MINRES BALDER review comment) | Background AI drafting is instructed to synthesise events into narrative phases, not chronologically list every activity. Chronology table handles the day-by-day log; Background handles the interpretation. |
| Allowing AI-drafted content into the report without review | Signing surveyor must verify every section against source data | GPN-AI review gate (ACCEPTED / AMENDED / MY OWN) enforced on all AI-drafted sections before export. Already built. |

### Photo Caption Standard

Every photograph in the report must carry a caption in the following format:

```
[Photo No.] — [Component/Location] — [Direction of view or context] — [Date] — [Significance to claim]
```

Example: *"Photo 14 — Starboard bilge pump manifold — View looking forward — 17 December 2024 — Showing absence of non-return valve on bilge suction which permitted back-flooding."*

This applies to Inline, Section gallery, and Annexure placements alike (see Section 7 visual evidence model). The AI caption drafting assistant populates this format from the surveyor's short-form note and the photo EXIF; the surveyor edits significance for legal precision.

---

## Page 2 Legal Designations — Architecture

The analysis doc (§8.2) specifies that Page 2 of the report carries three distinct blocks in a fixed order **before** any substantive content:

```
┌─────────────────────────────────────────────────────────────────┐
│  (Vessel name and Assured banner — continues from cover)        │
├─────────────────────────────────────────────────────────────────┤
│  (a) LEGAL DESIGNATIONS                                          │
│  • WITHOUT PREJUDICE — "This report and all approvals of         │
│    expenditure contained herein are given without prejudice to   │
│    the rights of Underwriters."                                  │
│  • CONFIDENTIALITY — "This report is confidential and is         │
│    supplied without prejudice to any or all parties involved.    │
│    It shall not be copied or passed on to third parties without  │
│    the express permission of [issuing surveyor firm]."           │
│  • COPYRIGHT — "© [Year] [Survey Firm]. All rights reserved."    │
├─────────────────────────────────────────────────────────────────┤
│  (b) AI USAGE DECLARATION (where applicable — auto-generated)   │
│  Standard paragraph identifying: AI system used, its functions   │
│  in this report, non-substitution of surveyor's judgment,        │
│  reference to Annexure I (AI Audit Record).                      │
├─────────────────────────────────────────────────────────────────┤
│  (c) ADVICE SUMMARY                                              │
│  The Executive Summary table (see spec section below).           │
└─────────────────────────────────────────────────────────────────┘
```

### (a) Legal Designations — Locked Text

All three lines are verbatim locked clauses. Sourced from `clause_library` with `clause_type` values:

- `page2_without_prejudice`
- `page2_confidentiality`
- `page2_copyright`

Copyright year and firm name are placeholder-substituted from case + org config.

### (b) AI Usage Declaration — Auto-Generated at Export

Rendered only when the platform's audit log records that AI was engaged in this report. Auto-generated from the audit log at export time; locked on signing. Standard paragraph text (from analysis §6.4):

> *"This report was compiled with the assistance of Claude (Anthropic Inc.), a generative AI language model deployed via private API under a zero-data-retention agreement. AI assistance was used for the following purposes: [list of purposes, populated from audit log — extraction of technical data from source documents; formatting of field notes and voice transcriptions; drafting support for narrative sections as identified in Annexure I]. All AI-generated content was reviewed and where necessary amended by the signing surveyor. The opinions expressed in this report are those of the signing surveyor alone. Full details of the AI tools, model versions, source documents processed, and review records are set out in Annexure I."*

Where AI was not used at all in a given report, this block is suppressed and the Advice Summary follows the Legal Designations directly. This suppression is automatic — no surveyor toggle.

### (c) Advice Summary

The Executive Summary table as specified below.

### ⚠️ App Changes Required

| Change | Description |
|--------|-------------|
| `clause_library` seed rows | Add `page2_without_prejudice`, `page2_confidentiality`, `page2_copyright` clause rows with placeholder substitution for year and firm name. |
| AI Usage Declaration auto-generation | Wire the export step to read from the AI audit log and populate the standard declaration paragraph. Suppress when audit log has no entries for this report. |
| Page 2 layout in docx | Ensure legal designations render immediately below the vessel/assured banner, before the Advice Summary. |
| Signing lock | On report signing, the AI Usage Declaration and all Page 2 legal designations lock and cannot be edited by any subsequent user action. |

---

## Annexures and Cross-References — Architecture

This is a cross-cutting concern. Every AI-drafted paragraph, every quoted statement, and every reference to an owner-supplied document must be traceable to a specific annexure with a hyperlinked cross-reference. The current app has letter-based annexure references (Annexure A, B, C etc.) but the allocation logic is unclear, the mapping to source documents is manual, and annexures do not render in the Preview tab. This section defines the target model.

Two problems in scope:
1. **Annexure allocation** — how documents get grouped and assigned an annexure letter, given that the number and mix of annexures varies per case.
2. **Cross-references** — how in-text references (*"refer Annexure C"*, *"as stated in the Master's Attestation (Annexure D)"*) are auto-generated and kept in sync when annexures are reordered.

Corpus baseline: **REBECCA LILY** (Annexures A–I with title pages: "ANNEXURE – B", "ANNEXURE – C"), **BHAGWAN DRYDEN** (A–G, each titled by document group), **STELLA VII Final** (A–G), **SL MARTINIQUE** (A Investigation Report / B AMSA Incident Report / C Divers Reports / D BV Interim Statement / E Lube Oil Analysis). Corpus shows in-text references formatted as *"(Ref. Annex A)"* / *"(Ref. Annexure C)"* / *"(A copy of the correspondence can be found in Annexure B)"*.

---

### Annexure Allocation Model

The number of annexures varies case-by-case. Rather than pre-defining letter slots and manually assigning documents to them, the platform should group documents by **document category**, sort the categories into a deterministic order, and assign letters sequentially at export.

#### Document category (already in schema)

Every document in the vault has a `doc_category` field. The category taxonomy drives annexure grouping. Suggested category set (extend as needed — categories map to the corpus annexure titles seen across the reference reports):

| `doc_category` | Typical annexure title | Corpus examples |
|----------------|-----------------------|-----------------|
| `assessment_of_costs` | Assessment of Repair Costs | STELLA VII A, FV OLIVIA A, SOUTHERLY II A |
| `invoices` | Repair Invoices | FV OLIVIA B, SOUTHERLY II B |
| `certificates` | Survey Certificate(s) | FV OLIVIA C |
| `incident_report` | Insurance Claim / Incident Report | FV OLIVIA D, SL MARTINIQUE B |
| `investigation_report` | Investigation Report | SL MARTINIQUE A (Engage Marine 5 Whys) |
| `class_documents` | Class Correspondence / Statements | SL MARTINIQUE D (BV Interim Survey Statement) |
| `contractor_reports` | Contractor / Service Reports | BHAGWAN DRYDEN A (Korindo Energy) |
| `correspondence` | Correspondence and Quotes | BHAGWAN DRYDEN B, D |
| `oem_documents` | OEM / Manufacturer Documents | BHAGWAN DRYDEN C (Thrustmaster letter), E (Seal drawings), G (Thrustmaster recommendations) |
| `dive_reports` | Diver Reports | SL MARTINIQUE C |
| `oil_analysis` | Lube Oil Analysis | SL MARTINIQUE E, BHAGWAN DRYDEN F |
| `ndt_reports` | NDT / Inspection Reports | REBECCA LILY (Franmarine) |
| `photographs` | Photographs (grouped) | Referenced across reports |
| `drawings` | Technical Drawings / GAs | REBECCA LILY (barge GA) |
| `third_party_reports` | Third-Party Reports | Nordic examples |
| `prior_reports` | Progress / Update Reports | FV OLIVIA F |
| `bilge_modifications` / *other case-specific* | Case-specific document group | FV OLIVIA E (Bilge system modifications) |

#### Sort order — deterministic across all cases

Annexures render in a fixed category order to keep the report predictable across cases. Suggested default order (the platform admin can adjust; per-case override is discouraged for consistency):

```
1.  assessment_of_costs
2.  invoices
3.  certificates
4.  incident_report
5.  investigation_report
6.  class_documents
7.  contractor_reports
8.  oem_documents
9.  correspondence
10. dive_reports
11. oil_analysis
12. ndt_reports
13. drawings
14. photographs
15. third_party_reports
16. prior_reports
17. [any other category, alphabetical]
──────────────────────────────────
Last (fixed): AI Generation Record (Annexure I in current implementation — but the letter is dynamic; see below)
```

Categories with no documents in this case are skipped — no empty annexure slots.

#### Letter assignment

The platform assigns letters A, B, C … at export time by walking the sort order and skipping empty categories. The **AI Generation Record** always takes the **last letter**, regardless of what letter that turns out to be. Example:

- Case with 6 document categories present → Annexures A, B, C, D, E, F for the case documents; Annexure **G** for the AI Generation Record.
- Case with 3 categories → A, B, C for case documents; Annexure **D** for the AI Generation Record.

The current implementation names it "Annexure I" as a placeholder assuming 8 case annexures — this should become dynamic.

#### Annexure title page

Each annexure begins with a title page (as seen in REBECCA LILY corpus): a single centred phrase in large type — *"ANNEXURE – [letter]"* on one line, category title on a second line if space permits, or bare letter if the category name is self-evident. Rendered on a new page break.

---

### Cross-Reference Model

Every in-text reference to a document, an annexure, or a quoted statement must be a **hyperlink** in the rendered docx (a bookmark cross-reference) and a visible in-text token in the editor. Two flavours:

#### (a) Document-cited-in-narrative

When AI generates a paragraph from an uploaded document, or when a surveyor writes a paragraph referencing an owner-supplied document, the platform inserts a cross-reference token pointing to the annexure the document lives in.

**Token format in the editor:** `{{ref:doc_id}}` where `doc_id` is the document's UUID in the vault.

**Rendered form in docx:** `(Ref. Annexure C)` or `(A copy of the correspondence can be found in Annexure B)` — one of a small set of standard reference phrases the platform selects based on context. In the docx, the "Annexure C" text is a hyperlink to the annexure's title page bookmark.

**Rendered form in preview:** The reference appears as a clickable link that scrolls the preview to the annexure section.

**Standard reference phrases** — surveyor selects from a small set (or AI selects a sensible default that the surveyor can override):

| Phrase | Use when |
|--------|----------|
| *"(Ref. Annexure [X])"* | Compact reference at end of sentence — most common |
| *"A copy of [document] can be found in Annexure [X]."* | Full-sentence reference introducing the document |
| *"…as stated in [document] (Annexure [X])."* | Inline attribution |
| *"…refer [document] at Annexure [X]."* | Formal citation style |
| *"See Annexure [X] for [document]."* | End-of-paragraph reference |

Each phrase resolves the `[document]` and `[X]` placeholders from the document record at render time.

#### (b) Quoted statement / extract

When AI extracts a verbatim quote from a document (e.g. owner's incident report statement, class survey finding, contractor's service report text), the platform renders the quote as an indented block quote followed by an attribution + annexure reference:

```
> "Water back-flooded through the bilge chest in to the engine room.
>  This occurred due to valves not being shut and no one-way flow valve
>  being installed…"
>
> — Owner's Incident Report, 17 December 2024 (Annexure D)
```

The attribution + annexure reference is auto-generated from the document metadata. This matches the FV OLIVIA report's treatment of the owner's incident-report quote in Section 9.1.

#### (c) Cross-section references

Reference to another section of the same report (e.g. *"see Section 7 Damage Description"*) uses a similar bookmark mechanism. Token format `{{ref:section:damageDescription}}` renders as `Section 7 (Damage Description)` with a hyperlink to the section heading bookmark.

---

### AI-Driven Cross-Reference Insertion

When AI drafts a paragraph from a context cue (see Section 8 context cue workflow), the platform auto-inserts the appropriate cross-reference to the source document. Rule:

**If the AI-drafted paragraph is derived from a specific document in the vault → the platform appends a cross-reference token to the paragraph, using the standard reference phrase for the context.**

Example flow:

1. Surveyor uploads *"Master's Attestation dated 12 October 2025"* to the document vault. `doc_category = incident_report`. `doc_id = 550e8400-…`
2. AI extracts context cues from the document, tagged `background:casualty_event`.
3. Surveyor drafts Background (Section 6). AI-drafted paragraph uses information from the Master's Attestation.
4. Platform auto-inserts `{{ref:550e8400-…}}` at end of the sentence.
5. On preview/export, this renders as `…the Master reportedly observed the alarm at 1719 hours (Ref. Annexure D).` — where "Annexure D" is a hyperlink to the annexure title page.

**Surveyor controls:**
- The reference phrase can be changed via a dropdown on the token (five standard options).
- The reference can be deleted if the surveyor determines it's not needed.
- Deleting the reference removes the link but flags the paragraph as "attribution removed by surveyor" in the AI audit log — this is GPN-AI transparency.

**Sync behaviour:**
- If the document is re-assigned to a different category (changing its annexure letter), all cross-references pointing to it update automatically at next render.
- If the document is deleted from the vault, cross-references become broken links flagged in the editor with a red marker; the surveyor must resolve before export (either remove the reference or restore the document).

---

### Preview Rendering of Annexures

The current Preview tab does not render annexures. This is a significant gap — the surveyor cannot see the final report structure until they export the docx and open it in Word, which defeats the purpose of a Preview tab.

**Required change:** The Preview tab renders the full report including annexures. Each annexure appears as a bordered section with:

- Title page (as it would render in docx): *"ANNEXURE – [letter]"* + category title
- Document list: each document in the category shown with its filename, date, and a thumbnail (for PDFs — first page) or preview (for images)
- Clickable to expand the document inline

Documents themselves are not fully rendered in the preview (that would require in-browser PDF rendering per document — heavy). Instead, the preview shows the annexure title and a document manifest; clicking a document opens it in the vault viewer.

**Cross-reference links in the preview** are clickable and scroll to the target annexure section — this lets the surveyor click through their own references to check that everything resolves correctly.

---

### ⚠️ App Changes Required

| Change | Description |
|--------|-------------|
| Dynamic annexure allocation | Replace fixed letter slots with category-driven sort at export time. AI Generation Record always takes the final letter. |
| `doc_category` taxonomy extension | Ensure the full category set is present in the schema and the document vault UI. Extend with `oem_documents`, `investigation_report`, `dive_reports`, `oil_analysis`, `ndt_reports`, `drawings`, `contractor_reports` where missing. |
| Category sort order (admin setting) | The 17-slot default order shown above becomes an admin-configurable setting; per-case override is intentionally not exposed. |
| Cross-reference token model | Editor supports `{{ref:doc_id}}` and `{{ref:section:sectionType}}` tokens. Renders as hyperlinked text in docx and preview. |
| Standard reference phrase library | Small clause library of 5 standard reference phrases, selectable per token via inline dropdown. |
| Quoted-extract block format | AI-extracted verbatim quotes render as indented block quote + auto-generated attribution line + annexure reference. |
| AI cross-reference insertion | AI-drafted paragraphs derived from a specific document auto-insert a `{{ref:doc_id}}` token. Surveyor can edit/delete/replace the phrase. Deletion logged in AI audit trail. |
| Broken reference guard | If a referenced document is removed from the vault, the token becomes a visible red marker in the editor and blocks export until resolved. |
| Preview renders annexures | Partially done 3 July 2026 — Preview tab now renders one page per annexure letter (title + document manifest: title/date, sourced from the same `annexure_assignment` fixed-letter model as the docx export via shared `annexure_groups.dart`) plus the AI Generation Record as a final page, both included in the page-count/footer numbering and the auto-generated TOC. **Not done:** clickable cross-reference links (depends on the `{{ref:doc_id}}` token model below, which is unbuilt), thumbnails/document preview, and the dynamic category-driven letter allocation (still the fixed per-document `annexure_assignment` field). |
| Docx bookmark generation | Each annexure title page and each section heading generates a Word bookmark; cross-references render as `HYPERLINK` fields pointing to those bookmarks. |
| Reference audit trail | Every cross-reference insertion/deletion/edit logged in the AI audit trail alongside the paragraph it belongs to. |

---

## How to Read the Rest of This Document

The remainder of this document is the **target spec** as developed section by section, based on the corpus of 11+ H&M survey reports (Marsh Maritime, ABL London, Nordic Insurers formats) and Andrew Marsh's editorial input. Where a section contains an "⚠️ App Changes Required" table, that table lists deltas from the current implementation.

The spec's section numbering (Executive Summary + 1–13) does **not** map one-to-one to the code's 21 `SectionType` values or to the analysis doc's 19-section structure — see the Reconciliation table above for the mapping. For implementation, the code's finer-grained section split is the operative one; the spec's structure is a document-design convenience for describing the rendered output.

The Writing Style Rulebook and Page 2 Legal Designations sections above are cross-cutting — they apply throughout the report and should be treated as inputs to any AI-drafting system prompt and to any surveyor review checklist.

---

## Section: Executive Summary (Advice Summary Table)

The executive summary is presented as a **single page**, largely tabular. It sits immediately below the vessel name and Assured line on Page 2, following the Legal Designations and AI Usage Declaration blocks. Best-practice model: **STEEP POINT Advice 3** (AU-M53-1078 R004) and CARMA Advice 1 (LO-M53-052171) — both use an identical two-column layout where bold row labels occupy a narrow left column (~30%) and free content fills the right column (~70%). Rows vary in height as needed. No column headers. Full-width border on the outer table; horizontal rules between rows only.

### Suggested Page Layout

```
┌─────────────────────────────────────────────────────────┐
│  [Vessel Name — large, centred]                         │
│  ASSURED: [Assured Name — centred]                      │
│  [REPORT TYPE] SUMMARY — centred, underlined            │
└─────────────────────────────────────────────────────────┘

┌──────────────────────┬──────────────────────────────────┐
│ UCR / Reference      │ [auto or TBD]                    │
├──────────────────────┼──────────────────────────────────┤
│ Date and Nature      │ [DOL date] – [nature, 1 line]    │
│ of Casualty          │                                  │
├──────────────────────┼──────────────────────────────────┤
│ Description          │ [2–5 sentences, AI-drafted,      │
│ of Damage            │  surveyor edits]                 │
├──────────────────────┼──────────────────────────────────┤
│ Nature of Repairs    │ [2–4 sentences, AI-drafted,      │
│                      │  surveyor edits]                 │
├──────────────────────┼──────────────────────────────────┤
│ Status of Repairs    │ [dropdown value + free text]     │
│ (If deferred,        │                                  │
│ do we know to when?) │                                  │
├──────────────────────┼──────────────────────────────────┤
│ [Estimated /         │ Permanent Repairs: [CCY amount]  │
│  Approved WP]        │ Including general expenses: Y/N  │
│                      │ Including towing costs: Y/N/N/A  │
├──────────────────────┼──────────────────────────────────┤
│ Survey Fee Reserve   │ Hours: [n]    Expenses: [CCY n]  │
│                      │ [locked disclaimer text, italic] │
├──────────────────────┼──────────────────────────────────┤
│ Remarks              │ [allegation status, 1 line]      │
│                      │ Is a follow-up required: Yes/No  │
│                      │ [free text if Yes]               │
└──────────────────────┴──────────────────────────────────┘
```

> **Note on cost row label:** renders as "Estimated Cost of Repairs" on Preliminary/Progress reports. Changes to **"Sum Approved Without Prejudice"** (bold, locked phrase) when accounts have been reviewed on Interim/Supplementary/Final reports.

### Fields

| Field | Input Type | Source / Behaviour |
|-------|------------|--------------------|
| UCR / Client Reference | Short text | Entered at case creation; editable. Show yellow flag if still "TBD" at Final report stage. |
| Date and Nature of Casualty | Date picker + short text | Date pulled from DOL field. Nature of casualty entered by surveyor (owners' description — not surveyor's causation finding). |
| Description of Damage | Multi-line text | AI-drafted from Section 7 content (2–5 sentences, no causation language). Surveyor edits before approval. |
| Nature of Repairs | Multi-line text | AI-drafted from Section 8 content (2–4 sentences). Surveyor edits. |
| Status of Repairs | Dropdown + optional free text | Options: *Complete / Ongoing / Awaiting [text] / Deferred to [date] / Not yet commenced* |
| Estimated / Approved Cost | Currency + amount | Separate rows for Temporary, Permanent, Estimated. Label changes to "Sum Approved Without Prejudice" when accounts have been reviewed — phrase is locked, not editable. |
| Cost inclusions | Checkbox | General expenses: Yes / No. Towing costs: Yes / No / N/A. |
| Survey Fee Reserve | Hours (numeric) + Expenses (currency + amount) | Followed by verbatim standard disclaimer — locked text, not editable. |
| Allegation status | Radio button | *Allegation made (refer to remarks section)* / *No formal allegation made*. Drives WP clause wording in body of report. |
| Follow-up attendance required | Radio + conditional text | Yes / No. If Yes: expand free-text field for nature and expected timeline of follow-up. |
| Remarks | Multi-line text | Optional free text for anything not captured above. |

> ⚠️ **"Reportedly" rule — Executive Summary:** The Date and Nature of Casualty line and the Description of Damage must use **"reportedly"** when describing events not directly witnessed by the surveyor (e.g. *"04 January 2025 — Reported Grounding"*, *"…damage reportedly sustained following contact with the seabed…"*). Applies to all AI-drafted content in this section.

### Auto-populated (read-only in editor)

Vessel name, IMO, GT, Flag, Report type, Report number, Tech File number, Instruction date, Report date, Attending surveyor name and contact — all pulled from case record and user account.

### Conditional display

- Cost approval fields (WP label) only appear when accounts have been reviewed.
- Fee Reserve disclaimer text always shown below fee fields; verbatim locked.
- Follow-up free-text collapses when "No" is selected.
- On Progress / Interim / Supplementary / Final reports: pre-populate from prior advice and highlight changed fields.

---

## Section 1: Introduction / Opening Certification

> **Applicability:** This section applies to **Progress, Interim, Supplementary, and Final reports only**. It is **not rendered for Preliminary reports**, where the executive summary table is sufficient and no formal survey attendance has yet been completed. The platform should suppress this section entirely in Preliminary mode.

This section is designed to fit on a **single page**, shared with the Attending Representatives table (Section 2) and — on smaller cases — the Vessel's Particulars (Section 3). It is compact by design: one short certifying paragraph, one occurrence table. Best-practice models: **MINRES BALDER Advice 2** (SI-M53-057350) for the ABL "This is to certify" format; **FV OLIVIA Final Report** and **STELLA VII Final Report** for the Marsh Maritime equivalent paragraph.

### Suggested Page Layout

```
1  INTRODUCTION / SCOPE OF WORK
   ─────────────────────────────────────────────────────────
   This is to certify that at the request of [Instructing
   Underwriter], being the [Leading / Subscribing] Hull &
   Machinery Underwriters of the above-mentioned vessel,
   the Undersigned Surveyor has on [survey date(s)] [action:
   surveyed / attended / undertaken enquiries regarding]
   the subject vessel [location details], in order to
   ascertain the cause, nature and extent of damage
   sustained on the following occasion:

   ┌──────────────────────┬──────────────────────────────────┐
   │ Occurrence No. 1     │ [DOL date]                       │
   │                      │ [Occurrence title — 1 line]      │
   └──────────────────────┴──────────────────────────────────┘

   [Optional: second sentence referencing prior reports in
   the succession, e.g. "A Preliminary Report was issued
   on [date]. This [Interim / Final] Report is issued
   in continuation thereof."]
```

### Fields

| Field | Input Type | Source / Behaviour |
|-------|------------|--------------------|
| Instructing underwriter | Short text | Pulled from case record; editable. |
| Leading / Subscribing | Radio button | *Leading* / *Subscribing* / *H&M Underwriters Concerned* |
| Survey date(s) | Date picker (multi) | One or more attendance dates; auto-populated from case attendance log. |
| Survey action verb | Dropdown | *surveyed / attended / undertaken enquiries regarding* — surveyor selects the appropriate level of engagement. |
| Survey location | Short text | Yard name, port, country — entered by surveyor. |
| Occurrence table — date | Date (read-only) | Pulled from DOL field. |
| Occurrence table — title | Short text (read-only) | Pulled from occurrence description on cover page. |
| Prior report reference | Conditional text | On Progress/Interim/Supplementary/Final: auto-inserts reference to the preceding advice(s) by report number and date. Surveyor can edit. On first advice: suppressed. |

> ⚠️ **"Reportedly" rule:** Any reference to the casualty, occurrence, or damage within this section — and throughout all AI-drafted content — must use the word **"reportedly"** when describing events as relayed by the owners, crew, or operators rather than directly witnessed by the surveyor. E.g. *"…in relation to an engine room flooding event that reportedly occurred on 16 December 2024…"* This applies to the occurrence description in the certifying paragraph, the occurrence table title, and any AI-generated narrative. The platform should flag surveyor-written text in this section that describes the occurrence without this qualifier.

### Auto-populated (read-only)

Instructing underwriter name, DOL, occurrence title, and prior report references are all pulled from the case record. The certifying paragraph is AI-assembled from these fields using the fixed sentence structure above; the surveyor edits as needed before approval.

### Conditional display

- Entire section suppressed on **Preliminary** reports.
- Prior report reference sentence suppressed on **first advice** (Progress or Interim Advice No. 1).
- Survey action verb defaults to *"surveyed"* when a physical attendance date is logged; defaults to *"undertaken enquiries regarding"* when no physical attendance has been recorded.

---


---

## Section 2: Attending Representatives

This section is structured as **one block per attendance**, not a single flat table. Each attendance has its own introductory line, date/location details, and attendee table. The surveyor can add as many attendance blocks as required. This matches how the platform currently operates and reflects what is required in multi-visit cases.

### Suggested Layout (per attendance block)

```
2  ATTENDING REPRESENTATIVES

   Attendance No. 1
   ─────────────────────────────────────────────────────────
   [Introductory line — auto-selected]

   Date        : [date]
   Location    : [yard / vessel name, port, state]
   Purpose     : [e.g. Initial survey / Damage inspection / Repair inspection]

   ┌──────────────────┬─────────────────────────┬───────────────────────────────┐
   │ Name             │ Company                 │ Function                      │
   ├──────────────────┼─────────────────────────┼───────────────────────────────┤
   │ [name]           │ [company]               │ [function / role]             │
   │ ...              │ ...                     │ ...                           │
   │ [Surveyor name]  │ Marsh Maritime Pty Ltd  │ Surveyor for H&M Underwriters │
   └──────────────────┴─────────────────────────┴───────────────────────────────┘

   Attendance No. 2  [+ Add attendance]
   ─────────────────────────────────────────────────────────
   [same structure repeats]
```

### Fields (per attendance block)

| Field | Input Type | Source / Behaviour |
|-------|------------|--------------------|
| Introductory line | Auto-selected text | Physical attendance: *"The following persons were also present during the survey / meetings:"* Correspondence only: *"The following persons were in attendance, or provided information:"* Selected based on attendance type; not editable. |
| Date | Date picker | Entered by surveyor. |
| Location | Short text | Yard name, vessel location, port, state. Entered by surveyor. |
| Purpose | Short text + suggestions | Free text. Common values: *Initial survey / Damage inspection / Repair inspection / Follow-up inspection / Docking attendance*. |
| Name | Short text | Entered by surveyor. |
| Company | Short text | Entered by surveyor. |
| Function / Role | Short text + suggestions | Free text. Common values: *Master / Chief Engineer / Vessel Superintendent / Technical Manager / Engineering Supervisor / Class Surveyor / Operations Manager / Dive Supervisor*. |
| Attending surveyor row | Read-only | Auto-populated from user account. Locked at bottom of each table, cannot be reordered. |

### Notes

- The **"+ Add attendance"** button appends a new block. Blocks are numbered sequentially.
- Each block has its own attendee table — attendees can differ between attendances.
- On successive reports, blocks are pre-populated from the prior advice. New attendance blocks are added for visits that occurred since the previous report.
- For Preliminary reports with no physical attendance, a single block with correspondence-only phrasing suffices; the attendee table may contain only owner/manager contacts plus the surveyor row.

---


---

## Section 3: Vessel's Particulars

A key-value list rendered in two columns (label : value), no outer border, compact line spacing. Typically shares a page with Sections 1 and 2. Best-practice models: **GREAT MIND Preliminary** and **MINRES BALDER Advice 2** for classed/SOLAS vessels; **BHAGWAN DRYDEN**, **NW LOUISA BAY**, **STELLA VII**, **FV OLIVIA** for Australian DCV vessels.

The field set is driven by a **Regulatory Standard selector** (see below), which must sit near the top of the identity tab — not at the bottom as currently implemented.

---

### ✅ App Change Done — Regulatory Standard Selector

**Status:** Done — `regulatory_standard` column added (`docs/migrations/011_vessel_regulatory_standard.sql`), `RegulatoryStandard` enum + `ChipRow<RegulatoryStandard>` selector inserted immediately below Vessel Type in `vessel_particulars_screen.dart`'s Identity tab. The free-text "Construction Standard" field has been removed from the UI (its column/data is left untouched, just no longer editable). Field masking implemented for the Identity tab only: the Classification section (Class Society/Notation/P&I Club) hides when DCV is selected; a new DCV-only block appears in its place. Dimensions-tab relabeling per standard (e.g. "Length (Measured)" vs "LOA") was **not** done — deferred, out of scope for this pass. `_buildVesselText`/docx export updated additively to render the new fields.

**Current behaviour (superseded):** "Construction Standards" is a free-text field at the bottom of the vessel particulars screen.

**Required changes:**

1. **Rename and relocate:** Replace with a **Regulatory Standard** dropdown, positioned immediately below Vessel Type at the top of the identity tab.
2. **Field masking:** Selecting a Regulatory Standard hides all irrelevant fields and reveals only those applicable to that standard. This is how the app should already work — confirm this is implemented at the Regulatory Standard level, not the legacy Construction Standards field.

**Dropdown options:**

| Value | When to use |
|-------|-------------|
| **Convention Vessel** | SOLAS / IMO vessels — internationally trading or classed, with an IMO number and flag state certification |
| **DCV — National Law** | Australian domestic commercial vessel under the Marine Safety (Domestic Commercial Vessel) National Law Act 2012, surveyed to Marine Order 503. Covers both NSCV (new vessels, post-2013) and USL Code (existing/transitional vessels). No need to distinguish USL vs NSCV at this level — the survey certificate itself records the applicable standard. |

> **Rationale for merging DCV into one option:** Both USL and NSCV vessels are issued the same AMSA Certificate of Survey format (COS-xxxxx-xxx), carry the same AMSA class notation and UVI, and are regulated under the same national law. The distinction between USL and NSCV is a construction/survey standard question, not a reporting field — it does not affect what appears in an H&M survey report. One DCV option is cleaner and sufficient.

---

### ✅ App Change Done — AMSA Vessel Class Field (DCV only)

**Status:** Done — `amsa_vessel_use_class`/`amsa_service_category` columns added (migration 011), `AmsaVesselUseClass`/`AmsaServiceCategory` enums + two `ChipRow`s added to the DCV-only block, with a live "Class 3B"-style combined preview. `VesselModel.amsaClassDisplay` getter added. Note: no free-text "Class" field holding values like "3B" actually existed anywhere in the codebase prior to this change (confirmed by search) — this was a net-new addition, not a rename.

**Current behaviour (superseded):** The "Class" field is a free-text field, used inconsistently (e.g. "3B", "AMSA DCV – 3B", "AMSA DCV 3B").

**Required change:** Replace with a structured two-part field:

- **Vessel Use Class** (dropdown) — drives the service category suffix options
- **Service Category** (dropdown, conditional on class) — the operational area suffix

**AMSA Vessel Use Class dropdown:**

| Option | Meaning |
|--------|---------|
| Class 1 | Passenger vessel (>12 passengers) |
| Class 2 | Non-passenger vessel (≤12 passengers) |
| Class 3 | Fishing vessel |
| Class 4 | Hire and drive (recreational hirer) |

**Service Category suffix dropdown** (appended to class, e.g. "3B"):

| Suffix | Operational area |
|--------|-----------------|
| A | Unlimited domestic operations (all domestic waters) |
| B | Offshore operations (beyond 3 nm, up to and including 200 nm) |
| C | Restricted offshore operations (up to 30 nm, or specified areas) |
| D | Partially smooth water operations |
| E | Smooth water / sheltered water operations |

Combined display in rendered report: **Class 3B**, **Class 1C**, **Class 2D** etc. — matching the format on the AMSA Certificate of Survey.

> **Note:** The "3B" notation seen across the corpus (STELLA VII, FV OLIVIA, NW LOUISA BAY) is Class 3 (Fishing) + B (Offshore operations). This two-part structured approach correctly represents all combinations in the fleet without free-text inconsistency.

---

### Suggested Layout

```
3  VESSEL'S PARTICULARS
   ─────────────────────────────────────────────────────────

   [CONVENTION VESSEL]

   Type               :  [vessel type]
   Regulatory Standard:  Convention Vessel
   GT / DWT           :  [x] / [x] tonnes
   IMO No.            :  [xxxxxxx]
   Flag / Home port   :  [flag] / [port]
   Built              :  [date or year], [shipyard], [country]
   Owners             :  [owner name]
   Managers           :  [manager name]      ← suppress if same as owner
   Class / Notation   :  [society] / [full notation string]
   DOC details        :  [issuer], Exp [date]
   ISM SMC details    :  [issuer], Exp [date]
   Casualty ISM reported?    :  Yes / No / N/A
   Prior related ISM reports?:  Yes / No / Not Seen
   Last drydock       :  [location], [date]   ← Convention only

   ─────────────────────────────────────────────────────────

   [DCV – USL or DCV – NSCV]

   Type               :  [vessel type]
   Regulatory Standard:  DCV – USL / DCV – NSCV
   Owner              :  [owner]
   Flag / Home port   :  Australian / [port]
   Built              :  [year or date]
   Hull material      :  [Steel / Aluminium / GRP / Timber]
   Length (Measured)  :  [x] m
   Breadth (MLD)      :  [x] m
   Depth (MLD)        :  [x] m
   Gross Tonnage      :  [x] (National)
   Unique Vessel Identifier  :  [UVI]
   Survey Certificate No.    :  [COS-xxxxx-xxx]
   Class              :  [e.g. 3B]
   Equipment Due      :  [date]
   Hull Due           :  [date]
   Tail Shaft Due     :  [date]
```

---

### Fields — Convention Vessel

| Field | In app? | Input Type | Notes |
|-------|---------|------------|-------|
| Vessel Type | ✅ | Short text | e.g. Offshore Supply Vessel, Bulk Carrier, Tug |
| Regulatory Standard | ⚠️ move up | Dropdown | See selector note above |
| GT / DWT | ✅ | Numeric pair | tonnes |
| IMO No. | ✅ | Numeric (7 digits) | |
| Flag / Home port | ✅ | Short text | |
| Built | ✅ | Date or year | |
| Shipyard / Place of build | ❌ add | Short text | Seen in MINRES BALDER: "Astilleros Ría de Avilés / Spain / 2008" |
| Owners | ✅ | Short text | |
| Managers | ✅ | Short text | Suppress row if same as owner |
| Class / Notation | ✅ | Short text | Full notation string, e.g. ABS / A1, OSV (TOW, ATB), AMS, ACCU |
| DOC details | ✅ | Short text + date | Issuing authority + expiry |
| ISM SMC details | ✅ | Short text + date | Issuing authority + expiry |
| Casualty ISM reported? | ✅ | Radio | Yes / No / N/A |
| Prior related ISM reports? | ✅ | Radio + text | Yes (describe) / No / Not Seen |
| Last drydock | ❌ add | Location + date | Seen in London template and GREAT MIND |

### Fields — DCV Vessel (National Law)

| Field | In app? | Input Type | Notes |
|-------|---------|------------|-------|
| Vessel Type | ✅ | Short text | e.g. Fishing Vessel, Passenger Vessel, Work Boat |
| Regulatory Standard | ⚠️ move up + rename | Dropdown | Replaces "Construction Standards"; see selector above |
| Owner | ✅ | Short text | |
| Flag / Home port | ❌ add | Short text | Always "Australian / [port]" but must be explicit |
| Built | ❌ add | Date or year | Not consistently captured for DCV; required for report |
| Hull material | ❌ add | Dropdown | Steel / Aluminium / GRP / FRP / Timber |
| Length (Measured) | ✅ | Numeric + m | |
| Breadth (MLD) | ✅ | Numeric + m | |
| Depth (MLD) | ✅ | Numeric + m | |
| Gross Tonnage | ✅ | Numeric | Append "(National)" in rendered output |
| Unique Vessel Identifier | ✅ | Short text | UVI number |
| Survey Certificate No. | ✅ | Short text | COS number |
| AMSA Vessel Use Class | ⚠️ replace free text | Dropdown | Class 1 / 2 / 3 / 4 — see structured field note above |
| Service Category | ⚠️ replace free text | Dropdown (conditional) | A / B / C / D / E — combined display as e.g. "3B" |
| Equipment Due | ✅ | Date | |
| Hull Due | ✅ | Date | |
| Tail Shaft Due | ✅ | Date | |

### Notes

- All fields pre-populated from the case record; editable by surveyor. Locked once Final report is signed.
- Regulatory Standard selector can be changed until the first report is locked.
- On successive reports, particulars carry forward; surveyor updates certification expiry dates as needed.
- Managers row suppressed in rendered output if identical to Owners.

---


---

## Section 4: Vessel's Movements & Events

The table structure is already handled by the app. This note covers **what dates to include, what to exclude, and how to phrase entries** — the display rules rather than the mechanics.

The section renders as a three-column table: **Date | Time | Movement & Events**. Best-practice models: FV OLIVIA (clean, tight), STELLA VII Final (spans multiple months well), MINRES BALDER Advice 2 (clear event/date structure for a complex case).

---

### Date Display Rules

**Include:**

| Date type | Rule |
|-----------|------|
| Date of Loss / occurrence | Always first row. Use exact date and time if known. |
| Vessel movements directly related to the casualty | Departure from incident location, arrival at repair port, slipping/drydocking, undocking. |
| Survey attendances | Each attendance by the Undersigned Surveyor — date only, brief description (e.g. "Initial survey attendance at [yard]"). |
| Key repair milestones | Commencement of repairs, completion of repairs, sea trials if relevant. |
| Regulatory events | AMSA notification, prohibition notice issued/lifted, accredited surveyor attendance if relevant. |
| Report issuance dates | On successive reports, include dates prior reports were issued (e.g. "Preliminary Report issued"). |

**Exclude:**

- Routine operational events unrelated to the casualty (normal voyages before the DOL, cargo operations, crew changes).
- Internal owner/manager correspondence dates — these belong in Background or Available Information, not here.
- Approximate or uncertain dates unless clearly flagged (use "approx." or "early [month] [year]" — see STELLA VII corpus example).
- Future projected dates (repair completion estimates etc.) — these belong in the Status of Repairs field, not the movements table.

---

### Time Field Rules

- Use 4-digit 24-hour format where known: **1430**, **0900**, not "2:30pm" or "9am".
- Time ranges permitted for a single event: **0900–1130**.
- If time is unknown, leave the Time cell blank — do not fill with "N/A" or "unknown".
- Vague times acceptable where that is all that is known: **AM**, **PM**, **Morning**, **Evening** — as seen in corpus (FV OLIVIA: "PM").
- Timezone: note local time only. If the event occurred in a different timezone from the repair location, add a bracketed qualifier: **(WST)**, **(AEST)** — as seen in PEDRO 1 corpus.

---

### Entry Wording Rules

- One event per row. If multiple things happened at the same time, use separate rows with the same date/time.
- Keep entries factual and concise — one sentence. Detail belongs in Background.
- ⚠️ **"Reportedly" rule applies**: any entry describing what the vessel or crew did at the time of the casualty (as relayed by owners) must use "reportedly" or "it was reported that". Entries describing surveyor attendances or confirmed documented events do not need this qualifier.
- Avoid passive constructions where the agent is clear: prefer "Vessel arrived at Fremantle" over "Vessel was arrived at Fremantle".
- Location entries: include port/yard name and state where relevant, especially for repair attendances.

---

### Successive Report Behaviour

On Progress / Interim / Supplementary / Final reports, the table carries forward all prior rows (read-only, greyed out) and the surveyor adds new rows for events since the previous report. This gives the reader a complete timeline in every report without re-entry of prior data.

---


---

## Section 5: Brief Technical Description

This section draws from two sources: (1) the **vessel particulars / machinery tab** for vessel-level and propulsion system data, and (2) the **claim object tree** for the specific machinery in scope for this claim. The rendered output is a compact, key-value description — not a general machinery survey. Only what is relevant to the claim is shown.

Best-practice models: **NW LOUISA BAY** (single-component, clean format), **GREAT MIND Preliminary** (opening vessel summary sentence + component details), **MINRES BALDER Advice 2** (multi-unit propulsion system with quantity and serial numbers), **BHAGWAN DRYDEN** (thruster unit with full technical spec block).

---

### Structure

The section renders in two parts, always in this order:

**Part A — Vessel summary sentence** (auto-generated, one sentence)
Drawn from vessel particulars. Identifies the vessel type, GT, LOA, shipyard, build year, flag, and class. Gives the reader context before the component detail.

Example: *"The vessel 'MV GREAT MIND' is a bulk carrier of 40,913 GRT, 225.0 metres OAL, built in Huangpu Shipyard, China in 2011, flagged under Hong Kong and maintained in CCS Class."*

This sentence is auto-assembled from the case record. Surveyor can edit.

**Part B — Claim object technical detail block(s)**
One block per top-level claim object (e.g. Main Engine #2, Port Azimuth Thruster). Each block renders as a key-value list with a brief introductory line, followed by subcomponent blocks indented beneath it.

---

### Suggested Layout

```
5  BRIEF TECHNICAL DESCRIPTION
   ─────────────────────────────────────────────────────────
   [Vessel summary sentence — auto-generated, surveyor edits]

   The technical details of the [object description] are as follows:

   ┌─ [Object label, e.g. "Main Propulsion Gearbox — Starboard"] ─────────┐
   │  Description        :  [free text]                                    │
   │  Manufacturer       :  [value]                                        │
   │  Model              :  [value]                                        │
   │  Serial Number      :  [value]                                        │
   │  [Type-specific fields — see below]                                   │
   │  Date of Manufacture:  [value]                                        │
   │  Total Running Hours:  [value or "Not Confirmed"]                     │
   │  Hours Since Last   :  [value or service description + date]          │
   │  Overhaul / Service                                                   │
   │                                                                       │
   │  ┌─ [Subcomponent, e.g. "Turbocharger"] ──────────────────────────┐  │
   │  │  Manufacturer    :  [value]                                     │  │
   │  │  Model           :  [value]                                     │  │
   │  │  Serial Number   :  [value]                                     │  │
   │  └──────────────────────────────────────────────────────────────┘  │
   └───────────────────────────────────────────────────────────────────────┘

   [Second object block if applicable — same structure]
```

---

### Fields — Common to All Claim Objects

| Field | Source | Notes |
|-------|--------|-------|
| Object label / Description | Claim object name + free text description | E.g. "Marine Reversing Hydraulic Gearbox", "Controllable Pitch Propeller Azimuth Thruster" |
| Manufacturer | Machinery tab / claim object | |
| Model | Machinery tab / claim object | |
| Serial Number | Machinery tab / claim object | "NA" or "Not Confirmed" if unavailable — never leave blank |
| Date of Manufacture | Machinery tab / claim object | Year or full date; "Approx [year]" if estimated |
| Total Running Hours | Claim object | "Not Confirmed" if unavailable |
| Hours Since Last Overhaul / Service | Claim object | Free text — include nature of last service and date where known (e.g. "Serviced with primary thrust bearing replacement 15/11/24") |

### Type-Specific Fields (appear for relevant object classes only)

| Object class | Additional fields |
|--------------|-----------------|
| Gearbox | Ratio (e.g. 6.00:1) |
| Thruster / propulsion unit | Type (e.g. Controllable Pitch / Fixed Pitch / Azimuth), Quantity on vessel, Thrust rating or Power (kW) |
| Main engine | Type (diesel / gas turbine etc.), Power (kW or BHP @ RPM), Fuel type |
| Generator | kVA rating, voltage, frequency |
| Valve / actuator | Actuator type (electric / hydraulic / pneumatic), Quantity affected |
| Pump | Type, capacity |

### Nameplate Photo Rule

Each claim object and subcomponent in the app has an attached nameplate photo field. In the rendered report, **nameplate photos do not appear in this section** — they are referenced in Annexures. A note in the section footer confirms: *"Nameplate photographs are retained on file."* The data fields are populated from the nameplate; the photo lives in the annexure.

### Rules

- Only machinery **in scope for the claim** appears here. Propulsion systems not involved in the casualty are not described, even if entered in the machinery tab.
- If two identical units are present (e.g. port and starboard thrusters of the same type), show a single block with **Quantity: 2** and list both serial numbers on separate lines, labelled Port / Starboard (or #1 / #2 etc.).
- If a subcomponent has its own serial number and is independently in scope (e.g. a turbocharger on a damaged engine), it gets its own indented subcomponent block.
- "Not Confirmed" is the correct value for any field where data has not yet been verified by the surveyor — never omit a field or leave it blank in the rendered output.
- The introductory line ("The technical details of the [x] are as follows:") is auto-generated from the object class name. Surveyor can edit.

### Successive Report Behaviour

The BTD block is pre-populated from the first advice and carries forward read-only. If a replacement component is fitted during repairs (e.g. a new gearbox with a different serial number), the surveyor can update the serial number field and the change is flagged in the diff view for that report.

---


---

## Section 6: Background

This is the most complex section in the report and the one with the most significant gaps in the current app data input model. It is **entirely free-prose narrative**, but it draws on structured data from several sources — some already in the app, some not yet captured anywhere.

Best-practice models: **BHAGWAN DRYDEN** (structured into numbered subsections for a complex multi-phase history), **SL MARTINIQUE** (opens by attributing source, then narrates chronologically), **FV OLIVIA** (tight, factual, one paragraph per phase), **NW LOUISA BAY** (concise, well-hedged single-occurrence case).

---

### What the Background Section Contains

The Background covers **three distinct narrative layers**, always in this order:

**Layer 1 — Pre-casualty history of the affected machinery** (where relevant)
Any documented service, maintenance, dry-docking, overhaul, or prior incident involving the specific machinery in scope — up to and including the DOL. This is what makes BHAGWAN DRYDEN's subsection structure necessary: 5.1 Drydock Service, 5.2 Operational Noise, 5.3 Re-Docking, 5.4 Water Ingress. Without this layer, causation cannot be properly assessed.

**Layer 2 — The casualty event itself**
The owners' / crew's account of what happened, from the moment leading up to the incident through to the vessel being secured post-incident. Written in third person, past tense, with "reportedly" throughout. Sources must be attributed (Master's statement, AMSA incident report, investigation report etc.).

**Layer 3 — Post-casualty response** (where applicable to this report type)
Immediate mitigation actions, emergency repairs, notification to Class / AMSA, initial inspections. This layer grows with successive reports as more post-incident activity is documented.

---

### ⚠️ App Data Input Gaps

The following information is needed for the Background but has **no structured home in the app** at present:

| Gap | Description | Suggested fix |
|-----|-------------|---------------|
| **Pre-casualty service history** | Last drydock date and yard, last overhaul of affected machinery (date, nature, contractor), any prior related defects or near-misses — for the specific claim objects, not just the vessel | Add a **Service History** sub-tab to the claim object in the machinery tab. Fields: Date, Yard/Contractor, Nature of work, Annexure reference. Repeating rows. |
| **Prior related incidents or conditions of class** | Existing class conditions or recommendations relevant to the affected machinery at DOL | Add field to vessel particulars: "Prior conditions of class relevant to this claim" — Yes / No / Description |
| **Source attribution for the casualty narrative** | The Background must state where the account came from (e.g. "The following is a summary of the description of events in the Engage Marine Group 5 Whys Investigation Report (Annex A)"). Currently there is no structured way to log source documents against the narrative | Tie to the **Available Information** table (see Section for that) — documents listed there should be linkable as attribution sources in the Background editor |
| **Immediate post-casualty actions** | Mitigation steps taken before the surveyor attended — by crew, owner, or third parties | These could be entered as early rows in the **Movements & Events** table (Section 4), but currently the app doesn't distinguish between movement events and response-action events. Consider adding an "Event type" tag: *Movement / Casualty event / Mitigation action / Survey attendance / Repair milestone* |

---

### Structure and Subsections

For simple single-occurrence cases (one event, no complex pre-history): **no subsections** — flat narrative of 2–5 paragraphs.

For complex cases where the pre-casualty history is material to causation (e.g. recent drydock, prior defect, prior service on the affected component): **numbered subsections**, one per phase. The BHAGWAN DRYDEN structure is the model:

```
6  BACKGROUND

   6.1  [Pre-casualty phase title, e.g. "Drydock Service of Thrusters"]
        [narrative paragraphs]

   6.2  [Next phase, e.g. "Reported Operational Anomalies"]
        [narrative paragraphs]

   6.3  [Casualty event, e.g. "Water Ingress — Discovery and Response"]
        [narrative paragraphs]
```

The platform should offer a **"+ Add subsection"** button. Default is no subsections (flat). The surveyor adds subsections when the history is complex enough to warrant them.

---

### AI Assistance

The Background is the section where AI drafting assistance is most valuable and most risky. The following rules apply:

- **Layer 2 (casualty event):** AI can draft an initial paragraph from the DOL entry, the chronology of events table, and any uploaded source documents (AMSA incident report, Master's statement). The draft must be clearly marked as AI-generated and require surveyor review before approval.
- **Layer 1 (pre-casualty history):** AI can draft from service history entries in the claim object (once that sub-tab exists — see gap above). Until then, this layer is surveyor-entered free text only.
- **Layer 3 (post-casualty response):** AI can draft from the Movements & Events table entries tagged as mitigation actions.
- ⚠️ **"Reportedly" rule applies throughout Layer 2.** All events described from owner/crew accounts must carry "reportedly", "it was reported that", or attribution to a named source document. AI drafts must be checked to ensure this is enforced.
- Attribution sentences (e.g. "The following is a summary of events as described in [document name] (Annexure [X]).") should be auto-inserted by the platform where a source document has been linked, and suppressed where no source document is linked.

---

### Successive Report Behaviour

On Progress, Interim, Supplementary, and Final reports:
- Prior content carries forward read-only (greyed out).
- The surveyor adds new paragraphs or subsections for developments since the previous report.
- New content from the current report period is visually distinguished from carried-forward content in the editor.
- The rendered output presents the complete narrative seamlessly with no visible breaks between report periods.

---


---

## Section 7: Damage Description

### Current App Model — Problems

The current model organises damage by: **Occurrence → Category (structural / mechanical / electrical / other) → Mapped machinery/system → Affected part → Location → Description → Condition found → Average-related flag.**

This creates three problems in practice:

1. **Category-first ordering is wrong for reporting.** The corpus never organises damage by category. It organises by **physical system or component**, with the surveyor narrating what was found. A gearbox failure may involve mechanical damage (broken gear teeth), structural damage (cracked casing), and potentially electrical damage (control system) — splitting these across category tabs fragments what should be a single coherent component narrative.

2. **"Condition found" and "damage description" are not distinct fields in practice.** Experienced surveyors write one integrated description per item. Separating them creates artificial duplication.

3. **The average-related flag at the item level is correct in concept but needs to output to the right place.** In reports, unrelated damage is mentioned inline within the narrative ("some unrelated damage to coatings was seen on the upper sections of the thruster legs") — it is not split into a separate section. The flag drives a notation in the output, not a structural reorganisation.

### Proposed Revised Model

Reorganise the damage input around **Damage Items**, where each item is attached to a **Claim Object** (from the machinery/hull tree) rather than to a damage category. The damage category becomes a tag on the item, not the top-level organiser.

```
Damage Item
├── Claim Object link          → [links to object in machinery/hull tree]
├── Occurrence link            → [links to occurrence — supports multi-occurrence cases]
├── Location on vessel         → [free text: "Starboard gearbox, bull gear"]
├── Damage type tag            → [Structural / Mechanical / Electrical / Coating / Other]
├── Damage description         → [free text — surveyor's own words, what was found]
├── Condition / status         → [dropdown: Confirmed / Probable / Potential / Unrelated]
├── Average-related            → [Yes / No / Partial — with free text for Partial]
└── Photo links                → [attached survey photos]
```

The **Condition / status** field replaces the ambiguous separation of "condition found" and "damage description":
- **Confirmed** — directly observed and measured by the surveyor.
- **Probable** — assessed from evidence but not directly opened or measured (e.g. internal damage inferred from external signs).
- **Potential** — possible further damage not yet inspected or confirmed.
- **Unrelated** — observed but not connected to the casualty.

---

### Best-Practice Report Output Structure

The rendered section is **prose narrative with bullet points**, not a table. The surveyor's free-text descriptions are the output; the structured fields feed AI-assisted drafting and the photo log. Best-practice models:

**NW LOUISA BAY** — single component, one opening context sentence, then bullets. Clean:
> *"The gearbox was inspected, lying on blocks on the floor of Independent Marine Engineering workshop on 14 August 2025. The top cover had been removed. The following damage was observed: [bullets]"*

**SL MARTINIQUE** — subsectioned into "Damage Sighted" (7.1) and "Potential Damage" (7.2). The Confirmed / Potential split becomes the subsection structure for cases where not all damage is yet fully accessible.

**STELLA VII Final** — multiple components, subsectioned by physical location/system (Hull Damage, Keel Cooling Pipes, Bilge Keel). Multi-occurrence cases with complex damage extend this further.

**REBECCA LILY** — extensive hull damage catalogued by compartment reference with a grid layout. Extreme case showing that the object tree needs to support hull compartment references as a location type.

---

### Suggested Layout (rendered output)

```
7  DAMAGE DESCRIPTION

   [Single component, simple case]

   The [component] was inspected [location, date]. The following damage
   was observed:

   • [Damage item 1 — confirmed]
   • [Damage item 2 — confirmed]
   • [Damage item 3 — probable, based on...]

   It is considered that further damage to [x] may exist, pending
   [further disassembly / dry docking / specialist inspection].

   [Unrelated damage, if any — inline, single sentence]

   ─────────────────────────────────────────────────────────────────

   [Multi-component or multi-occurrence case — subsectioned]

   7.1  [Component or system name]
        [Narrative + bullets]

   7.2  [Next component or system]
        [Narrative + bullets]

   7.3  Potential Damage  ← only if unconfirmed damage exists
        [Narrative]
```

---

### Subsection Rules

| Case type | Structure |
|-----------|-----------|
| Single occurrence, single component | Flat — no subsections |
| Single occurrence, multiple components | Subsections by component/system name |
| Multiple occurrences | Top-level subsections by occurrence, then sub-subsections by component |
| Confirmed + Potential damage | Add a final "Potential Damage" or "Further Damage to Be Confirmed" subsection |
| Unrelated damage found | Mentioned inline within the relevant component subsection, not as a separate subsection |

---

### AI Assistance

The AI can draft each Damage Item narrative from the structured fields (location, damage type, description, condition) and the linked survey photos (via photo captions). The opening context sentence ("The [component] was inspected at [location] on [date]") is auto-generated from the attendance log and claim object. The surveyor reviews and edits.

⚠️ **The average-related flag (Yes / No / Partial) does not affect the narrative structure** — it feeds the cost section and the Summary of Accounts, not this section. Unrelated items are mentioned in passing in the narrative only.

---

### ✅ App Changes Done

| Change | Description | Status |
|--------|-------------|--------|
| Reorganise primary input axis | Damage item → Claim Object (not Damage Category → item) | ✅ Done — `add_damage_item_sheet.dart` now picks Machinery/Component first; Damage Category moved down and relabeled "Damage Type" (tag). `damage_register_screen.dart` groups by claim object (machinery, or component name when unlinked) instead of category. |
| Add Condition / Status field | Replaces "condition found" + "damage description" split; uses Confirmed / Probable / Potential / Unrelated | ✅ Done — `condition_status` column + `ConditionStatus` enum added additively; `condition_found` free text kept as an optional supplementary field, not removed. |
| Add Confirmed by field | Multi-select + date per Damage Item — see Third-Party Confirmation below | ✅ Done — `confirmed_by text[]` + `confirmation_date` + `confirmation_method`, `ConfirmedByRole` enum (8 values per spec), checklist UI reusing the Services Provided pattern from `add_repair_period_sheet.dart`. |
| Damage type becomes a tag | Structural / Mechanical / Electrical / Coating / Other — tag on each item, not the top-level organiser | ✅ Done — `DamageCategory.coating` added (plain `text` column, no DB migration needed); category chips moved to a secondary "Damage Type" position. |
| Hull compartment location type | The location field needs to support hull compartment references (e.g. "Frame 24, Stbd, 2m below deck") for grounding/collision cases | Accepted — no code change needed; `location_on_vessel` was already free text and already supports this. |
| Multi-occurrence linking | Each damage item links to a specific occurrence — already in the model, confirm it's working | Confirmed working — `occurrence_id` FK + `itemsForOccurrence` in `damage_provider.dart`; no change needed. |
| Photo linking at item level | Each damage item can have attached survey photos; these render in the Annexures keyed to item references | Partially done — photo↔damage-item linking already existed (`attachToDamageItem`). New in this pass: Inline placement photos now embed directly under the item's narrative in the docx export (`docx_export_service.dart`). Annexure-mode auto-numbering/cross-references still not implemented — part of the separate Annexures architecture epic. |

---

### Third-Party Confirmation of Damage

In complex cases, the surveyor identifies damage at initial attendance, but a specialist or third party (OEM engineer, Class surveyor, AMSA accredited surveyor, dive contractor, NDT specialist) subsequently confirms additional or different damage during their own inspection. Without structured tracking of who confirmed what and when, the report narrative and cost section become ambiguous about the source and timing of each finding. This also matters for GPN-AI chain-of-evidence requirements — AI-drafted damage descriptions must be traceable to a human confirmation source.

**Required addition to the Damage Item model:**

| Field | Input type | Notes |
|-------|------------|-------|
| Confirmed by | Multi-select | *Undersigned Surveyor / Class Surveyor / AMSA Accredited Surveyor / OEM Engineer / Specialist Contractor / Dive Contractor / NDT Specialist / Owner's Representative* |
| Confirmation date | Date | Date of the confirming inspection or report |
| Confirmation method | Short text | e.g. "Visual inspection", "Disassembly and measurement", "NDT", "Dive inspection", "Oil analysis" |

In the rendered report, confirmation source appears inline where the confirming party differs from the surveyor: *"Damage to the bull gear was confirmed by Independent Marine Engineering following disassembly on 14 August 2025."*

---

### Visual Evidence — Photos and Technical Drawings

#### The Problem with Annexure-Only Photo Reports

The current convention of placing all photos in a separate photo annexure (Annexure A or similar) works for simple cases but breaks down for complex ones. When a report describes 15 damage items across a grounded barge, a reader must constantly flip between the narrative and a photo annexure to understand what they are reading. For structural and hull damage cases in particular — where the spatial relationship between damage items matters — inline visuals are substantially clearer than a reference system.

The corpus itself shows this tension: the BHAGWAN DRYDEN report inserts inline photos with captions directly within the Background section to explain docking work. SOUTHERLY II inserts a photo grid directly within the Repairs section. The ABL/London format uses a Selected Photographs page at the end of Page 1 as a visual executive summary. None of these are "wrong" — they are each the right approach for that case complexity.

The platform needs to support **all three modes** and let the surveyor choose, per report, where each photo appears.

---

#### Photo Model — Three Placement Modes

Each photo uploaded to the platform is attached to a **Damage Item** (or a Repair Item, or a Background event) in the data model. At upload, the surveyor assigns a placement mode:

| Mode | Where it renders | When to use |
|------|-----------------|-------------|
| **Inline** | Immediately after the paragraph or bullet point describing that damage item | When the photo directly illustrates what the text describes and its meaning is lost without spatial context. Ideal for structural damage, hull compartment damage, component closeups showing specific failure modes. |
| **Section gallery** | As a grouped photo grid at the end of the subsection (e.g. end of Section 7.1) | When multiple photos of the same component or location form a coherent visual set that benefits from being seen together. Ideal for repair progression photos, before/after pairs. |
| **Annexure** | Photo annexure (Annexure A by default, or a named annexure) | When the photo is supporting evidence that a diligent reader may want to examine but that does not need to interrupt the narrative. Nameplate photos, certificates, third-party inspection photos. |

The default mode for survey photos is **Inline** for damage items and **Annexure** for supporting documents. Nameplate photos always go to Annexure — enforced by the platform.

---

#### Photo Fields Per Image

| Field | Input type | Notes |
|-------|------------|-------|
| Photo file | Upload (JPG/PNG/HEIC) | Taken on mobile or uploaded from camera roll |
| Caption | Short text | Surveyor-written — appears below the photo in all modes. Required before placement. |
| Damage item link | Select from damage tree | Links the photo to a specific damage item; auto-populates in context |
| Placement mode | Dropdown | Inline / Section gallery / Annexure |
| Annotation | Drawing tool overlay | Surveyor can draw arrows, circles, dimension lines, text labels over the photo in-app. Annotations are burned into the rendered image. |
| Photo source | Radio | *Taken by undersigned surveyor* / *Provided by owner/operator* / *Provided by contractor* / *Third-party inspection report* |
| Date taken | Date + time | Auto-populated from EXIF if available; editable |
| Annexure reference | Auto-assigned | e.g. "Photo 1", "Photo 2" — sequential within the annexure; referenced in narrative as "(refer Photo 3, Annexure A)" |

> ⚠️ **Photo source matters for professional standards.** Photos not taken by the surveyor must carry attribution ("The following images were provided by [party] and were taken during [event]. The descriptions are provided by the Undersigned Surveyor based on examination of the images." — as per BHAGWAN DRYDEN). The platform should auto-insert this attribution sentence when any photo in a section is tagged with a non-surveyor source.

---

#### Technical Drawings and General Arrangements

For structural and hull damage cases, an extract of the vessel's General Arrangement (GA) or structural drawings is often the clearest way to locate and describe damage. The REBECCA LILY case in the corpus shows this — the compartment grid table is essentially a simplified damage map derived from the GA.

The platform should support a **Drawing Extract** asset type, distinct from a survey photo:

| Field | Input type | Notes |
|-------|------------|-------|
| Drawing file | Upload (PDF/PNG/SVG) | Can be a full drawing or a cropped extract |
| Drawing title | Short text | e.g. "General Arrangement — Plan View", "Midship Section", "Thruster Arrangement Drawing" |
| Drawing reference | Short text | Document number / revision from the original drawing |
| Source | Short text | Owner-supplied / Yard-supplied / OEM drawing |
| Damage markup | Drawing tool overlay | Surveyor marks up the drawing with damage location indicators, hatching, dimension callouts. Annotations burned in on render. |
| Placement mode | Same as photos | Inline / Section gallery / Annexure |
| Annexure | Auto-assigned | Separate annexure letter from photo annexure (e.g. Annexure B for drawings, Annexure A for photos) |

**Suggested use cases:**
- Grounding / hull damage: GA plan view with damage compartments highlighted and annotated
- Thruster / propulsion damage: OEM arrangement drawing with affected components circled
- Complex machinery damage (multiple systems): P&ID extract or system schematic with affected circuits marked

---

#### Inline Photo Rendering — Layout

When placement mode is **Inline**, photos render as a two-column grid immediately below the damage item text, with captions beneath each image. Maximum two photos per row. For a single standout photo, full-width single image with caption.

```
[Damage item narrative text]

┌─────────────────────────┐  ┌─────────────────────────┐
│                         │  │                         │
│      [Photo 1]          │  │      [Photo 2]           │
│                         │  │                         │
└─────────────────────────┘  └─────────────────────────┘
  Caption for Photo 1           Caption for Photo 2

[Next damage item narrative]
```

For drawing extracts inline, full-width single render with title and reference below.

---

#### Annexure Photo Page — Layout

The photo annexure renders in the same two-column grid with numbered references. Each photo carries its caption and, if source is not the surveyor, its attribution. The London/ABL format (Selected Photographs page on Page 1) is a compact version of this — the platform can optionally generate a **Selected Photographs** page as part of the executive summary layout, populated by a subset of photos the surveyor flags as "highlight" images.

---

#### ⚠️ App Changes Required

| Change | Description | Status |
|--------|-------------|--------|
| Placement mode field | Add to photo upload flow: Inline / Section gallery / Annexure | ✅ Done — `placement_mode` column (local SQLite, additive `ALTER TABLE` — see below), `PlacementMode` enum, selector in `photo_detail_sheet.dart`. Inline photos now embed directly in the docx export under their damage item's narrative (`docx_export_service.dart`, via `doc.addImage`). Section gallery mode has no distinct rendering yet (behaves like Annexure) — narrower gap than it looks, but not fully implemented. |
| Annotation tool | In-app drawing overlay on photos and drawings — arrows, circles, text, dimension lines | Deferred — not started, substantial standalone feature. |
| Photo source attribution | Auto-insert attribution sentence when non-surveyor source is detected | Partially done — `photo_source` field + `PhotoSource` enum + selector added, but the auto-inserted attribution sentence itself ("The following images were provided by...") is **not yet wired** into the report text or docx export. Field is captured, not yet consumed. |
| Drawing Extract asset type | Separate from survey photos; supports PDF/PNG/SVG upload + markup | Deferred — not started. |
| Damage item linking | Each photo and drawing links to a specific damage item in the data model | Already existed (`attachToDamageItem`, `linked_to_type`/`linked_to_id`) — confirmed working, no change needed. |
| "Highlight" flag | Allows surveyor to designate select photos for a Selected Photographs summary page | Deferred — not started. |
| Annexure auto-numbering | Sequential numbering within each annexure; cross-reference insertion in narrative ("refer Photo 3, Annexure A") | Deferred — part of the separate Annexures/Cross-References architecture epic documented earlier in this doc. |

**Local SQLite migration note:** `app_database.dart`'s `_onUpgrade` previously did an unconditional `DROP TABLE` on every version bump — this was fine for `surveyor_notes` (genuinely a Supabase-backed cache) but **destructive** for `photos`/`correspondence`, which are 100% local with no cloud sync. Fixed as part of this change: v10→v11 is now an additive `ALTER TABLE`, and both tables are excluded from the drop entirely going forward.

---

---

## Section 8: Repairs

This section has the most complex data structure in the report. The current app model (Repair Periods → per Occurrence, map Damage Items to repair status) is the right conceptual approach but needs refinement based on the multi-occurrence experience and the full set of repair categories visible in the corpus.

Best-practice models: **MINRES BALDER Advice 2** (the most complete structure — separate sections for Temporary Repairs, Dry Docking, Extra Expenses to Reduce Delay, General Expenses, Work Not Concerning Average, Summary of Repair Times), **STELLA VII Final** (Emergency Temporary + Permanent split), **FV OLIVIA Final** (Damage Mitigation + Permanent Repairs subsections), **London template** (Temporary / Permanent / Deferred + General Services + Repair Times table).

---

### Data Model — Repair Period

The top-level unit is the **Repair Period** — a defined block of time at a specific location where repair work was carried out. Multiple repair periods can exist for a single case (e.g. emergency repair at incident port, then permanent repair at home port yard).

```
Repair Period
├── Period label          → [e.g. "Emergency Temporary Repairs", "Permanent Repairs — Henderson"]
├── Location              → [Yard / port / vessel location]
├── Start date            → [date]
├── End date              → [date or "Ongoing"]
├── Repair type           → [Temporary / Permanent / Deferred / Part-permanent]
├── Diversion flag        → [Yes / No — was this a deviation from the planned voyage?]
├── Diversion details     → [conditional free text if Yes]
├── Occurrence link(s)    → [which occurrences does this period address?]
└── Repair Items          → [see below]
```

---

### Data Model — Repair Item

Each Repair Period contains one or more **Repair Items**, each linked to a Damage Item from Section 7:

```
Repair Item
├── Damage item link      → [select from damage tree — the damage being repaired]
├── Repair description    → [free text — what was done]
├── Repair status         → [Complete / Ongoing / Deferred — with deferred-to date if known]
├── Contractor            → [who carried out the work]
├── Witnessed by          → [Undersigned Surveyor / Class / AMSA / Owner only]
├── Average-related       → [Yes / No / Partial]
└── Photo links           → [repair progress/completion photos]
```

---

### Additional Work Categories — Implementation via Context Cues

Beyond the average-related repair items, the following three categories must appear in the rendered report and have distinct cost implications. They currently have no structured input mechanism in the app. The agreed implementation approach uses **context cues** as the input layer.

---

#### What is a Context Cue

A context cue is a short, atomic note — either:
- **Entered by the surveyor** in the field (voice-to-text, typed note, or photo caption), or
- **Extracted by AI** from an uploaded document (yard invoice, owner's email, superintendent's report, Class statement)

Each cue is tagged at input to indicate which report section it belongs to. The AI then drafts the narrative paragraph(s) for that section from the accumulated cues, which the surveyor reviews and approves.

This is already the intended mechanism in the app. What needs to be defined is the **tagging taxonomy** for these three categories and the **output rules** for each.

---

#### Category 1 — General Services & Access

**What it covers:** Work required to access damage for inspection or repair but not itself a repair. Drydocking, slipping, hardstanding, gas freeing, hot work certification, staging, crane hire, diving for access, tug assistance for repositioning.

**Context cue tag:** `general_services`

**Input examples:**
- *"Vessel slipped at Fremantle Boat Lifters 3 Dec 2024 for inspection and repair"*
- *"Gas freeing required prior to hot work in engine room — 2 hours, certificated"*
- *"Crane hire for gearbox removal — ½ day, Coates Hire"*
- AI extraction from yard invoice line items categorised as "general services / access"

**Output rule:** Rendered as a subsection (e.g. **8.4 General Services and Access**) only when at least one `general_services` cue exists. If none, section is suppressed. Content is a short prose paragraph assembled by AI from the cues, stating what services were provided, by whom, and when. Does not include costs — those go to the cost section.

---

#### Category 2 — Extra Expenses Incurred to Reduce Delay

**What it covers:** Costs incurred specifically to accelerate repairs and minimise off-hire or operational disruption — yard selection premium, overtime, express freight of spare parts, additional crew for night shift. Must be distinguishable from normal repair costs.

**Context cue tag:** `extra_expenses`

**Input examples:**
- *"Birdon slip in Dampier unavailable until 20 Oct — vessel relocated to Silverstar Henderson at higher cost to reduce delay"*
- *"Overtime approved for weekend shifts to complete repairs before charter"*
- *"Express airfreight of replacement feedback cable from OEM in Netherlands — approx AUD 4,500"*
- AI extraction from superintendent correspondence or owner emails referencing urgency decisions

**Output rule:** Rendered as a subsection (e.g. **8.5 Extra Expenses Incurred to Reduce Delay**) only when at least one `extra_expenses` cue exists. AI drafts a factual paragraph identifying each extra expense, the reason it was incurred, and the approx amount if known. Amounts are flagged as estimates pending invoice confirmation. Section suppressed if no cues.

> **Note:** This category requires surveyor judgment — not all costs claimed as "extra expenses" qualify. The AI draft should include a note where the average-relatedness of a cue is ambiguous, flagging it for surveyor review before approval.

---

#### Category 3 — Work Not Concerning Average

**What it covers:** Owner's maintenance, improvement, or unrelated repair work carried out concurrently with average repairs — at the owner's account. Must be clearly identified so repair times and costs can be properly apportioned.

**Context cue tag:** `wnca`

**Input examples:**
- *"Owner instructed general hull cleaning and antifouling at own cost during drydock"*
- *"HVAC coil replacement — unrelated to casualty, owner's account"*
- *"Bow thruster hydraulic pump replacement — pre-existing defect, owner's account"*
- *"Main engine service — routine scheduled maintenance, owner's account"*
- AI extraction from yard invoices where line items are clearly maintenance rather than damage repair

**Output rule:** Rendered as a subsection (e.g. **8.6 Work Not Concerning Average**) with a standard opening clause followed by a bullet list of items. The opening clause is fixed and locked:

> *"Concurrently with the average repairs, the Owners / Managers of the vessel instructed repairs to be carried out to their own account. These included, but were not limited to, the following works:"*

AI populates the bullet list from `wnca`-tagged cues. Section suppressed if no cues.

This WNCA list feeds the Repair Times Table — the "Work not concerning average" row is populated from these same cues, with the surveyor entering the estimated time (dry dock / afloat) separately.

---

#### Context Cue Workflow Summary

```
Field input / Document upload
        ↓
AI extracts or surveyor enters short notes
        ↓
Surveyor tags each cue:
  [general_services] [extra_expenses] [wnca] [repair_item] [background] etc.
        ↓
Per-section AI draft assembled from tagged cues
        ↓
Surveyor reviews and approves each draft paragraph
        ↓
Approved content locks into the report section
```

The tagging can happen at the time of input (surveyor selects category on the cue entry screen) or retroactively in the cue management view. AI can suggest a tag based on cue content, but the surveyor confirms.

---

### ⚠️ App Changes Required

| Change | Description |
|--------|-------------|
| Context cue tags | Add `general_services`, `extra_expenses`, `wnca` to the cue tagging taxonomy alongside existing tags |
| Section suppression logic | Sections 8.4 / 8.5 / 8.6 render only when at least one cue with the relevant tag exists; suppressed otherwise |
| WNCA opening clause | Fixed locked text for the WNCA subsection header — not AI-generated, not editable |
| Extra expenses ambiguity flag | AI should flag any `extra_expenses` cue where average-relatedness is uncertain, requiring surveyor sign-off before that item is included |
| WNCA → Repair Times feed | WNCA cues should populate the "Work not concerning average" row in the Repair Times Table, with a separate time entry field (dry dock days / afloat days) per WNCA item group |
| Damage Status Dashboard | Internal tracking view showing all damage items with repair status, period, and average flag across all occurrences |
| Repair Times Table | Auto-generate from repair period start/end dates, broken down by occurrence and WNCA; split dry dock vs afloat |
| Witnessed by field | Add to each Repair Item: Undersigned Surveyor / Class / AMSA Accredited Surveyor / Owner only — drives narrative wording |

---


---

## Section 9: Other Matters of Relevance

This is a **conditional, catch-all section** for substantive information that is germane to the claim but does not fit cleanly into Damage Description, Repairs, or Cause Consideration. It appears only when there is something material to report. Best-practice models: **SL MARTINIQUE** (dive inspection reports + oil analysis, each its own subsection), **BHAGWAN DRYDEN** (labelled "Closing Comments" — ongoing mitigation, future cause assessment, notification of potential liability), **PEDRO 1** (second-hand gearbox valuation, related barge damage — distinct topics warranting their own subsections).

The section heading varies across the corpus: "Other Matters of Relevance" (Marsh Maritime standard), "Closing Comments" (BHAGWAN DRYDEN), "Surveyor's Notes" (London/ABL). The platform should use **"Other Matters of Relevance"** as the default, consistent with the Marsh Maritime house style.

---

### What Goes Here

Content that belongs in this section falls into the following categories. Not all will be present in every case — the section is suppressed entirely if there is nothing material.

| Category | Description | Example from corpus |
|----------|-------------|-------------------|
| **Third-party specialist reports** | Summaries of and commentary on reports from dive contractors, NDT specialists, oil analysis labs, OEM engineers, naval architects — where the surveyor's assessment of those reports is itself a substantive finding | SL MARTINIQUE: surveyor's critique of dive inspection reports; BHAGWAN DRYDEN: oil analysis discussion |
| **Ongoing monitoring or mitigation** | Where repair is not yet possible and interim management actions are in place — the surveyor's assessment of their adequacy and the risk outlook | BHAGWAN DRYDEN 9.1: desorber unit effectiveness, water content trending |
| **Future actions recommended** | Specific actions the surveyor recommends be taken before the next report — further specialist attendance, further disassembly, measurements to be taken | BHAGWAN DRYDEN 9.2; SL MARTINIQUE: blade tip clearance measurement recommendation |
| **Notification of potential liability** | Where a third party (contractor, OEM, repairer) may bear responsibility and formal notification is required or has been given — or where RDC / collision cross-liability arises | BHAGWAN DRYDEN 9.3: Korindo Energy notified of water ingress |
| **Related damage on other vessels or property** | Where the occurrence caused damage to a third-party vessel or property — flagged here for P&I / RDC awareness | PEDRO 1: damage to towed barge REBECCA LILY |
| **Valuation or commercial matters** | Where a component is to be replaced with a second-hand part and its value needs to be established, or where salvage / CTL considerations arise | PEDRO 1: second-hand Reintjes gearbox valuation from ANDO |
| **Discrepancies or concerns with owner-supplied information** | Where documentation provided by the owner is inconsistent, incomplete, or raises questions — the surveyor records the concern and any follow-up requested | SL MARTINIQUE: oil analysis sampling date discrepancy |

---

### Structure

**Simple cases:** No subsections — one or two paragraphs of prose, each addressing a distinct matter.

**Complex cases:** Numbered subsections, one per category. The SL MARTINIQUE model (9.1 Dive Inspection Reports, 9.1.1 Brisbane, 9.1.2 Sydney, 9.2 Oil Analysis) shows how this scales. The BHAGWAN DRYDEN model (9.1 Ongoing Leakage Mitigation, 9.2 Future Assessment of Cause, 9.3 Notification of Potential Liability) shows a case where the "closing comments" function is dominant.

The platform should offer a **"+ Add subsection"** button. Default is flat (no subsections). Subsection titles are free text entered by the surveyor.

---

### Input Model — Context Cues

This section is well suited to the context cue approach. The surveyor tags notes during the case with:

**Context cue tag:** `other_matters`

Sub-tags for AI routing to the right subsection:

| Sub-tag | Subsection it feeds |
|---------|-------------------|
| `other_matters:specialist_report` | Third-party report commentary |
| `other_matters:monitoring` | Ongoing mitigation / monitoring |
| `other_matters:recommendation` | Future actions recommended |
| `other_matters:liability_notification` | Notification of potential liability |
| `other_matters:related_damage` | Related damage on other vessels/property |
| `other_matters:valuation` | Valuation / commercial matters |
| `other_matters:discrepancy` | Discrepancies in owner-supplied information |

AI drafts a subsection for each sub-tag group that contains at least one cue. The surveyor reviews, edits, and approves each subsection before locking.

Section is suppressed entirely if no `other_matters` cues exist.

---

### Tone and Attribution Rules

- Third-party report commentary must distinguish clearly between what the report states and the surveyor's own assessment of it. The SL MARTINIQUE approach is the model: state what the report says, then state the surveyor's opinion explicitly (*"In the opinion of the Undersigned Surveyor, the two reports do not accurately reflect the condition of the underwater hull"*).
- Recommendations must be framed as the surveyor's professional opinion, not as instructions to the owner: *"It is recommended that…"* / *"It would be prudent to…"*
- Liability notification content must be factual and precise — state what notification was given, to whom, by what means, and on what date. No speculation about liability outcome.
- ⚠️ **"Reportedly" rule**: any characterisation of what a third-party report states or what an owner's representative said must use appropriate attribution language.

---

### Successive Report Behaviour

Prior subsections carry forward read-only. The surveyor adds new content as the case develops. Where a matter raised in a prior report has been resolved (e.g. the discrepancy in oil analysis dating was explained), the surveyor adds a closing sentence to the existing subsection rather than repeating the full history.

---

## Section 10: Cause Consideration

This is the most legally sensitive section in the report. It must maintain a precise separation between three distinct voices — what the **owners allege**, what **third parties state**, and what the **Undersigned Surveyor assesses**. Conflating these voices is a professional and legal risk. The current app has a basic allegation flag but does not structurally enforce the voice separation or support the graduated opinion framework the corpus requires.

Best-practice models: **FV OLIVIA** (owner's allegation quoted verbatim, then surveyor agrees with it and extends the analysis), **SL MARTINIQUE** (final view expressed after analysing third-party reports), **STELLA VII Final** (clear navigational error finding), **BHAGWAN DRYDEN** (multi-factor preliminary assessment with explicit uncertainty), **CARMA / STEEP POINT** (standard allegation + standard remarks clause from London/ABL format), **SOUTHERLY II** (straightforward third-party fault with supporting evidence noted).

---

### The Three Voices — Strict Separation Required

| Voice | Who speaks | How to introduce it | Example |
|-------|-----------|--------------------|---------| 
| **Owner's allegation** | Owner / operator / assured | *"Owners allege that…"* / *"The following was stated by the owners to be the cause of loss:"* | "Owners allege that the damage forming the subject of this report was a result of grounding." |
| **Third-party statement** | Investigation report, Class, OEM, regulator, expert | *"The [party] investigation determined that…"* / *"It was stated in [document] that…"* | "The Engage Marine 5 Whys investigation determined that the use of an outdated chart caused the Master to set a track over a shoal." |
| **Surveyor's assessment** | Undersigned Surveyor only | *"It is the view / opinion of the Undersigned Surveyor that…"* / *"It is the opinion of the Undersigned that the damages detailed above may reasonably be attributed to a casualty of the nature of that alleged."* | "It is the view of the Undersigned Surveyor that the grounding incident was caused by a navigational error." |

These three voices must never be merged into a single paragraph without clear attribution markers. The surveyor's opinion must always be the last voice — never offered before the owner's allegation and any third-party findings have been set out.

---

### Data Model — What the App Needs to Capture

The current model has a single allegation flag (allegation made / not made) and a free-text field. This needs to expand into a structured set of inputs that drive the narrative while preserving voice separation.

#### Per Occurrence:

**1. Allegation status** (Radio — drives WP clause and section structure)
- *Formal allegation made* — owner has stated a cause in writing
- *Informal allegation / verbal only* — cause stated verbally or in correspondence but not formally
- *No allegation made* — standard WP clause applies (London format: "No formal written allegation of cause has been made in respect of this damage. It is understood that if a claim is to be made, the Owners will notify their Brokers of the allegation of cause. In view of the foregoing, the damage now found and reported upon are noted Without Prejudice to Underwriters' liability and the Owners Representative has been so advised.")

**2. Owners' stated cause** (Multi-line text, tagged as owner's voice)
- The owner's own words where possible. If from a document, quote source: *"As stated in the incident report dated [date]:"*
- This field is attributed in the output as the owner's allegation — the surveyor does not endorse or dispute it here; that comes in the surveyor's assessment.

**3. Third-party findings** (Repeating blocks — one per relevant third-party source)
- Source name and document reference
- Finding (free text)
- These are attributed explicitly in the output

**4. Surveyor's assessment** (Multi-line text, tagged as surveyor's voice)
- The surveyor's own professional opinion, expressed in first person of the office ("It is the view of the Undersigned Surveyor that…")
- Graduated certainty — the app should prompt the surveyor to select a certainty level that controls the hedging language:

| Certainty level | Suggested language | When to use |
|----------------|-------------------|-------------|
| **Agreed — no reservation** | *"The cause of loss as stated by owners appears to be reasonable and is agreed with."* | Cause is clear, evidence supports it, no contrary indications |
| **Agreed — pending further analysis** | *"…is agreed with, on a preliminary basis, pending further analysis."* | Cause plausible but full investigation not yet complete |
| **Consistent with allegation** | *"It is the opinion of the Undersigned that the damages detailed above may reasonably be attributed to a casualty of the nature of that alleged."* | Standard cautious endorsement — damage pattern consistent with allegation but cause not independently verified |
| **Preliminary assessment only** | *"A final conclusion on the cause cannot be reached at this stage. On a preliminary basis, the following potential causes are considered:…"* | Cause uncertain, multiple hypotheses, further investigation needed |
| **Surveyor disagrees / reserves position** | *"The Undersigned Surveyor is unable to agree with the allegation as stated, for the following reasons:…"* | Evidence does not support the allegation |
| **No opinion offered** | *"At this stage of the investigation, it is not possible to offer an opinion on cause."* | Insufficient information — rare, but correct when applicable |

**5. Additional analytical notes** (Free text, surveyor's voice)
Where the cause analysis extends beyond a single paragraph — e.g. FV OLIVIA's technical analysis of why the bilge system design permitted back-flooding, or BHAGWAN DRYDEN's multi-factor seal failure analysis. These are the surveyor's expert analysis, not just a restatement of the allegation.

---

### Rendered Output Structure

**Simple case (allegation + surveyor agrees):**
```
10  CAUSE CONSIDERATION

    [Owner's allegation paragraph — attributed]

    [Surveyor's assessment — one sentence using standard
     "consistent with allegation" language]
```

**Moderate case (allegation + third-party finding + surveyor analysis):**
```
10  CAUSE CONSIDERATION

    10.1  Owners' Allegation
          [Owner's stated cause, with source attribution]

    10.2  [Third-party finding, e.g. "Investigation Report Findings"]
          [Summary and surveyor's commentary on the finding]

    10.3  Surveyor's Assessment
          [Graduated opinion + analytical notes]
```

**Complex / contested case:**
```
10  CAUSE CONSIDERATION

    10.1  Owners' Allegation
    10.2  [Third-party source 1]
    10.3  [Third-party source 2]
    10.4  Surveyor's Preliminary Assessment of Cause
          [Multi-factor analysis with explicit uncertainty]
```

The subsection structure is driven by what inputs exist — one third-party source block per source, the surveyor's assessment always last.

---

### Standard Clauses (Locked Text)

Two standard clauses must be available as locked-text options:

**No formal allegation clause** (London/ABL format — used when allegation status = "No allegation made"):
> *"No formal written allegation of cause has been made in respect of this damage. It is understood that if a claim is to be made, the Owners will notify their Brokers of the allegation of cause. In view of the foregoing, the damage now found and reported upon are noted Without Prejudice to Underwriters' liability and the Owners Representative has been so advised."*

**Standard remarks clause** (used when allegation is consistent with damage pattern):
> *"It is the opinion of the Undersigned that the damages detailed above may reasonably be attributed to a casualty of the nature of that alleged."*

Both are verbatim from the corpus (London template; CARMA; STEEP POINT). Platform inserts them as locked text; surveyor cannot edit the wording but can choose to use or not use each.

---

### ✅ App Changes Done

| Change | Description | Status |
|--------|-------------|--------|
| Allegation status — three options | Replace binary flag with: Formal allegation / Informal allegation / No allegation — drives WP clause selection | ✅ Done — `allegation_type_enum` widened with a genuine `informal_allegation` value (kept the existing `tbc` as the distinct not-yet-decided default, so nothing is lost). Selector in `causation_sheet.dart`. |
| Owner's stated cause field | Separate structured field tagged as owner's voice; includes source document reference | ✅ Done — `owners_stated_cause` + `owners_stated_cause_source` columns, shown in `causation_sheet.dart` when an allegation exists. |
| Third-party finding blocks | Repeating blocks, one per source; each carries source name, document reference, and finding | ✅ Done — `third_party_findings` jsonb array + `ThirdPartyFinding` model, inline add/remove UI (same read-modify-write pattern as `RepairPeriodModel.notAverageItems`). |
| Surveyor's assessment field | Separate from owner's allegation; tagged as surveyor's voice | ✅ Done — `surveyors_assessment` column, dedicated field distinct from the renamed "Additional Analytical Notes" (formerly "Sub-Causation/Comments"). |
| Certainty level selector | Dropdown driving the hedging language of the surveyor's assessment paragraph | ✅ Done — `certainty_level` column + `CertaintyLevel` enum (6 values per spec), live (non-inserted) preview in the sheet; the actual hedging sentence is composed into the rendered Cause Consideration text in `report_provider.dart`. |
| Standard clause library | Two locked clauses available for insertion: no-allegation WP clause and standard remarks clause | ✅ Done — no-allegation clause (`allegation_none`) already existed; added `cause_standard_remarks` (new `clause_type_enum` value + seeded rows for abl/nordic/oceano_services), auto-selected when certainty level is "Consistent with Allegation". |
| Voice separation enforcement | AI drafting must attribute every statement to its correct voice — never merge owner's allegation with surveyor's assessment in the same sentence | ✅ Done — rendered text keeps each voice in its own paragraph (owner's allegation is a separate `SectionType`; third-party findings and the surveyor's assessment are separate paragraphs within `causation`, never share a sentence); `ClaudeApi.draftCauseConsideration` prompt updated to explicitly instruct the model not to adopt/restate the owner's allegation as its own finding. |

**Note:** `allegation_type_enum` and `clause_type_enum` turned out to be real Postgres enum types (not plain `text` like most columns touched so far this pass) — required `ALTER TYPE ... ADD VALUE` run as its own committed statement before the columns/seed migration, rather than the usual single-call `ALTER TABLE`.

---

## Section 11: Repair Costs

This section presents the financial outcome of the claim — estimated costs on Preliminary/Progress reports, approved costs on Interim/Final reports. It is closely linked to the cost assessment spreadsheet (Annexure A in Marsh Maritime reports) which is the detailed working document; the report section is a summary narrative with headline figures.

Best-practice models: **FV OLIVIA Final** (Assessment of Costs + Mitigation of Loss subsections), **STELLA VII Final** (short summary referencing spreadsheet annexure), **SOUTHERLY II** (Invoiced Cost + Outstanding Quoted Cost), **London/ABL** (detailed account-by-account breakdown within the report body).

> **Note on placement:** Marsh Maritime reports place cost near the end (after Cause Consideration). London/ABL format embeds account detail within the report body. The platform follows the Marsh Maritime convention — the detailed line-item assessment lives in the Annexure; this section contains the narrative summary and headline approved amounts only.

---

### Structure by Report Type

| Report type | Cost section content |
|-------------|---------------------|
| **Preliminary** | Estimated cost only — based on owner's indication or surveyor's estimate. State basis and caveats clearly. No accounts received yet. |
| **Progress** | Updated estimate if available; note any invoices received but not yet assessed. |
| **Interim** | Approved costs to date (WP) + outstanding costs pending. Both figures stated. |
| **Supplementary** | Approved costs for additional items; running total. |
| **Final** | Total approved costs (WP); any adjustments made; reference to Assessment of Costs annexure. |

---

### Fields

| Field | Input type | Notes |
|-------|------------|-------|
| Cost type | Auto from report stage | Estimated / Approved Without Prejudice |
| Currency | Dropdown | AUD / USD / GBP / EUR — case-level setting |
| Temporary repairs cost | Currency amount | Separate line |
| Permanent repairs cost | Currency amount | Separate line |
| General expenses cost | Currency amount | If applicable |
| Total claimed | Currency amount | As submitted by owners |
| Total adjustment | Currency amount | Items not related or not approved |
| Total approved WP | Currency amount | **Locked label "Without Prejudice" — not editable** |
| GST treatment | Radio | Ex GST / Inc GST / N/A (non-Australian cases) |
| Mitigation note | Multi-line text | Optional — where owner's actions materially reduced the loss |
| Outstanding costs | Multi-line text | Costs not yet invoiced or assessed — Preliminary/Progress only |
| Assessment reference | Annexure link | Links to the cost assessment spreadsheet in the annexures |

### Approved Cost — Mandatory WP Phrase

Where costs are approved, the platform must render:

> *"The accounts are approved by us subject to Underwriters' liability and adjustment in the usual manner, being considered fair and reasonable."*

Followed by:

> **Sum Approved Without Prejudice: [CCY] [amount]**

Both phrases are locked. The surveyor enters only the amount. This is one of the four legally required WP locations in the report (as defined in the report architecture).

### Estimate Caveats (Preliminary/Progress)

When no accounts are received, the platform inserts a standard caveat:

> *"At the time of report compilation, no repair accounts have been received. The following estimate should be regarded as [very preliminary / preliminary / indicative] as [reason — e.g. the damage has not been fully sighted / repair scope has not been confirmed]. Our estimate, subject to amendment when information is provided, is: [CCY] [amount]."*

The surveyor selects the caveat level (very preliminary / preliminary / indicative) and edits the reason.

---

## Section 12: Available Information / Documents

This section lists documents received, documents requested, and — where relevant — documents that were sought but not provided. It serves both as a case record and as a chain-of-evidence log for GPN-AI compliance.

In the Marsh Maritime format this appears as two bullet lists at the end of the report ("Documents Retained on File" / "Documents Requested"). In the London/ABL format it appears as a structured table in the body of the report (see MINRES BALDER "Available Information" table with Enclosed/Available columns).

The platform should support the **MINRES BALDER table format** as the default — it is more informative and directly supports the AI source-attribution function (Section 6 Background can link to rows in this table).

---

### Suggested Layout

```
AVAILABLE INFORMATION

┌────────────────────────────────────────────────┬────────────────────┐
│ Document                                        │ Status             │
├────────────────────────────────────────────────┼────────────────────┤
│ AMSA Incident Report — 07/10/2025              │ Available          │
│ Master's Attestation — 12/10/2025              │ Available          │
│ Class Certificate — issued 20/03/2025          │ Available          │
│ Yard work sheets and report                    │ Requested          │
│ External lube oil analysis results             │ Requested          │
│ Material datasheet — failed sliding bearing    │ Not received       │
└────────────────────────────────────────────────┴────────────────────┘
```

Status values: **Available** (received and on file) / **Requested** (requested, not yet received) / **Not provided** (requested, owner has declined or not responded).

---

### Fields (per document row)

| Field | Input type | Notes |
|-------|------------|-------|
| Document name | Short text | Descriptive name + date where applicable |
| Status | Dropdown | Available / Requested / Not provided |
| Source | Short text | Who provided / from whom requested |
| Annexure reference | Auto-assigned | If Available and appended: e.g. "Annexure B" |
| Background link | Toggle | Whether this document is cited as a source in the Background narrative — links the cue attribution system |

### Notes

- Rows are added dynamically throughout the case lifetime, not just at report compilation.
- On successive reports, prior rows carry forward. Status updates (e.g. "Requested" → "Available") are tracked with a date.
- Documents tagged with a Background link auto-generate the attribution sentence in Section 6 when relevant.
- The "Not provided" status is legally significant — it protects the surveyor by documenting that they sought information the owner did not supply, which feeds the Waiver clause.

---

## Section 13: Waiver

The Waiver is a locked, verbatim, mandatory section. It appears in every report of every type without exception. It is never omitted, never paraphrased, and never editable by the surveyor.

The Waiver text is identical across all Marsh Maritime reports in the corpus:

> *"This report is issued without prejudice to any or all the concerned parties with reservations as to information not made available, inaccessible, or hidden at the time of survey and neither the Company nor the Undersigned shall be held liable whatsoever for any act, error, omission or default in connection therewith."*

Followed — on Progress, Interim, Supplementary reports — by the continuation clause:

> *"We will follow up the case as necessary and report accordingly."*

This continuation clause is suppressed on Final reports.

---

### Sign-off Block

Immediately below the Waiver text, the sign-off block renders:

```
[City], [State]
[Report date]

Yours faithfully

[Signature image — uploaded by surveyor to user account]
________________________________

[Surveyor full name]
[Title — Attending Surveyor / Principal Surveyor]
[Company name]
Mob: [mobile]
E: [email]
W: [website]
```

All sign-off fields are auto-populated from the user account. The report date is the system date at the time the report is approved for issue. The signature image is uploaded once to the user profile and inserted automatically.

The Waiver and sign-off block lock permanently on report signing — no subsequent edits are possible to any content above this point.

---

### ⚠️ App Notes

- Waiver text: **verbatim locked** — platform version controlled. Any change to the Waiver text requires a platform-level update, not a per-report edit.
- Continuation clause: conditional on report type — suppressed on Final, present on all others.
- Sign-off date: system date at time of signing, not at time of drafting.
- Signature: uploaded to user account profile once; auto-inserted. Surveyor cannot insert an ad-hoc image in the report editor — signature comes from the account only.
