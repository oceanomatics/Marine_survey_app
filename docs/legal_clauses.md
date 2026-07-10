# London H&M Report — Legal Clauses & Conditional Language Schema

> **Purpose:** This schema captures every legally material clause, conditional phrase, and structured selection in the ABL London H&M report template. Each section documents the verbatim clause text, the decision trigger logic, required input fields, and the output rule. Designed for programmatic implementation and AI-assisted drafting.

---

## HOW TO USE THIS SCHEMA

Each block below follows this structure:

```
CLAUSE ID      — unique reference
TRIGGER        — what situation/fact selects this clause
FIELDS         — data inputs required (vessel, dates, parties, etc.)
VERBATIM TEXT  — the exact clause text from the template (with {field} placeholders substituted)
OUTPUT RULE    — which variant to use, or whether to omit entirely
```

Fields use `{FIELD_NAME}` notation throughout.

---

## PART A — VESSEL & CASE IDENTIFICATION FIELDS

These fields are referenced across multiple clauses. They must be resolved first.

| Field ID | Label | Type | Notes |
|---|---|---|---|
| `{VESSEL_NAME}` | Vessel name | Text | In quotes, e.g. `"SHIP NAME"` |
| `{REPORT_TITLE}` | Report title | Text | Describes casualty/damage type |
| `{JOB_NO}` | Job number | Text | Format: `LO-MXX-XXXX` |
| `{REPORT_NO}` | Report number | Text | Format: `LO-MXX-XXXX-RXXX` |
| `{INST_DATE}` | Instruction date | Date | Date surveyor was instructed |
| `{REPORT_DATE}` | Report date | Date | Date report is issued |
| `{DOL}` | Date of loss / casualty date | Date | |
| `{CASUALTY_LOCATION}` | Location of casualty | Text | Port, sea area, coordinates |
| `{CASUALTY_NATURE}` | Nature of casualty | Text | e.g. engine failure, grounding |
| `{OWNERS}` | Vessel owners | Text | Full legal name |
| `{FLAG}` | Flag state | Text | |
| `{PORT_OF_REGISTRY}` | Port of registry | Text | |
| `{IMO_NO}` | IMO number | Text | |
| `{CLASS_SOCIETY}` | Classification society | Text | e.g. Lloyd's Register, DNV |
| `{GT}` | Gross tonnage | Number | |
| `{NT}` | Net tonnage | Number | |
| `{DWT}` | Deadweight tonnage | Number | Tonnes |
| `{LOA}` | Length overall | Number | Metres |
| `{LBP}` | Length between perpendiculars | Number | Metres |
| `{BEAM}` | Breadth / beam | Number | Metres |
| `{DEPTH}` | Moulded depth | Number | Metres |
| `{DRAFT}` | Service/loaded/summer draft | Number | Metres |
| `{BUILD_YEAR}` | Year built | Year | |
| `{BUILD_YARD}` | Shipyard | Text | |
| `{SERVICE_SPEED}` | Loaded service speed | Number | Knots |
| `{PRIME_MOVER_COUNT}` | Number of main engines | Integer | |
| `{ENGINE_MAKE_MODEL}` | Engine make and model | Text | |
| `{ENGINE_TYPE}` | Engine type | Text | e.g. 4-stroke, 2-stroke diesel |
| `{ENGINE_MCR_KW}` | MCR in kW | Number | |
| `{ENGINE_MCR_BHP}` | MCR in BHP | Number | |
| `{ENGINE_MCR_RPM}` | MCR RPM | Number | |
| `{ENGINE_BUILDER}` | Engine builder | Text | |
| `{FUEL_TYPE}` | Fuel type | Text | e.g. HFO, MGO, LNG |
| `{DOC_ISSUER}` | DOC issuing authority | Text | |
| `{DOC_ISSUE_DATE}` | DOC issue date | Date | |
| `{DOC_EXPIRY}` | DOC expiry date | Date | |
| `{SMC_ISSUER}` | SMC issuing authority | Text | |
| `{SMC_ISSUE_DATE}` | SMC issue date | Date | |
| `{SMC_EXPIRY}` | SMC expiry date | Date | |
| `{LAST_DD_YARD}` | Last drydock yard | Text | |
| `{LAST_DD_DATE}` | Last drydock date | Date | |
| `{CURRENCY_CODE}` | Currency code | Text | e.g. USD, GBP, AUD |

---

## PART B — SURVEY TYPE PREAMBLE

### CLAUSE B-1 — Certification Opening

**Verbatim text (template):**

> THIS IS TO CERTIFY

**Trigger:** Always included. Fixed heading. No logic required.

---

### CLAUSE B-2 — Survey Type Description

**Trigger logic:**

| Condition | Select variant |
|---|---|
| Machinery / engine damage | Use: `"a machinery damage survey"` |
| Hull / structural damage | Use: `"a hull damage survey"` |
| Grounding damage | Use: `"a grounding damage survey"` |
| Combined hull and machinery | Use: `"a hull and machinery damage survey"` |
| Collision / RDC | Use: `"a collision damage survey"` |
| Fire damage | Use: `"a fire damage survey"` |

**Fields required:** `{SURVEY_TYPE}`, `{PROPULSION_TYPE}`, `{VESSEL_TYPE}`

**Output structure:**

> Survey type , propulsion type, type: — `{VESSEL_TYPE}`, `{PROPULSION_TYPE}` `{SURVEY_TYPE}`

---

## PART C — VESSEL DESCRIPTION CLAUSES

### CLAUSE C-1 — Ship Type Selection

**Trigger logic:**

| Vessel type | Output phrase |
|---|---|
| General cargo vessel | `"She is a general cargo vessel"` |
| Bulk carrier | `"She is a bulk carrier"` |
| Container vessel | `"She is a container vessel"` |
| Tanker (oil) | `"She is an oil tanker"` |
| Tanker (chemical) | `"She is a chemical tanker"` |
| Offshore support vessel | `"She is an offshore supply / support vessel"` |
| Tug | `"She is a tug"` |
| Passenger vessel | `"She is a passenger vessel"` |
| Ro-Ro / ferry | `"She is a Ro-Ro passenger ferry"` |
| Fishing vessel | `"She is a fishing vessel"` |

**Output structure:**

> Choose ship. It was built during `{BUILD_YEAR}` in `{BUILD_YARD}` and has a loaded service speed of `{SERVICE_SPEED}` knots.

---

### CLAUSE C-2 — Beam / Breadth Label Selection

**Trigger logic:**

| Dimension available | Label |
|---|---|
| Moulded breadth | `"Breadth (Mld)"` |
| Extreme breadth | `"Breadth (Ext)"` |

---

### CLAUSE C-3 — Draft Label Selection

**Trigger logic:**

| Draft type | Label |
|---|---|
| Summer load line draft | `"Draft (Summer)"` |
| Loaded service draft | `"Draft (Loaded)"` |
| Maximum draft | `"Draft (Maximum)"` |

---

### CLAUSE C-4 — Propeller Type Selection

**Trigger logic:**

| Propeller type | Output phrase |
|---|---|
| Fixed pitch propeller | `"Fixed Pitch Propeller (FPP)"` |
| Controllable pitch propeller | `"Controllable Pitch Propeller (CPP)"` |
| Azimuth / pod thruster | `"Azimuthing Thruster"` |
| Voith Schneider | `"Voith Schneider Propeller"` |

---

### CLAUSE C-5 — Drive Train Selection

**Trigger logic:**

| Drive type | Output phrase |
|---|---|
| Direct-coupled engine to shaft | `"Direct drive"` |
| Gearbox reduction | `"Via reduction gearbox"` |
| Electric drive (diesel-electric) | `"Diesel-electric drive"` |
| Hybrid | `"Hybrid mechanical/electric drive"` |

---

### CLAUSE C-6 — Certification Statements

**These are fixed clauses, included or excluded by condition:**

**C-6a — Class status (always include):**

> The vessel remains classed with `{CLASS_SOCIETY}`.

---

**C-6b — Document of Compliance:**

> Document of Compliance issued by `{DOC_ISSUER}` on `{DOC_ISSUE_DATE}`, valid until `{DOC_EXPIRY}`.

---

**C-6c — Safety Management Certificate:**

> Safety Management Certificate issued by `{SMC_ISSUER}` on `{SMC_ISSUE_DATE}`, valid until `{SMC_EXPIRY}`.

---

**C-6d — SMS Reporting (tick to include):**

**Trigger:** Include only if casualty was formally reported within vessel's SMS.

> The casualty was reported within the company Safety Management System.

---

**C-6e — Last Drydock (always include if known):**

> The Vessel was last drydocked at `{LAST_DD_YARD}` in `{LAST_DD_DATE}`.

---

**C-6f — Statutory Certificate Dropdown:**

**Trigger logic:**

| Certificate status | Output phrase |
|---|---|
| All certs valid and current | `"All statutory certificates were found to be current and valid at the time of the casualty."` |
| Certs expired / lapsed | `"The following statutory certificates were noted as expired at the time of the casualty: {CERT_DETAILS}."` |
| Certs not sighted | `"Copies of the statutory certificates were not made available to the Undersigned for review."` |

---

## PART D — FURTHER PARTICULARS (OWNERS' NARRATIVE)

### CLAUSE D-1 — Pre-Survey Owners' Description

**Verbatim text (template annotation):**

> `{DOL}` & `{CASUALTY_NATURE}`. Occurrences/Chronology — the owners' description of events leading up to the surveyor's first attendance, not the surveyor's description of what happened subsequently.

**Trigger:** Always included in this section. Text is the owners' account (pre-attendance). Surveyor's own account goes separately under the **Occurrences/Chronology** section.

**Fields:** `{DOL}`, `{CASUALTY_NATURE}`, `{OWNERS_NARRATIVE}` (free text)

---

### CLAUSE D-2 — Further Particulars Dropdown

**Trigger logic:**

| Condition | Select variant |
|---|---|
| Vessel was at sea when casualty occurred | `"The vessel was at sea at the time of the casualty."` |
| Vessel was in port / at anchor | `"The vessel was in port / at anchor at the time of the casualty."` |
| Vessel was undergoing maintenance / repairs | `"The vessel was undergoing scheduled maintenance at the time of the casualty."` |
| Vessel was manoeuvring | `"The vessel was in the course of manoeuvring at the time of the casualty."` |

---

### CLAUSE D-3 — Date of First Attendance

**Trigger:** Always include.

**Fields:** `{FIRST_ATTENDANCE_DATE}`, `{FIRST_ATTENDANCE_TIME}`, `{FIRST_ATTENDANCE_LOCATION}`

---

## PART E — CAUSATION / ALLEGATION CLAUSES

> **⚠️ Critical legal decision point.** These two variants are mutually exclusive. Selection must be based on whether owners have formally stated a cause.

---

### CLAUSE E-1 — Formal Allegation Made *(select if owners have stated a cause)*

**Trigger:** Owners have provided a written or verbal formal allegation of cause.

**Verbatim text:**

> Owners allege that the damage forming the subject of this report was a result of `{ALLEGED_CAUSE}`.

**Fields:** `{ALLEGED_CAUSE}` (free text — state cause as alleged by owners)

---

### CLAUSE E-2 — No Formal Allegation Made *(select if cause is not yet formally stated)*

**Trigger:** No written allegation of cause has been made. Claim may be pending. Underwriters' position is reserved.

**Verbatim text (verbatim from template):**

> No formal written allegation of cause has been made in respect of this damage. It is understood that if a claim is to be made, the Owners will notify their Brokers of the allegation of cause. In view of the foregoing, the damage now found and reported upon are noted Without Prejudice to Underwriters' liability and the Owners Representative has been so advised.

**Fields:** None. Insert as-is.

**Output rule:** Use one of E-1 or E-2 only — never both.

---

## PART F — GENERAL SERVICES & ACCESS CLAUSES

### CLAUSE F-1 — Vessel Arrival Mode

**Trigger logic:**

| How vessel arrived for repairs | Output phrase |
|---|---|
| Under own power, no assistance | `"Vessel arrived under own power for these repairs."` |
| With tug assistance only | `"Vessel arrived for these repairs with tug assistance."` |
| With pilot and tug assistance | `"Vessel arrived for these repairs with tug assistance and pilot's advice."` |
| With pilot, tug, lines, and gangway | `"Vessel arrived for these repairs with tug assistance, pilot's advice, line and gangway services."` |
| Vessel towed in (not under own power) | `"Vessel was towed to the repair facility, not under own power."` |

---

### CLAUSE F-2 — Services Provided (multi-select list)

**Trigger:** Tick all services that were provided during the repair period. Each selected item generates a bullet point.

| Tick | Service | Output phrase |
|---|---|---|
| ☐ | Crane / lifting | `"Crane and lifting services were provided."` |
| ☐ | Scaffolding | `"Scaffolding was erected in way of damage."` |
| ☐ | Gas freeing | `"Gas freeing and ventilation services were carried out."` |
| ☐ | Diving | `"Underwater diving inspection / services were carried out."` |
| ☐ | Class attendance | `"Classification society surveyor attended during repairs."` |
| ☐ | NDT / X-ray | `"Non-destructive testing (NDT) / X-ray inspection was carried out."` |
| ☐ | Hydraulic testing | `"Hydraulic / hydrostatic testing was carried out."` |
| ☐ | Air pressure testing | `"Air pressure testing was carried out."` |
| ☐ | Hose testing | `"Hose testing was carried out."` |

---

### CLAUSE F-3 — Material Reinstatement Standard

**Trigger logic:**

| Condition | Output phrase |
|---|---|
| All new and disturbed material restored to original standard | `"All new and disturbed material was restored as original."` |
| Special coatings used | `"All new and disturbed material was restored as original. Note: Special coatings consisted of {COATING_DETAILS}."` |
| Material not fully reinstated / pending | `"Material reinstatement is ongoing at the time of this report."` |

**Fields:** `{COATING_DETAILS}` (if special coatings apply)

---

### CLAUSE F-4 — Work Quality Sign-Off

**Trigger logic:**

| Condition | Output phrase |
|---|---|
| Work completed and accepted by all parties | `"All new and disturbed material was proved satisfactory to the satisfaction of all parties including Class. The work included all necessary hose tests, hydraulic or air pressure tests, X-Ray and Radiographic inspection."` |
| Work completed, Class not attended | `"All new and disturbed material was proved satisfactory to the satisfaction of attending parties. Class were not present during final inspection."` |
| Work ongoing / not yet finalised | `"The work was ongoing at the time of this report. Final quality sign-off is deferred to the next report."` |

---

### CLAUSE F-5 — Hot Work Gas Freeing Compliance

**Trigger:** Include whenever hot work (welding, burning, grinding) was conducted during repairs.

**Trigger logic:**

| Condition | Output phrase |
|---|---|
| Gas freeing conducted, certs valid throughout | `"Gas freeing of all spaces in way of damage repairs was carried out to comply with local regulations. The validity of gas free certificates was maintained throughout the repair period."` |
| Gas freeing conducted, certs not sighted | `"Gas freeing of all spaces in way of damage repairs was carried out. Gas free certificates were not made available to the Undersigned for review."` |
| No hot work — clause omitted | *(omit entirely)* |

---

## PART G — ESTIMATED COST CLAUSES

### CLAUSE G-1 — Estimated Cost Status

**Trigger logic:**

| Condition | Select variant |
|---|---|
| Estimate obtained and included | `"An estimated cost of repairs in the region of {CURRENCY_CODE} {ESTIMATED_COST} has been obtained."` |
| Estimate not yet available | `"An estimated cost of repairs has not been obtained at the time of this report."` |
| Repairs ongoing, cost TBC | `"Repair accounts are still being compiled. Estimated costs will be reported upon in a subsequent report."` |
| CTL scenario | `"An estimated cost of repairs has been obtained in the region of {CURRENCY_CODE} {ESTIMATED_COST}. This figure may be in excess of the insured value and a Constructive Total Loss situation may arise. Further advice will follow."` |

**Fields:** `{ESTIMATED_COST}`, `{CURRENCY_CODE}`

---

## PART H — ACCOUNTS APPROVAL CLAUSES

### CLAUSE H-1 — Account Approval Standard Statement

**Verbatim text (always included when accounts are being approved):**

> The accounts are approved by us subject to Underwriters' liability and adjustment in the usual manner being considered fair and reasonable as indicated below.

**Trigger:** Always include when any accounts are being approved in this report. Omit in preliminary reports where no accounts have been received.

---

### CLAUSE H-2 — Account Line Item Introduction

**Verbatim text (per invoice/account entry):**

> The above account appears to be a copy of an invoice for `{INVOICE_DESCRIPTION}`.

**Fields per account entry:**

| Field | Label |
|---|---|
| `{INVOICE_NO}` | Invoice number |
| `{INVOICE_DATE}` | Invoice date |
| `{CURRENCY_CODE}` | Currency |
| `{INVOICE_AMOUNT}` | Amount |
| `{INVOICE_DESCRIPTION}` | Description of works / services |

---

### CLAUSE H-3 — Account Assessment Outcome (per invoice)

**Trigger logic:**

| Condition | Select variant |
|---|---|
| Account approved in full | `"The account is considered fair and reasonable and is approved in full."` |
| Account approved subject to deductions | `"The account is approved subject to the deductions noted below."` |
| Account queried / not approved | `"The account is queried. Further information has been requested from the Owners / Repairers before approval can be given."` |
| Account for Owner's account only | `"The above account is considered to be for the Owner's account and not related to the casualty under review."` |
| Account split — partial approval | `"The account is partially approved. The portion attributable to the casualty under review is approved as noted. The balance is considered for Owner's account."` |

---

### CLAUSE H-4 — Dry-Dock Account — Owner's Maintenance Deduction

**Trigger:** Include when a drydock account contains items that are Owner's maintenance (not related to the casualty).

**Verbatim text:**

> The following items are not considered related to the casualty under review and more appropriately for Owner's account: —

*(Followed by deduction table: Item | Description | Amount)*

**Fields:** `{DEDUCTION_ITEMS}` (table rows), `{DEDUCTION_TOTAL}`

---

### CLAUSE H-5 — Sum Approved Without Prejudice

**Verbatim text:**

> **Sum Approved Without Prejudice:** `{CURRENCY_CODE}` `{APPROVED_AMOUNT}`

**Trigger:** Mandatory at each account approval block. "Without Prejudice" is a formal legal marker — do not omit or rephrase.

**Fields:** `{CURRENCY_CODE}`, `{APPROVED_AMOUNT}`

---

### CLAUSE H-6 — General Services Cost Attribution

**Trigger:** Include when the drydock account includes a general services section that may require proportional adjustment.

**Verbatim text:**

> As the above section is in the nature of dry-docking and general services the costs may be subject to adjustment.

**Output rule:** Apply to Section 1 of drydock accounts only, or any section labelled "General Services".

---

### CLAUSE H-7 — Sub-Account Section Inclusion Item

**Verbatim text (per sub-section of drydock account):**

> Included in this section is item `{ITEM_NO}` relating to `{ITEM_DESCRIPTION}`.

**Fields:** `{ITEM_NO}`, `{ITEM_DESCRIPTION}`

---

## PART I — REPAIR TIMES CLAUSES

### CLAUSE I-1 — Repair Times Guidance Statement

**Trigger:** Always include when a repair times opinion is provided.

**Verbatim text:**

> For the guidance of those concerned it is our opinion that had the repairs detailed above been carried out separately the following periods would have been required.

**Fields:**

| Field | Label |
|---|---|
| `{DAMAGE_REPAIR_DD_DAYS}` | Damage repair — drydock days |
| `{DAMAGE_REPAIR_ALONGSIDE_DAYS}` | Damage repair — alongside days |
| `{OWNERS_REPAIR_DD_DAYS}` | Owners' repairs — drydock days |
| `{OWNERS_REPAIR_ALONGSIDE_DAYS}` | Owners' repairs — alongside days |

---

## PART J — DISCLAIMER / LIABILITY CLAUSE

### CLAUSE J-1 — Standard Report Disclaimer

**Verbatim text (verbatim from template — do not modify):**

> This report (including any enclosures and attachments) has been prepared for the exclusive use and benefit of the addressee(s) and solely for the purpose for which it is provided. Save to the extent provided for in the Company's Terms and Conditions or such other contract between the Company (or its affiliate) and the Client (or its affiliate) governing the issuance of this report, the Company assumes no liability to the addressee(s) for any claims, loss or damage whatsoever suffered by the addressee(s) as a result of any act, omission or default on the part of the Company or any of its servants, whether due to negligence or otherwise. No part of this report shall be reproduced, distributed or communicated to any third party without the prior written consent of the Company. The Company does not assume any liability or owe any duty of care if this report is used for a purpose other than that for which it is intended or where it is disclosed to or used by a third party.

**Trigger:** Always included. Fixed. Appears at end of report body, before photographs. Do not omit, abbreviate, or paraphrase.

---

## PART K — DOCUMENT REGISTERS

### CLAUSE K-1 — Documents Retained on File

**Verbatim header text:**

> Copies of the following documents are retained by us on file:

**Trigger:** Always include. List all documents held by the surveying firm.

**Input:** Free-list of document names. Each generates a bullet point.

---

### CLAUSE K-2 — Documents Requested

**Verbatim header text:**

> Copies of the following documents have been requested from the Owners:

**Trigger:** Include when there are outstanding document requests. Omit if all documents have been received.

**Input:** Free-list of document names requested but not yet received.

---

## PART L — SIGN-OFF BLOCK

### CLAUSE L-1 — Standard Sign-Off

**Structure:**

| Block | Content |
|---|---|
| Left column | `ATTENDING SURVEYOR` + signature block |
| Right column | `REVIEWED BY` + signature block |

**Trigger:** Always included. Reviewed By column is omitted only if the report has not yet been peer-reviewed.

---

## QUICK REFERENCE: CLAUSE SELECTION DECISION TABLE

| Section | Clause | Always / Conditional | Key Decision Variable |
|---|---|---|---|
| B | B-1 Certification opening | Always | — |
| B | B-2 Survey type | Always | Damage type |
| C | C-1 Ship type | Always | Vessel type |
| C | C-6d SMS reporting | Conditional | Was casualty reported in SMS? |
| C | C-6f Statutory certs | Always | Cert status at DOL |
| D | D-2 Further particulars | Always | Vessel status at time of casualty |
| **E** | **E-1 Formal allegation** | **Exclusive / or** | **Has owner stated cause formally?** |
| **E** | **E-2 No allegation / WP** | **Exclusive / or** | **No formal cause stated** |
| F | F-1 Vessel arrival | Always | Mode of arrival |
| F | F-2 Services (multi-select) | Conditional | Services actually provided |
| F | F-5 Hot work / gas free | Conditional | Was hot work conducted? |
| G | G-1 Estimated cost | Always | Cost status |
| H | H-1 Account approval intro | Conditional | Are accounts being approved? |
| H | H-4 Owner's maintenance | Conditional | Does drydock account include Owner's items? |
| **H** | **H-5 Sum Approved WP** | **Mandatory per approval** | **Always at each approval block** |
| H | H-6 General services adj. | Conditional | Does account include general services? |
| I | I-1 Repair times | Conditional | Is a repair time opinion being given? |
| **J** | **J-1 Disclaimer** | **Always** | **Fixed. Never modify.** |
| K | K-1 Docs retained | Always | Documents in file |
| K | K-2 Docs requested | Conditional | Outstanding document requests |

---

## NOTES ON "WITHOUT PREJUDICE" USAGE

This template uses "Without Prejudice" in two legally distinct contexts:

| Location | Clause | Legal Function |
|---|---|---|
| Clause E-2 | No allegation / WP note | Reserves Underwriters' liability where cause is unestablished |
| Clause H-5 | Sum Approved Without Prejudice | Formal approval qualifier — approval does not constitute admission of liability |

Both usages are mandatory and verbatim in their respective contexts. Neither may be omitted when triggered.

---

*Schema version: 1.0 — extracted from ABL London H&M Report Template (London_HM_Report.docx)*
*Prepared for: Oceanoservices / Marsh Maritime AI Survey Platform*

---

## IMPLEMENTATION NOTES (this app)

*Added 2026-07-02. This section is the running log for turning the schema above into working code in `marine_survey_app`. Update it as decisions are made or revised — don't let it go stale.*

### Decisions made

1. **Format scope.** This schema is the legal content for `OutputFormat.abl` (`lib/features/cases/models/case_model.dart`), but per the surveyor: the *wording* is shared conceptually across formats — only presentation/section order differs by format (`oceano_services`, `abl`, `nordic`). Formats do **not** share rows at query time (no fallback logic); each `format_type` gets its own independent `clause_library` rows.
2. **Seeding strategy.** Since `oceano_services` is the new/primary working format and has no legal wording of its own yet, every clause added under this effort gets **duplicate rows seeded for both `format_type = 'abl'` and `format_type = 'oceano_services'`**, identical text. A future "format editor" will let each be edited/diverged independently per firm — this is out of scope for now, just keep row shape ready for it (`is_locked`, `editable_by`, `version` columns already exist on `clause_library`).
3. **Trigger selectors live at the data source**, not in a dedicated report-time panel — mirroring the existing `causation_sheet.dart` pattern for E-1/E-2 (Owner's Allegation). Selector fields get added to the vessel/occurrence/repair/account screens where the underlying fact naturally lives; `report_provider.dart`'s `buildSections()` just reads the stored trigger and looks up the matching clause.
4. **Clause wording is DB-driven** via `clause_library`, not hardcoded Dart enums — each "pick 1 of N" variant becomes its own `clause_type` enum value (e.g. `arrival_own_power`, `arrival_tug_only`, …), exactly like `allegation_formal` / `allegation_none` today. Rationale: a future per-firm format editor needs clause text to be editable data, not compiled code.
5. **Part H (accounts) is in scope for this effort**, not being built separately by hand — despite `edit_account_line_sheet.dart` / `import_invoice_sheet.dart` being mid-edit in the working tree for other reasons.
6. **Phasing:** (1) fixed/"always" clauses first — mostly wiring already-captured data into `clause_library` lookups; (2) then the genuine gaps (new trigger fields + UI); (3) then presentation/section-order polish.

### Audit — what's already implemented or data-ready vs. genuine gaps

**Already implemented end-to-end** (use as the template pattern for everything else):
- **E-1 / E-2 (Owner's Allegation)** — `lib/features/survey/widgets/causation_sheet.dart` sets `occurrence.allegationType` (`tbc` / `no_formal_allegation` / `formal_allegation`); `report_provider.dart:755-771` looks up `clause_library` rows `allegation_formal` / `allegation_none` by `format_type`. This is the reference implementation for every other trigger-driven clause below.
- **L-1 (Sign-off block)** — `docx_export_service.dart:624-645` already renders ATTENDING SURVEYOR / REVIEWED BY from `signed_off_attending_name/_at` and `signed_off_reviewing_name/_at` on the case, for Final reports only. No work needed.

**Data-ready — just needs a `clause_library` row + wiring, no new fields/UI:**
- **C-6a (Class status)** — `vessel.class_society` already captured.
- **C-6b / C-6c (DOC / SMC)** — `CertType.doc` / `CertType.smc` in `certificates_provider.dart` already carry `issuingAuthority`, `issueDate`, `expiryDate`.
- **C-6e (Last drydock)** — `vessel.last_drydock_yard` / `last_drydock_date` (migration 005/008).
- **C-6f (Statutory cert dropdown)** — `CertStatus` enum (`valid`/`expired`/`suspended`/`notSighted`/`tbc`) already exists per-cert; needs an aggregation rule across all certs on the case to pick the 1-of-3 variant (all valid / some expired / not sighted). No new fields.
- **C-2/C-3/C-4/C-5 (breadth/draft label, propeller type, drive train)** — `vessel.breadth_qualifier`, `draft_qualifier`, `propeller_type`, `propulsion_drive_type` already free-text fields on the vessel screen. Needs a phrase-lookup map, not new UI.
- **C-1 (Ship type)** — vessel screen already has a 25-item `_vesselTypes` dropdown (`vessel_particulars_screen.dart:33`), richer than the doc's 10 C-1 categories. Needs a many-to-one mapping table (e.g. "anchor handling tug" → tug phrase) rather than new UI; a few of the existing 25 types (LNG/LPG carrier, cable layer, research vessel, etc.) have no C-1 phrase yet and need one added.
- **D-3 (Date of first attendance)** — fully covered by `SurveyAttendanceModel` (now GPS/location-enriched from this session's work) — take the earliest `initial`-type attendance.
- **I-1 (Repair times guidance)** — fixed intro text + `drydock_days`/`afloat_days`/`owner_days` already modeled and rendered via `_buildRepairTimesText`.
- **H-1 (Account approval intro)** — fixed text, condition = `repairDocuments.isNotEmpty` and not a preliminary report with no accounts received.
- **H-5 (Sum Approved Without Prejudice)** — `RepairDocumentModel.totalApprovedUW` / `.withoutPrejudice` already computed; just needs the verbatim label format per document.
- **H-3 (Account outcome) / H-4 (Owner's maintenance deduction)** — `DocStatus`, `LineItemStatus`, `CostNature.ownersMaintenance`, `AccountLineModel.isOwnersAccount` already model this almost exactly. `presentationStatement` / `aiPresentationDraft` fields on both `RepairDocumentModel` and `AccountLineModel` look purpose-built for this narrative text — needs phrase-mapping logic, likely minimal new UI.
- **H-2 (Account line item intro) / H-7 (Sub-account item)** — `AccountLineModel.itemNumber` + `.description` already exist, map directly to `{ITEM_NO}` / `{ITEM_DESCRIPTION}`.

**Assumption flagged for review — D-1 (Pre-Survey Owners' Description):** mapped tentatively to the existing `occurrence.background_narrative` field (used today for the "Background" section). The doc's language ("owners' description of events... not the surveyor's description") suggests this might need to be a distinct field from the surveyor-authored background narrative. **Confirm before Phase 1 ships** — if they need to stay separate, `background_narrative` should NOT be reused for D-1 and a new field is needed instead.

**Genuine gap — new clause_type + render step needed, not currently wired at all:**
- **J-1 (Standard disclaimer)** — `docx_export_service.dart:648` currently only renders `organisation.disclaimer_text` (org-level override) with **no fallback tier** — if an org hasn't set it, nothing renders. Needs a new `clause_type` (proposed: `report_disclaimer`) added as the `clause_library` fallback, with the verbatim J-1 text as the ultimate hardcoded fallback — same 3-tier pattern already used for the waiver clause (org override → clause_library → hardcoded default, `report_provider.dart:858-866`). Note: the *existing* `closing_disclaimer` clause_type is mislabeled — it's currently rendered as "ADDITIONAL OBSERVATIONS" (`docx_export_service.dart:622`), not the true legal disclaimer. Don't conflate the two.
- **K-1 header text** — the documents-on-file table renders today but without the verbatim lead-in sentence ("Copies of the following documents are retained by us on file:"). Small addition.
- **K-2 (Documents requested)** — `SectionType.documentsRequested` exists as a section but is **always empty** (`report_provider.dart:849-853`, `const ReportSection(..., content: '')`) — there is no data source anywhere in the app for "documents requested but not received." Needs a new field/list, likely on the case or a small new table.
- **B-2 (Survey type description)** — no `survey_type` / `propulsion_type` fields exist yet anywhere. New trigger field needed (likely on the case or occurrence).
- **D-2 (Vessel status at casualty)** — distinct from `AttendanceModel.vesselStatus` (that's vessel status *at the attendance*, not *at the moment of loss*, which may be a different date). New field needed, likely on `occurrence`.
- **F-1 (Vessel arrival mode), F-2 (Services checklist), F-5 (Hot work / gas freeing)** — no existing fields. Natural home is probably the repair/repair-period screens (`repair_periods_screen.dart`) since these are repair-yard facts, not vessel or occurrence facts.
- **G-1 (Estimated cost status)** — no status field distinguishing "estimate obtained" / "not yet obtained" / "ongoing" / "CTL scenario" — natural home is the accounts feature, next to `AccountsSummary`.
- **H-6 (General services cost attribution)** — no explicit flag; closest existing concept is `CostNature`/`SupplierCategory`, but neither has a clean "general services" bucket yet.

### Progress log

**2026-07-02 — Phase 1, first slice shipped (no DB changes):**
- **C-2/C-3/C-4/C-5 (breadth/draft label, propeller, drive train)** — turned out to need no phrase-lookup at all: the vessel screen already stores the qualifier itself as the display label (e.g. `breadth_qualifier = 'Moulded Breadth'`, `propulsion_drive_type = 'Direct drive'`). Added 4 rows to the Vessel Particulars table in `docx_export_service.dart` that render these existing fields directly — previously they weren't shown anywhere in the export at all.
- **D-3 (Date of first attendance)** — `assembledDataProvider` now fetches `survey_attendances` (it wasn't being fetched at all before), added as `AssembledReportData.attendances`. `_fillOpeningClause()` in `report_provider.dart` now fills `[FIRST_ATTENDANCE_DATE]` / `[LOCATION_DESCRIPTION]` from the earliest actual attendance record instead of the occurrence's date-of-loss and generic case notes — those were subtly wrong (DOL ≠ first attendance date) and now double as a live consumer of this session's GPS/structured-location work on attendances.
- Initially added B-1 ("THIS IS TO CERTIFY") as a hardcoded heading, but **reverted** once DB access confirmed it was already the opening words of the seeded `opening_certification` clause — would have duplicated it. Left as-is, no code needed.

**2026-07-02 — Supabase Management API access granted.** Surveyor added `SUPABASE_ACCESS_TOKEN` (personal access token) to `.env`; project ref derived from `SUPABASE_URL`. This unlocks running SQL directly (`https://api.supabase.com/v1/projects/{ref}/database/query`) instead of handing over migration files — covers both DDL (`ALTER TYPE`) and data. Helper script at `$SCRATCH/run_sql.sh` for the rest of this session. Still narrating/showing SQL before running it, per the standing agreement — this access is a real escalation (bypasses RLS, full schema control) and the app holds real client claims data.

**Discovery findings (live DB, not guessed):**
- `clause_type` enum type name: `clause_type_enum`. `format_type` enum type name: `output_format_enum`. `output_format_enum` already included `oceano_services` — no need to add it.
- Only `nordic` and `abl` had any seeded `clause_library` content; **`oceano_services` had zero rows** — confirmed the "populate oceano from ABL wording" plan was live-needed, not hypothetical.
- Two rows were **mislabeled**, found by reading full `clause_text` rather than trusting `clause_type` names:
  - `closing_disclaimer` actually held clause **H-1** text ("The accounts are approved by us subject to Underwriters' liability...") — and was being rendered under an "ADDITIONAL OBSERVATIONS" heading in the docx export, which was also wrong.
  - `other` actually held clause **J-1**'s exact verbatim disclaimer text.
  - Fixed by: adding a new `account_approval_intro` clause_type, moving the H-1 content there; then moving J-1's text from `other` into the now-vacated (and correctly-named) `closing_disclaimer`. Applied to all three formats (`nordic`, `abl`, `oceano_services`) since the mislabeling was structural, not format-specific.
- `without_prejudice` clause_type exists and is unreferenced in code. Checked the surveyor's hypothesis (append it after `allegation_none`) against the live text: **`allegation_none`'s full text already ends with the exact same sentence** — appending would duplicate it. Left `without_prejudice` unwired.

**Clause library changes made (applied to `abl`, `oceano_services`, and where structural, `nordic`):**
- Duplicated all 6 `abl` clause rows into `oceano_services` (admin-facing `clause_label` reprefixed "Oceanoservices —", `clause_text` unchanged) per the earlier "duplicate, don't fall back" decision.
- Added 9 new `clause_type_enum` values with verbatim seed text (both `abl` and `oceano_services`): `account_approval_intro` (H-1), `class_status_statement` (C-6a), `doc_certificate_statement` (C-6b), `smc_certificate_statement` (C-6c), `last_drydock_statement` (C-6e), `statutory_certs_valid` / `statutory_certs_expired` / `statutory_certs_not_sighted` (C-6f, mutually exclusive), `repair_times_guidance` (I-1), `documents_on_file_header` (K-1).

**Code wired to the above (`report_provider.dart`, `docx_export_service.dart`):**
- `_buildClassStatutoryText` now takes the full `AssembledReportData` and composes C-6a (class society) / C-6b+C-6c (DOC/SMC, from `certificates` where `cert_type` = `doc`/`smc`) / C-6e (last drydock) / C-6f (aggregates `CertStatus` across all certs — expired beats not-sighted beats all-valid) ahead of the existing certificate/condition listing.
- Accounts section (`§13`) now prepends H-1 whenever `repairDocuments` is non-empty.
- Repair times section (`§14`) now prepends I-1 whenever there's repair-time data to comment on.
- Documents-on-file section (`§16`) now prepends the K-1 header sentence.
- Closing section (`§ closing`, formerly mistitled "Without Prejudice / Closing") retitled **"Disclaimer"**, now correctly resolves J-1 through the same 3-tier pattern as the waiver clause (org `disclaimer_text` override → `clause_library` `closing_disclaimer` → hardcoded verbatim fallback). The previously-separate, non-fallback-aware `org.disclaimer_text` render block in `docx_export_service.dart` was **removed** — it would have double-printed the disclaimer once `closing_disclaimer` started resolving correctly.
- **C-1 (ship type)** — superseded by the 2026-07-02 (later) entry below; initial "don't add clause_library rows" call was revised once the surveyor clarified the intended behaviour.

**Aside, not in scope for this doc:** `report_provider.dart` calls `data.clauseByType('waiver')` for the Limitation of Liability / Waiver section, but `waiver` is not a valid `clause_type_enum` value at all — that lookup silently always returns null, currently masked by the hardcoded fallback text. Not part of legal_clauses.md (no Part J waiver clause defined here), flagging for awareness only.

**2026-07-02 (later) — Vessel type capitalisation + C-1 implemented.**

Surveyor asked to: (1) capitalise `_vesselTypes` in `vessel_particulars_screen.dart` (Title Case), and (2) actually implement C-1 after all, on the rule "use the clause for a vessel type only if one exists for that type" — i.e. no forced/invented phrase when there's no match, which directly resolves the earlier hesitation about authoring content for the 15 uncovered types.

- **Capitalisation**: all 25 entries in `_vesselTypes` changed to Title Case (e.g. `'general cargo ship'` → `'General Cargo Ship'`). Checked the live `vessels` table first — **0 of the 3 existing vessel records use any dropdown value at all**; all three (`Yachting Service`, `Offshore Tug/Supply Ship`, `Icebreaker`) are Equasis-import terminology, a different vocabulary entirely. So no data migration was needed, and this also confirms `vessel_type` is effectively free text in practice, not a closed set — reinforces why C-1 needs to degrade gracefully to "omit" rather than guess.
- **C-1 clause_library rows**: added 10 new `clause_type_enum` values (`ship_type_general_cargo`, `ship_type_bulk_carrier`, `ship_type_container`, `ship_type_tanker_oil`, `ship_type_tanker_chemical`, `ship_type_offshore_support`, `ship_type_tug`, `ship_type_passenger`, `ship_type_roro_ferry`, `ship_type_fishing`), seeded verbatim from the doc's C-1 table, both `abl` and `oceano_services`.
- **Mapping (`_shipTypeClause` in `report_provider.dart`)** — exact-match only, from the (now-capitalised) dropdown strings to a clause_type:
  - General Cargo Ship → general cargo; Bulk Carrier → bulk carrier; Container Ship / Container Carrier → container; Oil Tanker → oil tanker; Chemical Tanker → chemical tanker; Offshore Support Vessel / Offshore Supply Vessel → offshore support; Tug → tug; Ro Ro / Passenger Ferry → Ro-Ro/ferry.
  - **One judgment call, recorded rather than asked**: "Passenger Ferry" could plausibly map to the doc's generic "Passenger vessel" category instead of "Ro-Ro / ferry" — went with Ro-Ro/ferry since "ferry" is the more specific signal and the doc's own Ro-Ro/ferry phrase explicitly says "passenger ferry". Low-stakes either way (now DB-editable via direct SQL if wrong, will be editable via the future format editor).
  - **Deliberately unmapped** (no clause_type at all, so C-1 is simply omitted for these): Products Carrier, Anchor Handling Tug, Reefer Vessel, LNG Carrier, LPG Carrier, Oceanographic Research Vessel, Seismic Survey Vessel, Dive Support Vessel, Tender, Crew Boat, Cable Layer, Pipe Layer, Work Boat, Pilot Boat — none of these have a real match in the doc's 10 categories, so no clause exists for them at all (not even seeded) except that the doc's own "Fishing vessel" and generic "Passenger vessel" categories were seeded anyway for future use even though no current dropdown value reaches them.
- **Rendering**: `_buildVesselText` now prepends the C-1 sentence (e.g. "She is a bulk carrier.") ahead of the existing structured `Vessel Name: / Type: / ...` lines, only when `_shipTypeClause` has a match — otherwise nothing is added, existing behaviour unchanged.

**2026-07-02 (later still) — H-1/H-3/H-4/H-5/H-6/I-1/K-1 wired into the actual docx export; H-2 and D-1 resolved; H-7 skipped.**

**Important architecture finding, caught before it caused a silent bug:** the H-1/I-1 wiring from earlier in this session (into `_buildCostSummaryText`/`_buildRepairTimesText`, feeding `sections[SectionType.accounts]`/`sections[SectionType.repairTimes]`) only reaches the **in-app preview** (`report_preview.dart` loops generically over `oceanoSectionOrder`). `docx_export_service.dart` — the code that produces the actual Word document clients receive — builds "REPAIR COSTS", "REPAIR TIMES", and "DOCUMENTS RETAINED ON FILE" from `assembled.repairDocuments` / `repairRecords` / `caseDocuments` **directly**, with its own dedicated table-building code, completely bypassing those `ReportSection`s. So H-1/I-1/K-1 were invisible in the real export until fixed here. Lesson for future clause work: always check whether a section is rendered via the generic `renderTextSection()` helper or has its own bespoke block in `docx_export_service.dart` before assuming the `report_provider.dart` wiring is sufficient for the live document.

**Fixed directly in `docx_export_service.dart`'s REPAIR COSTS block:**
- **H-1** — paragraph before the per-document loop.
- **H-2** — per surveyor's answer, the invoice description is already AI-extracted during account import and stored in `RepairDocumentModel.presentationStatement`. Moved that field's rendering from *after* the line-items table (a bare, unlabelled paragraph) to *before* it, now wrapped in the new `account_line_intro` clause template ("The above account appears to be a copy of an invoice for {INVOICE_DESCRIPTION}."). The old bare rendering was removed — it would otherwise have duplicated the same text twice.
- **H-3** — 5-way mutually-exclusive outcome, derived per document from `surveyor_status` (`DocStatus`) plus whether the document's lines are all/some/none `cost_nature IN ('owners_maintenance','class_statutory')`: all owners → `account_owners_only`; `approved` → `account_approved_full`; `partly_approved` + some owners-lines → `account_split_partial`; `partly_approved` + no owners-lines → `account_approved_subject_to_deductions`; `queried` → `account_queried`. `pending_review`/`under_review`/`rejected` → no clause (nothing meaningful to say yet, or no doc-provided phrase fits "rejected").
- **H-4** — triggered when a document has *some but not all* owners-account lines (the mixed case; all-owners is H-3's `account_owners_only` instead). Renders the `owners_maintenance_deduction_intro` clause plus a small Item/Description/Amount table of just the owners-account lines.
- **H-5** — renders `Sum Approved Without Prejudice: {currency} {amount}` (bold) per document, gated on `without_prejudice` (defaults true) and a non-zero underwriters total.
- **H-6** — renders `general_services_attribution` when `supplier_category == 'dry_dock_operator'`.
- **H-7** — **skipped**, per surveyor's confirmation. The doc's "sub-account section" concept doesn't exist in this app's flat line-item model, and forcing a sentence per line item would just duplicate the existing table.
- **I-1** — moved into the REPAIR TIMES block directly, same fix as H-1.
- **K-1** — moved into the "DOCUMENTS RETAINED ON FILE" block directly, same fix.

**New clause_type_enum values added this round** (verbatim text, seeded for `abl` + `oceano_services`): `account_approved_full`, `account_approved_subject_to_deductions`, `account_queried`, `account_owners_only`, `account_split_partial`, `owners_maintenance_deduction_intro`, `general_services_attribution`, `account_line_intro`.

**D-1 — confirmed, with a follow-up.** Surveyor confirmed `occurrence.background_narrative` is the right field. Also flagged that this field currently does double duty (owners' pre-attendance account for D-1, and the surveyor's own background narrative) and needs proper structuring later — logged as `docs/TODO.md` §2.13, not resolved now.

**Next: Phase 2 gaps** (B-2, D-2, F-1/F-2/F-5, G-1, K-2) — surveyor confirmed moving ahead, with each new field scoped and confirmed before adding (all of these need new DB columns, unlike Phase 1 which only needed `clause_library` rows). Not yet started as of this entry.

---

**2026-07-03 — Phase 2 backend/report-generation logic complete. UI (data entry) not started.**

Surveyor refined the Phase 2 field scoping with real domain input, changing several of the original proposals:

- **B-2 (Survey type)** — no new field. Practice's cases are always treated as "a hull and machinery damage survey"; derived directly from the existing `cases.case_type == 'hm'`, appended to the end of the opening certification clause. The doc's other 5 survey-type categories (pure machinery/hull/grounding/collision/fire) are not modelled — not needed for this practice.
- **D-2 (Vessel status at casualty)** — new field `occurrences.vessel_status_at_casualty` (text), dropdown in the occurrence edit screen (**UI not built yet**). Rendered into the Occurrence section.
- **F-1 → generalised into "Aftermath"** — surveyor's call: this isn't just "how did the vessel arrive for repairs" (the doc's narrow framing), it's "what happened after the casualty" more broadly, including vessels that never went for repairs at all. New fields `occurrences.aftermath_status` (text, 6 options — the doc's 5 plus a new **"proceeded with operations"** option for vessels that just carried on trading) and `occurrences.aftermath_port` (text, free-form port name). Lives on `occurrences`, not `repair_records` as originally scoped. New section needed in the occurrence edit sheet (**UI not built yet**).
- **F-2 (Services provided)** — confirmed per repair period as originally scoped, but surveyor added a second field: `repair_records.services_provided_notes` (free text) alongside `services_provided` (text array) — for context the AI extracts from invoices or the surveyor types manually. Both new, **UI not built**.
- **F-5 (Hot work/gas freeing)** — same pattern as F-2: `repair_records.hot_work_status` (text, 2 real states + null = not conducted/omitted) + `repair_records.hot_work_notes` (free text). **UI not built**.
- **G-1 (Cost estimate status)** — surveyor replaced the doc's original 4-state model with their own 3-state one, reflecting how they actually track this: (1) no invoices yet — repairs may or may not be done, cost unknown; (2) ongoing — some invoices in, not all, so estimate + running account total shown together; (3) completed — all invoices in, final account figure only, no estimate needed. New fields `cases.cost_estimate_status` (text, 3 values) + `cases.estimated_repair_cost` (numeric). States 2 and 3's clause text is **newly drafted, not verbatim from the source doc** (seeded with `is_locked = false` to flag it needs surveyor review) — the doc has no equivalent phrasing for "ongoing with partial invoices" or "completed, final figures only". **UI not built.**
- **K-2 (Documents requested)** — much bigger than originally scoped. Surveyor wants a full case-page "Documentation" section covering three categories (enclosed in report / retained on file / requested), each document tracked with a request date and an obtained date, plus free-form ad-hoc request line items (e.g. requesting something on site with no file yet), and eventually an auto-generated email listing outstanding requests — **the email generation is explicitly deferred, logged as a new TODO item** (see below). For *this* pass: added `documents.requested_date` (date) — `documents.availability` already had a `'requested'` value and a working `DocAvailability.requested` path in `document_provider.dart`, so that part needed no schema change, just use. **The actual "Documentation" section/screen is a new UI surface, not built yet.**

**Schema — 10 new columns added, no new Postgres enum types** (used plain `text` columns rather than new enum types, matching how most other dropdown-driven fields in this app already work, e.g. `vessel_type`, `propeller_type` — simpler migrations, no enum-value transaction-boundary issues):
- `occurrences`: `vessel_status_at_casualty`, `aftermath_status`, `aftermath_port`
- `repair_records`: `services_provided` (text[]), `services_provided_notes`, `hot_work_status`, `hot_work_notes`
- `cases`: `cost_estimate_status`, `estimated_repair_cost`
- `documents`: `requested_date`

**26 new `clause_type_enum` values seeded** (both `abl` and `oceano_services`): `survey_type_hull_and_machinery`; `vessel_status_at_sea`/`_in_port`/`_maintenance`/`_manoeuvring`; `aftermath_own_power`/`_tug_only`/`_tug_pilot`/`_tug_pilot_lines_gangway`/`_towed`/`_proceeded_operations`; `services_crane_lifting`/`_scaffolding`/`_gas_freeing`/`_diving`/`_class_attendance`/`_ndt_xray`/`_hydraulic_testing`/`_air_pressure_testing`/`_hose_testing`; `hot_work_certs_valid`/`_not_sighted`; `cost_status_estimate_obtained`/`_not_obtained`/`_ongoing`/`_completed`; `documents_requested_header`.

**Code wired (`report_provider.dart` + `docx_export_service.dart`, both — learned from the earlier H-1 lesson that some sections have dedicated docx-export code bypassing the generic section-content path):**
- B-2 appended to the filled opening clause text.
- D-2 and F-1/Aftermath (with port substitution) both appended into the Occurrence section via new `_buildOccurrenceText`.
- F-2 and F-5 appended per repair record via extended `_buildRepairsText`.
- G-1 computed once in `report_provider.dart` (`_buildCostStatusText`, feeds the in-app preview) **and** duplicated directly in `docx_export_service.dart`'s REPAIR COSTS block — including the `else` branch (no repair documents case), since "no invoices yet" is precisely the empty-docs scenario and needs to still render.
- K-2: `assembledDataProvider`'s documents fetch now also selects `availability`/`requested_date`/`received_date`; split into `caseDocuments` (availability == 'enclosed', for K-1) and new `requestedDocuments` (availability == 'requested', for K-2) fields on `AssembledReportData`. `SectionType.documentsRequested` now populated via new `_buildDocumentsRequestedText`. Documents with `availability` of `not_available`/`tbc` currently appear in neither K-1 nor K-2 — flagged as a possible future refinement, not addressed now.

**`docs/TODO.md` additions:**
- §2.13 (already added earlier) — background narrative structuring for D-1.
- New TODO needed for the K-2 auto-email feature (documents-requested summary email) — **not yet added, do this before considering the session's TODO updates complete.**

**Still not started — the actual data-entry UI:**
- Occurrence edit sheet: dropdown for D-2 (vessel status at casualty) + new "Aftermath" sub-section (dropdown incl. "proceeded with operations" + port name field).
- Repair period screen: services-provided tick-box list + notes field; hot-work status + notes field.
- G-1 selector — placement not yet decided (candidates: Accounts screen, or within Report Builder itself where the cost picture is reviewed).
- K-2 / Documentation section — a new case-page section summarising enclosed/on-file/requested documents with request+obtained dates and free-form ad-hoc line items. The largest remaining piece by far; auto-email generation explicitly out of scope for now.

---

**2026-07-03 — Phase 2 UI built (plan mode, `.claude/plans/compressed-foraging-hoare.md`).**

Before writing any UI, researched via two parallel Explore agents + direct verification, and caught a real bug: the F-2/F-5 columns from the previous session were on `repair_records`, a table with **zero rows and no writer UI at all** — confirmed live (`repair_records: 0`, `repair_periods: 2`, `repairs: 4`). Moved the 4 columns to `repair_periods` (the table the surveyor's own "per repair period" wording actually meant, and the one with a real screen) before building anything on top of it. Also discovered — but did not fix, logged as `docs/TODO.md` §2.14 — that the "REPAIR TIMES" table and Clause I-1 have the same dead-table problem; `repair_periods.repair_times` (jsonb) is the real current data source.

**Built:**
- **D-2 + Aftermath (F-1)** — `OccurrenceModel` gained `vesselStatusAtCasualty`/`aftermathStatus`/`aftermathPort`. `add_occurrence_sheet.dart` gained a vessel-status dropdown and a new bordered "Aftermath" sub-section (status dropdown + port field). `onSave` callback grew from 4 to 7 positional params; updated all **three** call sites (`occurrence_screen.dart` add + edit, and a third one in `damage_register_screen.dart` that `flutter analyze` caught after the fact — a good reminder to always re-run analyze project-wide, not just on the files touched).
- **F-2 + F-5** — `RepairPeriodModel` gained `servicesProvided`/`servicesProvidedNotes`/`hotWorkStatus`/`hotWorkNotes`. `add_repair_period_sheet.dart` gained a 9-item services checklist (reusing the `CheckboxListTile` pattern from `add_repair_sheet.dart`) + notes, and a 3-way hot-work chip selector + notes. No provider changes needed — this sheet already passed a full model to `onSave`.
- **G-1** — `CaseModel` gained `costEstimateStatus`/`estimatedRepairCost` (added to `copyWith` too, to keep the pattern consistent with the rest of that method). `cases_provider.dart`'s existing `updateCaseRefs(...)` extended with the two new params rather than adding a new method. New `_CostEstimateSelector` widget added to `accounts_screen.dart`, watching/updating `caseProvider` directly.
- **K-2** — `DocumentModel` gained `requestedDate`; `document_provider.dart`'s `addRecord()` now defaults it to today when `availability == requested`. The "Log requested document" dialog in `document_vault_screen.dart` now has an editable date picker (converted to `StatefulBuilder` to support it). `DocumentTile` (the shared card widget) now shows the requested date. New "Documentation" `_SectionCard` added to `case_home_screen.dart`, mirroring the existing "Accounts" card exactly.
- Logged a genuine data-model gap found while building K-2: `DocAvailability` has no distinct "enclosed in report" vs "retained on file" states — both collapse into `enclosed`. Not fixed, logged as `docs/TODO.md` §2.15.

**Verification:** `flutter analyze` clean at 139 pre-existing issues / 0 errors project-wide (caught and fixed the missed third call site this way). Confirmed live schema matches exactly (repair_records columns gone, repair_periods has them). Ran a live functional check — set `vessel_status_at_casualty`/`aftermath_status` on a real occurrence, confirmed the clause_library lookups resolve to the exact expected text, then reverted the test values back to null. Did not do a full manual UI click-through / actual docx export — recommend a quick real-world test (create an occurrence with the new fields, generate a report) when convenient.

---

**2026-07-10 — C-6f + condition-of-class (§1.8 S5) redesigned: composed narrative, not a mutually-exclusive pick.**

The surveyor flagged that both C-6f (statutory certificate status) and the condition-of-class narrative were wrongly modelled as "pick 1 of 3 canned phrases" when the underlying reality is a genuine assessment across multiple items — how many certificates were sighted vs. not, valid vs. expired vs. suspended, and how many conditions of class exist and how many of *those* relate to the casualty. A 3-way pick can only represent uniform states (all valid, or all-fall-into-one-bucket) and silently renders **nothing at all** for any real mix (e.g. one suspended certificate alongside otherwise-valid ones — confirmed as a live gap before fixing). Framed by the surveyor as a recurring "narrated description of hard fields" pattern to apply wherever this shape recurs — same precedent as `composeDamageRowDescription()` (damage register row summaries, §3.8).

**Built:** `lib/features/reports/utils/certification_narrative.dart` — two pure, deterministic, unit-tested functions:
- `composeStatutoryCertificatesNarrative(certs)` — groups every certificate by status (valid/expired/suspended/not_sighted/tbc) and narrates every non-empty bucket by name, instead of requiring the whole set to fit one of three shapes. All-valid still collapses to one clean sentence.
- `composeConditionOfClassNarrative(conditions)` — states the actual count of conditions of class issued and, when count > 1, how many specifically relate to the casualty vs. don't (singular/plural grammar handled explicitly: "1 is" / "2 are" / "all of which are" / "none of which are"). Deliberately doesn't restate the class society — C-6a already covers that immediately above in the current layout.

Wired into `_buildClassStatutoryText` in `report_provider.dart`, replacing the old `clauseByType('statutory_certs_*'/'condition_of_class_*')` lookups entirely. The 12 now-unused `clause_library` rows (6 clause types × 2 org formats) were marked `deprecated = true` via the Management API rather than deleted, preserving history. 14 new unit tests in `test/features/reports/utils/certification_narrative_test.dart`, including the exact mixed-status scenario the old logic silently dropped.

**Wording note:** `class_conditions` has no closed/satisfied status field — the narrative can only speak to whether a condition has been *issued*, not whether it remains outstanding. "Issued" is used throughout rather than "outstanding"/"current" to avoid overclaiming what the data supports. Flag if this distinction turns out to matter in practice — would need a new field.

**Not yet done:** the surveyor named this as a pattern to apply "in a few more places" — no systematic audit of `report_provider.dart` for other list-aggregation-into-canned-phrase spots was done this session (only these two, which were already flagged). Worth a dedicated pass later; the tell is a `clauseByType()` call fed by a mutually-exclusive if/else chain over a *list* (as opposed to a single hard field mapping 1:1 to one phrase, which is fine as-is — e.g. vessel status at casualty, aftermath status, survey type).
