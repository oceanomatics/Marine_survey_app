-- 057_merge_checklist_templates.sql
--
-- 14 July 2026 walkthrough §19: "content correction, not a bug" — the
-- checklist content Andy provided (migration 043, seeded only as the
-- case_type='pi' 58-item MM09 "Advice of Survey Attendance" set) is
-- actually applicable to most H&M surveys too. The two case-type-specific
-- template sets should be merged into one shared checklist rather than
-- keeping H&M on separate placeholder content (38 first-pass invented rows,
-- same vintage as the old pi placeholder set migration 043 replaced).
--
-- No application code change needed: cases_provider.dart's
-- _cloneChecklistTemplate() already clones whichever template_type rows
-- match the new case's own case_type at creation time — it just needs both
-- case_type values to carry the same content, which this migration does by
-- literally duplicating the pi content under case_type='hm'. Existing cases
-- that already cloned the old hm placeholder set into their own checklists
-- rows are untouched — this only changes what NEW cases get seeded with.
DELETE FROM checklist_templates WHERE case_type = 'hm';

INSERT INTO checklist_templates (case_type, stage, item_no, item_text, linked_section) VALUES
('hm', 'on_vessel', 1,  'Meeting with the Master', NULL),
('hm', 'on_vessel', 2,  'Meeting with the Chief Engineer', NULL),
('hm', 'on_vessel', 3,  'Meeting with Superintendent (if present)', NULL),
('hm', 'on_vessel', 4,  'Meeting with Repair Manager', NULL),
('hm', 'on_vessel', 5,  'Vessel Principal Particulars Sheet', 'vessel_particulars'),
('hm', 'on_vessel', 6,  'Access to vessel trading certificates', 'vessel_particulars'),
('hm', 'on_vessel', 7,  'Conditions of Class', 'vessel_particulars'),
('hm', 'on_vessel', 8,  'Port State / Flag State Inspection reports', 'vessel_particulars'),
('hm', 'on_vessel', 9,  'Class Status report', 'vessel_particulars'),
('hm', 'on_vessel', 10, 'Vessel Contact Details', NULL),
('hm', 'on_vessel', 11, 'Bridge Logbook', NULL),
('hm', 'on_vessel', 12, 'Engineroom Logbook', NULL),
('hm', 'on_vessel', 13, 'Crew List', NULL),
('hm', 'on_vessel', 14, 'Bell Book, or Movement Log', NULL),
('hm', 'on_vessel', 15, 'Telegraph Data Logger', NULL),
('hm', 'on_vessel', 16, 'Passage Plan, Charts', NULL),
('hm', 'on_vessel', 17, 'Statement of Facts', NULL),
('hm', 'on_vessel', 18, 'Note of Protest', NULL),
('hm', 'on_vessel', 19, 'Vessel ISM Incident Report', NULL),
('hm', 'on_vessel', 20, 'Relevant Work Procedures', NULL),
('hm', 'on_vessel', 21, 'Relevant Risk Analysis (Job Hazard Analysis)', NULL),
('hm', 'on_vessel', 22, 'Permit to Operate', NULL),
('hm', 'on_vessel', 23, 'Incident Report to Flag / Port State (AMSA Form 18 and 19)', NULL),
('hm', 'on_vessel', 24, 'Statement of Facts - ROB', NULL),
('hm', 'on_vessel', 25, 'On-Hire / Off-Hire times & dates', NULL),
('hm', 'on_vessel', 26, 'Ship''s Images', NULL),
('hm', 'on_vessel', 27, 'Repair Quotes / Estimates', NULL),
('hm', 'on_vessel', 28, 'Drawings with Damage Mark-Ups', NULL),
('hm', 'on_vessel', 29, 'Repair Plan', NULL),
('hm', 'on_vessel', 30, 'Discussion with repairers or technical representatives of damaged equipment', NULL),
('hm', 'on_vessel', 31, 'Towage Arrangements', NULL),
('hm', 'on_vessel', 32, 'Survey of Claimed Damage', 'damage_description'),
('hm', 'on_vessel', 33, 'Lube Oil Analysis', NULL),
('hm', 'on_vessel', 34, 'Manufacturers Manual', NULL),
('hm', 'on_vessel', 35, 'Parts Lists', NULL),
('hm', 'on_vessel', 36, 'Planned Maintenance System', NULL),
('hm', 'on_vessel', 37, 'Service / Overhaul Reports', NULL),
('hm', 'on_vessel', 38, 'Machinery Running Hours', NULL),
('hm', 'on_vessel', 39, 'Data / Alarm Logger Records', NULL),
('hm', 'on_vessel', 40, 'General Arrangement Drawing', NULL),
('hm', 'on_vessel', 41, 'Construction Drawings', NULL),
('hm', 'on_vessel', 42, 'Shell Expansion Drawing', NULL),
('hm', 'on_vessel', 43, 'Stability Book', NULL),
('hm', 'on_vessel', 44, 'Lashing & Securing Plan', NULL),
('hm', 'on_vessel', 45, 'Stowage Plan', NULL),
('hm', 'on_vessel', 46, 'Cargo Securing Manual', NULL),
('hm', 'on_vessel', 47, 'Oil Record Book', NULL),
('hm', 'on_vessel', 48, 'Bunker Receipts', NULL),
('hm', 'on_vessel', 49, 'Bunker Plan', NULL),
('hm', 'on_vessel', 50, 'Collection of Fuel Samples', NULL),
('hm', 'on_vessel', 51, 'Fuel Oil Analysis Records', NULL),
('hm', 'on_vessel', 52, 'Off Hire Records', NULL),
('hm', 'on_vessel', 53, 'Bunker ROB', NULL),
('hm', 'on_vessel', 54, 'Tank Plan', NULL),
('hm', 'on_vessel', 55, 'Fuel Changeover Procedure', NULL),
('hm', 'on_vessel', 56, 'Fuel Changeover Record', NULL),
('hm', 'on_vessel', 57, 'Onboard Fuel Treatment', NULL),
('hm', 'on_vessel', 58, 'Marine Fuel Oil Sulphur Record Book', NULL);
