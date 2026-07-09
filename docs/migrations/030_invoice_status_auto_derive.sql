-- 030_invoice_status_auto_derive.sql
--
-- Accounts — auto-derive invoice status from line-item statuses (flagged
-- by surveyor 9 July 2026, see docs/TODO.md §3.12).
--
-- `repair_documents.surveyor_status` (DocStatus) was purely manual — the
-- surveyor now wants it computed from the aggregate of that invoice's
-- `account_lines.surveyor_status` (LineItemStatus) values, with a manual
-- override still available for edge cases. This flag distinguishes
-- "currently auto-derived" (false, default — recomputed whenever a line
-- item's status changes) from "surveyor has manually overridden" (true —
-- left alone until explicitly reset back to auto).

ALTER TABLE repair_documents
  ADD COLUMN IF NOT EXISTS status_manually_set boolean NOT NULL DEFAULT false;
