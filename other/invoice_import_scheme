# Invoice Import Schema
## Marine Survey Platform — H&M Casualty Claims

**Version:** 1.0  
**Purpose:** Defines the data model for automated invoice import, AI extraction, and surveyor review workflows within the Marine Survey Platform. Designed for Hull & Machinery casualty surveys in the London/Lloyd's market.

---

## Background and Design Principles

This schema was developed by iteratively testing it against two real H&M casualty invoice sets:

- A CAT 3516B diesel generator catastrophic failure on a MinRes Marine offshore support vessel (Onslow, WA), involving WesTrac, Damen, MMC Electrical, OMSB, Pro Freight, and multiple parts suppliers.
- A grounding/bottom contact casualty on the research vessel Pangaea Ocean Explorer, involving Birdon Dampier Slipway, ABS, Luna Marine, Oceanic Offshore, and Revelare Systems (NZ).

The schema handles every invoice format encountered across both cases without structural modification.

### Core design decisions

**Three tiers, not five.** The schema collapses to `repair_document` → `account_line` → `raw_line`. The AI populates `raw_lines` from the PDF. The surveyor works only at the `account_line` level — one row per reviewable unit. This cuts data entry by roughly two thirds compared to line-by-line classification.

**`account_line` is the surveyor's unit of work.** A single invoice may contain multiple account lines (e.g. an ABS invoice mixing a Damage Survey with routine annual surveys). A single account line may group multiple raw lines (e.g. all labour lines for a single segment). The surveyor draws the boundaries; the AI suggests them.

**AI drafts, surveyor confirms.** Every `presentation_statement` and `surveyor_status` is AI-drafted on import and confirmed or edited by the surveyor. Nothing is auto-approved.

**Cost nature drives the account approval split.** The `cost_nature` enum on `account_line` is the single field that determines whether a cost goes to underwriters, owners, or is split. It is applied once per account line, not per raw line.

---

## Table Definitions

### `repair_document`

One row per invoice, estimate, or related document received. The root of the hierarchy.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | Primary key |
| `document_type` | enum | See enum reference |
| `line_item_structure` | enum | How the supplier structured the invoice |
| `document_number` | text | Supplier's invoice/estimate number |
| `document_date` | date | Date on the invoice |
| `due_date` | date | Payment due date |
| `contract_ref` | text | Quote or contract number referenced (e.g. KB2523, QU-0101) |
| `amendment_number` | integer | 0 = original; 1+ = amendments to same invoice |
| `billing_milestone` | enum | For milestone/progress billing structures |
| `supplier_id` | uuid → `supplier` | |
| `case_id` | uuid → `survey_case` | |
| `vessel_unit_id` | uuid → `vessel_unit` | Nullable — some invoices cover the whole vessel |
| `equipment_make` | text | e.g. Caterpillar |
| `equipment_model` | text | e.g. 3516B |
| `equipment_serial` | text | |
| `equipment_hours` | integer | SMU/running hours at time of casualty |
| `is_replacement_component` | bool | Flags new-for-old supply — triggers betterment review |
| `component_condition` | enum | new · refurbished · reman · exchange · reconditioned · used_serviceable · repaired |
| `component_part_number` | text | OEM part number for major components |
| `currency` | char(3) | ISO currency code, e.g. AUD, NZD |
| `exchange_rate_to_aud` | decimal | Stated on invoice where applicable |
| `tax_jurisdiction` | enum | Document-level default tax treatment |
| `foreign_tax_rate` | decimal | e.g. 0.15 for NZ GST |
| `subtotal_ex_tax` | decimal | |
| `tax_total` | decimal | |
| `discount_total` | decimal | |
| `core_charges_total` | decimal | Exchange component charges (OEM reman) |
| `core_credits_total` | decimal | Credits if cores returned in acceptable condition |
| `total_inc_tax` | decimal | |
| `mixed_nature_flag` | bool | True when invoice spans damage repair AND owners' maintenance items — triggers split-account narrative |
| `ai_presentation_draft` | text | AI-generated on import — one or two sentence description in surveyor's voice for presentation to underwriters |
| `presentation_statement` | text | Surveyor-confirmed version for insertion into report |
| `surveyor_status` | enum | Overall document-level status |
| `surveyor_notes` | text | Free text — legal/commercial framing stays here |
| `without_prejudice` | bool | Whether approval is WP |
| `ai_extracted_at` | timestamptz | |
| `ai_confidence` | decimal | 0–1 confidence score from extraction pass |
| `ai_model_version` | text | |
| `source_pdf_path` | text | Path to original PDF in storage |
| `ocr_required` | bool | True for scanned/image-based PDFs |

---

### `account_line`

The surveyor's unit of work. One row per reviewable cost grouping within a document. For a simple single-scope invoice this is one row. For a mixed-nature invoice (e.g. ABS combining damage survey and annual surveys) there are multiple rows.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | Primary key |
| `document_id` | uuid → `repair_document` | |
| `line_order` | integer | Display sequence |
| `description` | text | Surveyor's own label for this cost grouping |
| `cost_nature` | enum | The key classification field — see enum reference |
| `work_location` | enum | Where the work was physically performed |
| `gross_amount` | decimal | Sum of grouped raw lines |
| `approved_amount` | decimal | Surveyor's approved figure |
| `owners_portion` | decimal | Amount for owners' account |
| `underwriters_portion` | decimal | Amount approved to underwriters WP |
| `betterment_deduction` | decimal | New-for-old / spec upgrade deduction |
| `apportionment_notes` | text | Explanation of any split |
| `surveyor_status` | enum | Line-level status |
| `ai_presentation_draft` | text | AI-drafted statement for this cost grouping |
| `presentation_statement` | text | Confirmed statement for report — maps directly to account approval table narrative |
| `raw_line_ids` | uuid[] | References to grouped raw lines |

---

### `raw_line`

Verbatim extracted content from the PDF. AI-populated on import. Never manually edited — treated as the audit record of what the invoice actually says.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | Primary key |
| `document_id` | uuid → `repair_document` | |
| `account_line_id` | uuid → `account_line` | Nullable until surveyor groups |
| `line_number` | integer | Sequence from source document |
| `segment_code` | text | Supplier's segment/section code where present (e.g. 01, E1, 99) |
| `description` | text | Line description as extracted |
| `qty` | decimal | |
| `unit` | text | EA, hrs, days, KG, m³ etc. |
| `unit_price` | decimal | |
| `discount_pct` | decimal | |
| `amount` | decimal | Extended price |
| `tax_rate` | decimal | |
| `tax_jurisdiction` | enum | Per-line where invoice has mixed tax treatment (e.g. Revelare INV-0102 zero-rated vs taxable lines) |
| `is_reman` | bool | OEM remanufactured part |
| `has_core_charge` | bool | |
| `core_charge_amount` | decimal | |
| `stock_number` | text | Supplier part/stock number |
| `country_of_origin` | text | |
| `hs_code` | text | For customs/import lines |
| `hire_on_date` | date | For tool/equipment hire lines |
| `hire_off_date` | date | |
| `hire_daily_rate` | decimal | |
| `hire_asset_ref` | text | Hire docket or asset number |
| `technician` | text | For labour lines with named technician |
| `service_date` | date | Date work was performed |
| `narrative` | text | Extended field notes (e.g. WesTrac technician daily logs) |
| `raw_text` | text | Verbatim text from PDF — audit record |

---

### `freight_document`

Extension table, joined 1:1 on `document_id`. Only populated for freight/logistics invoices (Pro Freight, international airfreight, customs entries).

| Field | Type | Notes |
|-------|------|-------|
| `document_id` | uuid → `repair_document` | 1:1 join |
| `freight_mode` | enum | road · air_domestic · air_international · sea |
| `origin_port_code` | text | IATA/UN LOCODE |
| `destination_port_code` | text | |
| `consignor` | text | |
| `consignee` | text | |
| `goods_description` | text | |
| `weight_kg` | decimal | |
| `volume_m3` | decimal | |
| `mawb_hawb` | text | Master/house airway bill number |
| `flight_number` | text | |
| `etd` | date | |
| `eta` | date | |
| `customs_entry_number` | text | e.g. AFE7YEAAA |
| `customs_value_aud` | decimal | FOB value for customs — cross-checks against component invoice |
| `fob_value` | decimal | |
| `linked_document_id` | uuid → `repair_document` | Links freight invoice to the component invoice it transported |

---

### `port_service_line`

Flat line table for port services invoices (pilotage, berthage, stevedoring, cranage). Attaches directly to `repair_document` — these invoices do not use segments.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `document_id` | uuid → `repair_document` | |
| `account_line_id` | uuid → `account_line` | Grouped for approval |
| `service_type` | enum | See enum reference |
| `description` | text | |
| `service_date` | date | |
| `qty` | decimal | |
| `unit` | text | GRT, hours, per shift, per day |
| `rate_type` | enum | standard · non_standard |
| `unit_price` | decimal | |
| `discount_pct` | decimal | |
| `amount` | decimal | |

---

### `supplier`

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `name` | text | |
| `trading_name` | text | e.g. Luna Marine t/a Carter Marine Agencies |
| `abn` | text | |
| `supplier_category` | enum | See enum reference |
| `country` | char(2) | ISO country code |
| `address` | text | |
| `contact_name` | text | |
| `contact_email` | text | |

---

### `vessel_unit`

Allows ring-fencing costs to a specific machinery unit within a case (e.g. DG1, DG2, DG3, or the vessel generally).

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `case_id` | uuid → `survey_case` | |
| `unit_label` | text | e.g. DG1, DG2, DG3, Main Engine, Gondola |
| `unit_type` | enum | See enum reference |
| `make` | text | |
| `model` | text | |
| `serial` | text | |
| `hours_at_casualty` | integer | |

---

### `account_summary`

Report-level rollup table. Fed by `account_line` approved amounts. Output layer that populates the London H&M account approval table directly.

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | |
| `case_id` | uuid → `survey_case` | |
| `document_id` | uuid → `repair_document` | |
| `account_line_id` | uuid → `account_line` | |
| `account_code` | text | Cost code for London H&M approval table |
| `approved_ex_tax` | decimal | |
| `owners_portion` | decimal | |
| `underwriters_portion` | decimal | |
| `betterment_deduction` | decimal | |
| `approval_narrative` | text | Final narrative for report — drawn from `presentation_statement` |

---

## Enum Reference

### `document_type`

| Value | Description |
|-------|-------------|
| `estimate` | Pre-repair scope and cost estimate |
| `invoice` | Actual charges rendered |
| `credit_note` | Reversal or core return credit |
| `purchase_order` | Owner-issued PO (reference only) |
| `proforma` | Pre-payment proforma invoice |
| `delivery_note` | Goods receipt, no financials |
| `quotation` | Supplier quote, not yet accepted |

---

### `line_item_structure`

| Value | Description |
|-------|-------------|
| `segmented` | Work segments with parts/labour/misc buckets (WesTrac, shipyard) |
| `itemised` | Flat list of line items (parts suppliers, fasteners) |
| `service_schedule` | Rates × quantities — port, stevedoring, berth |
| `mixed_lump_sum` | Labour schedule + lump materials/expenses |
| `daily_rate` | Hire invoice — asset × days × rate |
| `milestone` | Progress billing against contract milestones (Birdon) |
| `time_and_material` | T&M with running totals, no formal segments |

---

### `billing_milestone`

| Value | Description |
|-------|-------------|
| `not_applicable` | Standard invoice, no milestone structure |
| `deposit` | Initial deposit payment |
| `progress` | Monthly progress billing |
| `milestone_mobilisation` | Mobilisation milestone (e.g. Birdon 30%) |
| `milestone_redelivery` | Redelivery/completion milestone (e.g. Birdon 70%) |
| `variation` | Contract change proposal / variation order |
| `final` | Final account |

---

### `cost_nature`

The key classification field — determines the underwriter/owner split for every account line.

| Value | Description |
|-------|-------------|
| `damage_repair` | Directly caused by the casualty → underwriters |
| `consequential_damage` | Secondary damage resulting from primary failure |
| `temporary_repair` | Interim fix to allow vessel to trade |
| `permanent_repair` | Full permanent restoration |
| `owners_maintenance` | Due regardless of casualty → owners |
| `class_statutory` | Required by class or flag state → generally owners |
| `general_service` | Yard/port general services — mixed allocation |
| `access_staging` | Scaffolding, tank cleaning, blanking for access |
| `mobilisation` | Technician travel to site |
| `demobilisation` | Technician return from site |
| `inspection_survey` | Strip-down, inspection, report, class attendance |
| `diving_inspection` | Underwater inspection — hull, propeller, rudder |
| `tool_hire` | Hired equipment — hydraulic, rigging, lifting |
| `port_services` | Pilotage, berthage, stevedoring, cranage |
| `freight_domestic` | In-country parts/toolbox freight |
| `freight_international` | International parts freight + customs |
| `testing_commissioning` | Post-repair trials, sea trial, load test |
| `surface_treatment` | Painting, blasting, coating, preservation |
| `waste_disposal` | Environmental/hazardous waste handling |
| `professional_fees` | Naval architect, surveyor, legal, agency fees |
| `crew_expenses` | Accommodation, meals, flights (owner-supplied) |
| `other` | Catch-all — requires surveyor note |

---

### `surveyor_status`

Applied at both `repair_document` and `account_line` level.

| Value | Description |
|-------|-------------|
| `pending_review` | Imported, not yet assessed |
| `under_review` | Surveyor actively reviewing |
| `queried` | Query raised with owner or contractor |
| `awaiting_docs` | Supporting documents requested |
| `approved` | Approved in full without prejudice |
| `partially_approved` | Approved with deduction or adjustment |
| `owners_account` | Not recoverable — owners to bear |
| `betterment_deducted` | New-for-old or specification upgrade deduction applied |
| `rejected` | Not related to casualty or otherwise not approved |
| `deferred` | Repair or approval deferred to future port call |

---

### `component_condition`

| Value | Description |
|-------|-------------|
| `new` | Brand new OEM or aftermarket |
| `refurbished` | Third-party rebuild |
| `reman` | OEM remanufactured to new specification (e.g. CAT Reman) |
| `exchange` | Exchange unit — core return expected |
| `reconditioned` | Cleaned and tested, not fully rebuilt |
| `used_serviceable` | Salvage or removed from sister unit |
| `repaired` | Original unit repaired in situ or ashore |

---

### `work_location`

| Value | Description |
|-------|-------------|
| `onboard_at_sea` | Work performed under way |
| `onboard_at_anchor` | Vessel at anchor |
| `onboard_alongside` | Vessel at berth |
| `dry_dock` | Vessel in dry dock |
| `slipway` | Vessel on slipway or cradle |
| `workshop_ashore` | Component removed to local workshop |
| `workshop_oem` | Sent to OEM or specialist facility |
| `transit` | In transport — freight or airfreight |
| `remote_offshore` | Offshore field location, CTV or helicopter access |
| `unknown` | Not determinable from document |

---

### `port_service_type`

| Value | Description |
|-------|-------------|
| `port_dues` | Harbour/GRT-based port entry levy |
| `pilotage_inbound` | Compulsory pilot in |
| `pilotage_outbound` | Compulsory pilot out |
| `pilotage_shifting` | Pilot for berth-to-berth move |
| `pilot_transfer` | Launch or helicopter for pilot embarkation |
| `towage` | Tug assistance |
| `berthage` | Per-hour or per-day berth fee |
| `anchorage` | Anchorage fee |
| `stevedoring` | Gang labour — cargo handling |
| `crane_hire` | Shore crane on-hire |
| `mobile_crane` | Mobile crane (Franna, LTM) on-hire |
| `forklift` | Forklift by capacity |
| `ewp` | Elevated work platform |
| `rigging_dogman` | Rigging/dogman labour |
| `plant_operator` | Plant/machinery operator |
| `supervisor` | Site/supply base supervisor |
| `allowance` | NW/remote/shift allowance |
| `gangway` | Gangway provision per day |
| `fender` | Fender provision per day |
| `lighting_tower` | Temporary site lighting |
| `waste_disposal` | Skip bin/waste removal |
| `water_supply` | Freshwater or ballast supply |
| `fuel_supply` | Bunker or gas oil supply |
| `shore_power` | Cold ironing/shore electricity |
| `agency_attendance` | Shipping agent attendance fee |
| `other` | Catch-all |

---

### `freight_charge_type`

| Value | Description |
|-------|-------------|
| `international_freight` | Zero-rated main freight charge |
| `domestic_freight` | In-country road or air leg |
| `exworks_charges` | Origin packing/collection charges |
| `customs_clearance` | Import/export declaration fee |
| `terminal_fee` | Destination terminal/handling |
| `airline_doc_fee` | Airway bill document fee |
| `bond_fee` | Customs bond/security |
| `quarantine` | DAFF/biosecurity inspection fee |
| `edi_fee` | Electronic lodgement fee |
| `cartage` | Final mile trucking to consignee |
| `customs_duty` | Import duty payable |
| `deferred_gst` | GST deferred at border |
| `insurance` | Cargo insurance premium |
| `storage_demurrage` | Storage at port or warehouse |
| `other` | Catch-all |

---

### `tax_jurisdiction`

| Value | Description |
|-------|-------------|
| `au_gst` | Australian GST at 10% |
| `nz_gst` | New Zealand GST at 15% |
| `zero_rated` | Explicitly zero-rated supply (international freight, export) |
| `exempt` | Exempt from tax |
| `not_applicable` | No tax applies |

---

### `supplier_category`

| Value | Description |
|-------|-------------|
| `oem_dealer` | Authorised OEM dealer (CAT/WesTrac, MAN, Wärtsilä) |
| `oem_direct` | OEM direct supply (Damen, Kongsberg) |
| `independent_workshop` | Non-OEM engine or machinery workshop |
| `electrical_specialist` | Marine/industrial electrical contractor |
| `hydraulic_specialist` | Hydraulic systems contractor |
| `ndt_specialist` | NDT, UT, MPI inspection services |
| `diving_services` | Underwater inspection or repair |
| `dry_dock_operator` | Dry dock or slipway facility |
| `port_authority` | Statutory port body/harbour master |
| `port_services_co` | Commercial port services provider |
| `shipping_agency` | Vessel agency (pilotage, port call management) |
| `freight_domestic` | Domestic freight forwarder/courier |
| `freight_international` | International freight forwarder/customs broker |
| `tool_hire_co` | Equipment hire company |
| `industrial_supply` | General industrial/fasteners/consumables |
| `electronics_supply` | Electrical/electronic components supplier |
| `marine_systems` | Marine scientific or navigation systems integrator |
| `class_society` | Classification society (LR, BV, DNV, ABS) |
| `surveying_co` | Marine surveying firm |
| `naval_architect` | Naval architecture and engineering consultancy |
| `legal_professional` | Solicitors, P&I correspondents |
| `other` | Catch-all |

---

### `vessel_unit_type`

| Value | Description |
|-------|-------------|
| `main_engine` | Propulsion main engine |
| `auxiliary_engine` | Auxiliary engine |
| `diesel_generator` | Dedicated power generation set |
| `bow_thruster` | Bow thruster drive unit |
| `stern_thruster` | Stern thruster drive unit |
| `gearbox` | Reduction gearbox or CPP hub |
| `propeller_shaft` | Shaft, stern tube, seal |
| `propeller` | Fixed or CPP propeller |
| `rudder` | Rudder blade, stock, bearing |
| `steering_gear` | Electro-hydraulic steering unit |
| `hull_structure` | Plating, frames, bulkheads |
| `gondola` | Gondola/keel-mounted sonar housing |
| `deck_machinery` | Windlass, winch, capstan, crane |
| `cargo_equipment` | Pumps, hatches, cranes |
| `electrical_system` | Switchboard, distribution, cabling |
| `navigation_equipment` | Radar, ECDIS, GPS, comms |
| `scientific_equipment` | MBES, SBES, SVS, sonar arrays |
| `fire_fighting` | CO₂, foam, sprinkler systems |
| `life_saving` | Lifeboat, raft, EPIRB |
| `accommodation` | Interior, HVAC, galley |
| `piping_system` | Bilge, ballast, fuel, cooling piping |
| `mooring_equipment` | Bitts, fairleads, ropes |
| `vessel_general` | General vessel — not unit-specific |
| `other` | Catch-all |

---

### `casualty_type`

| Value | Description |
|-------|-------------|
| `machinery_damage` | Engine, gearbox, or auxiliary machinery failure |
| `fire` | Fire onboard |
| `flooding_sinking` | Ingress, sinking, grounding-flooding |
| `grounding` | Contact with seabed |
| `collision` | Vessel-to-vessel contact |
| `contact_damage` | Contact with fixed or floating object |
| `heavy_weather` | Structural or cargo damage from weather |
| `explosion` | Explosion or burst |
| `structural_failure` | Hull or structure failure not weather-caused |
| `electrical_failure` | Electrical fault, short circuit, arc flash |
| `cargo_damage` | Loss or damage to cargo |
| `piracy_theft` | Piracy, armed robbery, theft |
| `pollution` | Oil spill, pollution liability |
| `third_party_liability` | P&I liability claim |
| `other` | Catch-all |

---

### `repair_status`

| Value | Description |
|-------|-------------|
| `casualty_reported` | Initial notification received |
| `attending_survey` | Surveyor attending or inspecting |
| `scope_agreed` | Repair scope agreed with owner |
| `temporary_repairs` | Vessel trading on temporary repairs |
| `awaiting_drydock` | Drydock or port slot pending |
| `in_repair` | Permanent repairs in progress |
| `repairs_complete` | Repairs done, vessel back in service |
| `accounts_in_review` | Repair accounts under surveyor review |
| `accounts_approved` | Accounts approved WP, submitted to adjusters |
| `closed` | Case closed |

---

## AI Extraction Workflow

### Import pass

On PDF upload, the extraction pipeline performs the following in sequence:

1. **OCR check** — if `ocr_required` is true, run OCR before extraction.
2. **Document classification** — identify `document_type`, `line_item_structure`, `supplier`, `currency`, and `tax_jurisdiction`.
3. **Header extraction** — populate all `repair_document` header fields.
4. **Line extraction** — populate `raw_line` rows verbatim from the document. Store `raw_text` for each line.
5. **Account line suggestion** — AI groups raw lines into suggested `account_lines` based on segment codes, headings, and content. For mixed-nature invoices, set `mixed_nature_flag: true` and suggest separate account lines for damage and maintenance items.
6. **Presentation statement draft** — for each `repair_document` and each suggested `account_line`, draft an `ai_presentation_draft` in surveyor's voice, e.g.:

> *"The above account is rendered by Birdon Pty Ltd, Dampier Slipway, in respect of the slipping and temporary hull damage repair of M/Y Pangaea Ocean Explorer at the Birdon Dampier Slipway Facility between 21 and 26 September 2025, including Contract Change Proposal 002 for plate steel and stiffener reinforcement to bottom plating between frames 60 and 68."*

7. **Confidence scoring** — set `ai_confidence` at document level. Documents below 0.75 are flagged for mandatory manual review before the surveyor sees AI-suggested groupings.

### Surveyor review pass

The surveyor's workflow for each imported document:

1. Review AI-suggested `account_lines` — confirm, split, merge, or relabel.
2. Assign `cost_nature` to each account line.
3. Set `approved_amount`, `owners_portion`, `underwriters_portion`, and `betterment_deduction`.
4. Edit `presentation_statement` from the AI draft.
5. Set `surveyor_status` to `approved`, `partially_approved`, `owners_account`, or `queried`.

### Report generation

`account_summary` rows are generated from approved `account_lines` and fed directly into the London H&M account approval table in the report builder. The `presentation_statement` on `repair_document` maps to the italicised introductory sentence per invoice. The `presentation_statement` on `account_line` maps to the section narrative below each approved amount.

---

## Key Cross-Document Relationships

The schema supports explicit linkages between related documents:

- `freight_document.linked_document_id` links a freight invoice to the component invoice it transported. This enables cross-checking of customs declared value against supplier invoice value (e.g. Pro Freight S00027009/B customs value of AUD 232,364 cross-checks against Damen invoice 90028998 for the same amount).
- Multiple `repair_document` rows sharing the same `contract_ref` are related invoices under one contract (e.g. Birdon K168-1 and K168-2 both reference contract KB2523).
- Multiple Revelare invoices sharing `reference: QU-0132` are progress billings under the same quote/engagement.

---

## Notes for Surveyors

**Betterment.** When `is_replacement_component` is true, the `component_condition` and `component_part_number` fields together support the betterment analysis. If a 3516B block is replaced with a 3516C (later generation), the surveyor must note this in `surveyor_notes` and apply a `betterment_deduction` at the `account_line` level.

**Mixed-nature class society invoices.** When `mixed_nature_flag` is true, the AI will suggest separate account lines. The damage survey line should carry `cost_nature: inspection_survey` and go to underwriters. Annual statutory survey lines should carry `cost_nature: class_statutory` and go to owners' account. SAF (Safety Attendance Fee) weekend/weekday surcharges and travel/hotel expenses follow the allocation of the survey they supported.

**Without prejudice.** The `without_prejudice` field at `repair_document` level records whether the approval is WP. This should always be true for H&M casualty approvals unless specifically instructed otherwise by the placing broker or underwriter.

**Free text fields.** `surveyor_notes` at both `repair_document` and `account_line` level is intentionally unconstrained. The legal and commercial framing of approvals, deductions, and queries must remain in the surveyor's own words and is not driven by enums.
