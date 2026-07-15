# Marine Survey App — Screen-by-Screen Walkthrough (14 July 2026)

**Purpose:** Full re-walkthrough of every module with the surveyor (Pierre-Louis), live against the running app. This is a fresh pass, not a continuation of the 8 July walkthrough (`docs/TODO.md` PHASE 0.1) — that one has since been code-verified in full (see `docs/TODO.md`'s "14 July 2026 re-verification" section, 60 done / 10 partial / 7 not done). This file starts clean so today's live feedback doesn't get tangled with that historical record.

**Format:** One section per module. Each has a short set of targeted questions — weighted toward things known to have changed recently or known to still be rough — plus room for anything else the surveyor notices. Answered live, in order, in this chat. `> ANSWER:` lines are filled in as we go.

**Status key:** `[ ]` not yet walked · `[✓]` walked, no new issues · `[!]` walked, issues found (see answers)

---

## 1. Authentication — `[✓]`

- Login, logout, session persistence all confirmed working, no issues.
- **New ask:** add a 2FA toggle to Profile/Account Settings — biometrics (Face ID/fingerprint/Windows Hello) accepted as the second factor, not just OTP/authenticator. Not previously tracked anywhere in TODO.md — new item, needs its own section once scoped (likely Account & Organisation Settings, §24 below, plus auth flow changes).
## 2. Cases (list + creation + Case Home) — `[!]`
> Q1. Cases list still loads cleanly, and new-case creation (job no / type / title) still smooth?
> ANSWER: Yes, fine.
>
> Q2. Case Home header redesign from 8 July (vessel name bold one-line + subline "survey type – tech file no. – instructing party") — does that read well now, or want it tweaked?
> ANSWER: Yes, good.
>
> Q3. Checklist quick-link at top of Case Home — confirmed it now actually navigates when tapped?
> ANSWER: OK, confirmed.
>
> Q4. Bottom capture toolbar — Camera/Interview/Quick Capture all work; the Stylus button is currently a dead no-op.
> ANSWER: **Camera button is NOT working (bug — needs investigation, regression from "works" state assumed earlier).** Interview: STT model quality is bad ("model is shit") — re-confirms known gap (walkthrough #79 in TODO.md, no alternative provider integrated yet) as a live blocker, not just theoretical. Stylus: confirmed dead end. Quick Capture: needs to be **redesigned** — currently implies the surveyor must know which section (Inbox, Damage, Checklist, etc.) an item belongs to at capture time. Should instead capture at a higher, undifferentiated level (a context cue / to-do item) and let it be **routed/triaged into the right box afterward**, not require picking the destination up front.
>
> Q5. New-case Drive folder creation — has this actually been exercised live yet?
> ANSWER: Yes, works — verified directly on his Google Drive. Two follow-on issues found live: (a) still occasionally prompts for a Drive login (re-auth), and (b) renaming the case (vessel name / tech file no.) does not rename the Drive folder **immediately** — suspected conflict with the same folder being open locally on his main PC (Drive desktop sync contention), not necessarily an app bug.
>
> Q6. Folded into Q5 above.
## 3. Vessel Particulars — `[!]`
> Q1. 5-tab split (Identity & Ownership / Registration / Classification / Dimensions / Machinery) — right breakdown?
> ANSWER: Structure fine, but **P&I Club field is misplaced on Classification** — should move to Registration tab as its own standalone subsection, "Insurance."
>
> Q2. Classification tab links out to case-level Certificates & Class screen instead of duplicating — flow OK?
> ANSWER: (covered by above — no separate complaint)
>
> Q3. Dimensions tab — breadth/draft now free-form fields — good now?
> ANSWER: **No — two problems.** (a) Moulded breadth field renders as a full-width field when it should be compact/half-width like the others. (b) Grouping is poor generally — redesign into **three groups: Longitudinal / Transversal / Vertical**, each with half-width fields, to make the whole tab more compact.
>
> Q4. Machinery nameplate photo thumbnail — confirmed showing now?
> ANSWER: **Still broken via one path, works via another.** Adding/selecting the nameplate photo directly from the Machinery tab still does NOT show a thumbnail. Adding it via the Edit menu DOES show it correctly. Two different code paths, only one fixed — needs the tab-level add flow to use the same thumbnail rendering as the edit-menu flow.
>
> Q5. Anything else on Vessel Particulars?
> ANSWER: **Propulsion section (Machinery tab) has an overflow bug** — the option pills are cropped at the end of the line. Wants it reorganised entirely as: number of screws / type of prime mover (motor, steam, electric) / thruster type (fixed pitch, variable pitch, azipods, waterjet). MCR field is fine as-is, no change needed there.
## 4. Occurrences — `[!]`
> Q1. Full-screen two-tab editor (Details / Narrative with cues + AI draft button) — working well?
> ANSWER: (see below — cue attachment issue overrides this)
>
> Q2. Context cues now scoped per-occurrence, shown under the narrative — confirmed correct?
> ANSWER: **No — contradicts what the code claimed.** Cues still show at the bottom of the screen, not visually attached to/nested under the specific occurrence. Wants: when a cue is being allocated, the surveyor should be able to **pick which occurrence** it's routed to (if the case only has one occurrence, default to it automatically, no prompt needed). Also flags the current **Active/Ignore** cue-state distinction as pointless in its present form — his reasoning: an Ignored cue is by definition not going to be allocated further, so there's redundant state here; the cue lifecycle should be simplified (needs a scoping conversation on exactly what states remain — not fully resolved live, just flagged as confusing/redundant as it stands).
>
> Q3. Title wrapping fixed on tablet width — confirmed?
> ANSWER: Not objected to — no complaint raised.
>
> Q4. Anything else on Occurrences?
> ANSWER: Wants **click-to-edit** on the occurrence itself (tap an occurrence → opens editor directly) — general principle requested: fast interface throughout, no hunting through menus to edit.
## 5. Damage Register — `[!]` (surveyor flagged: will need a further pass on this screen after this round)
> Q1. Full-screen editor, click-to-open — working?
> ANSWER: Yes, but **keep "Edit" in the ⋮ three-dot menu too**, for consistency with other screens (not either/or — both entry points).
>
> Q2. Cue → damage item promotion — working well?
> ANSWER: **Not visible/discoverable from this screen** — doesn't see a way to promote the cues listed at the bottom of the Damage Register. Possibly resolves itself as cue-processing UX gets addressed more broadly (see §16 Context Cues below) — not urgent, flagged not blocking.
>
> Q3. Damage Type first field, auto-composed row summary — reading well?
> ANSWER: Auto-composed narrative is **cropped** — wants it to read in full on the Damage Register screen, no truncation (current code caps at 4 lines).
>
> Q4. Confirmed By / Confirmation Date auto-populate, Condition Found feeding narrative — working as expected?
> ANSWER: **Confirmed By UI is awkward/oversized** — wants it collapsed into a couple of lines of compact toggleable pills instead of the current large widget.
> Two cue-attribution auto-classification asks (may partly already exist — see note):
>   - A cue originating from a **third-party service report** should auto-set attribution to **Third Party**. Surveyor suspects this logic may already exist and he's looking at stale cues generated before it was added — needs checking against fresh data, not assumed broken.
>   - A cue from an **incident report issued by master/superintendent/crew** should auto-allocate to **Assured/Owner**.
>   - The **"Concerning Average"** field (bottom of the edit damage item screen) — its three states should be **Yes / No / Challenged** rather than whatever the current three labels are.
>
> Q5. Anything else on Damage Register?
> ANSWER: Several more items:
>   - **"Affected Part/Component" field is leftover and now pointless** (superseded by the newer component picker) — remove.
>   - "Add new component" flow works well, no change.
>   - **"Location on Vessel" should be hidden when Machinery + System are already selected** — note: this is the *opposite* of the 2026-07-13 code decision, which deliberately reverted to always-showing this field because hiding it "left no way to view/edit a location note." Needs reconciling — possibly hide only when both Machinery AND System are populated, keep visible/editable otherwise, rather than a blanket show/hide.
## 6. Causation — `[!]` (surveyor explicitly deferring detailed redesign to a second pass — he'll review old reports first)
> Q1/Q2. Screen loads, edit cause type/allegation/narrative → save, general feedback?
> ANSWER: A few things could be made easier in the edit-causation flow:
>   - **Owner Stated Cause** could auto-fill by attaching a relevant context cue directly (insert the cue as the basis of the stated cause, rather than typing from scratch).
>   - **Source Document Reference** could auto-generate from the attached cue's origin/provenance — e.g. "in the incident report dated…", "in the correspondence dated…" — built from the cue's own metadata rather than typed manually.
>   - The big **Surveyor's Assessment** block (certainty level → auto-generates text → additional analytical notes → another standard formulation) feels awkward, with some redundant elements.
> **Explicitly marked for a second-pass review, not this round** — surveyor wants to look through old reports first and simplify his own approach before we redesign this section.
## 7. Repair Periods / Nature of Repairs / General Services / Additional Information — `[!]` (surveyor flagged: this page needs another pass too)
> Q1-5 combined ANSWER:
>
> **Nature of Repairs:** works well overall (broad confirmation; the specific rounded-corner bug my code audit flagged as still-live was not separately re-tested either way this session — status unconfirmed, not contradicted).
>
> **Repair Periods — live overflow bug reproduced**, full Flutter error captured:
> ```
> A RenderFlex overflowed... RenderFlex#ce70b relayoutBoundary=up5 OVERFLOWING
> creator: Column ← Padding ← DecoratedBox ← ConstrainedBox ← Container ← AnimatedContainer ←
>   ContextCuesPanel ← Column ← _RepairPeriodsBody ← KeyedSubtree-[GlobalKey#90f90] ← _BodyBuilder ← MediaQuery ← ⋯
> constraints: BoxConstraints(0.0<=w<=533.3, h=47.0)
> size: Size(533.3, 47.0)
> direction: vertical, mainAxisSize: max, crossAxisAlignment: stretch
> ```
> Vertical overflow inside `ContextCuesPanel` as rendered within `_RepairPeriodsBody` — content doesn't fit the `h=47.0` constraint. **A second, separate overflow also occurs when collapsing the context cues panel** on this same screen.
>
> **Context cues UX on this screen:** two separate menus for context cues currently (unclear to surveyor which is canonical). The "promote cue" control is too tiny/hard to hit — wants it duplicated inside the cue editor sheet itself, positioned just after the "Tagged: Repairs" label at the top, when a cue is allocated to a repair period.
## 8. Attendees & Attendances — `[!]`
> Q1. "Followup Attendance Required" badge in title bar — working?
> ANSWER: Over-engineered — currently a popup menu, should just be a **simple on/off switch**, no popup warranted.
>
> Q2. Attendee title shown wherever the name appears — confirmed?
> ANSWER: Title displays correctly, but **can't edit an already-inserted attendee's name** (bug — name field not editable post-creation). Title list needs revision:
>   - Add **military rank titles** (surveyor's example: "Lt" / Lieutenant) — wants a set of **Navy titles (shortened forms)**.
>   - **"Ms" and "Miss" are redundant** — drop one.
>   - **"Capt" should be reordered above Dr./Prof.** — used far more often than those.
>   - **"Prof" is rarely used** — low priority in the list ordering.
>
> Q3. Attendee ↔ Parties/Stakeholder link — still missing, build it?
> ANSWER: **Yes, definitely build it — important.** Also wants a proper **picker from the existing stakeholders list** (not just free text / not just add-new).
>
> Q4. Anything else?
> ANSWER: (covered above)
## 9. Document Vault — `[!]`
> Q1. AI extraction as background queue — confirmed working?
> ANSWER: Yes, works well — triggers automatically on document import.
>
> Q2. Upload/preview/annexure badge — good?
> ANSWER: Preview works well.
>
> Q3. Production Manager screen — used it, working?
> ANSWER: Several issues:
>   - **Navigation bug:** tapping into the Production Manager redirects to the main menu instead of linking directly to the relevant review screen for that item.
>   - **No merge option:** when extraction detects additional machinery/timeline events that look similar to an existing occurrence/machinery item, there's no way to merge — same "create new or merge into existing" gap already flagged for cues (§28 in the 8 July walkthrough) now surfacing for machinery/event extraction too.
>   - **Extraction failure on non-English document:** tried extracting a maintenance record written in French — returned nothing.
>   - **Bigger architectural question raised:** is extraction logic actually specialized per document type? Surveyor's read is **no** — "type" today is just a sorting/categorization field, not something that changes the extraction prompt/behavior. His ask: make extraction fully **generalist** regardless of declared type — every extraction pass should look for machinery, timeline events, occurrences, context cues, and hard data fields, all at once, from any document. Needs code-side confirmation of current behavior before scoping a fix.
>
> Q4. Anything else?
> ANSWER: (covered above)
> **Addendum (caught while on the next screen):** back button on the Document Vault "loops me around" — navigation bug, back stack cycling instead of exiting properly.

## 10. AI Extraction & Import Smart Merge — `[!]`
> Q1. Conflict dialog / per-field Keep/Report toggles — still working well?
> ANSWER: **Not thoroughly tested yet** — surveyor hasn't hit a real conflict; the data he's inserted so far has been internally consistent. Unconfirmed either way, needs a real test case.
>
> Q2/Q3 combined ANSWER — several findings:
>   - **Previous vessel name** now imports correctly (was previously broken).
>   - **P&I insurer is detected during extraction but not auto-populated** into the case/vessel record — real gap.
>   - General ask: **re-verify the extraction model covers every newer field** added to the schema recently — suspects some newish fields aren't being extracted for at all.
>   - **Re-importing the same file reports "no data extracted"** — unclear if that's correct behavior (everything already exists, nothing new to add) or a bug masking a real failure. Needs investigation, not assumed either way.
>   - **Machinery merge UX is awkward:** extracting a different file detected an existing diesel engine and offered a merge, but tapping just presents an ambiguous choice between "merge" and "make new" with no clear default. Wants a **clear proposed action** surfaced up front (e.g. "Merge into [existing item]" as the primary suggested action, "Add as new" as the alternative) rather than a flat unlabeled choice.
>   - **Occurrence merge:** multiple occurrences per case are rare, but wants the "merge as additional data into an existing occurrence" option **always offered** for every detected occurrence, not just sometimes.
>   - **"Detected event" label is ambiguous** — could mean either a detected Occurrence or a detected Timeline Event. Wants these clearly distinguished in the UI: "Detected Occurrence" vs. "Detected Timeline Event," never a generic "event."
## 11. Photos & Cloud Photo Sync — `[!]` **surveyor flagged: this page needs an in-depth review pass**
> Q1. Photo-to-attendance/event allocation — working well?
> ANSWER: **Auto-assign doesn't work** — root cause identified live: the photo's date is somehow coming from the *import* timestamp, not extracted from EXIF. Should read the real EXIF taken-date.
>
> Q2. Photo title convention consistent — confirmed?
> ANSWER: (not directly answered — no complaint raised)
>
> Additional findings:
>   - **Caption and "significance to claim" fields are functionally duplicative in practice** — currently buried as additional fields in another menu.
>   - **Still cannot manually allocate a photo to an existing attendance** — contradicts the code audit's "DONE" verdict for this (§75); worth re-checking, may be a UI-discoverability gap rather than a missing feature, or the manual (not auto) path was never actually wired.
>
> Q4. Sync/import/cover photo, anything else?
> ANSWER: Several real issues:
>   - **The 4 import types are awkward** — note to simplify, or at minimum better explain the source of each import option to the user.
>   - **Folder import doesn't work properly**, and there's no loading indicator while folder contents load — feels broken/frozen even when it's just slow.
>   - **Major bug — repeated Google Drive sign-in prompts, once per photo**, confirmed in the live Android log during a folder import:
>     ```
>     I/flutter: Drive photo upload skipped (offline or not configured): PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)
>     ```
>     repeated for essentially every photo in the imported folder. **`ApiException: 10` is Google Sign-In's `DEVELOPER_ERROR`** — almost always caused by a mismatch between the app's signing certificate (SHA-1 fingerprint) / package name and what's registered for the OAuth client in Google Cloud Console / Firebase, not a per-photo issue. Worth checking the Android OAuth client config directly before assuming it's an app-logic bug. Surveyor's expectation: sign in to Google Drive **once**, at profile setup, and never be re-prompted unless credentials actually change.
>   - **Same underlying bug affects EXIF processing** per surveyor's observation.
>   - **The "Update" button (top right) throws an error** — likely the same root cause as above (sign-in failure surfacing as a generic error).
## 12. Parties & Stakeholders — `[!]`
> Q1. Grouped sections, add/edit/delete — working well?
> ANSWER: Yes — saves now persist correctly within the grouped sections.
>
> Q2. Green save-confirmation toast now applied — confirmed?
> ANSWER: **Not what was actually asked for — discrepancy with the 8 July code audit's "DONE" verdict for §78.** What's built is a toast that fires *after* tapping Save. What the surveyor actually wants: a **persistent green indicator (bar or toast) that appears whenever there are unsaved changes**, and clears once saved — i.e. a page dirty-state indicator, not just a one-off confirmation. His complaint: the current blue Save button gives no visual signal of whether the page is currently modified-and-unsaved vs. already-saved. Needs reconciling — the original ask may have always meant this, and the "green toast on save" implementation only solved half of it.
>
> Q3. Anything else?
> ANSWER: No, everything else on this screen is fine.
## 13. Correspondence, Inbox & Gmail — `[!]` **BLOCKED — regression, could not test further**
> Q1-6: **Screen doesn't work at all right now** — mail import from the surveyor's email account fails outright with `PlatformException sign_in_failed`. Surveyor confirms "this used to work." Same signature as the §11 Photos Drive bug (`ApiException: 10` / `DEVELOPER_ERROR`) — likely one shared root cause (OAuth client / SHA-1 / signing config), not two separate bugs. Blocks live-testing the rest of this section until fixed. **Candidate for immediate investigation rather than deferral**, since it may also be blocking §14 Cloud Storage Sync.
## 14. Cloud Storage Sync (Google Drive) — `[!]` **also hit by the §11/§13 sign-in blocker, only partially testable**
> ANSWER: Folder creation clearly worked *at some point* — partial folders already exist in his Drive from earlier sessions — but full re-verification isn't possible until the sign-in regression is fixed. Surveyor accepts this needs a rework/re-test pass once that's resolved, not pursuing further today.
## 15. Timeline — `[!]`
> Q1. 3-tab structure with rating + chronology selection — working well?
> ANSWER: The detailed Timeline tab itself works well.
>
> Q2. Full event log currently doesn't aggregate correspondence/documents/report-gen — confirmed, wanted?
> ANSWER: Detailed, substantial redesign requested:
>   - **Context cues should auto-generate a real timeline event, not just be listed.** Example given: a cue reading "The vessel departed Perth for Hobart on 29/10/2025…" should immediately become a timeline event, not sit as a raw cue entry. Listing raw cues in the timeline is just bloating the page — remove that.
>   - **Custom event creation already works well** — keep as-is.
>   - **Correspondence and minor events should be listed in the Full Log.**
>   - **Report-generation timestamps should NOT be listed.** But **document date matters — specifically the date extracted from the document's own content, not the import date or the AI-processing date** — plus the surveyor's own report issuance date as a real milestone.
>   - **Full Log cards are too large ("massive").** Redesign as compact 2-line cards with appropriate status pills, full detail only on tap — same collapsed/expand pattern already used for Correspondence cards.
>   - **Simplify the rating model** — surveyor's proposed system: rating an event **is** the chronology-inclusion mechanism, collapsing today's two separate steps (rate, then separately add-to-chronology) into one:
>     - **Important** → goes straight into the main Timeline (report Chronology)
>     - **Normal** → stays only in the Full Log
>     - **Ignored** → goes straight to the Ignored tab, does not appear anywhere else
>     No separate "add to chronology" action needed under this model.
>
> Q3. Anything else?
> ANSWER: (covered above)
## 16. Surveyor Notes & Context Cues — `[!]`
> **Naming issue:** "Surveyor Notes" is an old term that no longer matches current usage — this screen is actually functioning as **"Advice to Owner"** now. Needs renaming to match its real meaning.
>
> Q1. Surveyor Notes / action-items-as-Follow-up — working?
> ANSWER: **Cannot test until Correspondence/Gmail is working again** (blocked by the §13 sign-in regression). Noted, revisit once that's fixed.
>
> Q2. Cue create-or-merge principle — build out everywhere, or wait for the routing redesign to settle?
> ANSWER: **Yes — make it consistent everywhere.** Also: if a cue creates a Timeline event (per the new auto-event-creation ask in §15), the cue should show a small **"Event created" pill** for traceability back from the cue.
>
> Q3. Anything else, general cue classification UX:
> ANSWER: Several points on the cue classification editor itself:
>   - **Conditional sub-allocation works well**, but will likely need review in light of the Occurrence-routing finding (§4 — picking which occurrence a cue routes to).
>   - **"Nature of Content" field is becoming less useful** as cue scope narrows — not urgent, flagged as potentially reviewable/removable later, may still find a use.
>   - Idea floated (not fully resolved): if the Follow-up/Open-Question flag is ticked, the cue effectively becomes more of an **action/to-do item** — surveyor isn't yet sure how to articulate this cleanly, needs more thought before scoping.
>   - **Too many nested tabs** in the classification UI — "Nature of Content" is its own tab, then "Evidentiary Weight" and "Origin" are further tabs beyond that. Feels over-structured.
>   - **If a cue is set to Ignore, no further classification should be required** — right now most of the subsequent menus still apply regardless, which is pointless once something is ignored. (Same point as the Active/Ignore redundancy flagged in §4 Occurrences.)
>   - **General layout ask:** the cue's own text should be presented at the top of the editor, prominently, along with a reminder of its origin (source report/document, page number, date document issued, etc.) — this context should be visible *while* classifying, not buried, since it's what actually informs the classification decision.
## 17. Quick Capture & Voice Notes — `[!]`
> Q1. On-device STT quality — how bad, exactly?
> ANSWER: **Worse than Android's own built-in voice recorder/dictation.** Otter.ai is still the best transcription quality option found so far. Two paths raised for a real fix: (a) integrate a third-party service like Otter, or (b) go further in-house with an improved model, boosted with a **marine-insurance-specific thesaurus/vocabulary** to lift accuracy on domain terms. Not decided — a real strategic call, ties into the existing STT strategy notes (platform STT / SpeechProvider abstraction / AssemblyAI-Deepgram-for-diarization plan).
>
> Q2. Anything else on Quick Capture beyond the routing redesign already noted?
> ANSWER: **Stylus feature should be built** ("reinstated/actioned" — currently a dead button, see §2). Vision given: something like the **iFLYTEK AINOTE Air 2** experience — an E-Ink-style tablet with stylus handwriting recognition plus built-in voice recording and real-time AI transcription. Surveyor doesn't rule out using a **second dedicated tablet for note-taking**, fully integrated with the case app (not necessarily built as a single-device in-app feature — could be a companion-hardware workflow). This is a bigger hardware/integration question, not just a UI fix — needs its own scoping conversation.
## 18. Interviews — `[!]`
> ANSWER: Beyond STT quality (§17): wants the recorder to be a **fully functional recorder with audio save** (persist the raw audio, not just the transcript) plus **post-processing** (re-run/improve transcription and/or derive summary/cues after the fact).
> **Implementation idea flagged (not a firm spec):** during a real meeting the surveyor needs to move around the rest of the app while an interview is being recorded — recording should keep running as something like a **persistent overlay/floating indicator** across screens, not require staying on the Interview screen for the whole recording.
## 19. Checklist — `[!]`
> ANSWER: **Content correction, not a bug:** the checklist Andy provided (currently seeded only as the 58-item `case_type='pi'` set) is actually applicable to **most H&M surveys too** — the two case-type-specific template sets should be **merged into one shared checklist** rather than keeping H&M on separate placeholder content. Overall functioning (Yes/No/N-A selector, auto-tick, progress) — surveyor is happy with it so far.
## 20. HSE — `[!]` **scope just expanded significantly — real content provided**
> ANSWER: Not just a priority check — surveyor has uploaded 17 real ABL HSE documents/forms into `docs/HSE docs/` as a basis for building this module for real. These are ABL-branded forms currently; will need to become brandable per organisation/firm profile later (same pattern as the existing branding config for reports). Surveyor expects **"a lot more discussion"** on this before it's scoped properly — this is the start of a real feature, not a quick fix.
>
> **Document catalog (background scan complete)** — 17 files, all genuine ABL Group material, two logo eras (pre/post rebrand), grouped by their original Drive folders:
>   - **Generic risk-assessment templates** (Towage RA, Rig Moving RA, a multi-tab vessel-inspection/client-site/location risk register workbook) — corporate-level references, predate the newer HIRA system below.
>   - **Crisis Management SOP-011 package** (main SOP + Emergency Evacuation Guide + Country Evacuation Planning Guide + a per-office Emergency Response Readiness Plan) — the readiness plan **contains real staff names/phone numbers per office (PII)**, needs scrubbing before reuse as a template.
>   - **Incident Reporting SOP-009 package** (main SOP + a "HELP Card" near-miss/hazard blank form + a 3-page, ~30-field Incident Reporting Form) — directly relevant, core HSE-module functionality.
>   - **Confined Space Entry SOP-010 package** (main SOP + a 46-item Yes/No/NA checklist + a pre-inspection requirements letter/checklist) — strong Permit-to-Work candidate.
>   - **Hazard Identification & Risk Assessment SOP-013 package** (main SOP with a 4×4 risk matrix + a generic "Dynamic Risk Assessment" 30-item checklist + a rig-inspection-specific variant of the same) — this DRA checklist is the closest thing to a JSEA in the batch. **Note: one file (doc_14) is an exact duplicate of another (doc_15)** — worth confirming that's accidental before using either as the canonical source.
>   - None are generic third-party templates — all need de-branding/genericizing to become an org-configurable template, same pattern as report branding.
## 21. Case Analyst (AI Assistant) — `[!]`
> ANSWER: UI is much nicer now, table creation works well. **Future-facing intent for this feature**, stated by the surveyor: eventually be able to use the Case Analyst to actually **draft report content directly via conversational prompts** — his example: *"I want you to insert here a table of all the defects found during inspection, cross-referenced by specialist assessment, and insert a short paragraph about your findings."* This implies the chat should be able to generate structured content (tables + narrative) destined for the report, not just answer Q&A about the case.
> **Requirement flagged:** make sure the Case Analyst has access to **all data extracted for the case** — full grounding, not a partial context window.
> **Voice input:** same STT quality complaint as Interviews/Quick Capture — Android's own built-in voice input is better than the in-app model (assumed to be the same underlying model as Interviews — "still crap").
## 22. Accounts / Invoices — `[!]` (real redesign requested, current single-screen layout deemed "bloated")
> ANSWER: Substantial restructure requested:
>   - **Split into two proper tabs:** Cost Estimate (up to and including Survey Fee Reserve) in its own tab, and proper Account/Invoice management in a separate tab — with a **summary at the top** of each. Current single-tab implementation is bloated.
>   - **Field confirmation UX:** pressing Enter/CR after entering a value currently does nothing useful — wants real validation on confirm. Also, the **keyboard stays up after confirming a field**, further bloating the screen — should dismiss.
>   - **Cost estimate line items are oversized cards** — should be condensed into a compact table instead.
>   - **Bug: cost estimate total doesn't sum correctly.**
>   - **No feedback/rollup of cost estimates entered at the repair-period level** — not visible anywhere once entered.
>   - **"Context archive" tab purpose unclear** — surveyor isn't sure what it does in practice, feels useless as currently presented.
>   - **Case Home summary card is unclear** — wants a clearly separated **Cost Estimate section** and **Accounts Summary section**, plus a visible **"Unallocated" indicator** — currently, if expenses haven't been allocated yet, the total shown is simply wrong rather than showing what's outstanding/unallocated.
## 23. Reports (Report Builder) — `[!!]` **WORST-PERFORMING MODULE — surveyor states this has seen the least real progress of anything reviewed today, wants implementation notes reviewed and a plan of action, not more ad hoc fixes**
> ANSWER — direct, frustrated feedback, quoted closely because the framing matters:
>   - **Advice Summary is still not the tabular, DB-linked, editable presentation asked for** — this is a repeat of a gap flagged as far back as the 3 July 2026 audit addendum (`docs/AUDIT_delta.md` — "Advice Summary… still fully missing").
>   - **Damage description and Nature of Repairs are still free-text fields** in the editor — by now these should be AI-drafted from case data, with only an optional **Remarks** field left as manual input. Every other field belongs on the case screens, not typed again in the report editor.
>   - **Section 1 opening wording** "still reads like a 2 year old wrote it" — tone/quality complaint on the generated prose.
>   - **Explicit statement: "I have already been through all these changes that I wanted to do, and none of it has been done."** Surveyor's read is that this module specifically has not absorbed prior feedback, in contrast to every other screen walked today. **Direct request: review ALL existing implementation notes (TODO.md §1.8/§1.9/§2.18, AUDIT_delta.md, docs/report_builder_editor_notes.md) against current code and today's feedback, and come back with an explicit plan of action** — not just log this and move to the next screen.
>   - **Accounts/cost section in the exported report does not match the original brief.** Original brief: invoices should resolve to one of a small number of clear states (fully approved / partially approved / not yet invoiced) — current implementation does not reflect this correctly. **"We've already been through this"** — a repeat complaint, not new.
>   - **Preview tab is broken** (not further specified — needs live repro).
>
> **This section needs its own dedicated review pass before further live walkthrough continues on it** — see follow-up conversation.
>
> **Fix pass completed same session** (plan: `.claude/plans/wiggly-chasing-piglet.md`; full log: `docs/TODO.md` "14 July 2026 — fresh live walkthrough + Report Builder second-pass fixes"): Advice Summary card rebuilt (damage/repairs auto-populated, Assured/Instructing Party added, real deep-links added); the AI-draft data-loss bug fixed; accounts/invoice states completed (all 6 `DocStatus` values now produce report text, plus a rollup line); AUTO badge added to distinguish auto-populated vs narrative sections. Not yet live-verified against the running app by the surveyor himself — code-verified + tested only.
>
> **Follow-up (same session, after seeing the fix summary):**
>   - **Wording clarified as changeable, not locked:** confirmed the surveyor is fine with the approved legal wording being reworded for readability as long as the required legal content stays present — it's not verbatim-locked like the WP/waiver clauses. Found and fixed the exact bug: `survey_type_hull_and_machinery` clause read "This **survey** was conducted as a hull and machinery damage **survey**." — fixed to "This was a hull and machinery damage survey." (migration `052_opening_survey_type_wording.sql`, both `abl`/`oceano_services` formats). The `[CLIENT]`/`[FIRST_ATTENDANCE_DATE]` placeholders he also saw unfilled are most likely a data-completeness issue on the specific case being viewed (no `instructing_party` / no attendance recorded yet), not a code bug — the fallback-chain code already prefers real data over the placeholder; not independently re-verified against that specific case.
>   - **Preview "broken" clarified:** not a crash — it's "all packed up into one stack of sheets that I cannot zoom through," i.e. not genuinely paginated/zoomable yet, so not functional as a page-by-page preview. Needs a pagination/zoom UX decision — logged, not fixed this session.
>   - **AI-drafting background queue reaffirmed** — explicit ask: unify with the existing AI extraction queue system so all AI interactions are queued, removing the ~20 second wait after pressing a draft button. Confirms the architecture item already scoped as its own future pass.
## 24. Account & Organisation Settings — `[!]` **repeat complaint — surveyor has already reviewed this screen before, nothing done since**
> ANSWER: Confirmed still not done — the requested restructure into **three tabs (Surveyor / Organisations / Connectivity)** has not been built. This matches the 8 July walkthrough's #6 finding, which TODO.md §2.16 records as a *deliberate* deferral (substance split across two screens instead) — surveyor is saying that deferral is not acceptable, this is a repeat ask, not new. 2FA/biometrics toggle (§1) would live under the Surveyor tab once this exists.
## 25. API Usage — `[!]` **repeat complaint — confirmed already logged (8 July walkthrough #4 + this session's Group A code audit)**
> ANSWER: "We are still at the same level here." Matches prior finding exactly: per-case split exists in code but isn't presented the way he wants, and feature labels are still raw `snake_case` in places. Specific ask, more detailed than before:
>   - **Group the presentation by case, then by feature within each case** (not a flat list).
>   - **If a case has been deleted, don't lose its usage history** — roll it into a single "previous/deleted cases" container aggregating all its past functions/features, rather than orphaning or dropping those records.
>   - **Feature names still shown in snake_case in places** — finish the human-readable label mapping everywhere, not just partially (matches the exact gap the code audit found: unmapped feature keys still fall back to raw `snake_case`).
## 26. App-wide navigation & save patterns — `[✓]` (partial coverage, no issues found so far)
> ANSWER: No further issues found beyond the Document Vault back-loop already caught (§9). Surveyor caveat: hasn't had a chance to test everything yet — this is a "nothing found so far," not an exhaustive pass.
## 27. Action Items — `[!]` **BLOCKED — same root cause as §13**
> ANSWER: Not tested — the "New from Correspondence" tier (the most likely real source of action items) can't be exercised while Correspondence/Gmail import is broken (§13's sign-in regression). Revisit once that's fixed.

---

**Walkthrough complete — all 27 sections covered, 14 July 2026.**

---
