# Marine Survey App — Business & Technical Brief

**Prepared:** 8 July 2026, for use in an external session preparing presentation materials for survey companies, loss adjusters, and underwriters.
**Author context:** Pierre-Louis Constant, freelance marine surveyor (principal, ABL Group), sole developer.
**Purpose of this document:** a complete, honest snapshot of what the app currently does, what it doesn't yet do, and where it's heading — so presentation content doesn't overclaim or omit real strengths.

---

## 1. What This Is

A Flutter + Supabase platform built to replace a marine surveyor's handwritten field notes and manual Word-template report writing with a single structured workflow: capture survey data in the field (including offline, at sea or in a shipyard), build up vessel/damage/cost records as the case develops, and generate a fully branded, legally compliant Hull & Machinery survey report — with AI assistance throughout, but a complete human-reviewable audit trail behind every AI contribution.

It is currently a **single surveyor's field tool** first, with an AI case-analysis assistant and a sophisticated report builder as its two most developed capabilities. It is not yet a multi-company SaaS product (see §9, §11).

---

## 2. Current Deployment Status

- **Phase 1 — internal testing.** Single-user deployment for ABL Group (the author's own practice). Not yet sold or deployed to other survey companies.
- **Architecture is commercial-deployment-ready in principle** (Supabase backend, offline-sync design) but **multi-tenancy (separate companies/data isolation) does not exist yet** — see §9 and §11 for what's required before any external company could use it.
- Live real-world use: real cases, real client data, real Google Workspace integration (Drive/Gmail/Photos) tested against the author's own accounts.

---

## 3. Core Workflow (a survey job, end to end)

1. **Instruction received** → case created (technical file number, claim reference, vessel, survey type, instructing party/assured).
2. **Attendance** → surveyor logs each site visit (date, location, attendees present), captures data offline if needed.
3. **Field capture** → photos (camera or import), voice-dictated notes (on-device speech-to-text, routed by AI to the right section), quick-capture notes tagged by relevance.
4. **Technical record-building** → vessel particulars & certificates, occurrence & causation, damage register, repair periods, general services during repair.
5. **Financial record-building** → repair invoices imported and AI-parsed, apportioned line-by-line between Owners' account and Underwriters' account, multi-currency handled automatically.
6. **Communication & documents** → correspondence register (including direct Gmail import), document vault (certificates, class reports, service reports — with AI extraction of key data on import).
7. **Report drafting** → structured report builder, section-by-section, with AI-drafted narrative available per section (surveyor must review/accept/amend every AI contribution).
8. **Quality gate** → self-review → submit for QC → QC comments → approved.
9. **Dual sign-off** → attending surveyor and reviewing surveyor each sign (hand-drawn signature or PNG upload) — export is technically blocked until both are done for a Final report.
10. **Export & delivery** → native Word (.docx) document generated, branded, with all mandatory legal/compliance content embedded automatically.

---

## 4. Functional Modules

| Module | What it does (plain language) | Status |
|---|---|---|
| **Cases** | Job creation, listing, case "home" hub linking everything else | Fully built |
| **Vessel Particulars** | IMO, class, tonnages, dimensions, machinery specs, statutory dates — manual entry or AI-read from nameplate photos/class PDFs, plus a direct Equasis registry lookup | Fully built |
| **Survey (Occurrence/Causation/Damage/Repair)** | The technical backbone: what happened, alleged cause, itemised damage register, repair periods, nature of repairs | Fully built |
| **Accounts** | Repair invoice import (AI-parsed, multi-invoice PDFs auto-split), line-by-line apportionment (Owners vs Underwriters, betterment deductions), multi-currency via live FX rates | Fully built |
| **Attendances** | Log of every site visit — dates, location, attendees | Fully built |
| **Background** | Case narrative + "context cues" (tagged surveyor notes that feed the AI and the report) | Fully built |
| **Field Capture** | Quick Capture (route-tagged notes/photos), Voice Note (on-device dictation, AI-routed) | Functional; the dedicated document-scanning **Camera screen is a stub** |
| **Checklist** | Stage-based progress tracker (attendance / report stages etc.) | Fully built, but **100% manually ticked today** — see roadmap §12 |
| **Correspondence** | Email/letter register tied to the case file, with a Gmail message picker | Fully built |
| **Documents (Vault)** | Central repository for all case documents, with AI extraction, merge, and "requested but not received" tracking | Fully built — the largest single feature in the app |
| **Interviews** | Structured interview recording with parties (master, crew, etc.), on-device transcription | Fully built |
| **Parties** | Stakeholder/contact register (assured, owners, agents, class, P&I) | Fully built |
| **Photos** | Gallery with cropping/compression, damage-item linking, Google Drive/Photos import | Fully built |
| **Report Builder** | See §6/§7 below | Fully built, most sophisticated feature |
| **Settings** | Organisation branding/letterhead, surveyor profiles, AI usage/cost dashboard, speech-to-text settings | Fully built |
| **Timeline** | Auto-aggregated chronology (attendances, damage, notes) plus manual events | Fully built |
| **HSE** | Health & Safety records (JSEA, permits, toolbox talks) | **Placeholder only** — "Coming Soon" |
| **Timesheet** | Time tracking | **Placeholder only** — not started |
| **Unified inbox** | A planned single inbox view | **Stub** — distinct from the working Correspondence screen |

---

## 5. AI Capabilities

**Case Analyst** — an in-app chat assistant, one per case, built on Claude Haiku 4.5. It answers questions using a purpose-built context assembled server-side from the actual case data: vessel particulars, all occurrences and their causation, the full damage register (with unusual-cost flags), prioritised surveyor notes, and repair accounts with apportionment. Supports voice input. Every call is logged for cost tracking.

**Document & data extraction** — a broad set of AI-backed extractors (Claude Sonnet for heavier tasks): certificate data, equipment nameplate photos, vessel particulars from class-society PDFs, invoice data (including automatic splitting of multi-invoice PDF bundles), generic document classification, correspondence extraction, email classification, photo classification, voice-note routing, and document-scan corner/orientation detection.

**Narrative drafting assist** — AI can draft the prose for report sections (occurrence, causation, general services, previous works, extra expenses, other matters, etc.) from the structured case data, which the surveyor then reviews, amends, or authors themselves.

**Full AI audit trail** — every single AI call (prompt, response, model, token counts, SHA-256 hash of the prompt) is logged to a dedicated table. This is not a lightweight log — it is built specifically to satisfy **GPN-AI**, the Federal Court of Australia's April 2026 practice note on AI use in litigation-adjacent documents, and it feeds directly into the exported report as a dedicated annexure (see §6). This is a genuine differentiator: the report can show, section by section, exactly what AI contributed and that a human reviewed it.

---

## 6. Legal & Regulatory Compliance

This is one of the app's strongest and most developed areas — worth leading with in underwriter/loss-adjuster-facing material.

- **GPN-AI compliance (Federal Court of Australia, April 2026):** full AI generation audit log; an automatically-generated AI usage disclosure paragraph in the report body; a dedicated **Annexure I** built from the audit log showing every AI-assisted section; export is hard-blocked until every AI-drafted section has been explicitly reviewed (accepted / amended / surveyor-authored) by a human.
- **"Without Prejudice" language** is embedded programmatically in all four locations required by the report template (page footer, cover header, cover block, cost section), plus the formal closing waiver — pulled from firm-level configuration so it can never be silently omitted.
- **Dual sign-off gate:** Final report export is technically blocked unless both the attending surveyor and a reviewing surveyor have signed (drawn signature or uploaded PNG), each with a timestamped declaration.
- **Standard report disclaimer** (liability limitation, third-party-use restriction) rendered verbatim, with a firm-level override option, and a hardcoded ultimate fallback so it is never silently missing.
- **Allegation-of-cause handling:** the report automatically selects the correct legally distinct clause — "Owners allege that damage was caused by X" vs. the formal "no allegation made, position reserved Without Prejudice" clause — based on what's actually recorded on the case, never both, never neither.
- **Account approval language:** every approved invoice line automatically carries the correct "Sum Approved Without Prejudice" formal marker, plus context-appropriate approval/query/partial-approval wording depending on the actual assessment outcome recorded.
- **Clause library architecture:** all of this legal wording lives in a database table, not hardcoded — meaning the exact phrasing can be tailored per report format (the app already supports ABL, Nordic, and an in-house "Oceanoservices" format) without a code change. This is a meaningful selling point to survey companies with their own house style/template requirements.
- **Export Validation Gate:** before any export, the app runs a checklist (sections approved, Advice Summary confirmed, mandatory sections non-empty) and shows a consolidated warning list rather than letting an incomplete report go out silently.

---

## 7. Report Output

- **Three report types:** Preliminary Report, Advice, Final Report.
- **Formal status workflow:** Draft → Self Reviewed → Submitted for QC → QC Comments → Approved → Issued → Locked.
- **Output format:** native Word (.docx), built by an in-house OOXML document generator — no dependency on an external Word template file, which makes per-firm branding fully data-driven (logo, colours, letterhead text, all four legal-notice blocks).
- **Report structure:** distinct cover page (vessel photo, status badge, info table), vessel particulars, machinery/equipment, class & statutory certification, chronology (formal table), occurrence, causation, damage register, repair times, formal cost/accounts table (multi-currency, WP-noted), Advice Summary (structured, editable), general services & access, documents retained/requested, annexures A–I (A–H are case documents grouped by surveyor-assigned category, I is the AI audit record), sign-off block, disclaimer.
- **Version control:** auto-incrementing report numbers (R001, R002…), with a document-control table (version/date/type/supersedes/changes) tracking the report's own revision history.
- **Delivery:** platform-aware — native file save on desktop/mobile, browser download on web.
- **Not yet available:** PDF export (docx only, currently).

---

## 8. Data Inputs & Outputs

**Inputs**
- Manual structured entry: vessel/occurrence/damage/repair/accounts/parties data
- Photos: camera capture, gallery import, Google Drive import, Google Photos import
- Voice: on-device dictation (works offline, no cloud dependency) for notes, interviews, and chat with the Case Analyst
- Documents: PDF/image import with AI-assisted extraction (certificates, invoices, class reports, correspondence)
- Email: direct Gmail import into the correspondence register
- External vessel data: Equasis registry lookup by IMO number
- Live FX rates for invoice currency conversion

**Outputs**
- Branded Word (.docx) survey reports (Preliminary / Advice / Final)
- AI audit annexure (Annexure I) — compliance record of every AI contribution
- Case documents organised into a Google Drive folder structure per case (photos sorted by attendance, correspondence, collected documents, claim invoices, reports, HSE)
- Photo albums shared via Google Photos
- (Not yet built: standalone PDF output, auto-generated outstanding-document-request emails)

---

## 9. External Integrations

| Integration | Purpose | Status |
|---|---|---|
| Google Drive | Case document storage/backup, folder-picker import | Live, working |
| Gmail | Correspondence import and sending | Live, working |
| Google Photos | Shareable per-case photo albums | Live, working |
| Equasis | Vessel registry PDF lookup by IMO | Live, working, but screen-scrape based (comments in code note it as fragile/reverse-engineered — a genuine registry API would be more robust for scale) |
| openexchangerates.org | Live FX rates for multi-currency accounts | Live, working, requires an API key, degrades gracefully if unset |
| On-device speech-to-text (sherpa-onnx) | Voice dictation, works fully offline, no per-use cloud cost | Live on mobile/desktop; web has no equivalent yet |
| Claude (Anthropic) | Case Analyst chat, document extraction, narrative drafting | Live — Haiku 4.5 for chat, Sonnet for extraction/drafting |

All three Google integrations share a single OAuth consent flow.

---

## 10. Architecture (brief, for technical audiences)

- **Backend:** Supabase — Postgres, Auth, Storage, Edge Functions.
- **Offline-first:** local SQLite cache with a sync-status column per record (`synced` / `pending_upsert` / `pending_delete`) — data is shown immediately from local cache and synced to the cloud in the background. This matters operationally: surveyors work in shipyards and at sea with poor or no connectivity, and the app is designed around that reality rather than treating it as an edge case.
- **State management:** Riverpod, async-notifier pattern throughout.
- **Report generation:** in-house OOXML document builder (no third-party templating dependency).
- **Security posture today:** standard Supabase email/password auth, no SSO, no in-app role/permission system, no multi-tenant data isolation yet — appropriate for a single-firm deployment, **not yet appropriate to present as multi-company-ready** (see §11).

---

## 11. Known Limitations — Be Transparent About These

Useful to know explicitly before building presentation claims:

- **No multi-tenancy yet.** All data currently lives in one Supabase project with no organisation-level isolation (Row Level Security) or per-company access control. This is required before any second company could safely use the platform.
- **No role-based access control.** There is an organisation/branding model with named surveyor profiles, but it is not an access-control system — anyone with a login sees everything.
- **HSE, Timesheet, and unified Inbox are unbuilt placeholders**, not partial features — do not present these as available.
- **Document-scanning camera** (perspective-corrected scan capture) is a stub — photo capture itself works, but the dedicated scan-and-flatten workflow is not built.
- **No PDF export** — Word only.
- **No automated error/crash reporting** to the developer — issues currently surface only when the user reports them.
- **Equasis integration is a screen-scrape**, not an official API — functional but not guaranteed stable long-term.
- **AI cost attribution / usage billing per client** does not exist yet — required before AI costs can be fairly passed through or metered in a multi-company deployment.

---

## 12. Roadmap

### Near-term (completing the current phase)
- AI disclosure paragraph and Annexure I refinements, remaining report-builder compliance polish
- Photo register / Annexure E (photo metadata: location, direction, significance-to-claim)
- Auto-generated outstanding-document-request emails

### Commercial readiness (required before external company rollout)
- Multi-tenancy: `organisations` table, Row Level Security on all tables, per-org invite/onboarding, admin console
- AI cost attribution: per-org/per-case usage tracking and a billing-model decision
- Terms of service / data processing agreements per client, backup & export policy, destructive-action audit log

### Strategic / new initiatives (added 8 July 2026)

1. **Event-driven asynchronous background AI extraction & production manager.** Move from today's manual, on-demand AI extraction to an automatic pipeline: new documents/photos/notes trigger extraction as soon as they land, with a background job queue and a "production manager" view showing what's been processed, what's pending, and what's outstanding across a case — reducing manual "process this now" clicking and giving oversight of the AI pipeline itself.

2. **A companion app for managing a survey company** (one principal/manager overseeing multiple surveyors). Distinct from the current field-survey tool: job/case assignment across a team, workload visibility, cross-surveyor QC/report-pipeline oversight, and team-level KPIs. Builds on top of the multi-tenancy work above but adds an internal management hierarchy (manager vs. surveyor roles) rather than just company-to-company data isolation.

3. **General survey-status evaluation.** A completeness/health check per case: minimum information required to consider a survey "adequately progressed," with visible indicators for which sections are actually populated vs. outstanding — giving a surveyor or manager an at-a-glance read on how far along a case really is, beyond just the report-export checklist that exists today.

4. **Smart, partly-automated checklists.** Extend the existing (currently fully manual) checklist feature so items can tick themselves automatically once the underlying data condition is satisfied (e.g., "vessel particulars complete" ticks itself once the required fields are filled), while other items remain manually confirmed (e.g., "attended site"). Naturally builds on item 3 above — the same "is this section actually populated" logic drives both.

5. **Admin/finance module: surveyor logs, freelancer agreements, and external invoicing.** A proper admin section covering surveyor time/activity logging, storage and tracking of freelance work agreements, and outgoing invoicing to clients/survey companies — with potential integration into an accounting platform such as Xero. This significantly broadens the scope of the currently-unbuilt Timesheet placeholder into a full practice-administration capability.

6. **In-app "why this matters" explanations, front end and report.** Every data-entry section and every report section gets a short, clear explanation of why it matters from a marine-survey best-practice standpoint — not just what to enter, but why it's professionally/legally significant. Serves two purposes: ease of use for all surveyors, and self-training for junior or new surveyors who can learn good survey practice from the app itself. Much of the underlying "why" already exists as internal documentation (the legal clause rationale in `docs/legal_clauses.md`); this surfaces it in-app.

### Already-identified future items (carried forward)
- Native PDF export
- Voice transcription upgrade for interviews (AssemblyAI/Deepgram-style diarization — a genuine P&I product differentiator; Azure Speech considered for enterprise data-residency needs)
- Document scanner (camera-based perspective correction)
- P&I report format / policy-type support (currently H&M-focused)
- Automated error/crash reporting
- Instructing-party CRM linkage (currently free text, could become a proper contact record)
- Assured's invoice-relevance spreadsheet import, and AI-driven invoice line-item consistency checking against the full case record (flagging unsubstantiated or out-of-period claims before submission to underwriters)

---

## 13. Suggested Angles Per Audience (for presentation prep)

- **Survey companies:** operational efficiency (offline-first, voice dictation, AI-assisted drafting), consistent branded output, house-style-aware clause library, upcoming multi-surveyor management layer.
- **Loss adjusters:** full financial apportionment workflow (Owners vs. Underwriters, betterment, multi-currency), formal cost-table output with mandatory WP language, document/correspondence audit trail, upcoming invoice-consistency AI cross-check.
- **Underwriters:** the compliance story is the strongest asset — GPN-AI-compliant AI audit trail, mandatory dual sign-off, Without Prejudice language enforced in every required location, defensible clause-by-clause legal wording, export gates that make it structurally difficult to issue a non-compliant report.

---

## Backlog — to review (added 21 July 2026)

- **Stylus tool — review.** The stylus / handwriting-annotation capture path
  needs a proper review (relates to §17 in the walkthrough audit — the
  stylus/second-tablet hardware-integration question, currently deferred).
  Assess: what the stylus is meant to drive (annotating photos/plans, sketching
  damage, signing off), how well the current capture works on the tablet, and
  whether it needs a dedicated annotation surface.
- **Neater presentation tools.** Provide a cleaner set of presentation-mode
  tools for showing the app/reports to prospects (survey companies, loss
  adjusters, underwriters — see §13 above). Candidates to scope: a distraction-
  free "present this report" view, a demo/sample case with polished data, a
  one-tap PDF/preview share, and cleaner on-screen affordances for walking a
  client through the report front page (Advice Summary) and export.
- **Scan a screen / monitor (future).** Extend the document-scanner principle
  (capture → detect outline → dewarp → save to vault → queue AI extraction) to
  capture a *screen or monitor* — e.g. an ECDIS/engine-control/CCTV display or a
  laptop showing data. Same pipeline, tuned to detect a rectangular display
  (bezel/screen edges) rather than paper, and to handle glare/moiré. The native
  ML Kit document scanner is paper-tuned, so a screen mode likely wants the AI
  corner-detect path (DocumentScanner.flatten, prompted for a display) or a
  dedicated model. Requested 21 July 2026.
