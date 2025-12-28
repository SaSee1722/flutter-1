-- RUN THIS IN YOUR SUPABASE SQL EDITOR TO FIX MESSAGE SENDING
-- This adds the missing media columns and updates the status constraint.
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS attachment_url text;
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS attachment_type text;
-- Optional: Ensure status constraint is correct (if you had a restrictive one)
-- ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_status_check;
-- ALTER TABLE public.messages ADD CONSTRAINT messages_status_check CHECK (status IN ('sent', 'delivered', 'read'));