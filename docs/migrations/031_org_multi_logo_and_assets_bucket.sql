-- 031_org_multi_logo_and_assets_bucket.sql
-- §2.1 / §2.16 — Firm branding: multi-logo support + real logo upload.
--
-- 1. Multi-logo data model: organisations previously had a single
--    `logo_storage_path` (letterhead logo). Firms often need a primary
--    letterhead logo PLUS a secondary co-brand logo, so we add an ordered
--    array `logo_storage_paths` (element 0 = primary, used wherever the
--    single logo is used today). The legacy single column is retained and
--    kept in sync (mirror of element 0) for backward compatibility.
--
-- 2. Storage: the docx export already tries to download logos/signatures
--    from a bucket named `organisation_assets`, but that bucket was never
--    actually created — so logo embedding has never worked in practice.
--    Create the (private) bucket and grant authenticated users access,
--    mirroring the existing single-policy pattern on storage.objects.

-- ── Multi-logo column ────────────────────────────────────────────────────────
ALTER TABLE organisations
  ADD COLUMN IF NOT EXISTS logo_storage_paths TEXT[] NOT NULL DEFAULT '{}';

-- Backfill the array from any existing single logo path.
UPDATE organisations
   SET logo_storage_paths = ARRAY[logo_storage_path]
 WHERE logo_storage_path IS NOT NULL
   AND logo_storage_path <> ''
   AND (array_length(logo_storage_paths, 1) IS NULL);

-- ── Private storage bucket for firm assets (logos, signatures) ───────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('organisation_assets', 'organisation_assets', false)
ON CONFLICT (id) DO NOTHING;

-- Authenticated users may read/write firm assets. Kept as its own policy so
-- the existing "Authenticated access documents" policy is left untouched.
DROP POLICY IF EXISTS "Authenticated access organisation_assets" ON storage.objects;
CREATE POLICY "Authenticated access organisation_assets"
  ON storage.objects
  FOR ALL
  TO authenticated
  USING (bucket_id = 'organisation_assets')
  WITH CHECK (bucket_id = 'organisation_assets');
