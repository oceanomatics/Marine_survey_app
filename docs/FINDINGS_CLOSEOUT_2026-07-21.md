# Findings close-out — 21 July 2026

Final pass over the **TODO list + 14/16 July walkthrough backlog + house-style
notes** (`docs/house_style.md`, `docs/report_builder_house_style_mods.md`,
`docs/occurrence_narrative_spec.md`, `docs/SWEEP_RESUME_2026-07-16.md`,
`docs/WALKTHROUGH_AUDIT_2026-07-16.md`).

**Method:** every backlog item was re-checked against **actual current source**
on the `overnight-work-2026-07-08` branch, not against the checklist marks
(which drift both ways). Three parallel code-reading passes mapped the cue/
occurrence, Report Builder, and scattered-bug domains; migration state was
verified live via the Management API.

## Headline

The backlog is **overwhelmingly already built and committed.** Across the
worktree-agent merges on this branch, essentially every SWEEP_RESUME batched
item and house-style modification shipped:

- **Occurrence Narrative feature** (spec fully built): forked before/incident/
  aftermath cues, `OccurrencePhase` + `surveyor_notes.occurrence_phase`,
  reported-by attendee picker (`occurrences.reported_by_attendee_id`), AI
  pre-sort, house-style `draftOccurrenceNarrative` rewrite. Commit `d2fe42b`.
- **Occurrence/cue UX polish**: Active/Ignored toggle removed from
  `ContextCuesPanel`, Occurrence SaveBar, voice-capitalise, chip alignment.
  Commit `c9a1808`.
- **House-style Report Builder alignment**: italic purpose lines, waiver
  auto-generation from the legal-clause library, Class & Statutory (ISM/ISPS/
  detentions), reviewer/QC sign-off block, repair-times "Days" inline + no
  cross-period total, real Word tables (Vessel Particulars/Attendees/Chronology/
  Repair Times), Photo Register + Annexure E, drafting-prompt rewrites
  (Occurrence/Background/Damage/Cause). Commits `d2fe42b`, `bb103d4`.
- **Scattered bug cluster**: case-title occurrence-brief regression, /inbox
  MIME+HTML decode, Drive Base Folder editor wiring, Parties polish, Edit-Cue
  chip indentation. Commits `426484b`, `3e4b039`, `f6090e7`.
- **Correspondence** (case-filtered inbox, new-mail badges, auto-queue
  extraction — `3b6343a`), **Photos** (Picker import, Drive backup, own/
  third-party grouping — `8afb14c`), **Certificates** (issued/status —
  `809ca4e`), **Repairs** (post-repair sea trial — `a37c2c0`).

**Migrations:** all applied and live-verified (058, 059, 054×2, 055, 056, 062,
053×3 incl. class-conditions issued/status and account-lines FX). DB in sync.

## Fixed in this pass (the genuine residual gaps)

1. **House-style §A2 — empty-section negative statements now wired.** The
   `sectionNoDataSentence` map existed and was unit-tested but never consumed.
   Added `sectionBodyOrNoData()` and wired it into both the Preview and the
   docx export so the five optional sections (Extra Expenses, General Services,
   Previous Works, Contractual/Hire, Other Matters) emit their explicit "No
   indication was given…" statement when empty instead of being silently
   omitted (R15/R18/R19). Pagination estimate and body filter updated to match.
2. **Bug 2 residual — background mail poller now decodes headers.**
   `GmailService.listRecentSilent` (feeds the new-mail count badge + previews)
   was emitting raw `Subject`/`From`/`snippet`; now runs `decodeMailHeader`/
   `decodeMailText` like `listRecent`. Also added HTML-entity decoding to
   `EmlParser._decodeHeader` so **filed** (.eml) correspondence decodes `&#39;`
   etc., matching the Gmail path.
3. **Bug 5 residual — correspondence AppBar badge no longer clipped.** The
   new-mail `Badge` inside the AppBar `IconButton` had its "99+" label cropped
   by the tight action bounds; added right padding + an inward badge offset.

Tests added: `sectionBodyOrNoData` behaviour (3 cases) and a new
`eml_parser_test.dart` (HTML entities, MIME words, and both together). Touched
files analyze clean; affected suites pass.

## Still open — by design, not oversight

- **Google Sign-In `ApiException: 10`** — a **Google Cloud Console config
  action** (register package `com.example.marine_survey_app` + debug SHA-1 as an
  Android OAuth client), not code. Gates the live re-test of Drive photo sync /
  Gmail / Action Items. Runbook: `docs/google_signin_setup.md`.
- **Deferred by the surveyor** (do not build unilaterally): §6 Causation second
  pass, §17 STT vendor choice + stylus/second-tablet, §20 HSE module.
- **§20 HSE docs PII** — the 17 uploaded ABL docs under `docs/HSE docs/` carry
  real staff PII and remain **deliberately uncommitted** pending a scrub /
  hosting decision.
- **Live verification** — the above is code-verified; the surveyor still needs
  to exercise it on the tablet (see `docs/WALKTHROUGH_RECENT_MODS_2026-07-16.md`).

## Not built (explicit "build Oceano first, remap later" decision)

Per-format section machinery for Nordic/ABL/Marsh (ordered section lists +
format-specific wording branches). Only the Oceanoservices canonical order
exists; drafting prompts take `reportFormat` as a label substitution. This is
the sequenced remap step, not a gap.
