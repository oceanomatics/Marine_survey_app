# Manual walkthrough — recent modifications (as of 2026-07-16)

A tap-by-tap follow-along for everything changed in the **13–16 July 2026**
sessions. Work top to bottom on the tablet; tick each box and jot a note if
anything looks off. Items marked **✓ live-verified 16 Jul** were already
exercised during the automated sweep — re-check only if you want to confirm by
hand.

Test case used below: **SI-M53-055873 – MINRES ODIN – H&M** (has real data in
every section).

---

## 1. Auth & session

- [ ] **Stay logged in** — fully kill the app (swipe from recents), reopen.
  *Expected:* straight to Cases list, no login screen. ✓ live-verified 16 Jul
- [ ] **Biometric app-lock** — Account (person-gear icon) → Surveyor tab →
  toggle **Require biometric unlock** on. Background the app <60s, reopen.
  *Expected:* no re-prompt (60s grace). Background >60s, reopen → biometric
  prompt. Then toggle it back off if you don't want it.
- [ ] **Google Sign-In** — open a case → **Mail** rail → top-right mail icon →
  pick your Google account. *Expected:* native account picker (NOT
  `ApiException: 10`), then live inbox loads. ✓ live-verified 16 Jul

## 2. Google Workspace screens (newly unblocked)

- [ ] **Correspondence** (case → Mail rail) — list of email threads loads with
  trail counts + extraction badges. ✓ live-verified 16 Jul
- [ ] **Inbox / Triage** (Mail → top-right mail icon) — live Gmail, each message
  has *Link to case* / *New case*. ✓ live-verified 16 Jul
- [ ] **Extract an email** — expand a thread → **Extract**. *Expected:* badge
  Processing → Extracted; produces summary + detected parties + action items.
  ✓ live-verified 16 Jul (cleared both previously-"Failed" items)
- [ ] **Photos** (case → Photos rail) — grid loads, grouped By Visit, unassigned
  pool + Auto-assign. ✓ live-verified 16 Jul
- [ ] **Action Items** (Case Home → Action Items card) — expands inline. ✓
  live-verified 16 Jul (empty on this case — try one with linked emails)

## 3. Vessel — Dimensions / Propulsion regroup

Case → **Vessel** rail → tabs across the top.
- [ ] **Dimensions** tab — Tonnage (GT/NT/DWT) then Principal Dimensions grouped
  **Longitudinal / Transversal / Vertical** with "fill whichever were collected"
  hints. ✓ live-verified 16 Jul
- [ ] **Machinery** tab — **Propulsion Particulars**: *Number of Screws* (new),
  *Type of Prime Mover* (Motor/Steam/Electric), *Thruster Type*
  (Fixed/Variable pitch/Azipods/Waterjet), MCR power (kW/bhp) + RPM. Then
  Machinery & Equipment list with sub-components. ✓ live-verified 16 Jul

## 4. Checklist — Y/N/N-A rework + auto-tick + H&M/P&I merge

Case → **Checklist** rail.
- [ ] Four phase tabs: **Pre-Survey / On Vessel / Before Leaving / Post-Survey**
  with per-phase counts. ✓ live-verified 16 Jul
- [ ] Each item has **Y / N / N-A** buttons (not a plain checkbox). ✓
- [ ] **Auto-tick** — the "Vessel pre-populated from DNV/class PDF import" item
  shows an **auto** badge + timestamp when the vessel was imported from a class
  PDF. ✓ live-verified 16 Jul
- [ ] **Mark all done** on a phase header sets the whole phase.
- [ ] Content is the real **MM09** P&I attendance items (merged H&M + P&I set).

## 5. Occurrence + Context Cues

Case Home → **Occurrence** card.
- [ ] Occurrence renders with narrative, date, location. ✓ live-verified 16 Jul
- [ ] **Context Cues** panel at the bottom (Active / Ignored). Tap **+ Add** and
  confirm the **cue routing picker** lets you route a cue to a target section.
- [ ] From an occurrence/event cue elsewhere, confirm the **Event pill** shows on
  the cue (punch-list item).

## 6. Advice / cue-to-report system

Case → **Advice** rail.
- [ ] Four tabs: **Retained / Suggested / Unallocated / Ignored**. ✓ 16 Jul
- [ ] Cues grouped by target section (Background / Occurrence /
  Allegation-Causation…), each tagged by type (Observation/Finding, Opinion,
  Allegation, Fact) and source (Surveyor / Third Party / Assured). ✓ 16 Jul
- [ ] Source-document chips + evidence count (e.g. "Engine failure 4/14"). ✓
- [ ] **Add Cue** FAB works.

## 7. Case Timeline

Case Home → **Case Timeline** card.
- [ ] Tabs: **Timeline / Full Log / Ignored**. ✓ live-verified 16 Jul
- [ ] Aggregates Occurrence + Attendance + Correspondence in date order with
  colour-coded nodes + type pills. ✓
- [ ] **Full Log** shows every event incl. AI relevance rating; **Ignored** holds
  demoted events; curation here drives the report Chronology.

## 8. Case Analyst (grounded chat + report insertion)

Case → **Analyst** rail.
- [ ] Header reaches **"Context loaded — ask anything"** + suggested prompts. ✓
- [ ] Ask "What is the primary occurrence and its apparent cause?" → grounded
  answer citing the real engine S/N, bolt part no., load/RPM. ✓ live-verified
- [ ] **Insert into report** button appears under an answer. ✓ (verify it lands
  the text in the intended report section)
- [ ] Mic button offers voice input.

## 9. AI Tasks unification (global task explorer)

- [ ] Start any AI action (an Extract, an Analyst query). *Expected:* the
  sparkles icon in the app bar shows a **running-count badge**; opening it lists
  the task with a time estimate; it clears on completion. ✓ live-verified 16 Jul
- [ ] Navigate away mid-task — the indicator persists across screens (it's
  global, not per-screen).

## 10. API Usage — by-case attribution (§25)

Cases list → bar-chart icon (top bar).
- [ ] **By Feature** list shows per-feature token cost. ✓
- [ ] **BY CASE** section lists real case names (e.g. "SI-M53-055873 – MINRES
  ODIN – H&M"), NOT "Previous / deleted cases". ✓ live-verified 16 Jul
- [ ] Run a fresh AI call on a case, return here → its tokens attributed to that
  case by name.

## 11. Attendees — title order (§8)

Case → **Attendance & Representatives** → add/edit an attendee → Title picker.
- [ ] Order is **Mr, Mrs, Ms, Capt., Dr., Adm, Cdre, Cdr, Lt Cdr, Lt, Sub Lt,
  Prof** — Capt above Dr; no "Miss". ✓ live-verified 16 Jul (order in code)

## 12. Accounts & Settings

Account (person-gear icon, top bar).
- [ ] Three tabs: **Surveyor / Organisations / Connectivity**. ✓ 16 Jul
- [ ] **Connectivity** — API Keys (Anthropic Active), Cloud Storage, FX Rates,
  Speech, External Accounts (+ Add Account). ✓
- [ ] **Accounts screen Enter-key** — in the Add/edit account fields, pressing
  Enter submits/advances (punch-list fix).
- [ ] **Organisations** tab — org switcher / multi-tenancy surface.

## 13. Interviews (sticky-points build)

Case Home bottom bar → **Interview**.
- [ ] Records audio with a live overlay; produces an interview **detail screen**.
- [ ] **AI summary** generated from the transcript.
- [ ] (Diarisation / vendor STT is deferred — not expected yet.)

## 14. Quick Capture

Case Home bottom bar → **Quick Capture**.
- [ ] Fast note/photo capture flow lands the item into the case.

## 15. Repair Periods — budget rollup

Case Home → **Repair Periods** card.
- [ ] Multiple repair periods roll up into a **budget total** (punch-list item).

## 16. Report builder (10 Jul work, verify if not yet)

Case → open the report / builder.
- [ ] **Auto-populated sections** (Occurrence, Nature of Repairs, Documents
  Requested, Damage Schedule) show read-only table/prose + **Edit link** +
  **Remarks** field (§2.18).
- [ ] **3-way documentation split** — each doc is enclosed-in-report / retained-
  on-file / requested; the *enclosed* flag flows to the export (§3.4).
- [ ] **docx export** includes the **Photo Register + Annexure E** (§2.4).

---

## Observations already logged (cosmetic, non-blocking)

- Case Home briefly shows a wrong-lower completeness figure on cold entry
  (~3s) before settling — a shimmer would read better.
- Case header shows vessel name title-cased ("Minres Odin") while the Vessel
  Particulars field is all-caps ("MINRES ODIN").
- A correspondence sender name rendered with a MIME-decode artifact ("Wánk").

## Deferred — do NOT expect these yet
§6 Causation second pass · §17 STT vendor / stylus · §20 HSE module.
