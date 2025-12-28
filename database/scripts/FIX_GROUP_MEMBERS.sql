-- =====================================================
-- GOSSIP - Fix Group Relationships & Permissions
-- =====================================================
-- This script fixes the relationship between group_members 
-- and profiles, allowing the app to show usernames in the list.
-- =====================================================
-- 1. Link group_members to profiles (instead of auth.users)
-- This enables the join query used in the app.
DO $$ BEGIN IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_name = 'group_members_user_id_fkey'
) THEN
ALTER TABLE public.group_members DROP CONSTRAINT group_members_user_id_fkey;
END IF;
END $$;
ALTER TABLE public.group_members
ADD CONSTRAINT group_members_user_id_profiles_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
-- 2. Ensure RLS on profiles allows members to see each other
-- Users need to be able to see profiles of group members.
DROP POLICY IF EXISTS "Anyone can view profiles" ON public.profiles;
CREATE POLICY "Anyone can view profiles" ON public.profiles FOR
SELECT USING (true);
-- 3. Verify the relationship works
-- This query should return results if there are members
SELECT gm.user_id,
    p.username,
    gm.role
FROM public.group_members gm
    JOIN public.profiles p ON gm.user_id = p.id
LIMIT 5;