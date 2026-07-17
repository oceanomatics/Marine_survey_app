-- 059_surveyor_notes_occurrence_phase.sql
--
-- Occurrence Narrative feature (docs/occurrence_narrative_spec.md).
-- A context cue allocated to the Occurrence section forks into one of three
-- phases, and the AI narrative is drafted from those phases in order:
--   1. before    — activities immediately before the incident (prelude)
--   2. incident   — information about the incident (the event)
--   3. aftermath  — the aftermath (post-event, through to a place of safety)
--
-- `occurrence_phase` is only meaningful for cues whose case_section =
-- 'occurrence'. Nullable: a cue not yet sorted into a phase (e.g. freshly
-- AI-extracted) sits in the "Unsorted" bucket until the surveyor or the AI
-- pre-sort assigns it. Cue forking = surveyor picks, AI pre-sorts.

ALTER TABLE surveyor_notes
  ADD COLUMN IF NOT EXISTS occurrence_phase text
  CHECK (occurrence_phase IS NULL
         OR occurrence_phase IN ('before', 'incident', 'aftermath'));

COMMENT ON COLUMN surveyor_notes.occurrence_phase IS
  'For occurrence-section cues only: which narrative phase (before/incident/aftermath) the cue feeds (docs/occurrence_narrative_spec.md).';
