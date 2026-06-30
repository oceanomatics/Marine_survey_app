-- Migration 005: add missing columns to vessels table
-- Run in Supabase SQL editor

ALTER TABLE vessels
  -- Identity / registration
  ADD COLUMN IF NOT EXISTS call_sign              text,
  ADD COLUMN IF NOT EXISTS mmsi                   text,
  ADD COLUMN IF NOT EXISTS service_speed          numeric,

  -- Dimensions (qualifier columns added here; numeric ones may already exist)
  ADD COLUMN IF NOT EXISTS breadth_qualifier      text,
  ADD COLUMN IF NOT EXISTS draft_qualifier        text,

  -- Statutory / class status
  ADD COLUMN IF NOT EXISTS official_number        text,
  ADD COLUMN IF NOT EXISTS class_status           text,   -- 'classed' | 'conditional' | 'suspended' | 'not_classed'
  ADD COLUMN IF NOT EXISTS construction_standard  text,
  ADD COLUMN IF NOT EXISTS registered_owner       text,
  ADD COLUMN IF NOT EXISTS last_drydock_date      date,
  ADD COLUMN IF NOT EXISTS last_drydock_yard      text,
  ADD COLUMN IF NOT EXISTS ism_incident_reported  boolean,
  ADD COLUMN IF NOT EXISTS class_incident_reported boolean,
  ADD COLUMN IF NOT EXISTS psc_last_inspection    date,
  ADD COLUMN IF NOT EXISTS psc_last_result        text,   -- 'no_deficiencies' | 'deficiencies' | 'detained'
  ADD COLUMN IF NOT EXISTS psc_summary            text,
  ADD COLUMN IF NOT EXISTS pi_club                text,
  ADD COLUMN IF NOT EXISTS isps_status            text;   -- 'compliant' | 'non_compliant' | 'unknown'
