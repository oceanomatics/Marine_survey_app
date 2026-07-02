# Marine Survey App — Master To-Do List

**Last updated:** 1 July 2026 — added attendance reorder, EXIF photo assignment, section sub-paragraphs  
**Spec reference:** `docs/report_builder_specs`  
**Schema reference:** `docs/SCHEMA.md`  
**Test sheet:** `TEST_SHEET.md` (110 items, all untested)

Status legend: `[ ]` Not started · `[~]` In progress · `[✓]` Done · `[!]` Blocked

---

## PHASE 0 — Active Bugs (fix now)

| # | Bug | Location | Notes |
|---|-----|----------|-------|
| B1 | Vessel particulars data not displaying | `vessel_particulars_screen.dart` | Error now shown (fix deployed); likely DB-side — check Supabase vessel_id link or type cast failure |
| B2 | `_buildScaffold` silently swallowed fetch errors | `vessel_particulars_screen.dart` | **Fixed** — now shows error card with Retry button |

---

## PHASE 1 — Report Builder: Tier 1 (Blocking for Any Production Export)

Nothing here is optional. A report that misses these items is not professionally or legally acceptable for H&M submission.

### 1.1 Dual Sign-Off Gate
- [✓] `signed_off_attending`, `signed_off_reviewing`, `signed_off_at`, `dualSignOffComplete` on `CaseModel` — **DONE**
- [✓] Export button (`export_button.dart`) hard-blocks Final export unless both flags true — **DONE**
- [ ] Build Sign-Off UI screen: drawn signature (touch) / PNG upload (desktop); captured at sign-off time only — **MISSING**
- [ ] Notification to reviewing surveyor when attending surveyor submits for QC — **MISSING**
- [ ] Surveyor declaration text embedded in sign-off block — **MISSING**

**Spec:** §2.1, §4.10, §5.4

### 1.2 WITHOUT PREJUDICE — All Four Required Locations
- [✓] Page footer (every page): `wpFooterText` from org config, fallback text — rendered via `doc.setFooter()` — **DONE**
- [✓] Cover page header: `wpHeaderText` from org config — **DONE**
- [✓] Cover block (location 2, below title): `wpCoverText` from org config — **DONE**
- [✓] Cost section (location 3): `wpCostSectionText` from org config, with fallback — **DONE**
- [✓] Waiver (closing): `waiverText` from org config, assembled as `SectionType.waiver` — **DONE**

**All four WP locations are done. Spec:** §4.7, §8.3

### 1.3 AI Audit Log (GPN-AI Compliance — Federal Court of Australia, April 2026)
- [✓] `AiGenerationLogModel` with all required fields: `promptSha256`, `promptText`, `responseText`, `humanReviewed`, `humanEdited`, `reviewedAt`, `reviewedBy` — **DONE** (`lib/core/models/ai_generation_log_model.dart`)
- [✓] `AiLogService` writes to `ai_generation_log` Supabase table — **DONE** (`lib/core/services/ai_log_service.dart`)
- [✓] `ClaudeApi` wired to `AiLogService` on every call — **DONE**
- [✓] Per-section review UI in `section_editor.dart`: `SurveyorReview` (reviewedAccepted / reviewedAmended / surveyorAuthored) — **DONE**
- [ ] Gate export on: all AI-generated sections having a `surveyor_review` value set — **MISSING**

**Spec:** §3.3, §8.1

### 1.4 AI Disclosure Paragraph + Annexure I (AI Audit Record)
- [ ] Auto-generate disclosure paragraph on export — **MISSING**
- [ ] Auto-build Annexure I table from `ai_generation_log` at export — **MISSING**
- [ ] Snapshot `ai_generation_log` entries into JSON field on `report_outputs` at sign-off (per decision C4) — **MISSING**
- [ ] Suppress if all sections are `surveyor_authored` — **MISSING**

**Spec:** §3.4, §3.5, §4.1 item 33

### 1.5 Cost Section Rendered in Report
- [✓] Repair documents + account lines fetched and assembled in docx export — **DONE**
- [✓] Formal accounts table with Item / Supplier / Invoice Ref / Amount / Allocation — **DONE**
- [✓] Totals: Owner's Account + Underwriters' Account + Grand Total — **DONE**
- [✓] WP notation below cost table (`wpCostSectionText`) — **DONE**
- [✓] Multi-currency via `FxRateService` (openexchangerates.org, locked to invoice date) — **DONE** (`lib/core/services/fx_rate_service.dart`)

**Spec:** §4.6 — fully done

### 1.6 Cover Page
- [✓] Programmatic OOXML builder in place — no external `.docx` templates — **DONE** (`lib/core/docx/docx_builder.dart`)
- [✓] Cover content: WP header, firm name, metadata table (Report No., Claim Ref., Policy UCR, Occurrence, Location) — **DONE**
- [✓] Vessel Particulars table on cover — **DONE**
- [✓] Machinery & Equipment table on cover (conditional) — **DONE**
- [✓] Certificates & Class Conditions tables on cover — **DONE**
- [ ] Distinct visual cover page design: vessel name in large coloured title band, status badge, vessel cover photo, 2-column info box, firm logo — **MISSING**
- [ ] Running header on body pages (2+): logo + right-aligned title text + rule — **MISSING**
- [ ] No running header on page 1 (cover) — **MISSING**

**Spec:** §1.2.1, §1.2.2, §4.2

### 1.7 Export Validation Gate
- [✓] Hard-blocks Final export if dual sign-off incomplete — **DONE**
- [ ] Full validation checklist before export (empty mandatory sections, allegation vs. opinion check, cost total, all AI sections reviewed, Advice Summary confirmed) — **MISSING**
- [ ] User-friendly error summary sheet — **MISSING**

**Spec:** §5.4

---

## PHASE 1 — Report Builder: Tier 2 (Full Feature Parity with Spec)

### 2.1 Account Branding Configuration
- [✓] `OrganisationModel` with full fields: firm identity, ABN, address, contact, logo path, primary/secondary colour, all 4 WP text blocks, disclaimer, waiver — **DONE** (`lib/features/settings/models/organisation_model.dart`)
- [✓] `SurveyorProfileModel` with name, title, qualifications, signature storage path — **DONE**
- [✓] Organisation list screen + detail screen (3-tab: Identity / Legal Text / Surveyor Profiles) — **DONE** (`lib/features/settings/screens/`)
- [✓] Docx export reads all branding from org config — zero hardcoded values — **DONE**
- [✓] `org_id` on `CaseModel`, resolved at report build time — **DONE**
- [ ] Logo file upload to Supabase Storage in org detail screen — **MISSING**
- [ ] Colour picker UI (currently text hex fields only) — **MISSING**
- [ ] Logo embedded in running header of body pages — **MISSING**

**Spec:** §1.1, §1.2, §9.4

### 2.2 Document Vault Enhancement
- [✓] `is_cover_photo` on `DocumentModel` — **DONE**
- [✓] `annexure_assignment` (String: A–I or null) on `DocumentModel` — **DONE**
- [✓] `surveyor_confirmed` bool on `DocumentModel` — **DONE**
- [✓] Document tile shows cover photo badge and annexure badge inline — **DONE**
- [✓] Document tile edit sheet allows cover photo toggle and annexure assignment — **DONE**
- [ ] Report builder sorts documents into annexures by `annexure_assignment` at export — **MISSING**

**Spec:** §5.3

### 2.3 Chronology as Formal Table
- [✓] Timeline events rendered as formal two-column table (Date | Event) in docx output — **DONE**
- [✓] Events sorted ascending by `event_date` — **DONE**
- [ ] Coloured header row using `primary_colour` from org config — **MISSING** (uses standard bold row)

**Spec:** §4.3

### 2.4 Photo Register + Annexure E
- [ ] Add photo metadata fields: location/component, direction/context, significance-to-claim
- [ ] Build photo register table (Photo No. | Location | Direction | Date | Significance) as Annexure E opener
- [ ] Thumbnails at ~120px wide in register; full-size captioned photos follow
- [ ] Caption format: `[Photo N] — [component/location] — [direction/context] — [date] — [significance]`

**Spec:** §4.8

### 2.5 Report Version Numbering (R001, R002…)
- [✓] `sequenceNo` int on `ReportOutput`; `versionString` computed as `R001` format — **DONE**
- [✓] Auto-increment picker in `new_output_sheet.dart` — **DONE**
- [ ] Final Report "this report supersedes all prior…" statement — **MISSING**
- [ ] Progress/Supplementary "this report supplements Report [R00N]…" statement — **MISSING**
- [ ] Version Control Block showing document management history (version, date, type, attending surveyor, "changes from previous" field) — **MISSING**

**Spec:** §4.9, §7

### 2.6 Advice Summary Editor Screen
- [ ] `AdviceSummaryModel` (policy_ucr, assured, instructing_party, date_nature, damage_description_summary, probable_cause, repair_status, cost_claim, cost_owners, cost_adjustment, loh_implication, outstanding_actions, remarks) — **MISSING**
- [ ] Auto-populate from case data; AI draft for narrative fields — **MISSING**
- [ ] `AdviceSummaryScreen` tab inside Report Builder — **MISSING**
- [ ] Gate export on Advice Summary confirmed — **MISSING**

**Spec:** §2.17, §4.1

### 2.7 Report Sections Status
Current state: all major sections coded. Re-audit against spec:

- [✓] Section 5: Machinery / Equipment Particulars — **DONE** (`SectionType.machineryParticulars`, assembled in docx)
- [✓] Section 6: Class & Statutory Certification — **DONE** (`SectionType.classStatutory` + certificates/conditions tables in docx)
- [✓] Section 7: Available Information Sources — **DONE** (`SectionType.informationSources`)
- [✓] Section 12: General Services & Access — **DONE** (`SectionType.generalServices`)
- [✓] Section 15: Surveyor's Notes — **DONE** (`SectionType.surveyorNotes`, assembled from `surveyor_notes` table)
- [✓] Section 16: Documents Retained on File — **DONE** (assembled as formal table in docx)
- [✓] Section 19: Waiver / Limitation of Liability — **DONE** (`SectionType.waiver`, from org `waiverText`)
- [✓] Chronology — **DONE** (formal table, assembled from `timeline_events`)
- [ ] Section 17: Documents Requested — new model + section needed — **MISSING**
- [ ] Section 18: Principal Dates (milestone timeline events) — **MISSING**
- [ ] Annexures A–H: Cost Assessment, Invoices, Certificates, Incident Report, Third-party Reports, Correspondence, Prior Reports — **MISSING** (docs listed but not sorted/formatted as annexures)

**Spec:** §4.1 (full section order)

### 2.8 Logo in Running Header
- [ ] Embed firm logo as inline image in body-page header paragraph (NOT table cell) — **MISSING**
- [ ] Right-aligned tab stop for title text: `[Vessel Name] — [Report Type] — [Claim Reference]` — **MISSING**

**Spec:** §1.2.2, §1.2.5

### 2.9 Table Row Break Prevention
- [✓] `cantSplit` applied to all table rows in `ooxml_helpers.dart` — **DONE**

**Spec:** §6.4

### 2.10 Case Header — Fields
- [✓] `policyUcr`, `instructingParty`, `instructingPartyRole`, `assured`, `baseCurrency`, `organisationId` on `CaseModel` — **DONE**
- [ ] UI to edit `policyUcr` in new case / case editor screen — **CHECK** (may already be there)

**Spec:** §2.1

### 2.11 Vessel Model — Statutory Fields
- [ ] Add `official_number`, `class_status`, `construction_standard`, `registered_owner`, `last_drydock_date`, `last_drydock_yard`, `ism_incident_reported`, `class_incident_reported`, `psc_last_inspection`, `psc_last_result`, `pi_club`, `isps_status` to `vessels` table + `VesselModel` + Vessel Particulars screen — **MISSING**
- [✓] Document-level cert fields (`survey_cert_no`, `equipment_due`, etc.) remain in `certificates` table — **DONE** (per decision B3)

**Spec:** §2.2

### 2.12 Section Sub-Paragraphs (Oceanoservices format only)
- [ ] Data model: allow narrative sections to have child paragraphs, each with its own title and content
- [ ] Numbering: parent section gets `N.` prefix; children get `N.1`, `N.2`, … — e.g. §3 Opening → §3.1 Background, §3.2 Notifications
- [ ] Editor UI: add / remove / reorder sub-paragraphs within a section card
- [ ] TOC auto-update: child entries indented under parent, with correct page numbers
- [ ] Preview: sub-paragraph headings rendered at a visually subordinate level to section headings

### 2.13 Background Narrative Structuring (Clause D-1)
- [ ] `occurrence.background_narrative` currently does double duty: it's both the surveyor's own background account (rendered under §8 Background) and, per the legal_clauses.md audit, is meant to also cover D-1 — the *owners'* description of events leading up to first attendance, which the spec frames as a distinct voice/perspective from the surveyor's own narrative.
- [ ] Decide/implement: either split into two fields (owners' pre-attendance account vs. surveyor's background), or restructure the single field with a clear internal convention (e.g. a leading owners'-account subsection) so both purposes are served without conflating them.
- [ ] Confirmed 2026-07-02: keep using `background_narrative` for now, but this structuring is a known follow-up, not resolved.

**Spec:** see `docs/legal_clauses.md` Part D (D-1)

### 2.14 REPAIR TIMES section likely always blank in real reports
- [ ] Discovered 2026-07-03 while building Phase 2 UI: the "REPAIR TIMES" table in `docx_export_service.dart` (and Clause I-1's guidance text) reads from `assembled.repairRecords`, sourced from the `repair_records` table — which has **zero rows and no Dart model or screen writing to it at all**. It's dead/legacy.
- [ ] The actively-used table for this concept is `repair_periods` (`RepairPeriodModel`, has a real screen: `repair_periods_screen.dart`), which stores drydock/alongside days in a `repair_times` jsonb column (`RepairTimeEntry`), keyed by occurrence/owner — a different shape from `repair_records`' flat `drydock_days`/`afloat_days`/`owner_days` columns.
- [ ] Fix: rewrite the REPAIR TIMES table + Clause I-1 rendering to aggregate `repair_periods.repair_times` instead of `repair_records`. Not fixed yet — flagged only, out of scope for the Phase 2 clause UI work (see `docs/legal_clauses.md`).
- [ ] Note: F-2/F-5 (services provided / hot work) were correctly placed on `repair_periods` during this same session, once this table confusion was caught — see `docs/legal_clauses.md` 2026-07-03 entry.

### 2.15 Documentation section: only 2 meaningful availability states, not 3
- [ ] The new case-home "Documentation" card (K-2, added 2026-07-03) wants three categories — enclosed in report / retained on file / requested — but `DocAvailability` only has `enclosed`/`requested`/`not_available`/`tbc`, i.e. no distinction between "enclosed in the exported report" and "retained on file but not enclosed". Currently both concepts collapse into `enclosed`, labelled "On File" in the summary card.
- [ ] If the distinction matters in practice, needs either a new `DocAvailability` value or a separate boolean (e.g. `included_in_report`) — not added now since it wasn't clear this distinction is actually needed day-to-day.

---

## PHASE 1 — Case Management Enhancements

### 3.1 Attendance Editor — Attendee Ordering
- [ ] Manual drag-to-reorder attendees within an attendance record
- [ ] Persist order via `sort_order` int on `attendees` table (add migration)
- [ ] Attendance list renders attendees sorted by `sort_order`
- [ ] Default order: insertion order (existing rows get `sort_order` = row index on migration)

### 3.2 Photo-to-Attendance Assignment (EXIF-based)
- [ ] Read `DateTimeOriginal` EXIF tag from each imported photo at import time; store as `taken_at` on `photos` table
- [ ] Auto-assign: after import, match `taken_at` against available attendance date ranges and set `attendance_id` automatically where unambiguous
- [ ] Conflict handling: if a photo timestamp falls in more than one attendance range (or in none), leave unassigned and flag for manual review
- [ ] Manual assignment UI: unassigned photos surfaced in a review sheet; surveyor picks the attendance from a list
- [ ] Bulk auto-assign action: re-run the EXIF matching pass on demand (e.g. after adding a new attendance)

### 3.3 Google Photos Integration — Photos Routed to Visit Date
- [ ] When photos are added to an attendance/visit, upload them to Google Photos and file them under an album named for that visit date (e.g. `"2026-06-28 — MV Surveyor — Attendance 1"`)
- [ ] Use `taken_at` (EXIF) as the photo date so Google Photos timeline reflects the actual survey date, not the upload date
- [ ] Requires Google OAuth + Photos Library API (`photoslibrary.appendonly` scope); reuse token store from §2.1 Google Workspace integration
- [ ] On upload failure, queue for retry and surface status in the photo gallery
- [ ] See also Phase 3 — Google Workspace integration (broader Drive/Gmail/Photos roadmap)

### 3.4 Documentation Section (Case Page) + Auto-Generated Document Request Email
- [ ] New case-page "Documentation" section summarising three categories: documents enclosed in the report, documents retained on file, documents requested (not yet received) — backed by `documents.availability` (`enclosed`/`requested`/`not_available`/`tbc`, already exists) plus new `documents.requested_date` (added 2026-07-02) and existing `received_date`
- [ ] Support free-form ad-hoc "requested" line items with no file attached yet (e.g. requesting something on site during a visit) — `documents` already supports a nullable `file_path`, so no schema change needed there
- [ ] Works both pre-survey and post-survey, not tied to a specific attendance
- [ ] Auto-generate an email listing all outstanding requested documents (to Owners/Repairers), from the same data — **not started**
- [ ] See `docs/legal_clauses.md` Part K (K-2) for the report-side rendering, already implemented

---

## PHASE 2 — Pre-Launch (Commercial Deployment)

From `README.md` commercial deployment section:

### Multi-Tenancy
- [ ] Introduce `organisations` table (also needed for branding config — coordinate with §2.1 above)
- [ ] Add `org_id` FK to: cases, vessels, documents, photos, repair_documents, surveyor_notes, attendees, interviews, timeline_events, checklists
- [ ] Apply Row Level Security policies on all tables — full org isolation
- [ ] User onboarding / invite flow per organisation
- [ ] Admin screen: manage organisations and users (ABL ops)

### AI Cost Attribution
- [ ] Create `analyst_usage` table: `case_id, user_id, org_id, model, input_tokens, output_tokens, created_at`
- [ ] Update `case-analyst` Edge Function to insert a row after each Anthropic call
- [ ] Build usage report view: per company, per case, per month
- [ ] Decide billing model: include in service fee vs. pass-through at cost

### Configuration & Secrets
- [ ] Per-deployment `ANTHROPIC_API_KEY` as Supabase secret
- [ ] Terms of service and DPA per client
- [ ] Backup / export policy for case data
- [ ] Audit log for destructive operations (delete case, delete document, etc.)

---

## PHASE 3 — Future Roadmap

From `memory/project_future_roadmap.md` + spec §3 Tier 3:

- [ ] **Flutter PDF module** — native PDF output (same data model as docx; renderer-only change)
- [ ] **Voice transcription pipeline** — SpeechProvider abstraction → AssemblyAI/Deepgram for interview diarization (P&I selling point); Azure Speech for enterprise data residency
- [ ] **Offline mode** — case snapshot tables + write queue (architecture in `docs/offline_sync_plan.md`)
- [ ] **Google Workspace integration** — Gmail correspondence import, Drive photo export, Google Photos library
- [ ] **Automatic error reporting** — Sentry or custom backend
- [ ] **Batch AI extraction** — process all case documents in one pass
- [ ] **Document scanner** — camera-based perspective warp + corner detection (`document_warp.dart` skeleton exists)
- [ ] **P&I integration** — separate report format, policy type support
- [ ] **Shared Drive / NAS export** — bulk photo export for case archive
- [ ] **Instructing party linkage** — `cases.instructing_party` is currently a free-text field; should become a FK to `principals_clients` so contact details, billing address, and email domain are auto-populated. Report builder already joins `principals_clients` for the client — pattern established, just needs extending

---

## OPEN QUESTIONS / DECISIONS NEEDED

| # | Question | Raised by |
|---|----------|-----------|
| Q1 | `technical_file_no` vs `job_number` — same field or distinct? Spec uses `technical_file_no`, codebase uses `jobNumber` | Report Builder Spec §2.1 |
| Q2 | Class & statutory cert data: keep in separate `certificates` table (current) or denormalize onto vessel model? | Spec §2.2 |
| Q3 | Who is "reviewing surveyor" — another platform user or just a name+signature? Multi-user sign-off requires auth records | Spec §4.10 |
| Q4 | `docx_template` package or raw XML for cover page (separate template) — can `docx_template` handle two templates per export? | Spec §1.2.1 |
| Q5 | SHA-256 prompt hashing: hash the full prompt text before or after variable substitution? | Spec §3.3 |
| Q6 | Annexure I (AI Audit Record) — should it be locked in Supabase (snapshot) or always regenerated from `ai_generation_log`? | Spec §3.4 |
| Q7 | EXIF photo assignment: use device-local `taken_at` timestamp or server receipt time as fallback when EXIF is absent? | §3.2 |

---

## SPEC COMPLIANCE SCORECARD

Answering the 15 questions from Spec §10.3 — **re-audited 30 June 2026**:

| # | Question | Current Answer |
|---|----------|---------------|
| 1 | Colours/fonts from config or hardcoded? | ✅ All colours from `OrganisationModel` — docx reads org config |
| 2 | Firm logo in running header on every page? | ❌ Logo upload exists; not yet embedded in body-page header |
| 3 | AI audit log (model_version, prompt_hash, prompt_text, ai_output_text, surveyor_review)? | ✅ `AiGenerationLogModel` + `AiLogService` + wired into `ClaudeApi` + per-section review UI |
| 4 | AI disclosure paragraph auto-generated from audit log? | ❌ Missing |
| 5 | Advice Summary auto-populated and editable? | ❌ No model or screen yet |
| 6 | Chronology as formal table? | ✅ Rendered as formal Date\|Event table in docx |
| 7 | Cost section as formal accounts table + WP notation? | ✅ Fully assembled: repair docs + account lines + totals + WP cost notice |
| 8 | Sign-off block gating Final Report export? | ✅ Export gate exists; ❌ sign-off UI screen (drawn sig / PNG upload) missing |
| 9 | Report version numbering (R001, R002…)? | ✅ `versionString` computed as R001 format; auto-increment picker in new output sheet |
| 10 | Document Vault tracks `annexure_assignment`? | ✅ Field exists on `DocumentModel`; badges on tile; editable in detail sheet |
| 11 | `cantSplit` on table rows? | ✅ Applied in `ooxml_helpers.dart` |
| 12 | WP in all four required locations? | ✅ All four locations rendered from org config (header/cover/cost/footer) |
| 13 | Cover page separate template (no running header on page 1)? | ❌ Programmatic builder in place; separate cover design not yet implemented |
| 14 | Cover page: vessel band, status badge, info box, photo, logo? | ❌ Metadata table exists; visual cover page elements missing |
| 15 | Logo in header as inline paragraph (not table cell)? | ❌ No running header logo yet |

**Score: 9 / 15** ↑ from 0/15 — major progress; remaining gaps: cover page design, logo in header, AI disclosure, Advice Summary, sign-off UI.

---

## DOCUMENT MAP

| Document | Purpose |
|----------|---------|
| `docs/TODO.md` ← this file | Master consolidated to-do |
| `docs/report_builder_specs` | Full H&M Report Builder Specification v1.0 |
| `docs/SCHEMA.md` | Supabase schema dump (partial — truncated at `damage_items`) |
| `docs/offline_sync_plan.md` | Offline case pinning architecture design |
| `TEST_SHEET.md` | 110-item feature test sheet (all untested) |
| `README.md` | Project overview + commercial deployment pre-launch checklist |
