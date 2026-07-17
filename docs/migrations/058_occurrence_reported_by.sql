-- 058_occurrence_reported_by.sql
--
-- Occurrence Narrative feature (docs/occurrence_narrative_spec.md).
-- "Reported by" = an attendee picker on the occurrence. The chosen attendee's
-- role (Master / Chief Engineer / Owner's Representative …) fills the "[role]"
-- slot in the fixed narrative opening
--   "It was reported by the [role] that on [date], the subject vessel was …".
--
-- Nullable FK -> attendees. ON DELETE SET NULL so removing an attendee never
-- blocks or cascades into the occurrence; the narrative simply falls back to
-- the generic "vessel's Master" descriptor until a new reporter is picked.

ALTER TABLE occurrences
  ADD COLUMN IF NOT EXISTS reported_by_attendee_id uuid
  REFERENCES attendees(attendee_id) ON DELETE SET NULL;

COMMENT ON COLUMN occurrences.reported_by_attendee_id IS
  'Attendee whose account the occurrence narrative is reported from; fills the [role] slot in the narrative opening (docs/occurrence_narrative_spec.md).';
