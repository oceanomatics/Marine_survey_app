# Marine Survey App — Delta Audit vs Report Builder Spec v1.0

**Audit date:** June 2026  
**Auditor:** Claude Code  
**Spec:** `docs/report_builder_specs`  
**Status of answers:** Questions below marked `> DECISION:` — answers added inline as user confirms

---

## SECTION A — Architecture & Priority Decisions

### A1. Session Priority Order
> **QUESTION:** For this afternoon's big coding session, what order do you want to tackle things?
> Suggested priority based on dependency chain:
> 1. AI audit log table + logging (unlocks GPN-AI compliance and disclosure paragraph)
> 2. WP notation in report output (all four locations)
> 3. Cost section assembled into report
> 4. Cover page as distinct template
> 5. Dual sign-off gate
> 6. Branding / org config
>
> Do you want to follow this order, or is there something more urgent (e.g. the cover page look matters more to you right now)?

> **DECISION (A1):** Suggested dependency-driven order — AI audit log → WP notation → Cost section → Cover page → Sign-off gate → Branding config.

---

### A2. Branding — Hardcode ABL Now or Build Config UI?
The branding config (colours, logo, firm name, waiver text) is a significant Tier 2 item. But it blocks cover page and WP text work.

Two options:
- **Option A (pragmatic):** Hardcode Oceanoservices / ABL branding as constants in the app now. Build the config UI later when multi-tenancy is needed. Gets cover page + WP working immediately.
- **Option B (correct):** Build the `organisations` table and branding config UI first, then cover page uses real data.

> **QUESTION:** Which approach? Option A (hardcode now, refactor later) or Option B (build proper config first)?

> **DECISION (A2):** Build `organisations` table + branding config UI first. Everything reads from DB from the start — no hardcoding.

---

### A3. WP & Disclaimer Text — Have You Written It?
The spec calls for specific legal text in four locations. Do you want to:
- Use the verbatim text from the spec (§8.3), or
- Paste your own firm-specific WP / disclaimer / waiver paragraphs?

> **QUESTION:** Do you have ready-made WP, waiver, and disclaimer text to paste in? Or should I draft from the spec wording and you'll review?

> **DECISION (A3):** Use spec draft text as the starting point for all four WP/waiver/disclaimer locations. Pierre-Louis will review and refine after the session.

---

## SECTION B — Data Model Changes

### B1. `technical_file_no` vs `job_number`
The spec uses `technical_file_no` (e.g. `24-0177`). The current codebase uses `job_number` / `jobNumber`. These appear to be the same thing.

> **QUESTION:** Should we rename `job_number` → `technical_file_no` everywhere (DB + Dart), or keep `job_number` as-is and treat the spec's `technical_file_no` as a synonym?

> **DECISION (B1):** Same thing — rename `job_number` → `technical_file_no` everywhere (DB column, Dart model, UI labels).

---

### B2. Reviewing Surveyor — Auth User or Free Text?
The spec requires a dual sign-off: Attending Surveyor + Reviewing Surveyor. Currently there is no reviewing surveyor on the case model.

Two options:
- **Option A (simple):** Add `reviewing_surveyor_name` (text) + `signed_off_reviewing` (bool) + `signed_off_reviewing_at` (timestamp). Name entered free-text on sign-off screen. Works for single-user deployment.
- **Option B (full):** Add `reviewing_surveyor_id` (FK to Supabase auth users). Reviewing surveyor must have a platform account and physically log in to sign. Requires multi-user setup.

> **QUESTION:** Option A (free text name, simpler) or Option B (platform user, proper multi-user)? For the current single-user ABL deployment, Option A is likely sufficient.

> **DECISION (B2):** There is already a Reviewer/QC field in the Parties & Stakeholders section. Link `reviewing_surveyor` to that existing party record rather than creating new fields. The sign-off timestamps (`signed_off_reviewing`, `signed_off_reviewing_at`) are still new fields on the case, but the name comes from the existing parties data.

---

### B3. Class & Statutory Certificate Fields
The spec lists many certification-level fields (`class_status`, `class_conditions`, `psc_last_inspection`, `last_drydock_date`, `ism_incident_reported`, `pi_club`, etc.) that currently live either nowhere or in the separate `certificates` table.

Options:
- **Option A:** Add them all to the `vessels` table and `VesselModel` (denormalized; simpler for report assembly)
- **Option B:** Keep in `certificates` table; aggregate at report-build time
- **Option C:** Some on vessel (class_status, class_conditions, psc, drydock, pi_club) + some in certificates (document-level: survey_cert_no, doc_expiry, smc_expiry)

> **QUESTION:** Which approach? My recommendation is Option C — put the "vessel condition" fields on `vessels` and keep document-level certs in the `certificates` table.

> **DECISION (B3):** Data collected at doc-vault import stays in the `certificates` table. Add a new **Certificates tab** on the Case Home screen (positioned above Attendance & Representatives). The tab shows a table of all certificates for the case with a data summary. Opening a certificate allows editing dates and fields not yet collected. No denormalization onto `vessels` — the report assembler reads from `certificates` at build time.

---

### B4. New Case Header Fields — Which Ones Now?
The spec adds 8 missing fields to the case header. In priority order:
```
technical_file_no  (already discussed in B1)
claim_reference    ← already exists ✓
policy_ucr         ← new (Lloyd's UCR)
instructing_party  ← new (underwriter/broker name)
instructing_party_role  ← new (enum)
assured            ← new (insured party name)
policy_type        ← new (H&M | P&I | Both)
date_of_first_attendance  ← new
survey_location    ← new
reviewing_surveyor_*  ← discussed in B2
```

> **QUESTION:** Do you want all of these added to the New Case / Case Editor screen now, or just the ones needed for the report cover page (`instructing_party`, `assured`, `policy_ucr`, `survey_location`, `date_of_first_attendance`)?

> **DECISION (B4):** Most "new" case header fields already exist in other parts of the app — use them directly rather than duplicating:
> - `instructing_party` → Underwriter/Insurer company in Parties & Stakeholders
> - `policy_type` → case type (H&M | P&I)
> - `assured` → Assured company in Parties & Stakeholders
> - `date_of_first_attendance` → initial attendance in Attendance & Representatives
> - `survey_location` → Attendance & Representatives section
> - `reviewing_surveyor` → Parties & Stakeholders Reviewer/QC (see B2)
>
> Genuinely new fields that need adding: `policy_ucr` (Lloyd's UCR reference) and formal `policy` details. The report assembler must know to pull from the correct linked tables rather than expecting everything on the `cases` row.

---

### B5. Existing Cases / Data Migration
When we add new nullable fields to existing tables (`cases`, `vessels`, `documents`), existing records will have `NULL` values. This means the cover page info box and vessel statutory section may be blank for existing test cases.

> **QUESTION:** Is that acceptable? Do you want to manually backfill any existing test case data, or is it fine to just start fresh on that data?

> **DECISION (B5):** NULLs are fine. Still in heavy development — no migration needed. New fields will be populated going forward through the UI.

---

## SECTION C — Report Output Decisions

### C1. Cover Page Template Approach
The docx export currently uses the `docx_template` package with `.docx` template files in `assets/templates/`. Building a true separate cover page has two options:

- **Option A:** Create a separate cover page template file (`template_abl_cover.docx`) with zones defined by content controls. Then merge cover + body into one docx at export. Complex but gives full Word-native formatting.
- **Option B:** Programmatically build the cover page as the first page of the existing template, using OOXML XML injection. More flexible but bypasses the template system.
- **Option C:** Build cover page using the `pdf` or `flutter_pdf` package as page 1 only, and keep docx for the rest. (Hybrid — complex.)

> **QUESTION:** Which approach? Option A (separate template) is cleanest long-term. Option B is faster to implement.

> **DECISION (C1):** ARCHITECTURAL SHIFT — Drop `docx_template` substitution approach entirely. Build the full docx **programmatically** (raw OOXML/XML in Dart, zipped as .docx). This gives complete control over layout including the cover page. Each organisation will get its own presentation config; for enterprise clients a separate template-creation tool may be needed later. The report builder is the authoritative document renderer — no external .docx template files.

---

### C2. AI Audit Log — Retrofit All Calls or Only Report Calls?
Currently Claude is called from:
1. `ClaudeApi` — document extraction, invoice extraction, report section drafting
2. `case-analyst` Edge Function — case Q&A via Case Analyst screen

The AI audit log (for GPN-AI compliance) technically needs to cover **all** AI calls that produce content in the report. The Case Analyst chat is interactive and probably out of scope for the formal audit log.

> **QUESTION:** Should the `ai_generation_log` table capture:
> - (a) All Claude API calls across the whole app, or
> - (b) Only calls that produce content that goes into a report section (extraction + report drafting)?
> My recommendation: (b) — the audit log is for report content only; the Case Analyst is a tool, not a report author.

> **DECISION (C2):** Report content only — document extraction calls and report-section drafting calls. Case Analyst is an interactive tool and is excluded from the formal audit log.

---

### C3. AI Prompt Storage — Privacy Consideration
The audit log spec requires storing the **full prompt text** per API call. These prompts contain real case data (vessel name, casualty details, surveyor notes).

> **QUESTION:** Are you comfortable storing full prompt text in the `ai_generation_log` Supabase table (same database as case data, subject to same RLS)? This is required for GPN-AI compliance but does increase the data footprint per case.

> **DECISION (C3):** Store full prompt text in `ai_generation_log`. Required for GPN-AI compliance. Protected by the same RLS policies as the rest of the case data.

---

### C4. Annexure I — Locked Snapshot or Live Query?
At export time, the AI Audit Record (Annexure I) must be locked after signing. Two approaches:
- **Option A:** At export, snapshot the `ai_generation_log` entries for this case into a JSON blob stored on the report output record. Annexure I always renders from that snapshot. Immutable.
- **Option B:** Always query `ai_generation_log` live. Lock the whole case (preventing log additions) after signing.

> **QUESTION:** Option A (snapshot into report record) or Option B (live query + case lock)?

> **DECISION (C4):** Snapshot to JSON blob at export. At sign-off, all `ai_generation_log` entries for the case are snapshotted into a JSON field on the `report_outputs` record. Annexure I always renders from that snapshot — immutable.

---

## SECTION D — UX & Screen Layout Decisions

### D1. Advice Summary — Where in the App?
The Advice Summary needs to be auto-populated from case data and then editable by the surveyor. Options:
- **Option A:** New screen under Case Home (alongside Vessel, Damage, etc.) — "Summary" tile
- **Option B:** A section within the existing Report Builder screen (tab or dedicated section in the editor)
- **Option C:** Pop up as the last step before export (review and confirm before building the docx)

> **QUESTION:** Which home does the Advice Summary belong in? My recommendation: Option B — inside Report Builder as a tab, since it's a report-output concern, not a data-entry concern.

> **DECISION (D1):** Tab inside the Report Builder screen. Advice Summary is a report-output concern, lives alongside the other report section editors.

---

### D2. Sign-Off UX
Options for the sign-off interaction:
- **Option A:** Simple: checkbox "I confirm the above" + timestamp auto-set. Name taken from account profile.
- **Option B:** Typed name + date picker (surveyor types their name as a quasi-digital signature).
- **Option C:** Drawn signature (finger/stylus on tablet). More formal but complex to implement.

> **QUESTION:** Which sign-off UX? Note: for a Final Report going to underwriters, typed name + date is the minimum professional standard. Drawn signature would be better on an iPad.

> **DECISION (D2):** WORKFLOW CHANGE — Sign-off is a two-party review process:
> 1. Attending Surveyor finalises the draft → system sends automatic email (or in-app notification) to the Reviewing Surveyor.
> 2. Reviewing Surveyor reviews in-app → signs off with:
>    - **Touch device (tablet/phone):** drawn signature captured in-app.
>    - **Desktop/PC:** upload a PNG of their signature.
> 3. Both signatures (attending + reviewing) are embedded in the report's sign-off block.
>
> Implication: need a `review_status` field on the report, a notification trigger (Supabase Edge Function or email), and a signature-capture widget (draw + PNG upload). Drawn signature stored as base64 image in Supabase.

---

### D3. Document Vault — Cover Photo & Annexure Assignment UI
For the Document Vault new fields (`is_cover_photo`, `annexure_assignment`, `surveyor_confirmed`):
- Tapping a document → opens existing detail sheet → adds a section for "Report Metadata" with cover photo toggle, annexure picker, and confirmed checkbox?
- Or inline chips/icons on the vault list tile?

> **QUESTION:** Where should annexure assignment and cover photo tagging live in the Document Vault UI? Inline on the tile, or in the document detail sheet?

> **DECISION (D3):** PHOTO-CENTRIC APPROACH — Cover photo and annexure allocation are managed through the Photo Gallery, not the Document Vault:
> - **Cover photo:** The Vessel Particulars screen selects a "general vessel picture" → this sets `is_cover_photo` on the `photos` table. A cross-connection pill/badge in the Photo Gallery shows the cover photo status.
> - **Annexure allocation for photos:** The existing allocation scheme in the Photo Gallery section manages this. The allocation menu needs improvement — more metadata fields per photo. When a photo is selected for a purpose from any front-end menu, the photo gallery status is updated.
> - **Document annexure assignment (non-photo):** Editable in the document detail sheet (rename "Edit Metadata" to something clearer). Also displayed as an annexure pill/badge on the vault list tile. Suggested automatically based on the document category. "None" = explicitly excluded from the report. Both read/write paths must sync.

---

### D4. General Services & Access — Checklist or Free Text?
The spec lists "General Services & Access" as a conditional section (include if non-empty). Current checklist module exists but is generic.

> **QUESTION:** Should General Services be a fixed checklist (e.g. Staging | Lighting | Ventilation | Cranage…) with tick boxes, or a free-text section where the surveyor types what services were provided?

> **DECISION (D4):** Checklist + free-text notes per item. Context cues extracted from imported documents (reports, emails, invoices) are surfaced under each pre-populated checklist item automatically. If no pre-defined item matches the context cue, a new item is created. The surveyor can add, edit, or remove items freely.

---

## SECTION E — Workflow & Process Decisions

### E1. Report Version Numbering — Auto or Manual?
The spec requires R001, R002… incremented per new report created for a case.

> **QUESTION:** Should the version number auto-increment every time "New Report" is pressed, or should the surveyor be able to set/override it? (Auto-increment is simpler and safer.)

> **DECISION (E1):** Auto-increment only. R001, R002, … incremented automatically each time "New Report" is pressed for a case. No manual override.

---

### E2. Progress/Supplementary Reports — Reference Prior Version?
The spec requires that Progress, Interim, Supplementary, and Final reports reference the prior report version. This means the UI must let the surveyor select "this report supplements R001 dated [date]".

> **QUESTION:** Should this be a dropdown showing prior reports for the same case, or free text? And do you want this enforced at export (must have a prior report selected before export of Progress/Final)?

> **DECISION (E2):** Auto-reference the immediately preceding version (no UI choice). Additionally, the Report Builder must include a **Version Control Block** showing the document management history (version, date, type, attending surveyor) and a brief "Changes from previous version" summary field editable per new version. This acts as a document changelog embedded in the report.

---

### E3. Without Prejudice — Exact Spec Text or Your Text?
The spec provides draft WP text for all four locations. Do you have your own firm-approved wording, or shall I implement the spec text verbatim and you'll edit from there?

> **QUESTION:** Use spec draft text as starting point (you'll edit after), or paste your own now?

> **DECISION (E3):** Use spec draft text verbatim as the starting point for all four WP/waiver/disclaimer locations. Pierre-Louis will review and replace with ABL-approved wording after seeing it in context.

---

### E4. Cost Section Currency
The `account_lines` module uses per-document currency (from `RepairDocumentModel.currency`). If a case has invoices in AUD, SGD, and USD, the cost section needs a base currency and exchange rates.

> **QUESTION:** For the initial report builder, is it acceptable to assume a single currency per report (the most common one in the account lines), or do you want multi-currency handling with exchange rates from day one?

> **DECISION (E4):** Full multi-currency with automatic FX:
> - Base reporting currency set at **case level** (in Edit Case Details).
> - Each invoice stores its original currency. FX rate fetched automatically from an external API at the **invoice date**.
> - The Accounts section UI shows: `[Case currency amount] ([original amount] [invoice currency])`.
> - The report cost table presents all amounts in the case base currency, with original currencies shown per line.
> - FX rates stored per invoice (not recalculated at report time — locked to invoice date rate).

---

## SECTION G — Organisations Config Decision

> **DECISION (G2 — Org selection in app):** Org format selection lives in "Edit Case Details" alongside the case currency. Set at case creation, changeable until first export.
>
> **DECISION (G3 — FX source):** Open Exchange Rates API (openexchangerates.org) free tier — daily rates, historical date lookup for invoice-date FX. API key stored in Supabase Vault / env.
>
> **DECISION (C1 addendum — Docx engine):** Build a thin in-house OOXML builder in Dart. Assembles `document.xml`, `styles.xml`, `relationships`, etc. and zips as `.docx`. Lives as a module inside the project (`lib/core/docx/`). No external docx dependency.

---

> **DECISION (G1):** All four org config field groups are in scope for v1:
> 1. **Firm identity:** name, ABN, address, contact details (appear on cover page and header)
> 2. **Branding:** logo file (Supabase Storage), primary colour, secondary colour
> 3. **Default WP/waiver/disclaimer text blocks** (four blocks, editable per org)
> 4. **Surveyor profiles:** name, title, qualifications — but **signature is NOT pre-stored**.
>
> **Signature design (deliberate):** Signature is captured at the moment the report is completed — not pre-loaded from a profile. This ensures the surveyor consciously reviews and endorses the AI-generated output before signing. The signature capture widget (drawn on touch / PNG upload on desktop) appears at sign-off time only.
>
> **Freelance/multi-org override:** Each case carries an `organisation_id` FK. Default = surveyor's own org (Oceanoservices/ABL). When doing freelance work for another firm, the surveyor selects that firm's org config on the case — their branding, WP text, and header are applied to that report. The `organisations` table therefore acts as a "format profile" store supporting multiple clients from day one, not just the surveyor's own firm.

---

## SECTION H — Infrastructure & Integration Decisions

> **DECISION (H1 — DB migrations):** No migration files. SQL is provided in the chat (during the session) and applied directly in the Supabase dashboard SQL editor. I'll write each migration as a runnable SQL block with clear comments.

> **DECISION (H2 — Interview module → Report):** Interview module stays in its own silo for now — no wiring to the report builder in this session. Also: check interview data for consistency with other case data.
>
> **Future architecture (logged for later):**
> 1. Interview captures audio recordings.
> 2. Recordings transcribed to text via STT (see Voice/STT memory — platform STT / AssemblyAI).
> 3. AI analyses transcription → extracts context cues tagged by report section.
> 4. Context cues suggested to the surveyor in the relevant section editors.
> 5. **Context Cue Manager needs architectural review** — cues may be relevant to multiple sections simultaneously; the current single-allocation model needs extending.

---

## SECTION F — Spec Compliance Scorecard
*(Answers at audit date — update as items are implemented)*

| # | Spec Requirement | Status | Target Phase |
|---|-----------------|--------|-------------|
| 1 | Colours/fonts from branding config | ❌ Hardcoded | Phase 1 Tier 2 |
| 2 | Firm logo in running header | ❌ Missing | Phase 1 Tier 2 |
| 3 | AI audit log (full fields) | ❌ Missing | Phase 1 Tier 1 |
| 4 | AI disclosure paragraph auto-generated | ❌ Missing | Phase 1 Tier 1 |
| 5 | Advice Summary auto-populated + editable | ❌ Missing | Phase 1 Tier 2 |
| 6 | Chronology as formal table | ❌ Not in report | Phase 1 Tier 2 |
| 7 | Cost section as formal table + WP | ❌ Not in report | Phase 1 Tier 1 |
| 8 | Sign-off block gating Final export | ❌ Missing | Phase 1 Tier 1 |
| 9 | Report version R001/R002 | ❌ Missing | Phase 1 Tier 2 |
| 10 | Document Vault: annexure_assignment | ❌ Missing | Phase 1 Tier 2 |
| 11 | cantSplit on table rows | ❌ Missing | Phase 1 Tier 2 |
| 12 | WP in all four locations | ❌ Flag exists, not rendered | Phase 1 Tier 1 |
| 13 | Cover page separate from body | ❌ Missing | Phase 1 Tier 1 |
| 14 | Cover page all five required elements | ❌ Missing | Phase 1 Tier 1 |
| 15 | Header logo as inline paragraph | ❌ Missing | Phase 1 Tier 2 |
