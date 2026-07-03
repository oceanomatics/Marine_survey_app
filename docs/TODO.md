# Marine Survey App — Master To-Do List

**Last updated:** 3 July 2026 — documentation-accuracy re-audit against actual code (see note below)  
**Note (3 July 2026):** The "1 July 2026 — added attendance reorder, EXIF photo assignment, section sub-paragraphs" line above was aspirational and never followed through — verified against code: attendance reorder and section sub-paragraphs are still NOT implemented (§3.1, §2.12); only EXIF *capture* (not attendance auto-assignment) exists (§3.2). Several other items in this file were also found stale in both directions (marked done when missing, and vice versa) and have been corrected below with file pointers.  
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
- [✓] Sign-Off UI screen: drawn signature (touch, `CustomPaint`) / PNG upload (desktop) — **DONE** (`lib/features/reports/widgets/sign_off_sheet.dart` — `_SignaturePad`/`_SignaturePainter` for drawing, `_uploadPng()` for PNG upload, uploaded to `exports` storage bucket)
- [ ] Notification to reviewing surveyor when attending surveyor submits for QC — **MISSING** (confirmed: no email/notification/push code anywhere in `lib/features/reports/`, `lib/core/services/`, or `supabase/functions/` — only `supabase/functions/case-analyst` exists, unrelated)
- [✓] Surveyor declaration text embedded in sign-off block — **DONE** (`sign_off_sheet.dart:441` — "By signing, I confirm that the professional opinions and…")

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
- [✓] Gate export on: all AI-generated sections having a `surveyor_review` value set — **DONE** (`lib/features/reports/widgets/export_button.dart:48-53` — `aiReviewBlocked`/`aiUnreviewedCount` hard-disables the export button, label changes to "AI review required (N)")

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
- [✓] Distinct visual cover page design: vessel name in large coloured title band, status badge, vessel cover photo, 2-column info box — **DONE** (`lib/features/reports/services/docx_export_service.dart:197-259` — `doc.addShadedBlock()` for the vessel-name band and the status-colour badge (green/blue/amber by output type), `coverPhotoBytes` image, `doc.addTable(infoRows, ...)` 2-column info box). **Caveat:** firm logo is NOT placed on the cover page itself — only the firm name as text (line 190-194); the logo image is only embedded in the body running header (see §2.8)
- [✓] Running header on body pages (2+): logo + right-aligned title text + rule — **DONE** (`lib/core/docx/docx_builder.dart:94-112` `setBodyHeader()`; `lib/core/docx/ooxml_helpers.dart:355-419` `_bodyHeaderXml()` — inline `w:drawing` logo, `w:tab w:val="right"` tab stop for title, `w:pBdr` bottom rule in primary colour)
- [✓] No running header on page 1 (cover) — **DONE** (`lib/core/docx/ooxml_helpers.dart:450-454` — `w:titlePg` + separate empty `header1.xml` for the first page vs. `header2.xml` for body pages)

**Spec:** §1.2.1, §1.2.2, §4.2

### 1.7 Export Validation Gate
- [✓] Hard-blocks Final export if dual sign-off incomplete — **DONE** (`export_button.dart:43-53` `signOffBlocked`)
- [✓] Hard-blocks export if any AI-drafted section lacks surveyor review — **DONE** (see §1.3 above, same file)
- [✓] Full validation checklist before export — **DONE 3 July 2026** (`lib/features/reports/utils/export_validation.dart` `buildExportWarnings()`): checks sections approved, Advice Summary confirmed (§2.6), Vessel's Particulars / Occurrence / Waiver sections non-empty, Damage Description non-empty when damage items exist, and Cause Consideration non-empty when an allegation has been recorded. Deliberately conservative (only checks that should never legitimately false-positive across report types) — cost-total and full mandatory-section-per-report-type modelling deferred as lower value / higher false-positive risk.
- [✓] User-friendly error summary sheet — **DONE** (`export_validation_sheet.dart` `showExportValidationSheet()`) — replaces the old two sequential ad hoc `AlertDialog`s with one consolidated checklist dialog listing every warning, "Cancel" / "Export anyway".

**Spec:** §5.4

---

## PHASE 1 — Report Builder: Tier 2 (Full Feature Parity with Spec)

### 2.1 Account Branding Configuration
- [✓] `OrganisationModel` with full fields: firm identity, ABN, address, contact, logo path, primary/secondary colour, all 4 WP text blocks, disclaimer, waiver — **DONE** (`lib/features/settings/models/organisation_model.dart`)
- [✓] `SurveyorProfileModel` with name, title, qualifications, signature storage path — **DONE**
- [✓] Organisation list screen + detail screen (3-tab: Identity / Legal Text / Surveyor Profiles) — **DONE** (`lib/features/settings/screens/`)
- [✓] Docx export reads all branding from org config — zero hardcoded values — **DONE**
- [✓] `org_id` on `CaseModel`, resolved at report build time — **DONE**
- [ ] Logo file upload to Supabase Storage in org detail screen — **MISSING** (confirmed: `organisation_detail_screen.dart:254-255` only shows instructional text — "Place your logo file at org-assets/&lt;org-id&gt;/logo.png in Supabase Storage for now" — no actual file picker/upload widget)
- [ ] Colour picker UI (currently text hex fields only) — **MISSING** (confirmed: `_ColourField` in `organisation_detail_screen.dart` is a plain hex `TextField`, no swatch/picker widget)
- [✓] Logo embedded in running header of body pages — **DONE** (see §1.6/§2.8 — logo fetched from `organisation.logo_path` in `docx_export_service.dart:44-51` and rendered via `DocxBuilder.setBodyHeader()`)

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
**Re-verified 3 July 2026: confirmed still fully missing.** `PhotoModel` (`lib/features/photos/models/photo_model.dart`) only has `caption` and `allocation` — no location/direction/significance fields; no "photo register" or "Annexure E" reference anywhere in the codebase.
- [ ] Add photo metadata fields: location/component, direction/context, significance-to-claim
- [ ] Build photo register table (Photo No. | Location | Direction | Date | Significance) as Annexure E opener
- [ ] Thumbnails at ~120px wide in register; full-size captioned photos follow
- [ ] Caption format: `[Photo N] — [component/location] — [direction/context] — [date] — [significance]`

**Spec:** §4.8

### 2.5 Report Version Numbering (R001, R002…)
- [✓] `sequenceNo` int on `ReportOutput`; `versionString` computed as `R001` format — **DONE**
- [✓] Auto-increment picker in `new_output_sheet.dart` — **DONE**
- [ ] Final Report "this report supersedes all prior…" narrative statement — **MISSING** (only a `Supersedes` column value in the table below, no prose statement)
- [ ] Progress/Supplementary "this report supplements Report [R00N]…" narrative statement — **MISSING** (same as above)
- [✓] Version Control Block showing document management history (version, date, type, "changes from previous" field) — **DONE** (`docx_export_service.dart:305-336` — "DOCUMENT CONTROL" table with Version/Date/Type/Supersedes/Changes columns, from `report_outputs.supersedes_version`/`changes_summary`); **note:** "attending surveyor" column is not included, only version/date/type/supersedes/changes

**Spec:** §4.9, §7

### 2.6 Advice Summary Editor Screen
**Built 3 July 2026** (same session as the re-verification above that confirmed it was missing).
- [✓] Structured fields on `report_outputs` (per-report, not per-case — status/cost legitimately change across successive reports): nature_of_casualty, description_of_damage, nature_of_repairs, status_of_repairs(+detail), cost_amount/currency/inclusions, fee_reserve hours+expenses, follow_up_required(+detail), remarks, confirmed — **DONE** (`docs/migrations/014_advice_summary.sql`, `ReportOutput` fields in `report_provider.dart`)
- [✓] Auto-populate read-only fields from case/vessel/occurrence data (vessel, IMO/flag, report type/no., tech file no.); allegation status reused from the existing Cause Consideration `allegation_type` rather than re-entered — **DONE** (`advice_summary_card.dart`). Also: "UCR / Reference" deliberately has **no** separate `advice_*` column — an `advice_ucr_reference` field was added then dropped in this same session on realising `cases.claim_reference` (already editable in Edit Case Details, e.g. "GARD-2025-0123456") is the same concept; the Advice Summary just displays it read-only. This also resolves TODO.md's old open question about a `policyUcr` field — it doesn't need to exist separately (see §2.10 below).
- [✓] Editor UI — **DONE**, but as a card in the existing Report Builder Editor tab (`AdviceSummaryCard` in `advice_summary_card.dart`, wired into `report_builder_screen.dart` above the section list) rather than a separate tab — simpler integration, same "Page 2" concern per decision D1.
- [✓] Rendered as a formal 2-column table in both the docx export and the Preview tab, sharing row-building logic via `advice_summary_rows.dart` (avoids the renderer-drift class of bug in gap #5) — **DONE** (`docx_export_service.dart`, `report_preview.dart`)
- [ ] AI draft for narrative fields (description of damage / nature of repairs) — **MISSING**, deliberately deferred; fields are plain surveyor-entered text for now.
- [✓] Gate export on Advice Summary confirmed — **DONE**, as a soft (dismissible) warning dialog matching the existing "not all sections approved" pattern, not a hard block — `export_button.dart`.

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
- [✓] Section 17: Documents Requested — **DONE** (`SectionType.documentsRequested` exists in `report_provider.dart:69`, editable text section built at `report_provider.dart:1019-1024`, rendered in `docx_export_service.dart:918` as "DOCUMENTS REQUESTED")
- [ ] Section 18: Principal Dates (milestone timeline events) — **MISSING, and deliberately so** — `report_provider.dart:70-71` has a code comment: "§18 Principal Dates — not implemented; the Chronology auto-table (built from `timeline_events`, see §7) covers this in practice." Not an oversight; a conscious design call. Revisit only if a dedicated milestone view is actually needed.
- [✓] Annexures A–H sorted/formatted at export — **DONE, but only the fixed-letter model, not the dynamic one** — `docx_export_service.dart:958-982` groups `assembled.caseDocuments` by the manually-set `annexure_assignment` letter (A–I, I reserved for AI record), sorts alphabetically, and renders each as its own "ANNEXURE X" page-break section. **Nuance confirmed against `docs/report_builder_editor_notes.md`:** this is the simple fixed-letter allocation (surveyor manually tags each document A–I in the Document Vault), NOT the fully dynamic category-driven allocation + auto-generated cross-reference hyperlinks described in that notes file (§"Annexure allocation" / "Cross-references", still aspirational, not built) — do not treat the two as the same feature.

**Spec:** §4.1 (full section order)

### 2.8 Logo in Running Header
**Duplicates §1.6 / §2.1 — reconciled 3 July 2026: both items are DONE, not missing.**
- [✓] Embed firm logo as inline image in body-page header paragraph (NOT table cell) — **DONE** (`ooxml_helpers.dart:373-401` — `w:drawing`/`wp:inline` inside the header `<w:p>`, not a table cell)
- [✓] Right-aligned tab stop for title text: `[Vessel Name] — [Report Type] — [Claim Reference]` — **DONE, close variant** — `docx_export_service.dart:157-175` builds `headerRight` as `[jobNo] — [vesselName] — [reportTypeLabel]` (technical file no. instead of claim reference, since claim ref is already elsewhere on the cover), joined with the em-dash and right-tabbed via `ooxml_helpers.dart:412-418` (`w:tab w:val="right"`)

**Spec:** §1.2.2, §1.2.5

### 2.9 Table Row Break Prevention
- [✓] `cantSplit` applied to all table rows in `ooxml_helpers.dart` — **DONE**

**Spec:** §6.4

### 2.10 Case Header — Fields
- [✓] `instructingParty`, `instructingPartyRole`, `assured`, `baseCurrency`, `organisationId` on `CaseModel` — **DONE** (`lib/features/cases/models/case_model.dart`)
- [✓] `policyUcr` — **RECONCILED 3 July 2026, while building the Advice Summary (§2.6):** no separate field needed. `cases.claim_reference` (editable in Edit Case Details as "Claim Reference", e.g. "GARD-2025-0123456") already covers this exact concept — it's a single case-level UCR/claim-reference field, and building `AdviceSummaryCard` confirmed it's already surfaced in report output (now shown read-only in the Advice Summary table, see §2.6). Not building a second, differently-named field for the same data — **DONE** (`cases.claim_reference`, `edit_case_screen.dart`, rendered via `advice_summary_rows.dart`)

**Spec:** §2.1

### 2.11 Vessel Model — Statutory Fields
- [✓] All 12 fields (`official_number`, `class_status`, `construction_standard`, `registered_owner`, `last_drydock_date`, `last_drydock_yard`, `ism_incident_reported`, `class_incident_reported`, `psc_last_inspection`, `psc_last_result`, `pi_club`, `isps_status`) exist on `VesselModel` (`lib/features/cases/models/case_model.dart:459-582`, note: `VesselModel` lives in `case_model.dart`, not a separate file) and are rendered on the report cover/body (`docx_export_service.dart:387-390`) — **DONE for the data model.** UI coverage confirmed per-field:
  - `official_number`, `construction_standard`, `pi_club`, `ism_incident_reported`, `class_incident_reported`, `psc_last_inspection`, `psc_last_result`, `isps_status` — editable in `lib/features/vessel/screens/vessel_particulars_screen.dart` (**DONE**, 8/12 fields)
  - `class_status`, `last_drydock_date`, `last_drydock_yard` — editable in a separate screen, `lib/features/vessel/screens/vessel_compliance_screen.dart` (**DONE**, 3/12 fields)
  - `registered_owner` — **no editor UI anywhere** (grepped the whole repo — only appears in `case_model.dart`'s constructor/fromJson/toJson) — **MISSING** (1/12 fields, UI gap only)
- [✓] Document-level cert fields (`survey_cert_no`, `equipment_due`, etc.) remain in `certificates` table — **DONE** (per decision B3)

**Spec:** §2.2

### 2.12 Section Sub-Paragraphs (Oceanoservices format only)
**Re-verified 3 July 2026: confirmed still fully missing** — no sub-paragraph/child-section model, numbering scheme, editor UI, or TOC-indent logic found anywhere in `lib/features/reports/`. The "1 July 2026" header note claiming this was added is inaccurate (see top-of-file note).
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
- [✓] Discovered 2026-07-03 while building Phase 2 UI: the "REPAIR TIMES" table in `docx_export_service.dart` (and Clause I-1's guidance text) read from `assembled.repairRecords`, sourced from the `repair_records` table — which had **zero rows and no Dart model or screen writing to it at all**. Dead/legacy. — **FIXED** (landed in the same session, commit `481b196`): the table now reads `repairPeriodModels` and aggregates via `RepairPeriodModel.drydockDaysTotal`/`alongsideDaysTotal`/`ownerDaysTotal` (`repair_period_model.dart:212-228`), which sum the `repair_times` jsonb column keyed by occurrence/owner. `repairRecords` field and query removed entirely — confirmed no remaining references in any `.dart`/`.sql` file. See also gap #3 in `docs/report_builder_editor_notes.md` (already marked done there).
- [✓] Note: F-2/F-5 (services provided / hot work) were correctly placed on `repair_periods` during this same session, once this table confusion was caught — see `docs/legal_clauses.md` 2026-07-03 entry.

### 2.15 Documentation section: only 2 meaningful availability states, not 3
- [ ] The new case-home "Documentation" card (K-2, added 2026-07-03) wants three categories — enclosed in report / retained on file / requested — but `DocAvailability` only has `enclosed`/`requested`/`not_available`/`tbc`, i.e. no distinction between "enclosed in the exported report" and "retained on file but not enclosed". Currently both concepts collapse into `enclosed`, labelled "On File" in the summary card.
- [ ] If the distinction matters in practice, needs either a new `DocAvailability` value or a separate boolean (e.g. `included_in_report`) — not added now since it wasn't clear this distinction is actually needed day-to-day.

---

## PHASE 1 — Case Management Enhancements

### 3.1 Attendance Editor — Attendee Ordering
**Built 3 July 2026** (same session as the re-verification above that confirmed it was missing).
- [✓] Manual drag-to-reorder attendees within an attendance record — **DONE**, `ReorderableListView.builder` + drag handle in `edit_attendees_sheet.dart` (replaces the plain `Column` list)
- [✓] Persist order via `sort_order` int on `attendees` table — **DONE**, `docs/migrations/015_attendee_sort_order.sql`, applied
- [✓] Attendance list renders attendees sorted by `sort_order` — **DONE**, `.order('sort_order', nullsFirst: false)` in both `attendees_provider.dart` (editor) and `report_provider.dart`'s `assembledDataProvider` (report/docx) — falls back to the old fixed role-based sort only for legacy rows with no `sort_order` (shouldn't occur post-backfill)
- [✓] Default order: insertion order — **DONE**, migration backfills existing rows via `row_number() OVER (PARTITION BY case_id, attendance_id ORDER BY created_at)`; new attendees append at the end of their attendance (`AttendeesNotifier.addAttendee`)

### 3.2 Photo-to-Attendance Assignment (EXIF-based)
**Re-verified 3 July 2026: EXIF capture is genuinely done; auto-assignment is genuinely still missing.** The "1 July 2026 added EXIF photo assignment" header note conflates the two — only the capture half happened.
- [✓] Read `DateTimeOriginal` EXIF tag from each imported photo at import time; store as `taken_at` on `photos` table — **DONE** (`lib/features/photos/providers/photo_provider.dart` — uses the `exif` package (`readExifFromBytes`), reads `EXIF DateTimeOriginal` then falls back to `EXIF DateTimeDigitized`, stored on `PhotoModel.takenAt`)
- [ ] Auto-assign: after import, match `taken_at` against available attendance date ranges and set `attendance_id` automatically where unambiguous — **MISSING**: `attendanceId` on `PhotoModel` is only ever set by explicit caller context (e.g. the surveyor adding photos from within a specific attendance's gallery view, `photo_gallery_screen.dart`) — no date-range matching logic exists anywhere
- [ ] Conflict handling: if a photo timestamp falls in more than one attendance range (or in none), leave unassigned and flag for manual review — **MISSING** (no such logic exists, since there's no auto-matching to begin with)
- [ ] Manual assignment UI: unassigned photos surfaced in a review sheet; surveyor picks the attendance from a list — **MISSING** (no review-sheet-for-unassigned-photos feature found)
- [ ] Bulk auto-assign action: re-run the EXIF matching pass on demand (e.g. after adding a new attendance) — **MISSING**

### 3.3 Google Photos Integration — Photos Routed to Visit Date
- [ ] When photos are added to an attendance/visit, upload them to Google Photos and file them under an album named for that visit date (e.g. `"2026-06-28 — MV Surveyor — Attendance 1"`)
- [ ] Use `taken_at` (EXIF) as the photo date so Google Photos timeline reflects the actual survey date, not the upload date
- [ ] Requires Google OAuth + Photos Library API (`photoslibrary.appendonly` scope); reuse token store from §2.1 Google Workspace integration
- [ ] On upload failure, queue for retry and surface status in the photo gallery
- [ ] See also Phase 3 — Google Workspace integration (broader Drive/Gmail/Photos roadmap)

### 3.4 Documentation Section (Case Page) + Auto-Generated Document Request Email
- [✓] New case-page "Documentation" section/card summarising availability counts — **DONE** (`lib/features/cases/screens/case_home_screen.dart:789-795` `_SectionCard` + `_documentationContent()` at ~line 1701, showing counts for `enclosed` ("On File"), `requested`, `notAvailable` from `DocAvailability`). **Note:** per §2.15 (already correctly logged), this surfaces 2 meaningful states in practice, not the full 3-way "enclosed in report / retained on file / requested" split — that's a known, deliberately-deferred nuance, not a bug.
- [✓] Support free-form ad-hoc "requested" line items with no file attached yet — **DONE** (`lib/features/documents/providers/document_provider.dart` — `DocumentModel.filePath` is nullable (`hasFile` getter guards on it); a dedicated request-creation path around line 482 sets `availability: DocAvailability.requested` with an auto-set `requestedDate` and no file)
- [✓] Works both pre-survey and post-survey, not tied to a specific attendance — **DONE** (`documents` records are case-scoped, not attendance-scoped — no `attendance_id` FK on the documents model)
- [ ] Auto-generate an email listing all outstanding requested documents (to Owners/Repairers), from the same data — **MISSING, confirmed** (grepped for "document request"/"requestEmail"/"generateEmail"/"mailto" — no hits)
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

Answering the 15 questions from Spec §10.3 — **re-audited 3 July 2026 against actual code** (the 30 June re-audit below was itself stale in several places — corrected):

| # | Question | Current Answer |
|---|----------|---------------|
| 1 | Colours/fonts from config or hardcoded? | ✅ All colours from `OrganisationModel` — docx reads org config |
| 2 | Firm logo in running header on every page? | ✅ **CORRECTED** — embedded as inline `w:drawing` in `header2.xml` (`docx_builder.dart:94-112`, `ooxml_helpers.dart:373-401`), fetched from `organisation.logo_path` in Supabase Storage at export time |
| 3 | AI audit log (model_version, prompt_hash, prompt_text, ai_output_text, surveyor_review)? | ✅ `AiGenerationLogModel` + `AiLogService` + wired into `ClaudeApi` + per-section review UI |
| 4 | AI disclosure paragraph auto-generated from audit log? | ✅ **CORRECTED** — `docx_export_service.dart:281-292`, "AI USAGE DISCLOSURE" heading + paragraph rendered whenever `assembled.aiGenerationLog` is non-empty; snapshotted to `report_outputs.ai_log_snapshot` at export (`docx_export_service.dart:98-105`) |
| 5 | Advice Summary auto-populated and editable? | ❌ Confirmed still missing — no model or screen (see §2.6) |
| 6 | Chronology as formal table? | ✅ Rendered as formal Date\|Event table in docx |
| 7 | Cost section as formal accounts table + WP notation? | ✅ Fully assembled: repair docs + account lines + totals + WP cost notice |
| 8 | Sign-off block gating Final Report export? | ✅ **CORRECTED** — export gate exists (`export_button.dart`) AND sign-off UI screen exists with drawn signature + PNG upload (`sign_off_sheet.dart`) |
| 9 | Report version numbering (R001, R002…)? | ✅ `versionString` computed as R001 format; auto-increment picker in new output sheet |
| 10 | Document Vault tracks `annexure_assignment`? | ✅ Field exists on `DocumentModel`; badges on tile; editable in detail sheet |
| 11 | `cantSplit` on table rows? | ✅ Applied in `ooxml_helpers.dart` |
| 12 | WP in all four required locations? | ✅ All four locations rendered from org config (header/cover/cost/footer) |
| 13 | Cover page separate template (no running header on page 1)? | ✅ **CORRECTED** — `w:titlePg` + distinct empty `header1.xml` vs. body `header2.xml` (`ooxml_helpers.dart:450-454`) |
| 14 | Cover page: vessel band, status badge, info box, photo, logo? | ⚠️ **PARTIALLY CORRECTED** — vessel-name colour band, status badge, cover photo, and 2-column info table are all done (`docx_export_service.dart:190-259`); firm **logo** is not placed on the cover page itself (only firm name as text) — logo only appears in the body running header |
| 15 | Logo in header as inline image (not table cell)? | ✅ **CORRECTED** — see #2 above |

**Score: 13 / 15 done, 1 partial (#14), 1 missing (#5)** — the 30 June "9/15" count undercounted; most of the previously-listed gaps (cover page, running header, AI disclosure, sign-off UI) were actually completed in the same or a subsequent session but never checked off here. Genuine remaining gaps: Advice Summary (§2.6) and firm logo specifically on the cover page (§1.6).

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
