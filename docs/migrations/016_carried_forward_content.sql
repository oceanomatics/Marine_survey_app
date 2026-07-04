-- 016_carried_forward_content.sql
--
-- Successive-report carry-forward (docs/report_builder_editor_notes.md
-- gap #10). Stores the prior report output's approved narrative for a
-- section as a frozen, read-only base — the surveyor's new `content` for
-- this output is the incremental delta only. Rendered seamlessly at
-- export/preview as carried_forward_content + '\n\n' + content (see
-- ReportSection.fullContent in report_provider.dart).
--
-- Additive only: nullable column, no existing rows touched.

ALTER TABLE report_sections
  ADD COLUMN IF NOT EXISTS carried_forward_content text;
