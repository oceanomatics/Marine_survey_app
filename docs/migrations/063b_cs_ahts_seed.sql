-- 063b_cs_ahts_seed.sql — seed the AHTS C&S section skeleton (§1.0–11.0)
--
-- Companion to 063_cs_ahts.sql. Run in the Supabase SQL editor AFTER 063.
-- Idempotent: seeds exactly once (guarded on the template name); re-running is
-- a no-op so it will not duplicate rows.
--
-- SCOPE OF THIS SEED (read before extending):
--   This is a STARTER skeleton — the 11 top-level sections plus the sub-item
--   groupings named in CS_AHTS_Integration.docx §3.2. It is deliberately
--   coarse: the docx gives section-level structure, not the full authoritative
--   per-row Ref/Item list. Rows with grade_applicable=false are section /
--   sub-group HEADERS (not graded); grade_applicable=true rows are the actual
--   inspection items. The full item list (every graded row of the reference
--   report) drops in later as additional INSERTs against this same template —
--   no schema change, no rework. Until then a surveyor can grade at this
--   granularity and add ad-hoc items.
--
--   Sections 1.0–9.0 are the common core (reused by any future C&S vessel
--   type). 10.0 (Tug/AHT supplement) and 11.0 (DP supplement) are the
--   AHTS-specific supplements — a later PSV/barge C&S swaps only these.

DO $$
DECLARE
  tmpl uuid;
BEGIN
  SELECT id INTO tmpl FROM cs_template
   WHERE name = 'AHTS Condition & Suitability (reference skeleton)'
     AND vessel_type = 'ahts'
   LIMIT 1;

  IF tmpl IS NOT NULL THEN
    RAISE NOTICE 'AHTS template already seeded (%); skipping.', tmpl;
    RETURN;
  END IF;

  INSERT INTO cs_template (name, vessel_type, version)
  VALUES ('AHTS Condition & Suitability (reference skeleton)', 'ahts', 1)
  RETURNING id INTO tmpl;

  -- section, ref_no, label, guidance_text, grade_applicable, sort_order
  INSERT INTO cs_template_item
    (template_id, section, ref_no, label, guidance_text, grade_applicable, sort_order)
  VALUES
    -- 1.0 Executive Summary (verdict + narrative — not item-graded)
    (tmpl,'1.0','1.0','Executive Summary', 'Verdict + narrative: instructions, circumstances, suitability statement, recommendations (§1.13), observations, general remarks.', false, 100),

    -- 2.0 General Particulars (structured facts — reuses Vessel Particulars)
    (tmpl,'2.0','2.0','General Particulars', 'Name, type, flag, IMO, build, dimensions, class notation, tonnages. Overlaps existing Vessel Particulars.', false, 200),

    -- 3.0 Certification & Documentation (checklist — feeds cs_certificate register)
    (tmpl,'3.0','3.0','Certification & Documentation', 'Flag / statutory / class / safety-equipment certificates. Threshold-driven (GT-based applicability).', false, 300),
    (tmpl,'3.0','3.1','Flag & statutory certificates', NULL, true, 310),
    (tmpl,'3.0','3.2','Class certificates & survey status', NULL, true, 320),
    (tmpl,'3.0','3.3','Safety equipment certificates', NULL, true, 330),

    -- 4.0 Manning (structured + graded)
    (tmpl,'4.0','4.0','Manning', 'Key personnel, certification, safe-manning compliance.', false, 400),
    (tmpl,'4.0','4.1','Key personnel & certification', NULL, true, 410),
    (tmpl,'4.0','4.2','Safe manning compliance', NULL, true, 420),

    -- 5.0 Hull Structure & Condition (graded checklist)
    (tmpl,'5.0','5.0','Hull Structure & Condition', 'Deck, shell, tanks, cranes, deck additional.', false, 500),
    (tmpl,'5.0','5.1','Deck & shell plating', NULL, true, 510),
    (tmpl,'5.0','5.2','Tanks & void spaces', NULL, true, 520),
    (tmpl,'5.0','5.3','Cranes & lifting appliances', NULL, true, 530),
    (tmpl,'5.0','5.4','Deck additional (crash rails, lashing points)', NULL, true, 540),

    -- 6.0 Machinery (graded checklist)
    (tmpl,'6.0','6.0','Machinery', 'PMS, ME/AE, thrusters, steering, consumables, environmental.', false, 600),
    (tmpl,'6.0','6.1','Planned maintenance system (PMS)', NULL, true, 610),
    (tmpl,'6.0','6.2','Main & auxiliary engines', NULL, true, 620),
    (tmpl,'6.0','6.3','Thrusters & propulsion', NULL, true, 630),
    (tmpl,'6.0','6.4','Steering gear', NULL, true, 640),
    (tmpl,'6.0','6.5','Consumables & environmental', NULL, true, 650),

    -- 7.0 Navigation & Communication (graded checklist, GT-thresholded)
    (tmpl,'7.0','7.0','Navigation & Communication', 'Bridge, charts, nav equipment by GT threshold, GMDSS.', false, 700),
    (tmpl,'7.0','7.1','Bridge & charts', NULL, true, 710),
    (tmpl,'7.0','7.2','Navigation equipment', NULL, true, 720),
    (tmpl,'7.0','7.3','GMDSS / communications', NULL, true, 730),

    -- 8.0 Lifesaving & Fire Equipment (graded checklist)
    (tmpl,'8.0','8.0','Lifesaving & Fire Equipment', 'LSA, fixed/portable fire, detection.', false, 800),
    (tmpl,'8.0','8.1','Life-saving appliances (LSA)', NULL, true, 810),
    (tmpl,'8.0','8.2','Fixed & portable fire-fighting', NULL, true, 820),
    (tmpl,'8.0','8.3','Fire detection', NULL, true, 830),

    -- 9.0 Health, Safety, Security & Environment (graded checklist)
    (tmpl,'9.0','9.0','Health, Safety, Security & Environment', 'SMS, permits, PPE, drills, security (ISPS).', false, 900),
    (tmpl,'9.0','9.1','Safety management system (SMS)', NULL, true, 910),
    (tmpl,'9.0','9.2','Permits to work & PPE', NULL, true, 920),
    (tmpl,'9.0','9.3','Drills & records', NULL, true, 930),
    (tmpl,'9.0','9.4','Security (ISPS)', NULL, true, 940),

    -- 10.0 Tug / AHT Supplement (AHTS-specific)
    (tmpl,'10.0','10.0','Tug / AHT Supplement', 'Bollard pull, tow & AH winches, wires, pennants, shark jaws + Anchor Handling & Bunkering sub-supplements.', false, 1000),
    (tmpl,'10.0','10.1','Bollard pull', NULL, true, 1010),
    (tmpl,'10.0','10.2','Tow & anchor-handling winches', NULL, true, 1020),
    (tmpl,'10.0','10.3','Wires & pennants', NULL, true, 1030),
    (tmpl,'10.0','10.4','Shark jaws & towing pins', NULL, true, 1040),
    (tmpl,'10.0','10.5','Anchor handling sub-supplement', NULL, true, 1050),
    (tmpl,'10.0','10.6','Bunkering sub-supplement', NULL, true, 1060),

    -- 11.0 DP Vessel Supplement (AHTS-specific)
    (tmpl,'11.0','11.0','DP Vessel Supplement', 'DP class, FMEA, reference systems, DP PMS, footprints.', false, 1100),
    (tmpl,'11.0','11.1','DP class & notation', NULL, true, 1110),
    (tmpl,'11.0','11.2','FMEA & proving trials', NULL, true, 1120),
    (tmpl,'11.0','11.3','Position reference systems', NULL, true, 1130),
    (tmpl,'11.0','11.4','DP planned maintenance', NULL, true, 1140),
    (tmpl,'11.0','11.5','DP capability / footprints', NULL, true, 1150);

  RAISE NOTICE 'Seeded AHTS C&S template % with % items.',
    tmpl, (SELECT count(*) FROM cs_template_item WHERE template_id = tmpl);
END $$;
