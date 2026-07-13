-- 039_action_items.sql
--
-- TODO.md §4.7 — App-Wide Action Items / Task Tracking. Scoped to
-- case-level tasks only for this pass — admin-level tasks (the other
-- flavour named in the original ask) tie into §4.5's Admin module, which
-- doesn't exist yet; nowhere for them to plug in. Revisit once §4.5 lands.
--
-- source_type/source_id let an item point back to where it came from
-- (correspondence.actions_json entries are the first concrete source,
-- already AI-extracted per-message but never aggregated anywhere — see
-- §3.14) without hard-coding a single source table, so a future source
-- (documents, context cues) can reuse the same column pair.
--
-- pending_review mirrors the same human-in-the-loop convention already
-- used for cue suggestions (docs/context_cue_system_review.md §3.5) and
-- the extraction "ready_for_review" states elsewhere in this app (§4.1):
-- an AI-surfaced candidate action is never auto-committed as a live task
-- until a surveyor confirms it.
CREATE TABLE IF NOT EXISTS action_items (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id       uuid NOT NULL REFERENCES cases(case_id) ON DELETE CASCADE,
  text          text NOT NULL,
  status        text NOT NULL DEFAULT 'open', -- open | done | dismissed
  source_type   text,                          -- 'correspondence' | 'manual'
  source_id     text,                          -- e.g. correspondence.id
  pending_review boolean NOT NULL DEFAULT false,
  due_date      date,
  created_at    timestamptz NOT NULL DEFAULT now(),
  completed_at  timestamptz
);

CREATE INDEX IF NOT EXISTS idx_action_items_case_id ON action_items(case_id);
