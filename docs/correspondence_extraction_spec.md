# Correspondence extraction → structured import (spec)

**Goal:** bring correspondence AI-extraction to **parity with document extraction** —
a per-item **selector switch** review sheet where the surveyor imports only the
relevant extracted data, each toggle writing into the correct record/table.

**Current gap (verified 23 July):** `correspondence_provider.dart:471`
(`_persist`) is where it stops. Extraction detects dates, parties, actions, etc.
but persists them **only as JSON columns on the `correspondence` row** and returns
4 case-header refs. No fan-out, no cues, no timeline/attendance/occurrence records.
The document pipeline's per-entity write-back (`document_vault_screen.dart`
`_ExtractionResultSheet._apply`) has no correspondence equivalent.

---

## Landing map — every extractable field → where it lands

Each row becomes one or more **switches** in the correspondence review sheet.
"Ready" = an existing public provider method to call (no new persistence code).

| Extracted data | DB table | Provider . method | Screen | Status |
|---|---|---|---|---|
| Case file no / claim ref / instruction date | `cases` | `caseProvider.updateCaseRefs(...)` | Case header | ✅ Ready (already applied via `ExtractedCaseRefs`) |
| Vessel name | `vessels.name` | `caseProvider.upsertVesselName(name)` | Vessel | ✅ Ready |
| Vessel particulars (IMO, flag, tonnage…) | `vessels` | `vesselForCaseProvider.applyExtraction(...)` | Vessel Particulars | ✅ Ready (needs richer schema) |
| Parties / contacts (people, companies, roles) | `assured_contacts` / `case_parties` | `assuredContactsProvider.addFromExtractedContacts(...)` / `partiesProvider.save(...)` | Parties | ✅ Ready |
| Key date — **event** | `timeline_events` (+ `timeline_event_ratings`) | `timelineProvider.add(TimelineEventModel)` + `timelineRatingsProvider.setRelevance(...)` | Timeline | ✅ Ready |
| Key date — **attendance** | `survey_attendances` (+ `attendees`) | `attendancesProvider.add({...})` + `attendeesProvider.addAttendee(...)` | Attendances | ✅ Ready |
| Incident / occurrence | `occurrences` | `damageProvider.createOccurrence({...})` | Occurrence | ✅ Ready |
| Damage | `damage_items` | `damageProvider.addDamageItem(...)` | Damage Register | ⚠️ Needs a parent occurrence first |
| Action item / follow-up | `action_items` | `actionItemsProvider.addSuggested(caseId, text, sourceId:)` (`pending_review`, `source_type:'correspondence'`) | Action Items | ✅ Ready (no assignee field) |
| Context finding (narrative snippet, section-tagged) | `surveyor_notes` (= context cues) | `surveyorNotesProvider.add(... caseSection:, pendingReview:true)` | Context cues (per section) | ✅ Ready — **this is the missing "cues" piece** |
| Background narrative | `case_background` | `backgroundProvider.save(content)` | Background | ⚠️ Upsert-replace — must read-modify-write to append |
| Repair / repair period | `repairs` / `repair_periods` | `damageProvider.addRepair(...)` / `repairPeriodsProvider.addPeriod(...)` | Repairs | ⚠️ `repairs` needs a parent occurrence |
| Cost — estimate line | `case_cost_estimate_items` | `costEstimateItemsProvider.addItem({category, description, amount})` | Accounts | ✅ Ready |
| Cost — invoice line (loose, no PDF) | `account_lines` | — needs parent `repair_documents` (invoice) | Accounts | ❌ No path for a bare emailed cost line without a PDF |
| Email attachment (file) | `documents` | `documentProvider.uploadAndCreate(... sourceCorrespondenceId:)` → auto-extracts | Doc Vault | ✅ Already wired (attachments already file + extract) |

**Relevance note (your timeline feedback):** timeline events carry a **separate**
relevance rating (`timeline_event_ratings`, `EventRelevance.important` vs full-log).
Correspondence-derived events should default to **not** important (full-log only) —
this is exactly your "correspondence shouldn't pollute the important timeline" note.

---

## What must be built

1. **Enrich the correspondence extraction schema** (`ClaudeApi.extractCorrespondence*`
   in `claude_api.dart`). Today: `summary, parties, key_dates, action_items,
   decisions, + header refs`. Add, per item, the fields needed to route it:
   - `key_dates[]` → tag each with `kind: event | attendance` (+ location for
     attendance) so it routes to timeline vs survey_attendances.
   - `context_findings[]` → `{text, case_section, note_category}` (mirror the
     document schema) so they become section-tagged cues.
   - `detected_incidents[]`, `detected_contacts[]` (with role) — mirror document
     schema so occurrences/parties can be created.
   - keep `action_items`, header refs, `summary` as-is.
2. **A review sheet** (`_CorrespondenceExtractionSheet`, mirroring the document
   `_ExtractionResultSheet`) — one **switch per extracted item**, grouped by type,
   with sensible defaults (header refs on; findings/dates on; occurrences off until
   reviewed; correspondence timeline events default full-log-only).
3. **Write-back fan-out** on "Import selected" — call the Ready provider methods
   above for each enabled item; skip/dedupe existing.
4. **Durable state** — reuse the document `pending_extraction`/`ready_for_review`
   pattern so an auto-extracted email can be reviewed later, not just inline.

## Decisions needed (the ⚠️/❌ rows)

- **Loose cost lines** (emailed figure, no invoice PDF): route to a cost **estimate**
  item, or skip cost extraction for now? (Bare `account_lines` needs a parent
  invoice doc — new code otherwise.)
- **Background narrative**: append (read-modify-write) vs skip auto-import (leave
  background as a manual field)?
- **Damage / repairs**: only offer these switches when a parent occurrence is also
  being imported (they require an `occurrence_id`).

---

*Reference maps: document pipeline (`document_vault_screen.dart:1280-1643`),
correspondence gap (`correspondence_provider.dart:471`). Ties to OUTSTANDING.md §10
(start-from-email, auto-summaries, extraction-doesn't-persist).*
