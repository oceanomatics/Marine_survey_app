-- 036_document_source_correspondence.sql
--
-- TODO.md §3.14 — "Attachments pulled into Doc Vault should show their
-- status back in Correspondence (cross-link, not orphan)". Both attachment
-- import paths (manual .eml upload, Gmail import — correspondence_screen.dart
-- _importEml/_importFromGmail) already create the CorrespondenceModel before
-- uploading its attachments to documents via uploadAndCreate(), so wiring
-- this through is a producer-side change, not a backfill of historical data
-- (existing attachment documents predate this column and will just show no
-- badge, same as before this migration).
-- correspondence.id is text (client-generated uuid string, offline-first
-- write pattern), not the uuid type most other tables use — match it.
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS source_correspondence_id text
    REFERENCES correspondence(id) ON DELETE SET NULL;
