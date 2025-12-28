-- ============================================
-- GROUP CHAT SCHEMA FOR GOSSIP APP
-- ============================================
-- This schema supports:
-- 1. Group creation with admin/creator
-- 2. Group members management
-- 3. Only creator can edit group details
-- 4. Members can only view group details
-- ============================================
-- 1. Create chat_rooms table (for groups)
CREATE TABLE IF NOT EXISTS public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    is_group BOOLEAN DEFAULT true,
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_message TEXT,
    last_message_time TIMESTAMP WITH TIME ZONE
);
-- 2. Create group_members table (who's in which group)
CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    role TEXT DEFAULT 'member',
    -- 'admin' or 'member'
    UNIQUE(room_id, user_id)
);
-- 3. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_rooms_admin ON public.chat_rooms(admin_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_is_group ON public.chat_rooms(is_group);
CREATE INDEX IF NOT EXISTS idx_group_members_room ON public.group_members(room_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON public.group_members(user_id);
-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================
-- Enable RLS on chat_rooms
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
-- Enable RLS on group_members
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
-- ============================================
-- CHAT_ROOMS POLICIES
-- ============================================
-- Policy 1: Anyone can view groups they are a member of
CREATE POLICY "Users can view groups they belong to" ON public.chat_rooms FOR
SELECT USING (
        EXISTS (
            SELECT 1
            FROM public.group_members
            WHERE group_members.room_id = chat_rooms.id
                AND group_members.user_id = auth.uid()
        )
    );
-- Policy 2: Any authenticated user can create a group
CREATE POLICY "Authenticated users can create groups" ON public.chat_rooms FOR
INSERT WITH CHECK (auth.uid() = admin_id);
-- Policy 3: ONLY the admin/creator can update group details
CREATE POLICY "Only admin can update group details" ON public.chat_rooms FOR
UPDATE USING (auth.uid() = admin_id) WITH CHECK (auth.uid() = admin_id);
-- Policy 4: ONLY the admin/creator can delete the group
CREATE POLICY "Only admin can delete group" ON public.chat_rooms FOR DELETE USING (auth.uid() = admin_id);
-- ============================================
-- GROUP_MEMBERS POLICIES
-- ============================================
-- Policy 1: Users can view members of groups they belong to
CREATE POLICY "Users can view group members" ON public.group_members FOR
SELECT USING (
        EXISTS (
            SELECT 1
            FROM public.group_members gm
            WHERE gm.room_id = group_members.room_id
                AND gm.user_id = auth.uid()
        )
    );
-- Policy 2: Admin can add members to their group
CREATE POLICY "Admin can add members" ON public.group_members FOR
INSERT WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.chat_rooms
            WHERE chat_rooms.id = group_members.room_id
                AND chat_rooms.admin_id = auth.uid()
        )
    );
-- Policy 3: Admin can remove members (or members can leave)
CREATE POLICY "Admin can remove members or users can leave" ON public.group_members FOR DELETE USING (
    -- Either you're the admin of the group
    EXISTS (
        SELECT 1
        FROM public.chat_rooms
        WHERE chat_rooms.id = group_members.room_id
            AND chat_rooms.admin_id = auth.uid()
    )
    OR -- Or you're removing yourself (leaving the group)
    group_members.user_id = auth.uid()
);
-- ============================================
-- FUNCTIONS AND TRIGGERS
-- ============================================
-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Trigger to auto-update updated_at on chat_rooms
DROP TRIGGER IF EXISTS update_chat_rooms_updated_at ON public.chat_rooms;
CREATE TRIGGER update_chat_rooms_updated_at BEFORE
UPDATE ON public.chat_rooms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Function to automatically add creator as admin member
CREATE OR REPLACE FUNCTION add_creator_as_admin() RETURNS TRIGGER AS $$ BEGIN -- Add the creator as an admin member of the group
INSERT INTO public.group_members (room_id, user_id, role)
VALUES (NEW.id, NEW.admin_id, 'admin');
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Trigger to add creator as admin when group is created
DROP TRIGGER IF EXISTS add_creator_to_group ON public.chat_rooms;
CREATE TRIGGER add_creator_to_group
AFTER
INSERT ON public.chat_rooms FOR EACH ROW EXECUTE FUNCTION add_creator_as_admin();
-- ============================================
-- STORAGE BUCKET FOR GROUP AVATARS
-- ============================================
-- Create storage bucket for group profile pictures
-- Run this in Supabase Dashboard > Storage or via SQL:
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('group_avatars', 'group_avatars', true)
-- ON CONFLICT (id) DO NOTHING;
-- Storage policy: Anyone can view group avatars
-- CREATE POLICY "Public group avatars"
-- ON storage.objects FOR SELECT
-- USING (bucket_id = 'group_avatars');
-- Storage policy: Only group admins can upload
-- CREATE POLICY "Group admins can upload avatars"
-- ON storage.objects FOR INSERT
-- WITH CHECK (
--   bucket_id = 'group_avatars' AND
--   EXISTS (
--     SELECT 1 FROM public.chat_rooms
--     WHERE chat_rooms.id::text = (storage.foldername(name))[1]
--     AND chat_rooms.admin_id = auth.uid()
--   )
-- );
-- ============================================
-- SAMPLE DATA (OPTIONAL - FOR TESTING)
-- ============================================
-- Uncomment to insert sample group (replace UUIDs with real user IDs)
-- INSERT INTO public.chat_rooms (name, bio, admin_id, is_group)
-- VALUES (
--   'Flutter Developers',
--   'A group for Flutter enthusiasts',
--   'YOUR_USER_ID_HERE',
--   true
-- );
-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Check if tables exist:
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' 
-- AND table_name IN ('chat_rooms', 'group_members');
-- Check if policies are enabled:
-- SELECT tablename, policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename IN ('chat_rooms', 'group_members');
-- ============================================
-- NOTES
-- ============================================
-- 1. Only the creator (admin_id) can:
--    - Update group name, bio, avatar_url
--    - Delete the group
--    - Add/remove members
--
-- 2. Regular members can:
--    - View group details
--    - View group members
--    - Leave the group (delete their own membership)
--    - Send messages (handled by messages table)
--
-- 3. The messages table already exists and will work with groups
--    - Messages reference room_id from chat_rooms
--    - No changes needed to messages table
--
-- 4. To create a group via app:
--    - User clicks "Create Group"
--    - Enters name, bio, selects members
--    - App calls createGroup() in repository
--    - Trigger automatically adds creator as admin member
-- ============================================