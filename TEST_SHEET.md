# Marine Survey App — Test Sheet

Status legend: `[ ]` Not tested · `[✓]` OK · `[~]` Partial · `[✗]` Broken

---

## Authentication

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Login screen loads and accepts credentials | `[ ]` | |
| 2 | Logout redirects to login screen | `[ ]` | |

---

## Cases

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 3 | Cases list loads and shows existing cases | `[ ]` | |
| 4 | Create new case (job no, type, title) | `[ ]` | |
| 5 | Open case → case home screen loads | `[ ]` | |
| 6 | All module tiles on case home navigate correctly | `[ ]` | |

---

## Vessel Particulars

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 7 | Identity tab shows existing vessel data | `[ ]` | |
| 8 | Edit identity fields → Save → persists | `[ ]` | |
| 9 | Dimensions tab saves correctly | `[ ]` | |
| 10 | New case: create vessel from scratch | `[ ]` | |
| 11 | Machinery tab: add item | `[ ]` | |
| 12 | Machinery: delete with confirm dialog | `[ ]` | |
| 13 | Globe icon appears when IMO is filled | `[ ]` | |
| 14 | Globe → no credentials → snackbar + Account link | `[ ]` | |
| 15 | Globe → valid credentials → Equasis PDF fetched | `[ ]` | |
| 16 | Equasis PDF appears in Document Vault | `[ ]` | |

---

## Occurrences

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 17 | Occurrence list loads | `[ ]` | |
| 18 | Add occurrence (title, date, location, description) | `[ ]` | |
| 19 | Edit occurrence → changes saved | `[ ]` | |
| 20 | Delete occurrence: confirm dialog → cascade removes damage & repairs | `[ ]` | |

---

## Damage Register

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 21 | Damage register grouped by occurrence | `[ ]` | |
| 22 | Add damage item under an occurrence | `[ ]` | |
| 23 | Edit damage item | `[ ]` | |
| 24 | Delete damage item (with confirm) | `[ ]` | |
| 25 | Delete occurrence from damage register (header popup) | `[ ]` | |

---

## Causation

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 26 | Causation screen loads with existing data | `[ ]` | |
| 27 | Edit cause type, allegation, narrative → save | `[ ]` | |

---

## Repairs

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 28 | Repair periods screen loads | `[ ]` | |
| 29 | Add repair record | `[ ]` | |
| 30 | Edit repair record | `[ ]` | |

---

## Attendees & Attendances

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 31 | Attendees list loads | `[ ]` | |
| 32 | Add attendee | `[ ]` | |
| 33 | Edit attendee | `[ ]` | |
| 34 | Delete attendee (with confirm) | `[ ]` | |
| 35 | Create attendance record | `[ ]` | |

---

## Document Vault

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 36 | Document vault loads and shows documents | `[ ]` | |
| 37 | Upload PDF → appears in list | `[ ]` | |
| 38 | Upload DOCX → appears in list | `[ ]` | |
| 39 | Upload image → appears in list | `[ ]` | |
| 40 | Tap PDF → opens preview | `[ ]` | |
| 41 | Tap image → opens full-screen | `[ ]` | |

---

## AI Extraction

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 42 | AI extraction runs on PDF without error | `[ ]` | |
| 43 | AI extraction runs on DOCX without error | `[ ]` | |
| 44 | Full extraction review screen shows parsed fields | `[ ]` | |
| 45 | Apply to Case: data written to DB | `[ ]` | |
| 46 | Revert import undoes all inserted rows | `[ ]` | |
| 47 | Narratives copied verbatim (not truncated) | `[ ]` | |
| 48 | cause_type / allegation_type / cause_narrative mapped | `[ ]` | |

---

## Import Smart Merge

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 49 | Identical field → skipped (no overwrite) | `[ ]` | |
| 50 | New value extends existing → auto-upgraded | `[ ]` | |
| 51 | New value shorter than existing → kept as-is | `[ ]` | |
| 52 | Contradictory value → conflict dialog appears | `[ ]` | |
| 53 | Per-field Keep / Report toggle works in dialog | `[ ]` | |
| 54 | Different IMO shown as conflict, not auto-changed | `[ ]` | |
| 55 | Re-importing same vessel → no 23505 crash | `[ ]` | |
| 56 | Machinery: duplicate role+make skipped on re-import | `[ ]` | |
| 57 | Certificate: duplicate type+number skipped on re-import | `[ ]` | |
| 58 | Occurrence renumber two-pass: no 23505 on re-import | `[ ]` | |

---

## Photos

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 59 | Photo gallery loads for case | `[ ]` | |
| 60 | Take photo with camera → appears in gallery | `[ ]` | |
| 61 | Upload photo from device → appears in gallery | `[ ]` | |
| 62 | Tap photo → full-screen viewer | `[ ]` | |

---

## Parties & Stakeholders

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 63 | Parties screen loads and shows grouped sections | `[ ]` | |
| 64 | Empty state shows "No stakeholders" message | `[ ]` | |
| 65 | Add stakeholder manually: name, company, role, group, phone, email, notes | `[ ]` | |
| 66 | Group dropdown shows all 6 groups (Insured, Underwriter, Broker, Surveyors, Technical Contractors, Other) | `[ ]` | |
| 67 | Stakeholder card shows initials avatar, name, company, role chip, contact rows | `[ ]` | |
| 68 | Delete stakeholder: confirm dialog → removed from list | `[ ]` | |
| 69 | Group header "Add" button pre-selects that group in the sheet | `[ ]` | |

---

## Correspondence & Inbox

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 70 | Inbox screen loads | `[ ]` | |
| 71 | Correspondence screen loads for case | `[ ]` | |
| 72 | FAB "Add" opens bottom sheet with PDF and EML options | `[ ]` | |
| 73 | Upload PDF → card appears collapsed in list | `[ ]` | |
| 74 | Tap card header → expands to show full card | `[ ]` | |
| 75 | Collapsed card shows: icon, title (1 line), status chip, date, party/action counts | `[ ]` | |
| 76 | Three-dot menu: Preview / Extract with AI / Delete | `[ ]` | |
| 77 | Delete: confirm dialog → card removed | `[ ]` | |
| 78 | Extract with AI → status changes to completed, summary + parties + actions populated | `[ ]` | |
| 79 | corrDate field populated after extraction (shows date in header) | `[ ]` | |
| 80 | Import .eml → card appears; From/To/Date pre-filled | `[ ]` | |
| 81 | EML import: attachment dialog appears with file list | `[ ]` | |
| 82 | Attachment dialog: image thumbnails shown; tap → full-screen zoom | `[ ]` | |
| 83 | Attachment dialog: size filter slider hides small images (default 20 KB) | `[ ]` | |
| 84 | Attachment dialog: "N small image(s) hidden" label appears when filter active | `[ ]` | |
| 85 | Attachment dialog: per-item checkboxes; "Save Selected (N)" button | `[ ]` | |
| 86 | Attachment dialog: "Skip All" closes without saving | `[ ]` | |
| 87 | Selected attachments appear in Document Vault after import | `[ ]` | |
| 88 | EML card: "View Email" opens preview with From/To/Date headers + selectable body | `[ ]` | |
| 89 | EML card: Extract with AI uses body text (not PDF path) | `[ ]` | |
| 90 | After extraction: extracted parties shown as chips in expanded card | `[ ]` | |
| 91 | "Add to Parties" button appears when parties extracted | `[ ]` | |
| 92 | "Add to Parties" dialog: pre-checked list of parties; deselect → excluded | `[ ]` | |
| 93 | Confirmed parties appear in Parties screen under correct group | `[ ]` | |
| 94 | Re-adding same party → snackbar "Already in stakeholders list" | `[ ]` | |
| 95 | Action items listed in expanded card with → Context icon button | `[ ]` | |
| 96 | Tap Context icon → action appears in Surveyor Notes as Follow-up / Important | `[ ]` | |

---

## Timeline

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 97 | Timeline screen loads and shows events | `[ ]` | |

---

## Surveyor Notes

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 98 | Notes screen loads | `[ ]` | |
| 99 | Create/edit a note | `[ ]` | |
| 100 | Action item sent from correspondence appears as Follow-up / Important | `[ ]` | |

---

## Timesheet

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 101 | Timesheet screen loads | `[ ]` | |

---

## Reports

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 102 | Report builder screen loads | `[ ]` | |

---

## Account Settings

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 103 | Account screen accessible from cases list icon | `[ ]` | |
| 104 | Save name / email / phone / address → persists after restart | `[ ]` | |
| 105 | Active Anthropic key shown (last 6 chars) | `[ ]` | |
| 106 | Add external account (label / url / user / pass) | `[ ]` | |
| 107 | Edit external account → changes saved | `[ ]` | |
| 108 | Delete external account (confirm dialog) | `[ ]` | |
| 109 | Equasis credentials survive app restart | `[ ]` | |

---

## API Usage

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 110 | Usage screen loads | `[ ]` | |
| 111 | Token counts increment after an extraction | `[ ]` | |

---

*Last updated: 2026-06-23*
