-- 054_attendee_representing_party.sql
--
-- Attendee -> Parties/Stakeholder link (14 July 2026 walkthrough: "Yes,
-- definitely build it — important"). `attendees.representing` has always
-- been free text with no link to the case's actual stakeholder list
-- (`assured_contacts`). This adds an optional FK alongside it — the
-- free-text field stays as a fallback/override for attendees who don't
-- correspond to any logged stakeholder, matching the same
-- pick-existing-or-add-new pattern already used for Machinery/Component in
-- the Damage Register.

ALTER TABLE attendees ADD COLUMN IF NOT EXISTS representing_party_id
  uuid REFERENCES assured_contacts(contact_id) ON DELETE SET NULL;
