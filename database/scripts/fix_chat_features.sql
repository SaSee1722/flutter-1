-- RUN THIS IN SUPABASE SQL EDITOR
-- 1. Add reactions column to messages
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS reactions jsonb DEFAULT '{}'::jsonb;
-- 2. Ensure Realtime is enabled for the messages table
-- We drop and recreate to ensure it includes etc.
ALTER publication supabase_realtime
ADD TABLE messages;
-- 3. Create a table for tracking unread counts if not using aggregate queries
-- For now, we will use a computed column or query logic in the app.
-- 4. Enable Realtime for Broadcast (Typing status)
-- Typing status will use Supabase Broadcast (no table needed, just enable in code).