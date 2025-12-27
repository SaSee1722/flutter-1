-- 1. DROP potential duplicate policies to fix the "Already Exists" error
-- This clears the way for a clean recreation.
DROP POLICY IF EXISTS "Avatars Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Authenticated Upload" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Owner Update" ON storage.objects;
-- Also cleanup Vibe/Chat policies to ensure we can recreate them cleanly
DROP POLICY IF EXISTS "Vibe Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Vibe Upload" ON storage.objects;
DROP POLICY IF EXISTS "Chat Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Chat Upload" ON storage.objects;
-- 2. Ensure ALL required buckets exist (Safe to run multiple times)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public)
VALUES ('vibe-media', 'vibe-media', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-media', 'chat-media', true) ON CONFLICT (id) DO NOTHING;
-- 3. Re-Create Avatar Policies
CREATE POLICY "Avatars Public Access" ON storage.objects FOR
SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Avatars Authenticated Upload" ON storage.objects FOR
INSERT WITH CHECK (
        bucket_id = 'avatars'
        AND auth.role() = 'authenticated'
    );
CREATE POLICY "Avatars Owner Update" ON storage.objects FOR
UPDATE USING (
        bucket_id = 'avatars'
        AND auth.uid() = owner
    );
-- 4. Re-Create Vibe Policies
CREATE POLICY "Vibe Public Access" ON storage.objects FOR
SELECT USING (bucket_id = 'vibe-media');
CREATE POLICY "Vibe Upload" ON storage.objects FOR
INSERT WITH CHECK (
        bucket_id = 'vibe-media'
        AND auth.role() = 'authenticated'
    );
-- 5. Re-Create Chat Media Policies
CREATE POLICY "Chat Public Access" ON storage.objects FOR
SELECT USING (bucket_id = 'chat-media');
CREATE POLICY "Chat Upload" ON storage.objects FOR
INSERT WITH CHECK (
        bucket_id = 'chat-media'
        AND auth.role() = 'authenticated'
    );