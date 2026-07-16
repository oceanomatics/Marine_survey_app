# Follow-up Audit — 14 July 2026 Walkthrough vs. Current Code (16 July 2026)

**Method:** Every point from `docs/WALKTHROUGH_2026-07-14.md` re-checked against **actual current source**, not against TODO.md's own "done" marks — because the surveyor's core §23 complaint was precisely that claimed fixes weren't real. Items built this session were verified firsthand; the rest were verified by four parallel code-reading passes (file:line evidence required for every verdict), plus a direct diagnosis of the Google Sign-In blocker and the report-editor sub-points.

## The headline

The walkthrough is **overwhelmingly addressed in code.** The surveyor's impression ("I have already been through all these changes… and none of it has been done") was formed against a running app that did **not** contain this work — nearly all of it was sitting **uncommitted** across several build sessions and has only now been committed (commits `72f22b8`, `8921160`, `d3f5d97`). So both things are true: he was right that he hadn't *seen* it, and the work *is* there.

What actually remains splits three ways:
1. **One config action** unblocks the single biggest cluster (§11/§13/§14/§16-Q1/§27) — the Google Sign-In `ApiException 10`.
2. **Three areas deferred by the surveyor's own call** — not ours to build unilaterally (§6 Causation, §17 STT/stylus, §20 HSE).
3. **A short list of small open/unverified items** — worth a quick fix or a live check.

**Caveat:** most verdicts below are *code-verified*, not *live-verified*. The AI-task explorer and one AI draft were checked live on the tablet this session; the rest needs the surveyor to see it running.

---

## Per-section verdicts

| § | Module | Verdict | Evidence / note |
|---|--------|---------|-----------------|
| 1 | Authentication (2FA/biometric) | **DONE** | Biometric app-lock built + wired (`main.dart:45`), settings toggle (`account_screen.dart` App Lock card), 60s background grace added this session. Supabase session already persists indefinitely (`sessions_timebox`/`inactivity_timeout` both 0, verified via Management API). |
| 2 | Cases / Case Home | **MOSTLY** | Q1-3 fine. Quick Capture "route-after-capture" exists (`quick_capture_provider` routeCapture + Route All). **Open: Camera button regression (Q4) — not re-verified.** Drive re-auth prompt = the §11 sign-in blocker. Folder-rename-not-immediate = suspected Drive-desktop sync contention, not an app bug. |
| 3 | Vessel Particulars | **DONE** | P&I Club moved to Registration→Insurance (`vessel_particulars_screen.dart:1403-1410`). Dimensions regrouped L/T/V half-width. Nameplate thumbnail now renders on both tab + edit paths (`machinery_card.dart:405-419`, shared `linkedToType='machinery_nameplate'`). Propulsion reorganised (screws/prime mover/thruster). |
| 4 | Occurrences | **DONE** | Cue routing picker (which occurrence) built. Click-to-edit works (`occurrence_screen.dart:185-186`). Active/Ignore state still exists — its *simplification* is a **deferred scoping decision**, not a bug. |
| 5 | Damage Register | **DONE** (2 minor partials) | Concerning Average = Yes/No/Challenged (`damage_provider.dart:48-51`). Confirmed-By now compact pills. Narrative crop removed (no maxLines). Edit kept in ⋮ menu + click-to-open. Cue→damage tooltip added. *Partial:* "Affected Part" field hidden-when-resolved rather than deleted; "Location on Vessel" hidden only when machinery selected AND empty (value-present escape hatch — matches the "reconcile, don't blanket-hide" intent). |
| 6 | Causation | **DEFERRED (surveyor)** | Surveyor explicitly deferred the redesign to a second pass — "review old reports first." No action expected. |
| 7 | Repair Periods / NoR / etc. | **MOSTLY** | ContextCuesPanel overflow fixed (passing test: "expanding a fully-populated repair period… does not overflow"). Promote-cue control duplicated into the editor sheet after the "Tagged:" label. *Unconfirmed:* the Nature-of-Repairs rounded-corner bug wasn't re-tested. Surveyor flagged "needs another pass" — partially deferred. |
| 8 | Attendees & Attendances | **DONE** (1 nit) | Follow-up = simple Switch. Attendee name now editable post-creation. Title list revised (Navy ranks added, Miss dropped, Prof last). Attendee↔stakeholder **picker** built (migration 054 wired). *Nit:* "Capt" sits just below "Dr", surveyor asked for it above Dr — trivial reorder. |
| 9 | Document Vault / Production Manager | **DONE** (1 unverified) | Production Manager deep-links each item to its review screen (no main-menu redirect). Merge option built. Non-English extraction fixed. **Generalist extraction: already satisfies the ask** — the declared type is only a passing hint; one schema always looks for machinery/events/occurrences/cues/hard-fields together. *Unverified:* the Document Vault back-button loop. |
| 10 | AI Extraction & Smart Merge | **DONE** (1 to confirm) | P&I insurer now extracted + auto-populated. 9 statutory fields added to the schema. Re-import "no data" root-caused + fixed. Machinery merge shows a clear "Merge into X" primary action. "Detected Occurrence" vs "Detected Machinery" labelled distinctly. *To confirm:* occurrence-merge "always offered" for every detected occurrence. |
| 11 | Photos & Cloud Photo Sync | **DONE / BLOCKED** | EXIF taken-date now read. Manual photo→attendance exists (detail sheet). Folder-scan spinner added. Caption/significance collapsed to one field. Import types clarified. **BLOCKED:** the per-photo Google Drive sign-in prompts and the "Update" button error are the `ApiException 10` config blocker (below), not app logic. |
| 12 | Parties & Stakeholders | **DONE** | Persistent dirty-state `SaveBar` driven by `_hasChanges`, clears on save — the page-level indicator asked for, not just a post-save toast. |
| 13 | Correspondence / Gmail | **BLOCKED** | Mail import fails with `sign_in_failed` — same `ApiException 10` root cause. Code path is otherwise intact; blocked purely on OAuth config. |
| 14 | Cloud Storage Sync (Drive) | **BLOCKED** | Same sign-in blocker. Folder creation demonstrably worked before; full re-test waits on the config fix. |
| 15 | Timeline | **DONE** | Full-Log cards now compact/collapsible. Rating = chronology-inclusion (Important→Chronology, Normal→Full Log, Ignored→Ignored), old separate "add to chronology" step gone. Cues auto-convert to real events; raw cues no longer bloat the timeline. Report-gen timestamps excluded; document *content* date used. |
| 16 | Surveyor Notes → **Advice to Owner** | **DONE** (Q1 blocked) | Screen renamed. Classification flattened from nested tabs to inline chip-rows. Ignore skips further classification. Cue text + source shown at top while classifying. "Event created" pill wired. Q1 (action-items/follow-up) is blocked by §13. |
| 17 | Quick Capture / Voice / Stylus | **DEFERRED (surveyor)** | STT quality = a strategic vendor decision (Otter vs in-house + marine thesaurus). Stylus/second-tablet = a hardware-integration scoping conversation. Both explicitly the surveyor's calls. |
| 18 | Interviews | **DONE** (1 minor gap) | Raw audio persisted to storage (`interview-audio` bucket, migration 055). Persistent recording overlay floats app-wide (`main.dart:55-59`). Post-processing derives summary + cues on demand. *Minor gap:* re-running STT from the saved audio isn't offered (transcript is manually editable instead). |
| 19 | Checklist | **DONE** | H&M/P&I template content merged into one shared 58-item set (migration 057, applied live). |
| 20 | HSE | **DEFERRED (surveyor)** | Real feature, "a lot more discussion" expected before scoping. Not built. **Note:** the 17 uploaded ABL docs (`docs/HSE docs/`) contain real staff PII (Emergency Response Readiness Plan) and were deliberately NOT committed — needs scrubbing / a hosting decision. |
| 21 | Case Analyst | **DONE** | Full case-data grounding wired. "Insert into report" action added (flattens a chat reply's markdown into a report section). Voice = the same deferred STT question. |
| 22 | Accounts / Invoices | **DONE** | Split into Cost Estimate + Accounts tabs. Enter/keyboard-dismiss fixed. Line items now a compact table. Cost total sum bug fixed (unparsable input reverts + warns instead of zeroing). Repair-period budget rollup surfaced. Context Archive clarified. Case Home shows separate Cost Estimate + Accounts Summary + Unallocated indicator. |
| 23 | Reports (Report Builder) | **DONE** (2 nuances) | Advice Summary = real data-driven table with deep-links. Damage Description + Nature of Repairs auto-populated (read-only content + optional Remarks; no content TextField). §1 wording reworded (migration 052) — reads professionally, and it's editable if he wants further changes. AI-drafting queue fully unified this session. *Nuance 1:* cost-account states — his clarification ("approval is at invoice level; the full account is a mixture of all invoices") actually **matches** the current per-invoice DocStatus→clause + account-level rollup; pending his live confirmation. *Nuance 2:* Preview zoom works on native/tablet (`InteractiveViewer`); web has fit-scroll only; true page-by-page pagination not built. |
| 24 | Account & Org Settings | **DONE** | Three-tab restructure (Surveyor / Organisations / Connectivity) built — the repeat complaint is now actually resolved (`account_screen_test`: "shows three tabs"). |
| 25 | API Usage | **DONE** | Grouped by case → feature. Deleted-case usage rolled into a "Previous / deleted cases" bucket. Complete human-readable feature-label mapping (31 keys), snake_case fallback now unreachable. |
| 26 | App-wide navigation | **OK** | No new issues beyond the §9 Document Vault back-loop (unverified). |
| 27 | Action Items | **BLOCKED** | The "New from Correspondence" tier can't be exercised until §13 sign-in is fixed. |

---

## THE ONE BLOCKER — Google Sign-In `ApiException: 10` (DEVELOPER_ERROR)

This single config issue gates §11 (Drive photo sync), §13 (Correspondence/Gmail), §14 (Cloud Storage re-test), §16-Q1 and §27 (both downstream of Correspondence). It is **not an app-logic bug** — the code already handles silent token refresh (`google_auth_service.dart`).

**Root cause (diagnosed 16 July):** `ApiException: 10` means the running app's `(package name, signing SHA-1)` pair is not registered as an Android OAuth client in the Google Cloud Console project that owns the OAuth credentials.
- Package name: **`com.example.marine_survey_app`** (still the Flutter template default — `android/app/build.gradle:18`).
- Debug signing SHA-1: **`51:AF:5C:AD:44:97:8D:19:D7:3B:C5:1A:8C:2D:80:AA:30:62:8F:72`**
- No `google-services.json` present (not strictly required for `google_sign_in`, but the Android OAuth client must exist).

**The fix (surveyor's Google Cloud Console — I can't do it from here):**
1. In the Cloud project that owns the OAuth consent screen, create/verify an **OAuth 2.0 Client ID → Android** with package name `com.example.marine_survey_app` and the debug SHA-1 above.
2. When a signed release build is made, register that keystore's SHA-1 too.

Once registered, the grant persists on Android and the already-built silent-refresh path stops the per-photo re-prompting — matching the surveyor's "sign in once, never again" expectation.

*(Separate, bigger decision for later: the placeholder package name `com.example.…` should become a real domain before production — but changing it now means re-registering everything, so unblock first.)*

---

## Small open / unverified items (quick wins or quick checks)

- **§2 Camera button regression** — reported broken; not re-verified. Needs a live check / likely a real fix.
- **§9 Document Vault back-button loop** — reported; not re-verified.
- **§8 "Capt" ordering** — trivial reorder to sit above "Dr".
- **§5 "Affected Part" field** — hidden-when-resolved rather than removed; decide whether to delete outright.
- **§10 occurrence-merge "always offered"** — confirm it's offered for every detected occurrence.
- **§18 re-transcription from saved audio** — not offered (summary/cues are); minor.
- **§4/§16 Active/Ignore cue-state simplification** — pending a scoping decision, not a fix.
- **§7 Nature-of-Repairs corner bug** — status unconfirmed.
- **§23 cost-account states** — pending the surveyor's live confirmation that the invoice-level + rollup model reads right.

---

## Deferred by the surveyor (do not build unilaterally)

§6 Causation second pass · §17 STT vendor choice + stylus/second-tablet hardware · §20 HSE module (+ PII scrub of the uploaded docs).
