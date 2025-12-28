-- =====================================================
-- GOSSIP - Complete Storage & Media Setup (Robust Version)
-- =====================================================
-- This script safely creates all required storage buckets 
-- and security policies. It handles existing policies.
-- =====================================================
-- 1. Create storage buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('chat-media', 'chat-media', true, 52428800),
    -- 50MB
    (
        'chat-documents',
        'chat-documents',
        true,
        10485760
    ),
    -- 10MB
    ('chat-audio', 'chat-audio', true, 10485760),
    -- 10MB
    ('group_avatars', 'group_avatars', true, 5242880) -- 5MB
    ON CONFLICT (id) DO NOTHING;
-- Clean Up Existing Policies to avoid "already exists" errors
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload chat media" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own chat media" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload chat documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own chat documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload chat audio" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own chat audio" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can upload group avatars" ON storage.objects;
DROP POLICY IF EXISTS "Group admins can update avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can view chat media" ON storage.objects;
DROP POLICY IF EXISTS "Users can view chat documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can view chat audio" ON storage.objects;
-- 2. General Public Access (Enable SELECT for all buckets)
CREATE POLICY "Public Access" ON storage.objects FOR
SELECT USING (true);
-- 3. CHAT MEDIA POLICIES
CREATE POLICY "Users can upload chat media" ON storage.objects FOR
INSERT TO authenticated WITH CHECK (bucket_id = 'chat-media');
CREATE POLICY "Users can delete own chat media" ON storage.objects FOR DELETE TO authenticated USING (
    bucket_id = 'chat-media'
    AND auth.uid()::text = (storage.foldername(name)) [1]
);
-- 4. CHAT DOCUMENTS POLICIES
CREATE POLICY "Users can upload chat documents" ON storage.objects FOR
INSERT TO authenticated WITH CHECK (bucket_id = 'chat-documents');
CREATE POLICY "Users can delete own chat documents" ON storage.objects FOR DELETE TO authenticated USING (
    bucket_id = 'chat-documents'
    AND auth.uid()::text = (storage.foldername(name)) [1]
);
-- 5. CHAT AUDIO POLICIES
CREATE POLICY "Users can upload chat audio" ON storage.objects FOR
INSERT TO authenticated WITH CHECK (bucket_id = 'chat-audio');
CREATE POLICY "Users can delete own chat audio" ON storage.objects FOR DELETE TO authenticated USING (
    bucket_id = 'chat-audio'
    AND auth.uid()::text = (storage.foldername(name)) [1]
);
-- 6. GROUP AVATARS POLICIES
CREATE POLICY "Anyone can upload group avatars" ON storage.objects FOR
INSERT TO authenticated WITH CHECK (bucket_id = 'group_avatars');
CREATE POLICY "Group admins can update avatars" ON storage.objects FOR
UPDATE TO authenticated USING (bucket_id = 'group_avatars');
-- 7. Ensure Messages table has media columns
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS media_url TEXT,
    ADD COLUMN IF NOT EXISTS media_type TEXT,
    ADD COLUMN IF NOT EXISTS media_name TEXT,
    ADD COLUMN IF NOT EXISTS media_size BIGINT;
-- 8. Verification query
SELECT id,
    name,
    public
FROM storage.buckets;