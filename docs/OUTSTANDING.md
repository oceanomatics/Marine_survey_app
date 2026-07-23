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
cover-page logo (§1.6) survive as genuine report-builder gaps.

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
- **Offline sync** — case pinning (design in `docs/offline_sync_plan.md`, not built).
- **Accounts reconciliation** — design in `docs/accounts_reconciliation_spec.md`, not built.

---

*Master history and per-section detail remain in `docs/TODO.md`. Completed
working docs are in `docs/archive/`.*
