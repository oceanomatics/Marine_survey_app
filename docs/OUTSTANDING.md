# Outstanding — clean to-do list

**Compiled:** 23 July 2026, from `FINDINGS_CLOSEOUT_2026-07-21.md` (code-verified),
`docs/last_entry` (the last request before the overnight interruption), and the
open items in `docs/TODO.md`.

**Context:** the backlog is overwhelmingly built and committed. The house-style
table lead-ins (the interrupted 22 July session) are now finished and committed
(`2bd5e21`); migration 063 is live. What follows is everything that is *actually*
still open.

---

## 1. Next up — Certificates + Class & Statutory merge  ⬅ the last request

From `docs/last_entry` (verbatim intent, lightly cleaned):

- **Merge** the Certificates section and the Class & Statutory section into one.
- **Certificates** — list all certificates with their details, presented like the
  Document Vault, and add-able inline.
- **Bottom section** — keep the current Class & Statutory edit content.
- **Conditions of Class** — make this an *add-item* section type, each item with:
  reference number · brief 2-line description · expiry date · a tick for "related
  to an occurrence in this case" · an occurrence select-dropdown (choices = the
  case's occurrences).
- **PSC** — list deficiencies (these are in the Equasis report already).
- **Incident** — display the **primary occurrence** here. Report status as:
  reported via **ISM** (yes/no) and/or to **Class** (yes/no). Heuristics:
  a formatted incident report present ⇒ reported via ISM; a Condition of Class
  issued in relation to the occurrence ⇒ reported to Class.
- *(The `last_entry` note trails off at "the data extraction is not…" — confirm
  with the surveyor what the intended data-extraction behaviour was before
  building that part.)*

> Relates to open question **Q2** (certificates in their own table vs. denormalised
> onto the vessel) — resolve that before finalising the merged data model.

---

## 2. Genuinely missing report-builder features

- **§2.6 Advice Summary editor** — no model, no screen. Auto-populated + editable
  advice summary is still absent.
- **§1.6 / scorecard #14 — firm logo on the cover page.** Logo currently embeds
  only in the body running header; the cover page shows the firm name as text
  only. (Everything else on the cover — vessel band, status badge, info box,
  photo — is done.)

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
