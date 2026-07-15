-- 053_debug_feedback.sql
--
-- In-app debug-mode bug/improvement capture. A floating button (visible
-- only in debug builds, see lib/core/widgets/debug_feedback_button.dart)
-- lets the surveyor screenshot the current screen, draw on it to point at
-- the exact problem, and attach a short note — using the `feedback`
-- package's built-in screenshot + draw-annotation UI. Submitted straight
-- into this table so nothing gets lost or garbled between "I saw a bug
-- while testing" and it actually being logged with the right context.

CREATE TABLE IF NOT EXISTS debug_feedback (
  feedback_id     uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  organisation_id uuid NOT NULL DEFAULT current_org_id() REFERENCES organisations(id),
  case_id         uuid REFERENCES cases(case_id) ON DELETE SET NULL,
  created_by      uuid REFERENCES auth.users(id),
  note            text NOT NULL,
  screenshot_path text NOT NULL,     -- path within the 'debug-feedback' storage bucket
  route           text,              -- go_router location at time of capture
  platform        text,              -- android | ios | web | ...
  app_version     text,
  status          text NOT NULL DEFAULT 'open', -- open | reviewed | resolved
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_debug_feedback_org_status ON debug_feedback(organisation_id, status);
CREATE INDEX IF NOT EXISTS idx_debug_feedback_case_id ON debug_feedback(case_id);

ALTER TABLE debug_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Org members full access" ON debug_feedback
  FOR ALL
  USING (organisation_id = current_org_id())
  WITH CHECK (organisation_id = current_org_id());

-- Screenshot storage — private bucket, reviewed via signed URL / the
-- Supabase Management API (same access pattern already used to review
-- this table's rows), same privacy posture as the 'exports' bucket.
INSERT INTO storage.buckets (id, name, public)
VALUES ('debug-feedback', 'debug-feedback', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Authenticated upload debug screenshots" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'debug-feedback');

CREATE POLICY "Authenticated read debug screenshots" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'debug-feedback');
