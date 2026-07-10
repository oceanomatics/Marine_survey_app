-- 027_timeline_event_ratings.sql
--
-- TODO.md §3.16 — Timeline: Full Event Log + AI Relevance Rating.
--
-- The in-app Case Timeline aggregates every dated item collected across a case
-- (occurrences, attendances, completed repairs, manual timeline events). This
-- table records a per-event *relevance* rating (important | normal | ignore)
-- and a *chronology inclusion* decision for each aggregated event, mirroring
-- the context-cue `pending_review` review pattern
-- (docs/context_cue_system_review.md §3.5): the rating is AI-suggested first
-- (`pending_review = true`), and nothing the AI guessed is treated as
-- confirmed until the surveyor reviews it.
--
-- `event_key` is a stable synthetic identity for an aggregated event —
-- "<source>:<source_id>", e.g. "occurrence:<uuid>", "attendance:<uuid>",
-- "repair:<uuid>", "manual:<timeline_event_id>". One row per rated event.
CREATE TABLE IF NOT EXISTS timeline_event_ratings (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id                UUID NOT NULL,
  event_key              TEXT NOT NULL,
  relevance              TEXT NOT NULL DEFAULT 'normal',   -- important | normal | ignore
  included_in_chronology BOOLEAN NOT NULL DEFAULT false,
  pending_review         BOOLEAN NOT NULL DEFAULT false,   -- unconfirmed AI suggestion
  ai_reason              TEXT,                             -- short AI rationale, if suggested
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (case_id, event_key)
);

ALTER TABLE timeline_event_ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated full access" ON timeline_event_ratings
  FOR ALL TO public USING (auth.role() = 'authenticated');

-- Non-timeline aggregated events (an occurrence/attendance/repair) reach the
-- report Chronology by being *promoted* into a real `timeline_events` row — the
-- report builder reads only `timeline_events`, so promotion keeps that pipeline
-- untouched. `source_key` records which aggregated event a promoted row came
-- from, so the Full Event Log can show it as "already in chronology" and avoid
-- listing the same event twice. NULL for manually-typed timeline events.
ALTER TABLE timeline_events ADD COLUMN IF NOT EXISTS source_key TEXT;
