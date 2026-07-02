# Report Builder — Current Implementation Overview

Snapshot of how the Report Builder works today: architecture, data flow, and
where each report section's content actually comes from in the front end.
Written to hand to another Claude session (or any new contributor) as
context — not a spec, a description of what's built.

App: Flutter + Riverpod + Supabase (Postgres). Marine survey report
generation for a freelance H&M/P&I surveyor (single-user today).

## 1. High-level architecture

```
lib/features/reports/
  providers/report_provider.dart     — all state: types, models, section assembly
  screens/report_builder_screen.dart — the 3-tab UI (Editor / Preview / Postprocessing)
  widgets/section_editor.dart        — one collapsible section card
  widgets/report_preview.dart        — WYSIWYG-ish preview of the docx
  widgets/new_output_sheet.dart      — "create report" bottom sheet
  widgets/export_button.dart         — export gating + triggers docx generation
  services/docx_export_service.dart  — builds the actual .docx (independent
                                        rendering logic from the preview)
```

`docx_export_service.dart` uses an in-house OOXML builder
(`lib/core/docx/docx_builder.dart`) — no template library, raw XML strings.

A **case** (`cases` table) can have multiple **report outputs**
(`report_outputs` table) — e.g. a Preliminary Report, one or more Advice
reports, and eventually a Final Report, all for the same case. Each output
has its own status/lifecycle and its own snapshot of section content.

## 2. Core concepts

### Output types (`OutputType`)
`preliminary` | `advice` (numbered 1–5, via a picker) | `final_`

### Report status lifecycle (`ReportStatus`)
`draft → submittedQc → qcComments → approved → issued → locked`
(`selfReviewed` exists in the enum but isn't part of the active stepper.)
Driven by `_StatusActions` in the Postprocessing tab — always shows the
single next applicable transition as a button, not a free-form picker.

### Sections (`SectionType`)
21 section types, always built in a fixed order (`oceanoSectionOrder`) that
maps to a written spec ("Oceanoservices H&M report format §4.1"). Every
section is always created for every report — content is empty string if
there's no data yet, not omitted. The section list, in order:

`executiveSummary, opening, attendees, vesselParticulars,
machineryParticulars, classStatutory, informationSources, background,
occurrence, damageDescription, allegation, causation, repairs,
generalServices, accounts, repairTimes, surveyorNotes, documentsOnFile,
documentsRequested, waiver, closing`

A few report elements are **not** editable text sections — they're rendered
directly from raw data at export time as auto-tables: Document Control
(version history), Chronology, Damage Schedule, Repair Times table,
Documents Retained table, and the AI Generation Record annexure.

### Clause library (`clause_library` table, `ClauseModel`)
Fixed/legal-standard report text ("This is to certify...", waiver language,
cost-approval statements, etc.) lives in a DB table, keyed by
`(format_type, clause_type)`. Fetched once per case via `outputFormat`
(currently only `'abl'` is seeded/used). Sections built from a clause are
marked `isLocked: true` and rendered read-only in the editor (purple
"LOCKED" badge) — the surveyor cannot free-type over approved legal wording,
only choose whether it applies (via upstream toggles) or leave it out.
`AssembledReportData.clauseByType(type)` is the lookup used everywhere.

Many clauses have `{PLACEHOLDER}` tokens filled by simple `.replaceAll()`
calls (e.g. `{CURRENCY_CODE}`, `{ESTIMATED_COST}`, `{CLASS_SOCIETY}`,
`{DOC_ISSUER}`). See `docs/legal_clauses.md` for the full mapping table and
the implementation history of this system (which clause maps to which
upstream field, judgment calls made, etc).

## 3. Data flow (the important part)

```
[Front-end screens]  →  [Supabase tables]  →  assembledDataProvider
                                                       │
                                                       ▼
                                          sectionDraftProvider.buildSections()
                                                       │
                                          Map<SectionType, ReportSection>
                                          (in-memory only — see caveat below)
                                                       │
                              ┌────────────────────────┼────────────────────────┐
                              ▼                        ▼                        ▼
                        Editor tab               Preview tab            docx_export_service
                     (SectionEditor,          (report_preview.dart,      (independent re-read
                      surveyor edits/          reads same section          of assembled data +
                      reviews in place)         map + assembled data)      section content)
```

**`assembledDataProvider`** (`FutureProvider.family<AssembledReportData,
String>`) is the single fan-out query: fetches the case row (joined with
vessel + client), occurrences, damage items, attendees, certificates,
repair_periods, survey_attendances, clause_library rows, repair_documents
(with nested account_lines), timeline_events, surveyor_notes, machinery,
class_conditions, documents (split into on-file vs requested by
`availability`), organisation config, AI generation log, and all report
outputs for the version table — about a dozen queries in parallel per case
load.

**`sectionDraftProvider.buildSections(assembled, {aiDraft})`** turns that
raw data into the 21 `ReportSection`s using a large set of private
`_buildXText()` template methods in `report_provider.dart`. This is plain
Dart string templating (not AI) for almost everything — occurrence text,
vessel particulars table text, damage list, etc. **Two sections do call
Claude** when `aiDraft: true` and the underlying DB field is empty:
Background narrative (`draftOccurrenceNarrative`) and Cause Consideration
(`draftCauseConsideration`). In practice `aiDraft` is currently always
`false` at the call site in `report_builder_screen.dart` — sections build
from whatever narrative text already exists in `occurrences.background_narrative`
/ `occurrences.cause_narrative`, with AI drafting present in the codebase
but not wired to a button yet.

**Important caveat: `sectionDraftProvider` state is not persisted anywhere.**
There's no `report_sections` table — `ReportSection.sectionId` exists on the
model but nothing ever sets it. Every time the report builder screen mounts
and finds an empty section map, it silently rebuilds all sections fresh from
current case data (`_buildDraft`) — so **any edits a surveyor made directly
in a section's text box are lost on app restart / navigating away and back**,
unless already exported. Surveyor review status (`SurveyorReview`) is
similarly ephemeral. This is a known architectural gap, not yet flagged to
the user or fixed — worth surfacing if asked to prioritise.

## 4. The three-tab UI (`report_builder_screen.dart`)

1. **Editor** — cover photo picker at the top (see §6), then all 21
   sections as collapsible cards (`SectionEditor`), in spec order. Each card
   shows a review-status dot, section number, LOCKED/AI DRAFT badges, and
   (unless locked) a free-text box plus three review chips: **ACCEPTED**,
   **AMENDED**, **MY OWN** (`SurveyorReview` enum) — this is the GPN-AI
   compliance gate (Australian Federal Court AI-disclosure practice note):
   every AI-drafted section must get an explicit human review status before
   export is allowed (enforced in `ExportButton`, not just UI decoration).

2. **Preview** — a closer visual approximation of the final docx (branded
   cover page, running header/footer, shaded blocks), built independently
   in `report_preview.dart` from the same section map + assembled data. Not
   pixel-identical to the docx — it's a separate rendering path, so the two
   can drift if one is updated without the other (has happened before, e.g.
   the cover-photo-not-updating bug).

3. **Postprocessing** — status stepper, changes-summary field (only shown
   when this output supersedes a prior version), sign-off row (Final
   reports only, via `sign_off_sheet.dart`), and the export button. This
   used to be a footer under Preview plus a hidden AppBar menu; consolidated
   into its own tab per surveyor request.

## 5. Section-by-section: front-end input source

| # | Section | Report title | Primary input screen(s) | Backing table(s) | Notes |
|---|---|---|---|---|---|
| — | executiveSummary | Executive Summary | *(auto template, no dedicated screen)* | occurrences, cases | Placeholder text with `[bracketed prompts]` — always needs manual editing; explicitly built last conceptually even though rendered first (per earlier surveyor request), current code doesn't enforce ordering of *when* it's written, just where it displays |
| 1 | opening | Introduction / Opening Certification | *(no screen — derived from case + attendance)* | clause_library, cases, survey_attendances | Locked clause text with client name / first-attendance date+location / hull-and-machinery survey-type phrase substituted in |
| 2 | attendees | Attending Representatives | `attendances/screens/attendees_screen.dart`, `attendances_screen.dart` | attendees, survey_attendances | Attendee title field (Mr./Ms./Capt.) added this session; case-home summary groups reps per attendance |
| 3 | vesselParticulars | Vessel's Particulars | `vessel/screens/vessel_particulars_screen.dart` (Identity + Dimensions tabs) | vessels | Also pulls a "ship type" locked clause sentence keyed off the vessel-type dropdown (only for types with a matching doc phrase — otherwise omitted, never guessed) |
| 4 | machineryParticulars | Machinery & Equipment Particulars | `vessel/screens/vessel_particulars_screen.dart` (Machinery tab) | machinery | Conditional — section/table omitted entirely if no machinery rows |
| 5 | classStatutory | Class & Statutory Certification | `vessel_particulars_screen.dart` (Class & Stat. tab) *and* `vessel/screens/vessel_compliance_screen.dart` ("Certificates & Class") | vessels (class fields, ISM/Class incident flags), certificates, class_conditions | **Two separate screens write overlapping vessel fields** — see §8 below |
| 6 | informationSources | Available Information Sources | `documents/screens/document_vault_screen.dart` | documents (`availability = 'enclosed'`) | Grouped by `doc_category` |
| 7 | *(chronology, no text section)* | Chronology of Events | `timeline/screens/timeline_screen.dart` | timeline_events | Auto-table only, ordered by `event_date` |
| 8 | background | Background | `survey/screens/occurrence_screen.dart` (narrative field) | occurrences.background_narrative | AI-draftable (Claude) if empty, currently not wired to a UI trigger |
| 9 | occurrence | Occurrence | `survey/screens/occurrence_screen.dart` / `add_occurrence_sheet.dart` | occurrences | Brief description + vessel-status-at-casualty clause + aftermath clause (with optional named port), all toggle-driven |
| 9 | damageDescription | Extent of Damage | `survey/screens/damage_register_screen.dart` / `add_damage_item_sheet.dart` | damage_items | Numbered list; also drives the Damage Schedule auto-table (component/description/repair type/average-vs-owner's) |
| 10 | allegation | Owner's Allegation | `survey/widgets/causation_sheet.dart` / `causation_screen.dart` | occurrences.allegation_type | Two mutually exclusive locked clauses: formal allegation raised / none raised |
| 10 | causation | Cause Consideration | `causation_screen.dart` / `causation_sheet.dart` | occurrences.cause_narrative | AI-draftable (Claude) if empty, same as Background |
| 11 | repairs | Repairs | `survey/screens/repair_periods_screen.dart` / `add_repair_period_sheet.dart` | repair_records *(legacy, effectively unused — see §8)*, repair_periods | Narrative + per-period services-provided checklist and hot-work-certificate status, each mapped to its own locked clause |
| 12 | generalServices | General Services & Access | *(no screen yet)* | — | Always empty — placeholder section in the spec, not built out |
| 13 | accounts | Repair Costs | `accounts/screens/accounts_screen.dart`, `invoice_detail_screen.dart` | repair_documents, account_lines | Cost-estimate-status selector (`_CostEstimateSelector`) drives a locked clause; full apportionment (underwriters'/owner's split, FX, per-invoice clauses H-1 through H-6) computed in the docx export step, not in the section text itself — the section text is just a supplier/total summary |
| 14 | repairTimes | Repair Times | `repair_periods_screen.dart` | repair_records | Drydock/afloat/owner's days per repair; auto-table + optional guidance clause |
| 15 | surveyorNotes | Surveyor's Notes | `surveyor_notes/screens/surveyor_notes_screen.dart` | surveyor_notes | Freeform, tagged notes captured throughout the survey (often voice-transcribed) |
| 16 | documentsOnFile | Documents Retained on File | `document_vault_screen.dart` | documents (`availability = 'enclosed'`) | Numbered list + locked lead-in clause; also drives an auto-table and the lettered Annexures A–H at the end of the docx |
| 17 | documentsRequested | Documents Requested / Outstanding | `document_vault_screen.dart` | documents (`availability = 'requested'`) | Has a `requested_date` (added this session) |
| — | *(principal dates, no text section)* | Principal Dates | *(no screen — derived)* | cases | **Not actually implemented** — a code comment in `report_provider.dart` claims this "renders automatically from case dates" at export, but there is no matching code in `docx_export_service.dart` at all (verified by search). This section of the spec is currently a no-op. |
| 19 | waiver | Limitation of Liability / Waiver | `settings/screens/organisation_detail_screen.dart` (org override) or none (falls to clause/hardcoded default) | organisations.waiver_text, clause_library | Resolution order: org override → clause_library → hardcoded fallback string |
| — | closing | Disclaimer | same as waiver | organisations.disclaimer_text, clause_library | Same resolution order |

**Cost/legal clause detail**: many of the smaller clause insertions (vessel
status at casualty, aftermath handling, services provided, hot work
certificates, class status, DOC/SMC certificate statements, drydock
statement, statutory cert status, cost-estimate status, account
approval/assessment outcomes) are driven by dropdown/toggle fields on the
relevant input screen, each mapped through a `static const Map<String,
String>` in `report_provider.dart` to a specific `clause_type`. When a
value has no map entry, the clause is simply omitted — the code is
deliberately conservative about never inventing legal-sounding phrasing for
a case the clause library doesn't cover. See `docs/legal_clauses.md` for
the full mapping tables and the reasoning behind each one.

## 6. Cover photo

Single case-wide concept — **one cover photo per case**, not per report
output (an earlier per-output override was built, then explicitly removed
per surveyor request). Setting a photo's allocation to "Cover Page" in the
Photo Gallery, Vessel Particulars, or the Report Builder's own picker
(top of the Editor tab) all write to the same place
(`photosProvider.updateAllocation(id, PhotoAllocation.coverPage)`), which
enforces uniqueness by clearing the flag from any other photo in the case.
Rendered `BoxFit.contain` (not `cover`) in both preview and docx — scaled to
fit, never auto-cropped; cropping is a deliberate, separate step in the
photo editor.

## 7. Export (`docx_export_service.dart` + `export_button.dart`)

Gating logic in `ExportButton` before a docx can be generated:
- Report must not be `locked`.
- If `Final` output type: both attending and reviewing surveyor sign-offs
  must be present (`signed_off_attending` / `signed_off_reviewing` on the
  case row).
- **Hard block**: any AI-drafted section (`aiDrafted: true`) with no
  `surveyorReview` set yet — this is the GPN-AI compliance gate, and it
  cannot be bypassed by any UI action other than actually setting a review
  status on that section.
- Soft warning (dismissible): not all sections marked `approved`.

The docx itself is built independently of the preview widget — same
underlying `AssembledReportData` and section map, but its own
paragraph-by-paragraph construction via the in-house OOXML builder. Cover
page (branded, WP notice, vessel name, report type/version band, cover
photo, info table) on an unnumbered page 1 (`w:titlePg`), then a running
header (`Job No — Vessel — Report Type`) from page 2 onward. Ends with
lettered Annexures A–H (documents grouped by `annexure_assignment`) and a
reserved Annexure I (AI Generation Record table, GPN-AI compliance).

Filename convention: `{technical_file_no}_{VESSEL_NAME}_{Prelim|Advice{n}|Final}_{date}.docx`.

## 8. Known quirks / things worth knowing before changing this

- **`repair_records` is legacy/dead data** — it has no writer UI anywhere in
  the app (confirmed empty in production during the legal-clauses audit).
  The actively-used table for repair grouping is `repair_periods`. Some
  export code still reads from `repairRecords` (e.g. the Repair Times
  table) — this is stale and will need reconciling if repair data entry
  ever moves fully onto `repair_periods`.
- **ISM/Class incident-reported flags are edited from two different
  screens** writing the *same* two `vessels` columns
  (`ism_incident_reported`, `class_incident_reported`): a plain on/off
  `SwitchListTile` pair in `vessel_compliance_screen.dart` ("Certificates &
  Class") titled "Incident reported in the ISM" / "Incident reported to
  Class", and a tri-state (Yes/No/unset) `_TriStateRow` pair in
  `vessel_particulars_screen.dart`'s "Class & Stat." tab titled "Reported
  via ISM" / "Reported to Class". Same underlying data, two different input
  widgets with different null-handling — not a bug exactly, but a
  duplication worth consolidating if ever touched again.
- **Section drafts are not persisted** (see §3 caveat) — this is the
  biggest architectural gap in the current implementation. Anything typed
  into a section's text box only survives for the current app session /
  until the report is exported.
- **`aiDraft` is currently hardcoded false** at the only call site — the
  Claude-drafting code paths for Background and Cause Consideration exist
  and work, but nothing in the UI currently triggers them. A surveyor would
  need those narrative DB fields populated some other way (e.g. manually,
  or via a future "AI draft" button) to see AI-authored content in those
  two sections today.
- **Preview vs docx are two independent rendering implementations** of the
  same data — they've drifted before (cover photo bug) and could again if
  one is changed without the other.
- Report format is effectively hardcoded to `'abl'` / the Oceanoservices
  H&M layout (`oceanoSectionOrder`) — the codebase has scaffolding for
  multiple formats (`outputFormat` field, per-format clause lookup) but
  only one section order/layout currently exists.

## 9. Related docs

- `docs/legal_clauses.md` — full clause-mapping tables, implementation
  history, and the specific judgment calls made while wiring each clause to
  an upstream field.
- `docs/EQUASIS_DEBUG_LOG.md` — unrelated to the report builder, but same
  "append every attempt" convention if this doc ever needs the same
  treatment for a hard bug.
