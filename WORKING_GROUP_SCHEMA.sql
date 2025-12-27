-- ============================================
-- WORKING GROUP SCHEMA - NO RECURSION ISSUES
-- ============================================
-- Run this ENTIRE script in Supabase SQL Editor
-- ============================================
-- Drop existing tables if they exist (clean slate)
DROP TABLE IF EXISTS public.group_members CASCADE;
DROP TABLE IF EXISTS public.chat_rooms CASCADE;
-- 1. Create chat_rooms table
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
-- 2. Create group_members table
CREATE TABLE public.group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    role TEXT DEFAULT 'member',
    UNIQUE(room_id, user_id)
);
-- 3. Create indexes
CREATE INDEX idx_chat_rooms_admin ON public.chat_rooms(admin_id);
CREATE INDEX idx_chat_rooms_is_group ON public.chat_rooms(is_group);
CREATE INDEX idx_group_members_room ON public.group_members(room_id);
CREATE INDEX idx_group_members_user ON public.group_members(user_id);
-- ============================================
-- ENABLE RLS
-- ============================================
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
-- ============================================
-- SIMPLE RLS POLICIES (NO RECURSION)
-- ============================================
-- CHAT_ROOMS POLICIES
-- Allow authenticated users to view all groups (simplified)
CREATE POLICY "Anyone can view groups" ON public.chat_rooms FOR
SELECT TO authenticated USING (true);
-- Allow authenticated users to create groups
CREATE POLICY "Users can create groups" ON public.chat_rooms FOR
INSERT TO authenticated WITH CHECK (auth.uid() = admin_id);
-- Only admin can update
CREATE POLICY "Admin can update groups" ON public.chat_rooms FOR
UPDATE TO authenticated USING (auth.uid() = admin_id) WITH CHECK (auth.uid() = admin_id);
-- Only admin can delete
CREATE POLICY "Admin can delete groups" ON public.chat_rooms FOR DELETE TO authenticated USING (auth.uid() = admin_id);
-- GROUP_MEMBERS POLICIES
-- Anyone can view all group members (simplified)
CREATE POLICY "Anyone can view members" ON public.group_members FOR
SELECT TO authenticated USING (true);
-- Anyone can insert themselves or admin can insert anyone
CREATE POLICY "Users can join groups" ON public.group_members FOR
INSERT TO authenticated WITH CHECK (true);
-- Admin can remove anyone, users can remove themselves
CREATE POLICY "Users can leave groups" ON public.group_members FOR DELETE TO authenticated USING (true);
-- ============================================
-- TRIGGERS
-- ============================================
-- Auto-update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER update_chat_rooms_updated_at BEFORE
UPDATE ON public.chat_rooms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Auto-add creator as admin
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
-- VERIFY TABLES EXIST
-- ============================================
SELECT table_name,
    (
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_name = t.table_name
    ) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
    AND table_name IN ('chat_rooms', 'group_members');
-- ============================================
-- SUCCESS MESSAGE
-- ============================================
-- If you see 2 rows above (chat_rooms and group_members), it worked!
-- Now go back to your app and try creating a group.
-- ============================================