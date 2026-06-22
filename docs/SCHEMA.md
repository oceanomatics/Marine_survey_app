# Supabase Schema Reference
<!-- Auto-maintained by Claude Code. Run the dump query, paste the result, ask Claude to update. -->
<!-- Last updated: 2026-06-22 — partial dump (message truncated at ~50k chars; tables a–d captured) -->

---

> **How to refresh this file:**
> Run the dump query below in **Supabase → SQL Editor**,
> copy the full result, paste it into the chat, and say "update the schema file".

```sql
SELECT
  'COLUMN' AS kind, c.table_name, c.ordinal_position::text AS seq,
  c.column_name AS name,
  c.data_type || CASE WHEN c.character_maximum_length IS NOT NULL
    THEN '(' || c.character_maximum_length || ')' ELSE '' END AS type,
  CASE c.is_nullable WHEN 'NO' THEN 'NOT NULL' ELSE '' END AS nullable,
  COALESCE(c.column_default, '') AS default_val
FROM information_schema.tables t
JOIN information_schema.columns c
  ON c.table_schema = t.table_schema AND c.table_name = t.table_name
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
UNION ALL
SELECT 'FK', tc.table_name, '', kcu.column_name,
  ccu.table_name || '(' || ccu.column_name || ')', rc.delete_rule, ''
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints rc ON rc.constraint_name = tc.constraint_name
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
UNION ALL
SELECT 'RLS', tablename, '', policyname, cmd, '', LEFT(qual,120)
FROM pg_policies WHERE schemaname = 'public'
UNION ALL
SELECT 'IDX', tablename, '', indexname, '', '', indexdef
FROM pg_indexes WHERE schemaname = 'public' AND indexname NOT LIKE '%_pkey'
UNION ALL
SELECT 'TRIGGER', event_object_table, '', trigger_name, event_manipulation,
  action_timing, LEFT(action_statement,120)
FROM information_schema.triggers WHERE trigger_schema = 'public'
ORDER BY table_name, kind, seq, name;
```

---

## Current Schema

> **Note:** Dump was truncated mid-table (`damage_items`). Tables from `documents` onward
> (including `surveyor_notes`, `vessels`, `occurrences`, etc.) are not yet captured here.
> Re-run the dump to get the full picture.

### `assured_contacts`
| col | type | nullable | default |
|-----|------|----------|---------|
| contact_id | uuid | NOT NULL | gen_random_uuid() |
| case_id | uuid | NOT NULL | |
| full_name | text | NOT NULL | |
| role_title | text | | |
| phone | text | | |
| email | text | | |
| notes | text | | |
| created_at | timestamptz | | now() |

FK: `case_id` → `cases(case_id)` CASCADE  
RLS: authenticated users can SELECT / INSERT / DELETE

---

### `attendances`
| col | type | nullable | default |
|-----|------|----------|---------|
| attendance_id | uuid | NOT NULL | uuid_generate_v4() |
| case_id | uuid | NOT NULL | |
| sequence_no | integer | NOT NULL | 1 |
| date | date | NOT NULL | |
| location | text | | |
| surveyor_id | uuid | | |
| vessel_draft_fwd | numeric | | |
| vessel_draft_aft | numeric | | |
| vessel_condition | text | | |
| notes | text | | |
| created_at | timestamptz | | now() |
| updated_at | timestamptz | | now() |

FK: `case_id` → `cases(case_id)` CASCADE  
Index: `idx_attendances_case_id`  
RLS: Authenticated full access  
Trigger: `trg_attendances_updated_at` → `update_updated_at()`

---

### `attendees`
| col | type | nullable | default |
|-----|------|----------|---------|
| attendee_id | uuid | NOT NULL | uuid_generate_v4() |
| case_id | uuid | NOT NULL | |
| attendance_id | uuid | | |
| full_name | text | NOT NULL | |
| rank_position | text | | |
| company | text | | |
| representing | text | | |
| role_type | text | | |
| dp_certification | text | | |
| cert_expiry | date | | |
| contact_email | text | | |
| contact_phone | text | | |
| created_at | timestamptz | | now() |

FK: `case_id` → `cases(case_id)` CASCADE; `attendance_id` → `attendances(attendance_id)` NO ACTION  
Index: `idx_attendees_case_id`  
RLS: Authenticated full access

---

### `case_background` ✅ EXISTS
| col | type | nullable | default |
|-----|------|----------|---------|
| case_id | uuid | NOT NULL | — (PK) |
| content | text | NOT NULL | `''` |
| updated_at | timestamptz | NOT NULL | now() |

FK: `case_id` → `cases(case_id)` CASCADE  
RLS: `Surveyor can manage own case background` (ALL) — `case_id IN (SELECT case_id FROM cases WHERE assigned_surveyor = auth.uid())`

---

### `case_parties`
| col | type | nullable |
|-----|------|----------|
| case_id | uuid | NOT NULL |
| principal_name / _company / _email | text | |
| reviewer_name / _company / _email | text | |
| underwriter_name / _company / _email | text | |
| adjuster_name / _company / _email / _phone | text | |

FK: `case_id` → `cases(case_id)` CASCADE  
RLS: authenticated SELECT / UPDATE / INSERT (upsert)

---

### `cases` ⭐ Primary table
| col | type | nullable | default |
|-----|------|----------|---------|
| case_id | uuid | NOT NULL | uuid_generate_v4() — **PK** |
| job_number | text | NOT NULL | |
| case_type | USER-DEFINED | NOT NULL | |
| status | USER-DEFINED | NOT NULL | `'open'` |
| output_format | USER-DEFINED | | |
| client_id | uuid | | |
| vessel_id | uuid | | |
| instruction_date | date | | |
| claim_reference | text | | |
| principal_id | uuid | | |
| assigned_surveyor | uuid | | **Used by RLS policies** |
| inbox_email_tag | text | | |
| storage_folder_path | text | | |
| notes | text | | |
| title | text | | |
| created_at | timestamptz | | now() |
| updated_at | timestamptz | | now() |

FK: `client_id` / `principal_id` → `principals_clients(principal_id)`; `vessel_id` → `vessels(vessel_id)`  
Indexes: `cases_job_number_key` (UNIQUE), `idx_cases_assigned`, `idx_cases_job_number`, `idx_cases_status`, `idx_cases_vessel_id`  
RLS: Authenticated full access  
Trigger: `trg_cases_updated_at`

---

### `certificates`
| col | type | nullable | default |
|-----|------|----------|---------|
| cert_id | uuid | NOT NULL | uuid_generate_v4() |
| case_id | uuid | | |
| vessel_id | uuid | | |
| cert_type | USER-DEFINED | NOT NULL | |
| cert_name / issuing_authority | text | | |
| issue_date / expiry_date / annual_survey_date | date | | |
| cert_number | text | | |
| status | USER-DEFINED | | `'tbc'` |
| source_doc_id | uuid | | |
| extracted_auto | boolean | | false |
| notes | text | | |
| created_at / updated_at | timestamptz | | now() |

FK: `case_id` → `cases(case_id)` CASCADE; `source_doc_id` → `documents(doc_id)` SET NULL; `vessel_id` → `vessels(vessel_id)`  
Index: `idx_certs_case_id`  
RLS: Authenticated full access  
Trigger: `trg_certificates_updated_at`

---

### `checklist_templates`
| col | type | nullable |
|-----|------|----------|
| template_id | uuid | NOT NULL |
| case_type | USER-DEFINED | NOT NULL |
| stage | USER-DEFINED | NOT NULL |
| item_no | integer | NOT NULL |
| item_text | text | NOT NULL |
| linked_section | USER-DEFINED | |
| created_at | timestamptz | |

---

### `checklists`
| col | type | nullable | default |
|-----|------|----------|---------|
| checklist_id | uuid | NOT NULL | uuid_generate_v4() |
| case_id | uuid | NOT NULL | |
| template_type | USER-DEFINED | | |
| stage | USER-DEFINED | NOT NULL | |
| item_no | integer | NOT NULL | |
| item_text | text | NOT NULL | |
| completed | boolean | | false |
| completed_at | timestamptz | | |
| completed_by | uuid | | |
| linked_section | USER-DEFINED | | |
| linked_id | uuid | | |
| notes | text | | |
| created_at / updated_at | timestamptz | | now() |

FK: `case_id` → `cases(case_id)` CASCADE  
Index: `idx_checklists_case_id`  
RLS: Authenticated full access  
Trigger: `trg_checklists_updated_at`

---

### `clause_library`
| col | type | nullable | default |
|-----|------|----------|---------|
| clause_id | uuid | NOT NULL | uuid_generate_v4() |
| format_type | USER-DEFINED | NOT NULL | |
| clause_type | USER-DEFINED | NOT NULL | |
| clause_label / clause_text | text | NOT NULL | |
| is_locked | boolean | | true |
| editable_by | USER-DEFINED | | `'admin_only'` |
| version | integer | | 1 |
| effective_date | date | | |
| deprecated | boolean | | false |
| created_at / updated_at | timestamptz | | now() |

Index: `idx_clause_format_type` (format_type, clause_type)  
RLS: Admin can modify (ALL); Authenticated can read (SELECT)  
Trigger: `trg_clause_library_updated_at`

---

### `cs_sections`
| col | type | nullable |
|-----|------|----------|
| section_id | uuid | NOT NULL |
| case_id | uuid | NOT NULL |
| section_type / rating / narrative | text | |
| photos_linked | jsonb | |
| created_at / updated_at | timestamptz | |

FK: `case_id` → `cases(case_id)` CASCADE  
RLS: Authenticated full access  
Trigger: `trg_cs_sections_updated_at`

---

### `damage_items` (partial — dump truncated)
Known columns: `damage_id`, `occurrence_id` (NOT NULL), `case_id` (NOT NULL), `machinery_id`, `component_name` (NOT NULL), `location_on_vessel`, `damage_description`, `repair_status`, `is_concerning_average`, `exclusion_reason`, `sequence_no`, `item_no`, `damage_category`, `created_at`, `updated_at`

---

### Tables not yet captured (dump truncated)
`documents`, `occurrences`, `principals_clients`, `surveyor_notes`, `vessels`, and any others alphabetically after `damage_items`.

---

## Pending Migrations

### `case_background` ✅ ALREADY EXISTS — no action needed

### `surveyor_notes` ✅ ALREADY EXISTS — no action needed
Confirmed columns: `id`, `case_id`, `content`, `category` (default `'general'`), `report_section`, `linked_to_type`, `linked_to_id`, `created_at`, `updated_at`  
All columns match app model. RLS and trigger status not separately verified but table is operational.

---

## App enums that map to DB text columns

### `report_section` (surveyor_notes)
| DB value | App enum | Screen label |
|---|---|---|
| `background` | `ReportSection.background` | Background |
| `occurrence` | `ReportSection.occurrence` | Occurrence |
| `attendance` | `ReportSection.attendance` | Attendance & Representatives |
| `timeline` | `ReportSection.timeline` | Case Timeline |
| `causation` | `ReportSection.causation` | Allegation / Causation |
| `damage` | `ReportSection.damage` | Extent of Damage |
| `repairs` | `ReportSection.repairs` | Repairs |
| `repair_times` | `ReportSection.repairTimes` | Repair Times |
| `extra_expenses` | `ReportSection.extraExpenses` | Extra Expenses |
| `general_expenses` | `ReportSection.generalExpenses` | General Expenses |
| `not_average` | `ReportSection.notAverage` | Work Not Concerning Average |
| `other_matters` | `ReportSection.otherMatters` | Other Matters of Relevance |

### `category` (surveyor_notes)
| DB value | App enum |
|---|---|
| `observation` | `NoteCategory.observation` |
| `measurement` | `NoteCategory.measurement` |
| `follow_up` | `NoteCategory.followUp` |
| `interview` | `NoteCategory.interview` |
| `technical` | `NoteCategory.technical` |
| `general` | `NoteCategory.general` |
