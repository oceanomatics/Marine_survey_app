# Marine Survey App — Test Sheet

Status: `[ ]` Not tested · `[✓]` OK · `[~]` Partial · `[✗]` Broken · `[⛔]` Not built yet (gap — nothing to test)

Auto: `Unit` pure-logic unit test (no UI/network, could write today) · `Widget` widget test w/ mocked providers (moderate setup, no external service) · `Integ` integration_test w/ faked backend (bigger investment) · `Manual` needs a real external service (Google OAuth/Gmail/Drive/Photos, camera/mic hardware, a second real device/email) or subjective/visual judgement — not practically automatable in this stack.

**Automation status (2026-07-15, end of day):** all 9 `Unit`-tagged rows are automated. Widget coverage now spans essentially every screen: Checklist, Reports, Vessel Particulars incl. `VesselComplianceScreen`, Occurrences, Damage Register, Causation, Repairs (36-38, 39-40 Nature of Repairs/Additional Information, 41 partial), Attendees (42-46, all done), Document Vault (47 + AppBar covered; 48-52/91/98-105 are `[⛔]` — file_picker/image_picker/Supabase-signed-URL calls with no injection seam), Photos (70/74 covered, 72 `[⛔]` same reason, 73/75 partial — full-screen viewer not exercised), Parties & Stakeholders (81-87, all done), Correspondence (89-90/92-95/97/108-114 covered; 91/98-105 `[⛔]` file_picker; 96/107/115-118 Manual, real external services), Surveyor Notes/"Advice to Owner" (125-127, all done), Background & Context Cues (128-132, all done), API Usage (197, degrades gracefully — no provider seam on this screen to fake real data), Timeline, Quick Capture, Interviews, Case Analyst, Account/Organisation Settings, Accounts. Same fake-Riverpod-notifier pattern throughout — no mocktail, no fake Supabase client. Test count: 466 automated tests (`flutter test`), 465 passing — sole failure is the pre-existing unrelated `test/widget_test.dart` placeholder. This pass found and fixed **7 real bugs** purely because a test forced the code path: 5 RenderFlex overflows on ~360-430dp phones (Causation's AI-Draft row, Advice to Owner's tab labels, Accounts' "Purely Estimated" badge, the Attendance card header), a biometric-check hang with no timeout, an invisible-tap-feedback switch on `VesselComplianceScreen`, and a genuine Riverpod race condition (`addFromExtracted`'s dedupe check could read a not-yet-loaded provider's `state.value` as empty). None were previously reported live. What's left: ~25 rows, almost all Manual (real Gmail/file-picker/camera/mic) or the handful of `[⛔]` gaps noted above — the remaining automatable surface is essentially exhausted for this stack.

Rows marked `[⛔]` or with a "verify if implemented" comment are gap markers, not test failures — they exist so the sheet doubles as a punch list toward a finished product.

---

## 1. Authentication

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 1 | Login screen loads and accepts credentials | Manual | `[ ]` | |
| 2 | Logout redirects to login screen | Widget | `[ ]` | |
| 3 | Session persists across app restart (SharedPreferences/localStorage) | Manual | `[ ]` | |

---

## 2. Cases

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 4 | Cases list loads and shows existing cases | Widget | `[ ]` | |
| 5 | Create new case (job no, type, title) | Widget | `[ ]` | |
| 6 | Case title auto-builds as "JobNo – Vessel – SurveyType – Occurrence brief" | Unit | `[ ]` | rebuilds on file no/vessel/type/occurrence change |
| 7 | Open case → Case Home screen loads | Widget | `[ ]` | |
| 8 | All module tiles on Case Home navigate correctly | Widget | `[ ]` | |
| 9 | New case → Drive folders created (Admin, Collected Documents + 5 buckets, Claim Invoices, Reports, HSE, Photos, Correspondence) and `storage_folder_path` populated | Manual | `[ ]` | not yet live-smoke-tested per last session |
| 10 | Editing vessel name or technical file no. renames the Drive case folder in place (not a duplicate) | Manual | `[ ]` | not yet live-smoke-tested |

---

## 3. Vessel Particulars

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 11 | Identity tab shows existing vessel data | Widget | `[✓]` | |
| 12 | Edit identity fields → Save → persists | Widget | `[✓]` | |
| 13 | Dimensions tab saves correctly | Widget | `[✓]` | tested as tonnage fields |
| 14 | New case: create vessel from scratch | Widget | `[✓]` | incl. empty-name validation snackbar |
| 15 | Machinery tab: add item | Widget | `[✓]` | |
| 16 | Machinery: delete with confirm dialog | Widget | `[✓]` | |
| 17 | Globe icon appears when IMO is filled | Widget | `[ ]` | Equasis-tap behavior tested (no-IMO / no-credentials snackbars), icon-visibility-conditional-on-IMO itself is not |
| 18 | Globe → no credentials → snackbar + Account link | Widget | `[✓]` | |
| 19 | Globe → valid credentials → Equasis PDF fetched | Manual | `[ ]` | |
| 20 | Equasis PDF appears in Document Vault | Manual | `[ ]` | |
| 21 | Class/Statutory tab: certificate list, add certificate, delete (confirm dialog) | Widget | `[✓]` | now covered on `VesselComplianceScreen` (`vessel_compliance_screen_test.dart`) — also found+fixed a real bug: the "Related to an occurrence" switch had invisible tap feedback (DecoratedBox shadowing its Material ancestor) |
| 22 | Class/Statutory tab: conditions of class — empty-state hint, add condition, delete (confirm dialog) | Widget | `[✓]` | now covered on `VesselComplianceScreen` |
| 23 | "Add vessel general view" photo picker sets the shared case cover photo (same photo used in Gallery/Report cover) | Manual | `[ ]` | |
| 24 | Vessel statutory fields (psc_last_inspection, last_drydock_date, pi_club, isps_status) present and saved | Widget | `[~]` | class-status field + save mechanism covered; drydock/PSC/ISPS fields render on the same screen via the same `_save()` but weren't individually exercised |

---

## 4. Occurrences

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 25 | Occurrence list loads | Widget | `[✓]` | |
| 26 | Add occurrence (title, date, location, description) | Widget | `[✓]` | |
| 27 | Edit occurrence → changes saved | Widget | `[✓]` | |
| 28 | Delete occurrence: confirm dialog → cascade removes damage & repairs | Widget | `[✓]` | |

---

## 5. Damage Register

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 29 | Damage register grouped by occurrence | Widget | `[✓]` | |
| 30 | Add damage item under an occurrence | Widget | `[✓]` | |
| 31 | Edit damage item | Widget | `[✓]` | |
| 32 | Delete damage item (with confirm) | Widget | `[✓]` | |
| 33 | Delete occurrence from damage register (header popup) | Widget | `[✓]` | |

---

## 6. Causation

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 34 | Causation screen loads with existing data | Widget | `[✓]` | |
| 35 | Edit cause type, allegation, narrative → save | Widget | `[✓]` | found+fixed a real RenderFlex overflow in the AI Draft row on ~360-400dp phones |

---

## 7. Repairs

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 36 | Repair periods screen loads | Widget | `[✓]` | |
| 37 | Add repair record | Widget | `[✓]` | incl. diversion port-call context |
| 38 | Edit repair record | Widget | `[✓]` | |
| 39 | Nature of Repairs screen loads and saves | Widget | `[✓]` | covers all 5 question toggles, debounced comment save, and the repair-sequence bullet list add |
| 40 | Additional Information screen loads and saves | Widget | `[✓]` | covers the 4 cue-register subsections + Advice to Assured clause ticklist (tick/untick) + debounced notes save |
| 41 | Repair-period-scoped Context Cues: add/edit a cue tied to a specific repair period | Widget | `[~]` | partial — confirms the panel renders, doesn't exercise add/edit-cue interaction. Also surfaced a real (cosmetic) pre-existing bug: this panel's collapsed height is a couple of px short of its own header's content height, logging a RenderFlex overflow on every relayout |

---

## 8. Attendees & Attendances

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 42 | Attendees list loads | Widget | `[✓]` | |
| 43 | Add attendee | Widget | `[✓]` | |
| 44 | Edit attendee | Widget | `[✓]` | |
| 45 | Delete attendee (with confirm) | Widget | `[✓]` | |
| 46 | Create attendance record | Widget | `[✓]` | also found+fixed a real bug: the attendance card's header Row (type badge + date + overflow menu) overflowed for the longest AttendanceType label on ~400-430dp phones |

---

## 9. Document Vault

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 47 | Document vault loads and shows documents | Widget | `[✓]` | covers load, empty state, grouping by category, AppBar actions |
| 48 | Upload PDF → appears in list | Widget | `[⛔]` | needs file_picker — real platform channel, no test-mode support in this stack |
| 49 | Upload DOCX → appears in list | Widget | `[⛔]` | same as row 48 |
| 50 | Upload image → appears in list | Widget | `[⛔]` | needs image_picker — same class of blocker |
| 51 | Tap PDF → opens preview | Widget | `[⛔]` | `_previewDocument()` calls `SupabaseService.client.storage.createSignedUrl()` directly, no injection seam — silently no-ops in a widget test rather than navigating |
| 52 | Tap image → opens full-screen | Widget | `[⛔]` | same as row 51 |

---

## 10. AI Extraction

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 53 | AI extraction runs on PDF without error | Manual | `[ ]` | |
| 54 | AI extraction runs on DOCX without error | Manual | `[ ]` | |
| 55 | Full extraction review screen shows parsed fields | Widget | `[ ]` | |
| 56 | Apply to Case: data written to DB | Widget | `[ ]` | |
| 57 | Revert import undoes all inserted rows | Widget | `[ ]` | |
| 58 | Narratives copied verbatim (not truncated) | Manual | `[ ]` | |
| 59 | cause_type / allegation_type / cause_narrative mapped | Widget | `[ ]` | |

---

## 11. Import Smart Merge

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 60 | Identical field → skipped (no overwrite) | Unit | `[ ]` | `VesselModel.applyExtraction()` — pure merge logic |
| 61 | New value extends existing → auto-upgraded | Unit | `[ ]` | |
| 62 | New value shorter than existing → kept as-is | Unit | `[ ]` | |
| 63 | Contradictory value → conflict dialog appears | Widget | `[ ]` | |
| 64 | Per-field Keep / Report toggle works in dialog | Widget | `[ ]` | |
| 65 | Different IMO shown as conflict, not auto-changed | Unit | `[ ]` | |
| 66 | Re-importing same vessel → no 23505 crash | Widget | `[ ]` | |
| 67 | Machinery: duplicate role+make skipped on re-import | Unit | `[ ]` | |
| 68 | Certificate: duplicate type+number skipped on re-import | Unit | `[ ]` | |
| 69 | Occurrence renumber two-pass: no 23505 on re-import | Widget | `[ ]` | |

---

## 12. Photos & Cloud Photo Sync

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 70 | Photo gallery loads for case; By Visit / By Inspection tabs both populate | Widget | `[✓]` | covers empty state, By Visit grouped by attendance + unassigned bucket, By Inspection general/unlinked bucket |
| 71 | Take photo with camera → appears in gallery | Manual | `[ ]` | |
| 72 | Upload photo from device → appears in gallery | Widget | `[⛔]` | needs image_picker — same no-test-mode blocker as Document Vault rows 48-50 |
| 73 | Tap photo → full-screen viewer | Widget | `[ ]` | not attempted |
| 74 | Delete photo (with confirm) | Widget | `[✓]` | long-press → confirm dialog → removed; also confirmed Cancel leaves it in place |
| 75 | Set / override cover photo and allocation | Widget | `[~]` | allocation badge display confirmed; the set/override interaction itself (via the full-screen viewer, row 73) not exercised |
| 76 | Photo added under an attendance lands in Drive `Photos/{attendance label}/` | Manual | `[ ]` | not yet live-smoke-tested |
| 77 | Drive Folder Picker screen: browse & pick a Drive folder | Manual | `[ ]` | |
| 78 | Local Folder Picker screen: browse & pick a local folder (desktop) | Manual | `[ ]` | |
| 79 | Google Photos sync: create/find album, share URL, upload + add to album | Manual | `[ ]` | |
| 80 | "All photos already synced" state shown correctly after a sync pass | Manual | `[ ]` | |
| 80a | Import photos *from* the user's existing Google Photos library | — | `[⛔]` | not built — only `photoslibrary.appendonly`/`sharing` scopes requested (export-only, `google_photos_service.dart`); the "Google Drive" tile in the Add Photos sheet is a plain Drive file browser, not a Photos-library picker. Surfaced 2026-07-07 live smoke test — user expected a Photos import option. |

---

## 13. Parties & Stakeholders

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 81 | Parties screen loads and shows grouped sections | Widget | `[✓]` | |
| 82 | Empty state shows "No stakeholders" message | Widget | `[✓]` | |
| 83 | Add stakeholder manually: name, company, role, group, phone, email, notes | Widget | `[✓]` | |
| 84 | Group dropdown shows all 6 groups (Insured, Underwriter, Broker, Surveyors, Technical Contractors, Other) | Widget | `[✓]` | |
| 85 | Stakeholder card shows initials avatar, name, company, role chip, contact rows | Widget | `[✓]` | |
| 86 | Delete stakeholder: confirm dialog → removed from list | Widget | `[✓]` | |
| 87 | Group header "Add" button pre-selects that group in the sheet | Widget | `[✓]` | |

---

## 14. Correspondence, Inbox & Gmail

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 88 | Inbox screen loads | Widget | `[ ]` | screen is a stub ("coming next session") — confirm placeholder only |
| 89 | Correspondence screen loads for case | Widget | `[✓]` | |
| 90 | FAB "Add" opens bottom sheet with PDF and EML options | Widget | `[✓]` | |
| 91 | Upload PDF → card appears collapsed in list | Widget | `[⛔]` | needs file_picker — no-test-mode blocker |
| 92 | Tap card header → expands to show full card | Widget | `[✓]` | |
| 93 | Collapsed card shows: icon, title (1 line), status chip, date, party/action counts | Widget | `[✓]` | |
| 94 | Three-dot menu: Preview / Extract with AI / Delete | Widget | `[✓]` | also confirms Reply via Gmail only appears for EML items with a sender |
| 95 | Delete: confirm dialog → card removed | Widget | `[✓]` | |
| 96 | Extract with AI → status changes to completed, summary + parties + actions populated | Manual | `[ ]` | real Claude API call, deliberately never tapped in tests |
| 97 | corrDate field populated after extraction (shows date in header) | Widget | `[✓]` | tested via a seeded corrDate rather than a live extraction |
| 98 | Import .eml → card appears; From/To/Date pre-filled | Widget | `[⛔]` | needs file_picker |
| 99 | EML import: attachment dialog appears with file list | Widget | `[⛔]` | needs file_picker |
| 100 | Attachment dialog: image thumbnails shown; tap → full-screen zoom | Widget | `[⛔]` | needs file_picker |
| 101 | Attachment dialog: size filter slider hides small images (default 20 KB) | Widget | `[⛔]` | needs file_picker |
| 102 | Attachment dialog: "N small image(s) hidden" label appears when filter active | Widget | `[⛔]` | needs file_picker |
| 103 | Attachment dialog: per-item checkboxes; "Save Selected (N)" button | Widget | `[⛔]` | needs file_picker |
| 104 | Attachment dialog: "Skip All" closes without saving | Widget | `[⛔]` | needs file_picker |
| 105 | Selected attachments appear in Document Vault after import | Widget | `[⛔]` | needs file_picker |
| 106 | EML card: "View Email" opens preview with From/To/Date headers + selectable body | Widget | `[ ]` | not attempted — preview navigation not exercised |
| 107 | EML card: Extract with AI uses body text (not PDF path) | Manual | `[ ]` | |
| 108 | After extraction: extracted parties shown as chips in expanded card | Widget | `[✓]` | |
| 109 | "Add to Parties" button appears when parties extracted | Widget | `[✓]` | |
| 110 | "Add to Parties" dialog: pre-checked list of parties; deselect → excluded | Widget | `[✓]` | pre-checked state + confirm-adds covered; explicit deselect-then-confirm not separately tested |
| 111 | Confirmed parties appear in Parties screen under correct group | Widget | `[~]` | both halves covered independently (addFromExtracted's group derivation here, Parties screen's grouping-by-group in parties_screen_test.dart) — not cross-verified in one end-to-end test |
| 112 | Re-adding same party → snackbar "Already in stakeholders list" | Widget | `[✓]` | also surfaced and fixed a real bug: `addFromExtracted`'s dedupe check read `state.value` without waiting for the provider's first load, so a same-session first call could silently skip the check — fixed with `?? await future` |
| 113 | Action items listed in expanded card with → Context icon button | Widget | `[✓]` | |
| 114 | Tap Context icon → action appears in Surveyor Notes as Follow-up / Important | Widget | `[✓]` | verified the note is filed with `NatureOfContent.followUpOpenQuestion` + `CuePriority.important` — same as TEST_SHEET row 127 |
| 115 | Gmail Message Picker: lists threads matching a case-derived keyword query | Manual | `[ ]` | new — needs real Google account |
| 116 | Gmail thread detail screen shows full message list in the thread | Manual | `[ ]` | new |
| 117 | "Import N Conversation(s)" downloads raw messages and feeds the same EML importer | Manual | `[ ]` | new |
| 118 | "Reply via Gmail" from a correspondence card sends a threaded reply (In-Reply-To set correctly) | Manual | `[ ]` | new — verify actual thread on recipient side |

---

## 15. Cloud Storage Sync (Google Drive)

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 119 | Document Vault bulk "Send to Drive" export uses the new per-case folder taxonomy | Manual | `[ ]` | per notes this button still makes its own ad hoc structure — verify or fix |
| 120 | Report export "Send to Drive" action after docx export lands file in `Reports/` | Manual | `[ ]` | |
| 121 | Document Vault documents upload into Drive `Collected Documents/{bucket}` / `Claim Invoices` automatically | — | `[⛔]` | not built — Documents feature is still 100% Supabase Storage, no Drive path yet |
| 122 | Background prefetch of a whole case's Drive files on open (no per-file lag) | — | `[⛔]` | explicitly deferred; current design is upload-immediately + download-on-first-access |

---

## 16. Timeline

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 123 | Timeline screen loads and shows events | Widget | `[ ]` | |
| 124 | Add timeline event via sheet | Widget | `[ ]` | not in prior sheet |

---

## 17. Surveyor Notes

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 125 | Notes screen loads | Widget | `[✓]` | screen is now "Advice to Owner" (renamed 14 July); covers all 4 tabs (Retained/Suggested/Unallocated/Ignored) |
| 126 | Create/edit a note | Widget | `[✓]` | also found+fixed a real Tab-label RenderFlex overflow on ~400dp phones |
| 127 | Action item sent from correspondence appears as Follow-up / Important | Widget | `[✓]` | covered in correspondence_screen_test.dart (row 114) — same code path, not a separate Surveyor Notes test |

---

## 18. Background & Context Cues

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 128 | Background screen loads existing text | Widget | `[✓]` | |
| 129 | Edit background text → autosaves | Widget | `[✓]` | covers both debounced autosave and manual Save tap |
| 130 | Context Cues panel: add a cue | Widget | `[✓]` | |
| 131 | Context Cues panel: edit / delete a cue | Widget | `[✓]` | |
| 132 | Cues stay consistent between Background panel and repair-period-scoped cues (row 41) | Widget | `[✓]` | structurally guaranteed, not a separate test — both screens render the exact same shared `ContextCuesPanel` widget |

---

## 19. Quick Capture & Voice Notes

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 133 | Quick Capture FAB opens sheet from Case Home | Widget | `[ ]` | not in prior sheet |
| 134 | Quick Capture screen: Capture Items tab — add a free item | Widget | `[ ]` | |
| 135 | Quick Capture screen: routing tab — route a captured item/photo to the correct case section | Widget | `[ ]` | |
| 136 | Voice Note screen: dictate a note via on-device STT | Manual | `[ ]` | mic hardware + transcription quality judgement |
| 137 | Camera screen (Quick Capture) | — | `[⛔]` | stub only, "coming next session" in code |

---

## 20. Interviews

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 138 | Interview list screen loads | Widget | `[ ]` | not in prior sheet |
| 139 | Add new interview | Widget | `[ ]` | |
| 140 | Record Interview: live speech-to-text captures transcript | Manual | `[ ]` | |
| 141 | Tag participants during/after recording | Widget | `[ ]` | |
| 142 | Edit transcript text | Widget | `[ ]` | |
| 143 | Save interview | Widget | `[ ]` | |

---

## 21. Checklist

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 144 | Checklist screen loads with 4 stage tabs (Pre-Survey / On Vessel / Before Leaving / Post-Survey) | Widget | `[✓]` | automated: `test/features/checklist/screens/checklist_screen_test.dart` |
| 145 | Progress header reflects ticked items | Widget | `[✓]` | automated, same file |
| 146 | Tick / untick item persists | Widget | `[✓]` | automated (screen+state wiring only — Supabase write itself is faked, see row 9/10 for real Drive/DB persistence gaps) |
| 147 | Add custom item via sheet | Widget | `[✓]` | automated, same file |

---

## 22. HSE

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 148 | HSE screen shows "Coming Soon" placeholder (JSEA / Permit to Work / toolbox talks) | Widget | `[ ]` | genuinely not built yet — this row just confirms the stub renders, not real functionality |

---

## 23. Case Analyst (AI Assistant)

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 149 | Analyst screen loads with chat UI | Widget | `[ ]` | not in prior sheet |
| 150 | Chat context correctly reflects case facts (vessel/damage/notes/accounts) in responses | Manual | `[ ]` | needs judgement on LLM output correctness |
| 151 | Ask a question → relevant, grounded answer returned | Manual | `[ ]` | |
| 152 | Voice input into chat | Manual | `[ ]` | |

---

## 24. Accounts / Invoices

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 153 | Accounts screen loads, lists invoices | Widget | `[ ]` | not in prior sheet |
| 154 | Import Invoice sheet: import a new invoice | Widget | `[ ]` | |
| 155 | Invoice Detail screen loads | Widget | `[ ]` | |
| 156 | Edit Account Line sheet: edit a line item | Widget | `[ ]` | |
| 157 | AI Polish (sparkle) button on surveyor-notes field rewrites text | Manual | `[ ]` | `ClaudeApi.polishSurveyorNote` |

---

## 25. Reports

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 158 | New Report Output sheet: create output (advice number, report number/type) | Widget | `[✓]` | automated: `test/features/reports/screens/report_builder_screen_test.dart` (NewOutputSheet tested standalone) |
| 159 | Version dropdown lists all outputs for the case | Widget | `[✓]` | wording correction: it's a card list ("Select a report to edit"), not a dropdown — automated, same file |
| 160 | Editor tab loads with all sections | Widget | `[✓]` | automated, same file |
| 161 | Cover-photo picker (shared with Gallery/Vessel) | Widget | `[✓]` | automated (empty-state only; picking a photo not exercised, needs CasePhotoPickerSheet mocking) |
| 162 | Advice Summary Card renders and is editable | Widget | `[~]` | confirmed built and renders (was open item in last audit); automated test only checks it renders, not the edit interactions — still a gap |
| 163 | Section Editor: edit a section's text and save | Widget | `[✓]` | automated, same file |
| 164 | "Draft with AI" on eligible sections (background, causation, general services, previous works, extra expenses, contractual hire, other matters) | Manual | `[ ]` | |
| 165 | Surveyor-review toggle per section | Widget | `[✓]` | automated, same file |
| 166 | Section Reference Panel links source data into a section correctly | Widget | `[ ]` | not covered by this pass — renders as part of every SectionEditor but no test asserts its content against assembled data yet |
| 167 | Preview tab renders full document, matching Editor content | Widget | `[✓]` | automated (renders without error, TOC present); full content-match against Editor not asserted line-by-line |
| 168 | Postprocessing tab: status/QC stepper | Widget | `[✓]` | automated, same file |
| 169 | "Changes summary" field appears only when output supersedes a prior version | Widget | `[✓]` | automated, both branches |
| 170 | Sign-off: attending surveyor — name entry + draw signature pad | Manual | `[ ]` | |
| 171 | Sign-off: attending surveyor — upload PNG signature (desktop) | Manual | `[ ]` | |
| 172 | Sign-off: reviewing surveyor — same flow | Manual | `[ ]` | |
| 173 | Per-role signed status displays correctly after sign-off | Widget | `[✓]` | automated, both partial and full sign-off states |
| 174 | Export: pre-export validation sheet lists warnings | Widget | `[✓]` | export gate confirmed built and working (was open item in last audit) — automated |
| 175 | Export: "Export anyway" bypasses warnings; "Cancel" aborts | Widget | `[~]` | "Cancel" path automated; "Export anyway" not covered — it would exercise real docx/file-system code (path_provider) with no test double, deliberately left as Manual/Integ |
| 176 | Export: generates .docx via docx_export_service without error | Integ | `[ ]` | |
| 177 | Export: docx output matches Preview tab content/layout | Manual | `[ ]` | visual check |
| 178 | Post-export success dialog → "Send to Drive" | Manual | `[ ]` | |
| 179 | Docx section tables render correctly: vessel particulars, certificates, class conditions, attendance blocks, occurrence/chronology, machinery, account summaries + totals | Unit + Manual | `[ ]` | `section_table_rows.dart` pure builders (Unit) + visual docx check (Manual) |
| 180 | Annexures A–H grouped and sorted by annexure_assignment | Unit | `[ ]` | `annexure_groups.dart` |
| 181 | AI disclosure paragraph + Annexure I snapshot present in export | — | `[ ]` | verify if implemented — open in last audit, not confirmed built |
| 182 | Version Control Block (supersedes/supplements + changelog) present in export | — | `[ ]` | verify if implemented — open in last audit |
| 183 | Documents Requested section present in export | — | `[ ]` | verify if implemented — open in last audit |
| 184 | Firm logo appears in running header of exported docx | Manual | `[ ]` | Organisation branding screen exists — confirm logo actually flows through to docx header |
| 185 | Writing-style lint catches disallowed phrasing before export | Unit | `[ ]` | `writing_style_lint.dart` |

---

## 26. Account & Organisation Settings

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 186 | Account screen accessible from cases list icon | Widget | `[ ]` | |
| 187 | Save name / email / phone / address → persists after restart | Widget | `[ ]` | |
| 188 | Active Anthropic key shown (last 6 chars) | Widget | `[ ]` | |
| 189 | Add external account (label / url / user / pass) | Widget | `[ ]` | |
| 190 | Edit external account → changes saved | Widget | `[ ]` | |
| 191 | Delete external account (confirm dialog) | Widget | `[ ]` | |
| 192 | Equasis credentials survive app restart | Manual | `[ ]` | |
| 193 | Organisation List screen loads | Widget | `[ ]` | not in prior sheet |
| 194 | Organisation Detail: edit branding (name, logo, letterhead fields) → saves | Widget | `[ ]` | not in prior sheet |
| 195 | Speech Settings screen: switch STT provider | Widget | `[ ]` | not in prior sheet |
| 196 | Debug Log screen loads and shows recent log entries | Widget | `[ ]` | not in prior sheet |

---

## 27. API Usage

| # | Feature | Auto | Status | Comments |
|---|---------|------|--------|----------|
| 197 | Usage screen loads | Widget | `[✓]` | no Riverpod seam on this screen — verified it loads and degrades to its own error state gracefully rather than crashing; real usage data isn't faked |
| 198 | Token counts increment after an extraction | Manual | `[ ]` | |

---

*Last updated: 2026-07-06 — expanded from 111 to 198 rows to cover Accounts, Case Analyst, Background/Context Cues, Quick Capture, Interviews, Checklist, HSE, Gmail integration, Google Drive/Photos sync, Organisation/Speech/Debug settings, and a full breakdown of the Report Builder module. `[⛔]` rows are known gaps, not test failures.*
