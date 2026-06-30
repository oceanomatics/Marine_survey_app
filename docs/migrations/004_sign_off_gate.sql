-- Migration 004: dual sign-off gate for Final Report export
-- Run in Supabase SQL editor

ALTER TABLE cases
  ADD COLUMN IF NOT EXISTS signed_off_attending  boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS signed_off_reviewing  boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS signed_off_at         timestamptz;
