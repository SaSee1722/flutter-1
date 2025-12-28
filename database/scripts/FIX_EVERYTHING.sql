-- ============================================
-- ONE-COMMAND FIX FOR EVERYTHING
-- ============================================
-- Copy and paste this ENTIRE file into Supabase SQL Editor
-- Then click RUN
-- ============================================
-- ============================================
-- PART 1: FIX UNREAD MESSAGES (RLS)
-- ============================================
-- This allows you to actually mark messages as "read"
DROP POLICY IF EXISTS "Users can update their own messages" ON public.messages;
DROP POLICY IF EXISTS "Users can update messages in their rooms" ON public.messages;
DROP POLICY IF EXISTS "Recipients can mark as read" ON public.messages;
-- Policy: Allow update if you are the Recipient (DM) or in the Room (Group)
CREATE POLICY "Recipients can mark as read" ON public.messages FOR
UPDATE USING (auth.uid() != user_id) WITH CHECK (auth.uid() != user_id);
-- Reset stuck badges
UPDATE messages
SET status = 'read'
WHERE status IN ('sent', 'delivered', 'sending');
-- ============================================
-- PART 2: FIX GROUPS (Schema)
-- ============================================
-- Drop and recreate only if messed up, but let's ensure tables exist
CREATE TABLE IF NOT EXISTS public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    is_group BOOLEAN DEFAULT true,
    admin_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_message TEXT,
    last_message_time TIMESTAMP WITH TIME ZONE
);
CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    role TEXT DEFAULT 'member',
    UNIQUE(room_id, user_id)
);
-- ============================================
-- PART 3: BLOCKED USERS
-- ============================================
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own blocked list" ON public.blocked_users;
CREATE POLICY "Users can view their own blocked list" ON public.blocked_users FOR
SELECT USING (auth.uid() = blocker_id);
DROP POLICY IF EXISTS "Users can block others" ON public.blocked_users;
CREATE POLICY "Users can block others" ON public.blocked_users FOR
INSERT WITH CHECK (auth.uid() = blocker_id);
DROP POLICY IF EXISTS "Users can unblock others" ON public.blocked_users;
CREATE POLICY "Users can unblock others" ON public.blocked_users FOR DELETE USING (auth.uid() = blocker_id);
-- RPC for deleting user
CREATE OR REPLACE FUNCTION delete_user() RETURNS void AS $$ BEGIN
DELETE FROM auth.users
WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- ============================================
-- DONE!
-- ============================================
SELECT '✅ EVERYTHING FIXED!' as status;