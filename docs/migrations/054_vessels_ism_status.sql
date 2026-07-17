-- Migration 054: add ism_status to vessels
-- ISM (DOC/SMC) compliance status, mirroring the existing isps_status column.
-- Typically sourced from the Equasis report; manual entry for now.
-- Values: 'compliant' | 'non_compliant' | 'tbc'
-- Run in Supabase SQL editor.

ALTER TABLE vessels
  ADD COLUMN IF NOT EXISTS ism_status text;
