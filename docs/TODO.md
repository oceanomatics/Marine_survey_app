# Marine Survey App — Master To-Do List

**Last updated:** June 2026  
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
- [ ] Add `reviewing_surveyor_id`, `signed_off_attending`, `signed_off_reviewing`, `signed_off_at` fields to `cases` table and `CaseModel`
- [ ] Build Sign-Off Block UI: two-column block (Attending Surveyor | Reviewed By), name/qualifications/date
- [ ] Add surveyor declaration text: *"I confirm that the professional opinions and technical findings in this report are my own and that all AI-assisted content has been reviewed and confirmed by me."*
- [ ] Block Final Report export unless both `signed_off_attending` AND `signed_off_reviewing` are `true`

**Spec:** §2.1, §4.10, §5.4

### 1.2 WITHOUT PREJUDICE — All Four Required Locations
Currently: WP flag exists on `RepairDocumentModel` but is **never rendered in report output**.

- [ ] Page footer (every page): passive notice — *"This report is supplied without prejudice to any or all parties involved and shall not be copied or passed on to third parties without the express permission of [Firm Name]. — Page N of Total"*
- [ ] Page 2 formal designation (before Advice Summary): standalone bold *"WITHOUT PREJUDICE"* + one-sentence explanation
- [ ] Cost summary: inline below each approved section — *"The above costs are approved without prejudice to Underwriters' rights and without admission of liability."*
- [ ] Waiver section (closing): full waiver paragraph from account branding `default_waiver_text`

**Spec:** §4.7, §8.3 — all four locations required even for Preliminary reports

### 1.3 AI Audit Log (GPN-AI Compliance — Federal Court of Australia, April 2026)
Currently: only `token_usage` table (cost tracking). **No compliance-grade log exists.**

- [ ] Create `ai_generation_log` Supabase table:
  ```sql
  log_id, case_id, report_section_id, model_version, source_doc_ids[],
  prompt_hash (SHA-256), prompt_text, ai_output_text,
  surveyor_review (reviewed_accepted | reviewed_amended | surveyor_authored),
  reviewer_user_id, reviewed_at, created_at
  ```
- [ ] Modify all `ClaudeApi` call sites to write to `ai_generation_log` after each response (model pinned, full prompt, full response, section id)
- [ ] Add per-section review UI in `section_editor.dart`: surveyor marks each AI-drafted section as `reviewed_accepted`, `reviewed_amended`, or `surveyor_authored`
- [ ] Gate export on: all AI-generated sections having a `surveyor_review` value set

**Spec:** §3.3, §8.1

### 1.4 AI Disclosure Paragraph + Annexure I (AI Audit Record)
Depends on 1.3 being done first.

- [ ] Auto-generate disclosure paragraph on export: lists sections where AI was engaged, model version, statement that surveyor reviewed all
- [ ] Auto-build Annexure I table from `ai_generation_log` (Report Section | AI Function | Model & Version | Source Docs | Surveyor Review Action)
- [ ] Lock both elements post-signing (cannot be edited after `signed_off = true`)
- [ ] Suppress Annexure I and disclosure if no AI was used (`all sections = surveyor_authored`)

**Spec:** §3.4, §3.5, §4.1 item 33

### 1.5 Cost Section Rendered in Report
Currently: `account_lines` and `repair_documents` exist but are **not assembled into the report output**.

- [ ] Fetch repair documents + account lines for case at export time
- [ ] Render formal accounts table: Item | Description | Invoice Ref. | Amount (currency) | Allocation
- [ ] Compute totals: Total Claim | Owner's Account | Subject to Adjustment | **GRAND TOTAL**
- [ ] Insert WP notation below summary (see §1.2 above)
- [ ] Currency from `RepairDocumentModel.currency`

**Spec:** §4.6

### 1.6 Cover Page as Separate Template
Currently: all pages rendered the same way; no distinct cover page.

- [ ] Modify docx export to detect page 1 and render separately
- [ ] Cover page elements:
  - [ ] Vessel name in large title band (`primary_colour` background, white bold text)
  - [ ] Report type/status band below vessel name (`secondary_colour` or dark charcoal)
  - [ ] Report status badge (PRELIMINARY=amber, PROGRESS=blue, INTERIM=grey-blue, FINAL=green, SUPPLEMENTARY=orange)
  - [ ] Vessel photograph (from Document Vault with `is_cover_photo = true`; if none, skip — no placeholder)
  - [ ] Bottom info box (2-column): Occurrence date+nature | Claim Reference / File No. / Report Version No.
  - [ ] Firm logo bottom left at `firm_logo_width_px`
  - [ ] **No running header on page 1**
- [ ] Body pages (2+): running header with logo (~33% size) + right-aligned title text + rule below; footer with WP notice + page N of Total

**Spec:** §1.2.1, §1.2.2, §4.2

### 1.7 Export Validation Gate
Currently: export proceeds regardless of completeness or review status.

- [ ] Before export dialog, validate and show checklist:
  - [ ] All mandatory sections non-empty
  - [ ] Owner allegation text ≠ surveyor opinion text (Final & Interim only)
  - [ ] Both sign-offs confirmed (Final only)
  - [ ] Cost total > 0 OR explicit "costs TBD" flag (Final only)
  - [ ] All AI audit log entries have `surveyor_review` set
  - [ ] Advice Summary has been confirmed
- [ ] Show user-friendly error summary for any failing checks
- [ ] Hard-block export for Tier 1 failures; soft-warn for Tier 2

**Spec:** §5.4

---

## PHASE 1 — Report Builder: Tier 2 (Full Feature Parity with Spec)

### 2.1 Account Branding Configuration
Currently: **entire section missing**. No org table, no branding config, no theme resolution.

- [ ] Create `organisations` Supabase table with full field set from §1.1:
  - firm_name, firm_address_*, firm_phone/email/website/abn
  - firm_logo_url, firm_logo_width_px
  - primary_colour, secondary_colour, accent_colour
  - body_font, heading_font (enum: Arial | Calibri | Helvetica)
  - report_footer_text, default_disclaimer_text, default_waiver_text, default_confidentiality_text
  - ai_disclosure_enabled, ai_disclosure_text_template
- [ ] Build Account Branding Settings UI in Settings module (logo upload, colour pickers, font selector, text editors for disclaimer/waiver/footer)
- [ ] Modify docx export to resolve **all** colours, fonts, and text from org config — zero hardcoded values
- [ ] Store `org_id` on case at creation; report builder fetches branding from that org
- [ ] Default Oceanoservices theme pre-populated: `#3D1A6E` / `#6A3D9A` / `#F0ECF7`, Arial

**Spec:** §1.1, §1.2, §9.4

### 2.2 Document Vault Enhancement
- [ ] Add `is_cover_photo` bool to `documents` table and `DocumentModel`
- [ ] Add `annexure_assignment` enum (A | B | C | D | E | F | G | H | I | None) to `documents` table
- [ ] Add `surveyor_confirmed` bool (default false; set to true when surveyor reviews AI extraction)
- [ ] Update DocumentVaultScreen: allow tapping a doc to mark as cover photo, assign to annexure, confirm AI extraction
- [ ] Report builder uses `annexure_assignment` to auto-sort documents into correct annexures

**Spec:** §5.3

### 2.3 Chronology as Formal Table
- [ ] In report assembly, render `TimelineEventModel` list as a formal two-column table (Date | Time | Movement/Event)
- [ ] Header row: `primary_colour` background, white text
- [ ] Alternating rows: white / `accent_colour` tint
- [ ] Events sorted ascending by date/time

**Spec:** §4.3

### 2.4 Photo Register + Annexure E
- [ ] Add photo metadata fields: location/component, direction/context, significance-to-claim
- [ ] Build photo register table (Photo No. | Location | Direction | Date | Significance) as Annexure E opener
- [ ] Thumbnails at ~120px wide in register; full-size captioned photos follow
- [ ] Caption format: `[Photo N] — [component/location] — [direction/context] — [date] — [significance]`

**Spec:** §4.8

### 2.5 Report Version Numbering (R001, R002…)
- [ ] Replace/augment `sequenceNo` (int) with formatted version string `report_version_number` (e.g. `R001`)
- [ ] Auto-increment on each new report created for a case
- [ ] Display in report header text and Advice Summary
- [ ] Final Report to state: *"This report supersedes all prior survey reports for this casualty…"*
- [ ] Progress/Supplementary to state: *"This report supplements Report [R00N] dated [date]…"*
- [ ] Enforce: Progress/Interim/Supplementary/Final must reference a prior report version

**Spec:** §4.9, §7

### 2.6 Advice Summary Editor Screen
- [ ] Create `AdviceSummaryModel` with fields: policy_ucr, assured, instructing_party, date_nature, damage_description_summary, probable_cause, repair_status, cost_claim, cost_owners, cost_adjustment, loh_implication (enum: Yes | No | TBD), outstanding_actions, remarks
- [ ] Auto-populate from case data on first build (AI draft for narrative fields)
- [ ] Build `AdviceSummaryScreen` for surveyor to edit and confirm
- [ ] Assemble as formatted section on Page 2 (after WP designation, before ToC)
- [ ] Gate export on Advice Summary having been confirmed

**Spec:** §2.17, §4.1

### 2.7 Missing Report Sections (10 sections not yet assembled)
Current state: 12 of 25 sections coded. Missing:

- [ ] Section 5: Machinery / Equipment Particulars (conditional on casualty type = machinery)
- [ ] Section 6: Class & Statutory Certification (aggregate from `certificates` table)
- [ ] Section 7: Available Information Sources (from documents with category = source doc)
- [ ] Section 12: General Services & Access (checklist — include if array non-empty)
- [ ] Section 15: Surveyor's Notes (assemble from `surveyor_notes` table, formatted)
- [ ] Section 16: Documents Retained on File (from Document Vault, formatted)
- [ ] Section 17: Documents Requested (new model needed)
- [ ] Section 18: Principal Dates (from `timeline_events` with milestone flag)
- [ ] Section 19: Waiver (from account `default_waiver_text` — always included)
- [ ] Annexures A, B, C, D, F, G, H (Cost Assessment, Invoices, Certificates, Incident Report, Third-party Reports, Correspondence, Prior Reports)

**Spec:** §4.1 (full section order)

### 2.8 Logo in Running Header
- [ ] Embed firm logo as inline image in header paragraph (NOT inside a table cell)
- [ ] Size to ~33% of `firm_logo_width_px`
- [ ] Right-aligned tab stop for title text: `[Vessel Name] — [Report Type] — [Claim Reference]`
- [ ] Ensure header row height accommodates logo without clipping

**Spec:** §1.2.2, §1.2.5

### 2.9 Table Row Break Prevention
- [ ] Apply `cantSplit = true` (or equivalent) to all table rows in docx output so header/content never splits across pages

**Spec:** §6.4

### 2.10 Case Header — Missing Fields
- [ ] Add to `cases` table + `CaseModel`: `technical_file_no`, `policy_ucr`, `instructing_party`, `instructing_party_role` (enum), `assured`, `policy_type` (H&M | P&I | Both), `date_of_first_attendance`, `survey_location`
- [ ] Add these fields to case creation / case editor UI
- [ ] Map `technical_file_no` → currently stored as `jobNumber` (possibly rename or alias)

**Spec:** §2.1

### 2.11 Vessel Model — Missing Statutory Fields
- [ ] Add to `vessels` table + `VesselModel`: `official_number`, `class_status` (enum: Classed | Conditional | Suspended | Not Classed), `class_conditions` (text), `construction_standard`, `registered_owner`, `last_drydock_date`, `last_drydock_yard`, `ism_incident_reported`, `class_incident_reported`, `psc_last_inspection`, `psc_last_result`, `pi_club`, `isps_status`
- [ ] Consider whether `survey_cert_no`, `equipment_due`, `hull_due`, `tailshaft_due`, `doc_issuer`, `smc_expiry` belong on vessel or in the `certificates` table (current architecture: `certificates` table — keep and aggregate)
- [ ] Add to Vessel Particulars screen (may warrant a 4th tab: "Statutory")

**Spec:** §2.2

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

---

## SPEC COMPLIANCE SCORECARD

Answering the 15 questions from Spec §10.3:

| # | Question | Current Answer |
|---|----------|---------------|
| 1 | Colours/fonts from config or hardcoded? | ❌ Hardcoded / absent — no branding config |
| 2 | Firm logo in running header on every page? | ❌ Not implemented |
| 3 | AI audit log (model_version, prompt_hash, prompt_text, ai_output_text, surveyor_review)? | ❌ Only token cost tracked; no compliance log |
| 4 | AI disclosure paragraph auto-generated from audit log? | ❌ Missing |
| 5 | Advice Summary auto-populated and editable? | ❌ No model or screen |
| 6 | Chronology as formal table? | ❌ Not rendered as table in report |
| 7 | Cost section as formal accounts table + WP notation? | ❌ Account lines not assembled into report |
| 8 | Sign-off block gating Final Report export? | ❌ No dual sign-off fields or validation |
| 9 | Report version numbering (R001, R002…)? | ❌ `sequenceNo` int exists; R-format string missing |
| 10 | Document Vault tracks `annexure_assignment`? | ❌ Field missing |
| 11 | `cantSplit` on table rows? | ❌ Not applied |
| 12 | WP in all four required locations? | ❌ Flag exists in DB; not rendered in report |
| 13 | Cover page separate template (no running header on page 1)? | ❌ All pages same |
| 14 | Cover page: vessel band, status badge, info box, photo, logo? | ❌ None of these |
| 15 | Logo in header as inline paragraph (not table cell)? | ❌ No header logo at all |

**Score: 0 / 15** — significant implementation work ahead before any report is production-ready.

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
