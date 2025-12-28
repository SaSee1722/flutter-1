-- ============================================
-- FIX PERFORMANCE INDICES
-- ============================================
-- 1. Index for Messages queries (Filtering by room and sorting by date)
CREATE INDEX IF NOT EXISTS messages_room_id_created_at_idx ON public.messages (room_id, created_at DESC);
-- 2. Index for Messages user queries (Unread counts)
CREATE INDEX IF NOT EXISTS messages_user_id_status_idx ON public.messages (user_id, status);
-- 3. Index for Friend Requests lookups
CREATE INDEX IF NOT EXISTS friend_requests_participants_idx ON public.friend_requests (sender_id, receiver_id);
CREATE INDEX IF NOT EXISTS friend_requests_status_idx ON public.friend_requests (status);
-- 4. Index for Group Members (Looking up rooms for a user)
CREATE INDEX IF NOT EXISTS group_members_user_id_idx ON public.group_members (user_id);
-- 5. Index for Group Members (Looking up members in a room)
CREATE INDEX IF NOT EXISTS group_members_room_id_idx ON public.group_members (room_id);
-- 6. Index for Calls (Active calls monitoring)
CREATE INDEX IF NOT EXISTS calls_status_receiver_idx ON public.calls (status, receiver_id);
-- 7. Index for Profiles (Username search)
-- 'gin' index is better for ILIKE/Text search operations
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS profiles_username_search_idx ON public.profiles USING gin (username gin_trgm_ops);
SELECT '✅ PERFORMANCE INDICES APPLIED' as status;