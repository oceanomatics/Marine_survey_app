-- Migration 009: attendee title (Mr./Ms./Capt. etc.) + structured GPS location for survey_attendances
-- Run in Supabase SQL editor

ALTER TABLE attendees
  ADD COLUMN IF NOT EXISTS title text;

ALTER TABLE survey_attendances
  ADD COLUMN IF NOT EXISTS latitude              double precision,
  ADD COLUMN IF NOT EXISTS longitude             double precision,
  ADD COLUMN IF NOT EXISTS location_type         text,   -- 'wharf' | 'shipyard' | 'workshop' | 'at_sea' | 'other'
  ADD COLUMN IF NOT EXISTS location_detail       text,   -- wharf/shipyard/workshop name, or anchorage name
  ADD COLUMN IF NOT EXISTS nearest_port          text,   -- 'at_sea' only
  ADD COLUMN IF NOT EXISTS distance_offshore_nm  numeric; -- 'at_sea' only
