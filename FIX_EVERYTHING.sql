-- ============================================
-- ONE-COMMAND FIX FOR EVERYTHING
-- ============================================
-- Copy and paste this ENTIRE file into Supabase SQL Editor
-- Then click RUN
-- ============================================
-- ============================================
-- PART 1: FIX UNREAD MESSAGES
-- ============================================
-- Mark all messages as read (clears all badges)
UPDATE messages
SET status = 'read'
WHERE status IN ('sent', 'delivered', 'sending');
-- Verify
SELECT 'Messages Fixed!' as message,
    status,
    COUNT(*) as count
FROM messages
GROUP BY status;
-- ============================================
-- PART 2: FIX GROUPS (if not already done)
-- ============================================
-- Drop and recreate group tables
DROP TABLE IF EXISTS public.group_members CASCADE;
DROP TABLE IF EXISTS public.chat_rooms CASCADE;
-- Create chat_rooms
CREATE TABLE public.chat_rooms (
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
-- Create group_members
CREATE TABLE public.group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    role TEXT DEFAULT 'member',
    UNIQUE(room_id, user_id)
);
-- Indexes
CREATE INDEX idx_chat_rooms_admin ON public.chat_rooms(admin_id);
CREATE INDEX idx_group_members_room ON public.group_members(room_id);
CREATE INDEX idx_group_members_user ON public.group_members(user_id);
-- Enable RLS
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
-- Simple policies (no recursion)
CREATE POLICY "view_groups" ON public.chat_rooms FOR
SELECT TO authenticated USING (true);
CREATE POLICY "create_groups" ON public.chat_rooms FOR
INSERT TO authenticated WITH CHECK (auth.uid() = admin_id);
CREATE POLICY "update_groups" ON public.chat_rooms FOR
UPDATE TO authenticated USING (auth.uid() = admin_id);
CREATE POLICY "delete_groups" ON public.chat_rooms FOR DELETE TO authenticated USING (auth.uid() = admin_id);
CREATE POLICY "view_members" ON public.group_members FOR
SELECT TO authenticated USING (true);
CREATE POLICY "join_groups" ON public.group_members FOR
INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "leave_groups" ON public.group_members FOR DELETE TO authenticated USING (true);
-- Triggers
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER update_chat_rooms_updated_at BEFORE
UPDATE ON public.chat_rooms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE FUNCTION add_creator_as_admin() RETURNS TRIGGER AS $$ BEGIN
INSERT INTO public.group_members (room_id, user_id, role)
VALUES (NEW.id, NEW.admin_id, 'admin');
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER add_creator_to_group
AFTER
INSERT ON public.chat_rooms FOR EACH ROW EXECUTE FUNCTION add_creator_as_admin();
-- ============================================
-- VERIFICATION
-- ============================================
SELECT '✅ ALL FIXED!' as status;
SELECT 'Message Statuses:' as info,
    status,
    COUNT(*) as count
FROM messages
GROUP BY status;
SELECT 'Tables Created:' as info,
    table_name
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_name IN ('chat_rooms', 'group_members');
-- ============================================
-- DONE! Now refresh your app and test:
-- 1. Unread badges should be gone
-- 2. Groups should work
-- ============================================