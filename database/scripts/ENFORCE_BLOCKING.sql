-- ============================================
-- ENFORCE BLOCKING LOGIC
-- ============================================
-- Function to check if a user is blocked by the recipient
CREATE OR REPLACE FUNCTION public.check_is_blocked() RETURNS TRIGGER AS $$
DECLARE recipient_id UUID;
is_blocked BOOLEAN;
BEGIN -- For DMs, room_id often corresponds to the friend_request ID where the status is accepted
-- We need to find the other person in that 'room'
-- 1. Get the recipient ID for DMs
-- We look into friend_requests where the id is the room_id
SELECT CASE
        WHEN sender_id = NEW.user_id THEN receiver_id
        ELSE sender_id
    END INTO recipient_id
FROM public.friend_requests
WHERE id::text = NEW.room_id::text -- room_id is sometimes text/uuid
LIMIT 1;
-- 2. If it's a DM (recipient_id is found), check if they blocked the sender
IF recipient_id IS NOT NULL THEN
SELECT EXISTS (
        SELECT 1
        FROM public.blocked_users
        WHERE blocker_id = recipient_id
            AND blocked_id = NEW.user_id
    ) INTO is_blocked;
IF is_blocked THEN RAISE EXCEPTION 'You are blocked by this user.';
END IF;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Apply trigger to messages
DROP TRIGGER IF EXISTS tr_check_block_on_message ON public.messages;
CREATE TRIGGER tr_check_block_on_message BEFORE
INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.check_is_blocked();
-- ============================================
-- BLOCKING FOR CALLS
-- ============================================
CREATE OR REPLACE FUNCTION public.check_call_block() RETURNS TRIGGER AS $$
DECLARE is_blocked BOOLEAN;
BEGIN -- For calls, the receiver_id is explicitly in the table
IF NEW.receiver_id IS NOT NULL THEN
SELECT EXISTS (
        SELECT 1
        FROM public.blocked_users
        WHERE blocker_id = NEW.receiver_id
            AND blocked_id = NEW.caller_id
    ) INTO is_blocked;
IF is_blocked THEN RAISE EXCEPTION 'You are blocked by this user.';
END IF;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Apply trigger to calls
DROP TRIGGER IF EXISTS tr_check_block_on_call ON public.calls;
CREATE TRIGGER tr_check_block_on_call BEFORE
INSERT ON public.calls FOR EACH ROW EXECUTE FUNCTION public.check_call_block();