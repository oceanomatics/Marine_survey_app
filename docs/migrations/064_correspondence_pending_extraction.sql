-- 064_correspondence_pending_extraction.sql
--
-- Correspondence AI extraction now produces a rich, routable result
-- (CorrExtractionResult: typed key-dates, context findings, incidents, damage,
-- repairs, costs, background, parties, header refs) that the surveyor reviews
-- and selectively imports into case records via a per-item selector sheet —
-- parity with the document-extraction pipeline.
--
-- Persist the pending result on the correspondence row so an auto-extracted
-- email can be reviewed later, not only inline. Set to null once imported.
-- Supabase-only column; the local SQLite cache (CorrespondenceModel.toMap) is
-- untouched — the review flow reads pending_extraction directly from Supabase.

ALTER TABLE correspondence
  ADD COLUMN IF NOT EXISTS pending_extraction jsonb;
