-- 035_extraction_queue.sql
--
-- TODO.md §4.1 — client-side async extraction queue. Scope decided with the
-- surveyor 13 July 2026: non-blocking within the app (auto-fire extraction
-- on upload, background processing, Production Manager status view), not
-- the full always-on server-side pipeline (that needs a Supabase secret +
-- Edge Function + pg_cron, deliberately left for when Phase 2's
-- ANTHROPIC_API_KEY-as-secret work happens anyway).
--
-- documents.pending_extraction: the RAW (un-confirmed) Claude extraction
-- result, persisted so a background-run extraction survives navigating
-- away / closing the review sheet without losing the work already done.
-- Distinct from the existing extracted_data column, which only ever holds
-- the surveyor-CONFIRMED subset after saveExtracted() — extraction here
-- still never auto-writes case data, same human-in-the-loop principle as
-- the cue pendingReview pattern. Cleared back to null once confirmed.
--
-- extraction_status gains one new value used by both tables: 'ready_for_review'
-- (extraction ran, raw result stored, awaiting the surveyor's confirm pass).
-- No CHECK constraint exists on either column (plain text) so no enum change
-- needed. repair_documents never had an extraction_status column at all —
-- extraction there was fully manual/on-demand; adding it lets the same
-- Production Manager view and auto-fire-on-import treatment cover invoices.
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS pending_extraction jsonb;

ALTER TABLE repair_documents
  ADD COLUMN IF NOT EXISTS extraction_status text;

-- Backfill: invoices already AI-extracted under the old fully-manual flow
-- get 'completed' so the Production Manager view doesn't show them as
-- never-processed; everything else is left NULL ("never queued"), same
-- as before this migration — only newly-imported invoices going forward
-- get auto-fired into 'pending'.
UPDATE repair_documents
  SET extraction_status = 'completed'
  WHERE ai_extracted_at IS NOT NULL AND extraction_status IS NULL;
