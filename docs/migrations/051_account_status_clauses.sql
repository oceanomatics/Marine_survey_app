-- 051_account_status_clauses.sql
--
-- H-3 (account assessment outcome) only had clauses for 3 of the 6
-- DocStatus values (approved/partly_approved/queried) — pending_review,
-- under_review, and rejected produced no report text at all (silently
-- skipped in docx_export_service.dart). Surveyor flagged this live,
-- 14 July 2026, as not matching the original brief: an invoice awaiting
-- assessment should not simply vanish from the report.
--
-- clause_type is a real Postgres enum (clause_type_enum) — new values
-- must be added before they can be inserted into clause_library.
--
-- NOTE: clause_text below is DRAFT wording (matching the tone of the
-- existing account_* clauses), not surveyor-approved verbatim text —
-- same "draft now, review after" pattern already used for the WP/waiver
-- clauses (see docs/AUDIT_delta.md decisions A3/E3). Needs Pierre-Louis's
-- review before relying on it for a real export.

ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'account_pending_assessment';
ALTER TYPE clause_type_enum ADD VALUE IF NOT EXISTS 'account_rejected';

INSERT INTO clause_library (format_type, clause_type, clause_label, clause_text, is_locked, editable_by) VALUES
  ('abl', 'account_pending_assessment', 'ABL Internal — Account — Pending Assessment',
   'The account has been received and is under review. Assessment has not yet been finalised.', true, 'admin_only'),
  ('abl', 'account_rejected', 'ABL Internal — Account — Rejected',
   'The account is not approved.', true, 'admin_only'),
  ('oceano_services', 'account_pending_assessment', 'Oceanoservices — Account — Pending Assessment',
   'The account has been received and is under review. Assessment has not yet been finalised.', true, 'admin_only'),
  ('oceano_services', 'account_rejected', 'Oceanoservices — Account — Rejected',
   'The account is not approved.', true, 'admin_only');
