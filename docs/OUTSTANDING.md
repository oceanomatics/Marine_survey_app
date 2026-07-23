# Outstanding — clean to-do list

**Compiled:** 23 July 2026, from `FINDINGS_CLOSEOUT_2026-07-21.md` (code-verified),
`docs/last_entry` (the last request before the overnight interruption), and the
open items in `docs/TODO.md`.

**Context:** the backlog is overwhelmingly built and committed. The house-style
table lead-ins (the interrupted 22 July session) are now finished and committed
(`2bd5e21`); migration 063 is live. What follows is everything that is *actually*
still open.

**Verification pass (23 July):** §1–§2 were re-checked against current source via
three parallel code reads. Result: the Certificates + Class merge (§1) and the
Advice Summary (§2.6) were both listed as open but are in fact **already built** —
corrected below. Only the Equasis PSC deficiency extraction (§1) and the
cover-page logo (§1.6) survive as genuine report-builder gaps. **Offline mode**
(§9) was also verified: effectively unbuilt beyond a foundation — full detail there.

---

## 1. Certificates + Class & Statutory merge — BUILT; residual = Equasis PSC extraction

**Verified 23 July against current code — the merge from `docs/last_entry` is
already built.** `lib/features/vessel/screens/vessel_compliance_screen.dart` is a
single "Certificates & Class" screen (routed from Case Home), containing every
requested section. Present today:

- ✅ Certificates list, Doc-Vault-linked, add inline (`CertificateCard` +
  `AddCertificateSheet`).
- ✅ Conditions of Class as an add-item with **all** requested fields — reference
  number, description, expiry date, "related to an occurrence" tick, occurrence
  dropdown (choices = case occurrences). Backed by `class_condition_model.dart`
  (`occurrence_related` / `occurrence_id`).
- ✅ Incident block — primary occurrence + "reported via ISM" (y/n) + "reported to
  Class" (y/n), including the CoC-issued ⇒ reported-to-Class heuristic nudge.
- ✅ PSC deficiency list — UI + storage (`psc_deficiencies` table) exist.

**Residual open items (the only real work left here):**

- **PSC deficiency auto-extraction from the Equasis report** — the deficiency list
  is **manual entry only**; `equasis_service.dart` returns the ship-folder PDF but
  parses no deficiencies. The screen itself flags this ("auto-populate is a
  follow-up"). *This is almost certainly what the `last_entry` note meant by its
  trailing "the data extraction is not…".* — **largest genuine piece.**
- **Delete the orphaned `certificates_screen.dart`** — a standalone
  `CertificatesScreen` still exists but is unreferenced dead code, superseded by
  the merged screen. Its "Total / Valid / Expiring / Expired" status-summary
  banner was *not* carried into the merged screen — port that first if the
  presentation is wanted, then delete.
- Cosmetic: CoC description is `maxLines: 3`, `last_entry` said "2-line" — trivial.

> Open question **Q2** (certificates in own table vs. denormalised) is effectively
> **resolved by the build** — certs stayed in their own table.

---

## 2. Genuinely missing report-builder features

- **§1.6 / scorecard #14 — firm logo on the cover page.** *(Verified 23 July: still
  open.)* Logo embeds only in the page-2+ running header
  (`docx_export_service.dart:210-215`); the cover page shows the firm name as
  centered text only. Everything else on the cover — vessel band, status badge,
  info box, cover photo — is done.

> **Removed after 23 July verification:** ~~§2.6 Advice Summary editor~~ — this was
> listed as missing but is in fact **fully built** (model with 16 `advice*` fields,
> `advice_summary_card.dart`, migration 014, auto-population, AI ✨ drafting,
> preview + docx render, export-gating, tests). The "missing" label was a stale
> scorecard row (`TODO.md:1249`) contradicting §2.6's own "Built 3 July" header.

---

## 3. Blocked on external config (not code)

- **Google Sign-In `ApiException: 10`** — register package
  `com.example.marine_survey_app` + the debug SHA-1 as an Android OAuth client in
  the Google Cloud Console. Runbook: `docs/google_signin_setup.md`. This gates the
  live re-test of **Drive photo sync, Gmail/Correspondence, and Action Items**.

---

## 4. Deferred by the surveyor — do NOT build unilaterally

- **§6 Causation** — second pass.
- **§17 STT** — vendor choice + stylus / second-tablet support.
- **§20 HSE module.**

---

## 5. Sequenced for later (deliberate "build Oceano first, remap later")

- **Per-format section machinery for Nordic / ABL / Marsh** — ordered section
  lists + format-specific wording branches. Only the Oceanoservices canonical
  order exists today; drafting prompts take `reportFormat` as a label
  substitution. This is the planned remap step, not a gap.

---

## 6. Data hygiene & verification

- **HSE docs PII scrub** — the 17 ABL documents under `docs/HSE docs/` carry real
  staff PII and remain **deliberately uncommitted** pending a scrub / hosting
  decision. (Also excluded from the repo by design.)
- **On-tablet live verification** — everything since 16 July is *code-verified
  only*. Walk `docs/WALKTHROUGH_RECENT_MODS_2026-07-16.md` on the device.
- **Multi-tenancy / RLS** — built and live-verified via simulated JWTs across 58
  tables, but **not yet exercised against the real running app**; `connected_accounts`
  is built but not wired into `google_auth_service`.

---

## 7. Open questions / decisions needed

| # | Question |
|---|----------|
| Q1 | `technical_file_no` vs `job_number` — same field or distinct? |
| Q2 | Class/stat cert data: keep separate `certificates` table (current) or denormalise onto the vessel model? *(gates the §1 merge above)* |
| Q3 | Who is the "reviewing surveyor" — another platform user, or just a name + signature? |
| Q4 | Cover page: `docx_template` package or raw XML — can it handle two templates per export? |
| Q5 | SHA-256 prompt hashing — before or after variable substitution? |
| Q6 | Annexure I (AI Audit Record) — locked snapshot in Supabase, or always regenerated from `ai_generation_log`? |
| Q7 | EXIF photo assignment — device-local `taken_at` or server receipt time as the fallback when EXIF is absent? |

---

## 8. Future roadmap (Phase 3/4 — not scheduled)

- **§4.1** Event-driven background AI extraction & production manager.
- **§4.2** Survey company management app (one manager, multiple surveyors).
- **§4.5** Admin: surveyor logs, freelance agreements, external invoicing.
- **§4.8** Subscription / tenant management console (developer/vendor).
- **Accounts reconciliation** — design in `docs/accounts_reconciliation_spec.md`, not built.
- **Offline mode** — a real feature, not just roadmap. See §9 below.

---

## 9. Offline mode — needs full implementation

*(Verified 23 July against current code. The "partial" state seen on another
workstation is the pre-existing foundation, not the offline-case feature.)*

Design: `docs/offline_sync_plan.md` (8 steps). **Effectively unbuilt** — none of
the 8 case-snapshot steps exist. What's already there is only the reusable
foundation, which pre-dates the plan:

- ✅ **Write-queue vocabulary** (`pending_upsert` / `pending_delete`) — but only on
  the 3 legacy cache tables: surveyor_notes, photos, correspondence.
- ✅ **`connectivity_plus`** fully wired — `connectivity_service.dart` →
  `connectivityProvider`, with reconnect-and-flush in those same 3 providers.

**Remaining work (all 8 steps):**

1. DB migration (**v17**, not the plan's "v11") — `offline_cases` control table +
   ~19 `snap_*` snapshot tables. DB is currently at v16.
2. `OfflineCaseService` — `pinCase` / `unpinCase` / `syncCase` / `flushWriteQueue`.
3. `offlineModeProvider` (SharedPreferences `offline_mode`) + `offlineCasesProvider`.
4. **Provider routing retrofit** — every feature provider (cases, vessels,
   occurrences, damage, repairs, interviews, checklists, …) currently hardcodes
   `SupabaseService.client`; each needs an online/offline data-source switch.
   *Largest and most invasive step.*
5. Extend the `pending_*` write queue onto the new snapshot tables.
6. File download on pin — `documents` + `audio` Storage buckets → local `cases/{id}/`.
7. UI — pin button (case list/home), app-bar offline badge, Settings "Sync now" +
   manual toggle.
8. Conflict resolution (last-write-wins to start).

**Leverage:** the connectivity reconnect-and-flush pattern and the `pending_*`
status vocabulary are already proven in 3 providers — template them across the
new snapshot layer rather than inventing fresh.

---

## 10. Live-testing notes (23 July — tablet workflow, running list)

Captured from the surveyor's hands-on pass on the clean prod. Not yet
investigated/verified against code — triage later.

- **Start a case *from* an email.** Can't search for / pick an email to begin a
  case; had to enter the vessel name first to get through. Wanted flow: search
  the inbox, pick the originating email, pre-fill the new case from it. This is
  the office/desktop scenario and ties directly into the desktop-Gmail work (§2)
  — a case often starts from an instructing email at the desk.
- **Auto-generate email summaries.** Correspondence/email summaries should be
  produced automatically (AI), not on manual request. (Check whether the
  existing thread-summary / AI-task pipeline can run on inbound mail on import.)
- **Trials generated weirdly / not grouped by trial.** *(Term to confirm — likely
  "trials" = sea trials / the trials & tests area, `trials_tests` table.)* The
  generated trials output isn't grouped by trial — items appear flat instead of
  nested under their parent trial, **which makes the (trial) summaries awkward to
  read.** Fix the grouping key in the trials/tests data model + report/summary
  rendering. Relates to the DP FMEA / trials module work the dev box is picking up.
- **Correspondence pollutes the "important" timeline.** Correspondence events
  should appear only in the **full event log**, not the curated "important"
  timeline. Check the Timeline relevance filter (§3.16, `timeline_events` /
  `timeline_event_ratings`) — exclude the correspondence event type from the
  important view (or default its relevance below the important threshold).
- **AI extraction finds dates but doesn't create timeline events.** The extraction
  identifies dates in documents/correspondence but never turns them into
  `timeline_events`. Wire the extracted dates through to timeline-event creation
  (the extraction → timeline pipeline is the gap, not the date detection).
- **AI extraction finds attendance dates but doesn't create attendances.** Same
  pattern as above — correspondence extraction detects attendance dates but no
  `attendances`/`survey_attendances` record is created. **Root theme: extraction
  DETECTS entities but doesn't PERSIST them into their records** (timeline events,
  attendances — check others too). The write-back step of the extraction pipeline
  is the common gap. **→ Being addressed** (correspondence→structured import, see
  `docs/correspondence_extraction_spec.md`).
- **DIRECTIVE — extraction should split by target section from the start.** For
  BOTH correspondence and document extraction, tell the AI to identify background
  elements vs occurrence elements vs damage/other-section elements and split the
  content into those buckets up front, rather than summarizing and then trying to
  fit it into a section (which causes overspill, e.g. occurrence detail bleeding
  into Background). Partly started: `background_text` now fenced to pre-incident
  context only (commit on 23 Jul). Generalise this to all sections in both
  extraction schemas (extend the `context_findings[]` section-tagging model).
- **DIRECTIVE — unify correspondence extraction UI with document extraction.**
  The surveyor wants the correspondence extraction to use the **same review
  screen + mechanics** as the document-vault extraction (`_ExtractionResultSheet`
  in document_vault_screen.dart) — "it works, and I want the same behaviour across
  the app". Replace/align the custom `CorrespondenceReviewSheet` with the shared
  document-extraction pattern (extract the doc review sheet into a reusable widget
  parameterised by source). Bigger refactor — do deliberately.
- **Timeline / chronology model (confirmed 23 Jul).** **Timeline tab = the report
  chronology** — ONLY items the surveyor has marked important/picked. **Full Log =
  everything**, the pool to pick from. Bugs: (a) the Timeline tab is showing
  un-picked items (a correspondence entry with no ★), and (b) aggregated items
  (correspondence, import-created events) default to "important" instead of
  full-log-only. Fix: Timeline tab shows important-only; new/aggregated items
  default to full-log; surveyor promotes into the chronology.
- **"Attendance" ≠ surveyor attendance.** A specialist/contractor visit (or vessel
  event) is a timeline EVENT, not a survey attendance. Correspondence extraction
  must not mis-create/badge these as attendances; a `survey_attendance` is the
  surveyor's own attendance, recorded deliberately. (Attendances screen was empty
  while the timeline showed "Attendance"-badged items — see investigation.)
- **Inbox case-filter too restrictive / not editable.** After importing one
  email, the case-filtered inbox hides other potentially-relevant emails for the
  case; the filter isn't adjustable. Make the case-relevance filter editable /
  loosenable so the surveyor can pull the rest of the thread. *(debug_feedback
  05:05, 23 Jul.)*
- **"New case from mail" is misplaced inside a case.** The inbox's new-case action
  is irrelevant when reached from correspondence *within* a case — creating a case
  from mail only makes sense from the case-selection screen. Hide/repurpose it in
  the in-case inbox context. *(debug_feedback 04:56.)*
- **Correspondence "which field?" clarity + clearer "review extracted data".** On
  the correspondence card it's unclear which field a value applies to; and the
  "review extracted data" affordance (chip tap → review sheet) should be more
  obvious. *(debug_feedback 04:17–04:59. Note: "can't do anything with this data"
  and "no attendance suggestions" are addressed by the new import build — pull.)*
- **Correspondence "back" overshoots to the case list.** Pressing back on the
  correspondence/import screen lands on the case-selection screen, not the case
  home. Likely the `BackAppBar` fallback (strips one path segment / `context.go`
  everywhere → `canPop()` false) deriving the wrong parent for the correspondence
  route. Fix: give the correspondence screen an explicit back target of the case
  home route.
- **Duplicate Google Drive folders per case.** *(Diagnosed 23 Jul.)* Two disjoint
  folder systems: the unified `Cases/<Year-TechNo-Vessel>/` taxonomy
  (`drive_storage_service.dart`, idempotent, persisted) AND a legacy
  `Marine Survey Reports/<case title>/` folder created ad-hoc by the report/doc
  export path (`export_button.dart:240`, `document_vault_screen.dart:273`) — not
  persisted, named by the mutable title (can spawn a 3rd on title change). Fix:
  route both export call sites through `DriveStorageService` (unified tree) and
  delete the `Marine Survey Reports` creation.

---

*Master history and per-section detail remain in `docs/TODO.md`. Completed
working docs are in `docs/archive/`.*
