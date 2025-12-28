-- ============================================
-- BLOCKED USERS SCHEMA
-- ============================================
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);
-- Enable RLS
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
-- Policies
CREATE POLICY "Users can view their own blocked list" ON public.blocked_users FOR
SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "Users can block others" ON public.blocked_users FOR
INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Users can unblock others" ON public.blocked_users FOR DELETE USING (auth.uid() = blocker_id);
-- RPC for deleting user account
CREATE OR REPLACE FUNCTION delete_user() RETURNS void AS $$ BEGIN
DELETE FROM auth.users
WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Apply filter to friend_requests
-- (Assuming friend_requests table exists)
-- If A blocks B, they shouldn't be friends or see requests.
-- Apply filter to messages (optional but good)
-- SELECT * FROM messages WHERE user_id NOT IN (SELECT blocked_id FROM blocked_users WHERE blocker_id = auth.uid());