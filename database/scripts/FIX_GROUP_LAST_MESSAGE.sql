-- =====================================================
-- GOSSIP - Auto-update Group Last Message
-- =====================================================
-- This script creates a trigger that automatically updates
-- the 'last_message' and 'last_message_time' in the chat_rooms
-- table whenever a new message is sent.
-- =====================================================
-- 1. Create the function to update last message
CREATE OR REPLACE FUNCTION update_group_last_message() RETURNS TRIGGER AS $$ BEGIN
UPDATE public.chat_rooms
SET last_message = CASE
        WHEN NEW.media_type IS NOT NULL THEN '' -- No text or icons for media uploads
        ELSE NEW.content
    END,
    last_message_time = NEW.created_at,
    updated_at = NOW()
WHERE id = NEW.room_id;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- 2. Create the trigger on the messages table
DROP TRIGGER IF EXISTS on_message_sent_update_group ON public.messages;
CREATE TRIGGER on_message_sent_update_group
AFTER
INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION update_group_last_message();
-- 3. Backfill existing messages to chat_rooms
-- Updates each room with its most recent message using the same logic
UPDATE public.chat_rooms cr
SET last_message = CASE
        WHEN m.media_type IS NOT NULL THEN ''
        ELSE m.content
    END,
    last_message_time = m.created_at
FROM (
        SELECT DISTINCT ON (room_id) room_id,
            content,
            media_type,
            created_at
        FROM public.messages
        ORDER BY room_id,
            created_at DESC
    ) m
WHERE cr.id = m.room_id;
-- 4. Verify results
SELECT id,
    name,
    last_message,
    last_message_time
FROM public.chat_rooms
WHERE is_group = true;