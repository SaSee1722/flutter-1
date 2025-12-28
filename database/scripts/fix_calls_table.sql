-- Run this script in your Supabase SQL Editor to fix the 400 Bad Request error during calls
-- Add missing columns to the calls table
ALTER TABLE public.calls
ADD COLUMN IF NOT EXISTS room_id uuid REFERENCES public.chat_rooms(id) ON DELETE CASCADE;
ALTER TABLE public.calls
ADD COLUMN IF NOT EXISTS is_video boolean DEFAULT false;
ALTER TABLE public.calls
ADD COLUMN IF NOT EXISTS caller_name text;
ALTER TABLE public.calls
ADD COLUMN IF NOT EXISTS caller_avatar text;
ALTER TABLE public.calls
ADD COLUMN IF NOT EXISTS duration integer DEFAULT 0;
ALTER TABLE public.calls
ADD COLUMN IF NOT EXISTS ended_at timestamptz;
ALTER TABLE public.calls
ALTER COLUMN receiver_id DROP NOT NULL;
-- Ensure foreign keys exist with correct names for joins
ALTER TABLE public.calls DROP CONSTRAINT IF EXISTS calls_caller_id_fkey,
    ADD CONSTRAINT calls_caller_id_fkey FOREIGN KEY (caller_id) REFERENCES public.profiles(id);
ALTER TABLE public.calls DROP CONSTRAINT IF EXISTS calls_receiver_id_fkey,
    ADD CONSTRAINT calls_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.profiles(id);
-- Enable RLS for the new columns if necessary (usually not needed if already enabled for the table)
-- But let's make sure policies allow access
DROP POLICY IF EXISTS "Users can view their own calls" ON public.calls;
CREATE POLICY "Users can view their own calls" ON public.calls FOR
SELECT USING (
        auth.uid() = caller_id
        OR auth.uid() = receiver_id
        OR EXISTS (
            SELECT 1
            FROM public.group_members
            WHERE group_members.room_id = calls.room_id
                AND group_members.user_id = auth.uid()
        )
    );
DROP POLICY IF EXISTS "Users can insert calls" ON public.calls;
CREATE POLICY "Users can insert calls" ON public.calls FOR
INSERT WITH CHECK (auth.uid() = caller_id);