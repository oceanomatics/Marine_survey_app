-- 055_interview_audio.sql
--
-- Persist the raw interview audio, not just the derived transcript (14 July
-- 2026 walkthrough — "fully functional recorder with audio save... plus
-- post-processing"). The on-device STT pipeline previously discarded the
-- recorded audio entirely once transcribed.

ALTER TABLE interviews ADD COLUMN IF NOT EXISTS audio_path text;

INSERT INTO storage.buckets (id, name, public)
VALUES ('interview-audio', 'interview-audio', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Authenticated upload interview audio" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'interview-audio');

CREATE POLICY "Authenticated read interview audio" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'interview-audio');
