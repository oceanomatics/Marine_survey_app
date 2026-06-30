-- Migration 008: add previous_name to vessels
-- Run in Supabase SQL editor

ALTER TABLE vessels
  ADD COLUMN IF NOT EXISTS previous_name text;
