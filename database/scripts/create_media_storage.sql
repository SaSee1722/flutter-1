-- =====================================================
-- GOSSIP - Media Storage Setup
-- =====================================================
-- This script creates storage buckets and policies for:
-- 1. Chat media (images, videos)
-- 2. Chat documents (PDFs, docs, etc.)
-- 3. Chat audio (voice messages, audio files)
-- =====================================================
-- Create storage buckets
INSERT INTO storage.buckets (
        id,
        name,
        public,
        file_size_limit,
        allowed_mime_types
    )
VALUES (
        'chat-media',
        'chat-media',
        true,
        52428800,
        ARRAY [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/webm'
  ]
    ),
    (
        'chat-documents',
        'chat-documents',
        true,
        10485760,
        ARRAY [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain'
  ]
    ),
    (
        'chat-audio',
        'chat-audio',
        true,
        10485760,
        ARRAY [
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/webm',
    'audio/ogg',
    'audio/aac',
    'audio/x-m4a'
  ]
    ) ON CONFLICT (id) DO NOTHING;
-- =====================================================
-- STORAGE POLICIES
-- =====================================================
-- Chat Media Bucket Policies
-- Allow authenticated users to upload
CREATE POLICY "Users can upload chat media" ON storage.objects FOR
INSERT TO authenticated WITH CHECK (bucket_id = 'chat-media');
-- Allow authenticated users to view media
CREATE POLICY "Users can view chat media" ON storage.objects FOR
SELECT TO authenticated USING (bucket_id = 'chat-media');
-- Allow users to delete their own uploads
CREATE POLICY "Users can delete their own chat media" ON storage.objects FOR DELETE TO authenticated USING (
    bucket_id = 'chat-media'
    AND auth.uid()::text = (storage.foldername(name)) [1]
);
-- Chat Documents Bucket Policies
-- Allow authenticated users to upload
CREATE POLICY "Users can upload chat documents" ON storage.objects FOR
INSERT TO authenticated WITH CHECK (bucket_id = 'chat-documents');
-- Allow authenticated users to view documents
CREATE POLICY "Users can view chat documents" ON storage.objects FOR
SELECT TO authenticated USING (bucket_id = 'chat-documents');
-- Allow users to delete their own uploads
CREATE POLICY "Users can delete their own chat documents" ON storage.objects FOR DELETE TO authenticated USING (
    bucket_id = 'chat-documents'
    AND auth.uid()::text = (storage.foldername(name)) [1]
);
-- Chat Audio Bucket Policies
-- Allow authenticated users to upload
CREATE POLICY "Users can upload chat audio" ON storage.objects FOR
INSERT TO authenticated WITH CHECK (bucket_id = 'chat-audio');
-- Allow authenticated users to view audio
CREATE POLICY "Users can view chat audio" ON storage.objects FOR
SELECT TO authenticated USING (bucket_id = 'chat-audio');
-- Allow users to delete their own uploads
CREATE POLICY "Users can delete their own chat audio" ON storage.objects FOR DELETE TO authenticated USING (
    bucket_id = 'chat-audio'
    AND auth.uid()::text = (storage.foldername(name)) [1]
);
-- =====================================================
-- UPDATE MESSAGES TABLE
-- =====================================================
-- Add columns for media attachments
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS media_url TEXT,
    ADD COLUMN IF NOT EXISTS media_type TEXT CHECK (
        media_type IN ('image', 'video', 'document', 'audio', 'voice')
    ),
    ADD COLUMN IF NOT EXISTS media_name TEXT,
    ADD COLUMN IF NOT EXISTS media_size BIGINT;
-- Create index for faster media queries
CREATE INDEX IF NOT EXISTS idx_messages_media_type ON messages(media_type)
WHERE media_type IS NOT NULL;
-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- Run these to verify the setup
-- Check buckets
SELECT id,
    name,
    public,
    file_size_limit
FROM storage.buckets
WHERE id IN ('chat-media', 'chat-documents', 'chat-audio');
-- Check policies
SELECT schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'objects'
    AND policyname LIKE '%chat%'
ORDER BY policyname;
-- Check messages table columns
SELECT column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'messages'
    AND column_name IN (
        'media_url',
        'media_type',
        'media_name',
        'media_size'
    );