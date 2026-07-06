# Manual QA Checklist

Generated from `TEST_SHEET.md` — every row tagged `Manual` there (i.e. it needs a real
Google account, camera/mic hardware, live LLM output judgement, or a visual check that
can't be scripted). Everything NOT on this list is either already automated
(`test/`), a known gap (`[⛔]` in TEST_SHEET.md), or still pending Widget-test
automation (see TEST_SHEET.md `Auto` column — not yet built).

Check items off as you go; row numbers match `TEST_SHEET.md` so you can cross-reference
comments/context there.

---

## Authentication
- [ ] [1] Login screen loads and accepts credentials
- [ ] [3] Session persists across app restart (SharedPreferences/localStorage)

## Cases
- [ ] [9] New case → Drive folders created (Admin, Collected Documents + 5 buckets, Claim Invoices, Reports, HSE, Photos, Correspondence) and `storage_folder_path` populated — not yet live-smoke-tested
- [ ] [10] Editing vessel name or technical file no. renames the Drive case folder in place (not a duplicate) — not yet live-smoke-tested

## Vessel Particulars
- [ ] [19] Globe → valid credentials → Equasis PDF fetched
- [ ] [20] Equasis PDF appears in Document Vault
- [ ] [23] "Add vessel general view" photo picker sets the shared case cover photo (same photo used in Gallery/Report cover)

## AI Extraction
- [ ] [53] AI extraction runs on PDF without error
- [ ] [54] AI extraction runs on DOCX without error
- [ ] [58] Narratives copied verbatim (not truncated)

## Photos & Cloud Photo Sync
- [ ] [71] Take photo with camera → appears in gallery
- [ ] [76] Photo added under an attendance lands in Drive `Photos/{attendance label}/` — not yet live-smoke-tested
- [ ] [77] Drive Folder Picker screen: browse & pick a Drive folder
- [ ] [78] Local Folder Picker screen: browse & pick a local folder (desktop)
- [ ] [79] Google Photos sync: create/find album, share URL, upload + add to album
- [ ] [80] "All photos already synced" state shown correctly after a sync pass

## Correspondence, Inbox & Gmail
- [ ] [96] Extract with AI → status changes to completed, summary + parties + actions populated
- [ ] [107] EML card: Extract with AI uses body text (not PDF path)
- [ ] [115] Gmail Message Picker: lists threads matching a case-derived keyword query — needs real Google account
- [ ] [116] Gmail thread detail screen shows full message list in the thread
- [ ] [117] "Import N Conversation(s)" downloads raw messages and feeds the same EML importer
- [ ] [118] "Reply via Gmail" from a correspondence card sends a threaded reply (In-Reply-To set correctly) — verify actual thread on recipient side

## Cloud Storage Sync (Google Drive)
- [ ] [119] Document Vault bulk "Send to Drive" export uses the new per-case folder taxonomy — per notes this button still makes its own ad hoc structure, verify or fix
- [ ] [120] Report export "Send to Drive" action after docx export lands file in `Reports/`

## Quick Capture & Voice Notes
- [ ] [136] Voice Note screen: dictate a note via on-device STT

## Interviews
- [ ] [140] Record Interview: live speech-to-text captures transcript

## Case Analyst (AI Assistant)
- [ ] [150] Chat context correctly reflects case facts (vessel/damage/notes/accounts) in responses
- [ ] [151] Ask a question → relevant, grounded answer returned
- [ ] [152] Voice input into chat

## Accounts / Invoices
- [ ] [157] AI Polish (sparkle) button on surveyor-notes field rewrites text (`ClaudeApi.polishSurveyorNote`)

## Reports
- [ ] [164] "Draft with AI" on eligible sections (background, causation, general services, previous works, extra expenses, contractual hire, other matters)
- [ ] [170] Sign-off: attending surveyor — name entry + draw signature pad
- [ ] [171] Sign-off: attending surveyor — upload PNG signature (desktop)
- [ ] [172] Sign-off: reviewing surveyor — same flow
- [ ] [177] Export: docx output matches Preview tab content/layout (visual check)
- [ ] [178] Post-export success dialog → "Send to Drive"
- [ ] [184] Firm logo appears in running header of exported docx — confirm logo actually flows through to the header, not just the branding screen

## Account & Organisation Settings
- [ ] [192] Equasis credentials survive app restart

## API Usage
- [ ] [198] Token counts increment after an extraction

---

*39 rows. Regenerate this list from TEST_SHEET.md if it changes — grep for `| Manual |`.*
