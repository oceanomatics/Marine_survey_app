-- Migration 007: add duration field to class_conditions
-- Run in Supabase SQL editor

ALTER TABLE class_conditions
  ADD COLUMN IF NOT EXISTS duration text;
