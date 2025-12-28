-- ============================================
-- FIX RLS SECURITY ISSUES
-- ============================================
-- 1. Enable RLS on Calls Table
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own calls" ON public.calls;
CREATE POLICY "Users can view their own calls" ON public.calls FOR
SELECT USING (
        auth.uid() = caller_id
        OR auth.uid() = receiver_id
        OR EXISTS (
            SELECT 1
            FROM group_members
            WHERE group_members.room_id = calls.room_id
                AND group_members.user_id = auth.uid()
        )
    );
DROP POLICY IF EXISTS "Users can insert calls" ON public.calls;
CREATE POLICY "Users can insert calls" ON public.calls FOR
INSERT WITH CHECK (auth.uid() = caller_id);
DROP POLICY IF EXISTS "Users can update their own calls" ON public.calls;
CREATE POLICY "Users can update their own calls" ON public.calls FOR
UPDATE USING (
        auth.uid() = caller_id
        OR auth.uid() = receiver_id
    );
-- 2. Enable RLS on ICE Candidates Table
ALTER TABLE public.ice_candidates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view ice candidates for their calls" ON public.ice_candidates;
CREATE POLICY "Users can view ice candidates for their calls" ON public.ice_candidates FOR
SELECT USING (
        EXISTS (
            SELECT 1
            FROM calls
            WHERE calls.id = ice_candidates.call_id
                AND (
                    calls.caller_id = auth.uid()
                    OR calls.receiver_id = auth.uid()
                )
        )
    );
DROP POLICY IF EXISTS "Users can insert ice candidates" ON public.ice_candidates;
CREATE POLICY "Users can insert ice candidates" ON public.ice_candidates FOR
INSERT WITH CHECK (auth.role() = 'authenticated');
-- 3. Cleanup unused table (we used profiles.fcm_token instead)
DROP TABLE IF EXISTS public.user_fcm_tokens;
-- 4. Fix Security Definer Functions (search_path)
CREATE OR REPLACE FUNCTION public.update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW();
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;
CREATE OR REPLACE FUNCTION public.add_creator_as_admin() RETURNS TRIGGER AS $$ BEGIN
INSERT INTO public.group_members (room_id, user_id, role)
VALUES (NEW.id, NEW.admin_id, 'admin');
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;
-- 5. Fix Chat Rooms RLS (ensure groups are secure)
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view rooms they are in" ON public.chat_rooms;
CREATE POLICY "Users can view rooms they are in" ON public.chat_rooms FOR
SELECT USING (
        (
            is_group = false
            AND EXISTS (
                SELECT 1
                FROM friend_requests
                WHERE id = chat_rooms.id
                    AND (
                        sender_id = auth.uid()
                        OR receiver_id = auth.uid()
                    )
            )
        )
        OR (
            is_group = true
            AND EXISTS (
                SELECT 1
                FROM group_members
                WHERE room_id = chat_rooms.id
                    AND user_id = auth.uid()
            )
        )
    );
SELECT '✅ SECURITY ISSUES FIXED' as status;