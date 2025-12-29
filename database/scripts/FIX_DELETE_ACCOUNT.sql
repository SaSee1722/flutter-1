-- ============================================
-- FIX DELETE ACCOUNT (CASCADE CONSTRAINTS)
-- ============================================
-- 1. MESSAGES
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_user_id_fkey,
    ADD CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- 2. FRIEND REQUESTS
ALTER TABLE public.friend_requests DROP CONSTRAINT IF EXISTS friend_requests_sender_id_fkey,
    ADD CONSTRAINT friend_requests_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.friend_requests DROP CONSTRAINT IF EXISTS friend_requests_receiver_id_fkey,
    ADD CONSTRAINT friend_requests_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- 3. STATUSES (VIBES)
ALTER TABLE public.statuses DROP CONSTRAINT IF EXISTS statuses_user_id_fkey,
    ADD CONSTRAINT statuses_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- 4. GROUP MEMBERS
ALTER TABLE public.group_members DROP CONSTRAINT IF EXISTS group_members_user_id_fkey,
    ADD CONSTRAINT group_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- 5. BLOCKED USERS
ALTER TABLE public.blocked_users DROP CONSTRAINT IF EXISTS blocked_users_blocker_id_fkey,
    ADD CONSTRAINT blocked_users_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.blocked_users DROP CONSTRAINT IF EXISTS blocked_users_blocked_id_fkey,
    ADD CONSTRAINT blocked_users_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- 6. PROFILES (Should already be cascade, but safe to enforce)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey,
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- 7. CHAT ROOMS (ADMIN)
-- If an admin is deleted, we might want to keep the group or delete it.
-- For now, let's CASCADE so the group disappears if the admin deletes their account.
-- Alternatively, we could set admin_id to specific system user, but CASCADE is cleaner for "complete deletion".
ALTER TABLE public.chat_rooms DROP CONSTRAINT IF EXISTS chat_rooms_admin_id_fkey,
    ADD CONSTRAINT chat_rooms_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- 8. ENSURE RPC EXISTS
CREATE OR REPLACE FUNCTION delete_user() RETURNS void AS $$ BEGIN
DELETE FROM auth.users
WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
SELECT '✅ DELETE ACCOUNT FIXED' as status;