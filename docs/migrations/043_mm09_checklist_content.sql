-- 043_mm09_checklist_content.sql
--
-- Replaces the case_type='pi' placeholder checklist_templates content (12
-- first-pass rows invented pending real content) with Andy's actual MM09
-- "Advice of Survey Attendance" document/access-request list (58 items).
-- All under stage='on_vessel' — the source document itself has no stage
-- breakdown, it's literally "the items that will require to be addressed
-- during our attendance". case_type='hm' templates are untouched.
--
-- linked_section is only set on the handful of items with an honest,
-- non-invented match to an existing case_completeness.dart key (mirroring
-- the same 4 vessel_particulars-linked items the old pi placeholder set
-- had, plus the one damage-description match) — everything else is left
-- NULL rather than force-fit, same discipline as migrations 040/041.
DELETE FROM checklist_templates WHERE case_type = 'pi';

INSERT INTO checklist_templates (case_type, stage, item_no, item_text, linked_section) VALUES
('pi', 'on_vessel', 1,  'Meeting with the Master', NULL),
('pi', 'on_vessel', 2,  'Meeting with the Chief Engineer', NULL),
('pi', 'on_vessel', 3,  'Meeting with Superintendent (if present)', NULL),
('pi', 'on_vessel', 4,  'Meeting with Repair Manager', NULL),
('pi', 'on_vessel', 5,  'Vessel Principal Particulars Sheet', 'vessel_particulars'),
('pi', 'on_vessel', 6,  'Access to vessel trading certificates', 'vessel_particulars'),
('pi', 'on_vessel', 7,  'Conditions of Class', 'vessel_particulars'),
('pi', 'on_vessel', 8,  'Port State / Flag State Inspection reports', 'vessel_particulars'),
('pi', 'on_vessel', 9,  'Class Status report', 'vessel_particulars'),
('pi', 'on_vessel', 10, 'Vessel Contact Details', NULL),
('pi', 'on_vessel', 11, 'Bridge Logbook', NULL),
('pi', 'on_vessel', 12, 'Engineroom Logbook', NULL),
('pi', 'on_vessel', 13, 'Crew List', NULL),
('pi', 'on_vessel', 14, 'Bell Book, or Movement Log', NULL),
('pi', 'on_vessel', 15, 'Telegraph Data Logger', NULL),
('pi', 'on_vessel', 16, 'Passage Plan, Charts', NULL),
('pi', 'on_vessel', 17, 'Statement of Facts', NULL),
('pi', 'on_vessel', 18, 'Note of Protest', NULL),
('pi', 'on_vessel', 19, 'Vessel ISM Incident Report', NULL),
('pi', 'on_vessel', 20, 'Relevant Work Procedures', NULL),
('pi', 'on_vessel', 21, 'Relevant Risk Analysis (Job Hazard Analysis)', NULL),
('pi', 'on_vessel', 22, 'Permit to Operate', NULL),
('pi', 'on_vessel', 23, 'Incident Report to Flag / Port State (AMSA Form 18 and 19)', NULL),
('pi', 'on_vessel', 24, 'Statement of Facts - ROB', NULL),
('pi', 'on_vessel', 25, 'On-Hire / Off-Hire times & dates', NULL),
('pi', 'on_vessel', 26, 'Ship''s Images', NULL),
('pi', 'on_vessel', 27, 'Repair Quotes / Estimates', NULL),
('pi', 'on_vessel', 28, 'Drawings with Damage Mark-Ups', NULL),
('pi', 'on_vessel', 29, 'Repair Plan', NULL),
('pi', 'on_vessel', 30, 'Discussion with repairers or technical representatives of damaged equipment', NULL),
('pi', 'on_vessel', 31, 'Towage Arrangements', NULL),
('pi', 'on_vessel', 32, 'Survey of Claimed Damage', 'damage_description'),
('pi', 'on_vessel', 33, 'Lube Oil Analysis', NULL),
('pi', 'on_vessel', 34, 'Manufacturers Manual', NULL),
('pi', 'on_vessel', 35, 'Parts Lists', NULL),
('pi', 'on_vessel', 36, 'Planned Maintenance System', NULL),
('pi', 'on_vessel', 37, 'Service / Overhaul Reports', NULL),
('pi', 'on_vessel', 38, 'Machinery Running Hours', NULL),
('pi', 'on_vessel', 39, 'Data / Alarm Logger Records', NULL),
('pi', 'on_vessel', 40, 'General Arrangement Drawing', NULL),
('pi', 'on_vessel', 41, 'Construction Drawings', NULL),
('pi', 'on_vessel', 42, 'Shell Expansion Drawing', NULL),
('pi', 'on_vessel', 43, 'Stability Book', NULL),
('pi', 'on_vessel', 44, 'Lashing & Securing Plan', NULL),
('pi', 'on_vessel', 45, 'Stowage Plan', NULL),
('pi', 'on_vessel', 46, 'Cargo Securing Manual', NULL),
('pi', 'on_vessel', 47, 'Oil Record Book', NULL),
('pi', 'on_vessel', 48, 'Bunker Receipts', NULL),
('pi', 'on_vessel', 49, 'Bunker Plan', NULL),
('pi', 'on_vessel', 50, 'Collection of Fuel Samples', NULL),
('pi', 'on_vessel', 51, 'Fuel Oil Analysis Records', NULL),
('pi', 'on_vessel', 52, 'Off Hire Records', NULL),
('pi', 'on_vessel', 53, 'Bunker ROB', NULL),
('pi', 'on_vessel', 54, 'Tank Plan', NULL),
('pi', 'on_vessel', 55, 'Fuel Changeover Procedure', NULL),
('pi', 'on_vessel', 56, 'Fuel Changeover Record', NULL),
('pi', 'on_vessel', 57, 'Onboard Fuel Treatment', NULL),
('pi', 'on_vessel', 58, 'Marine Fuel Oil Sulphur Record Book', NULL);
