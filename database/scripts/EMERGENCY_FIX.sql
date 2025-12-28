-- ============================================
-- EMERGENCY FIX - Run this in Supabase NOW!
-- ============================================
-- Step 1: Check what statuses exist
SELECT status,
    COUNT(*) as message_count
FROM messages
GROUP BY status
ORDER BY status;
-- Step 2: See which messages are being counted as unread
-- (Replace 'YOUR_USER_ID' with your actual user ID from auth.users)
SELECT m.id,
    m.content,
    m.status,
    m.user_id,
    m.room_id,
    m.created_at,
    p.username as sender
FROM messages m
    LEFT JOIN profiles p ON m.user_id = p.id
WHERE m.status != 'read'
ORDER BY m.created_at DESC
LIMIT 20;
-- Step 3: NUCLEAR OPTION - Mark ALL messages as read for testing
-- This will clear all unread badges
-- Uncomment and run if you want to test:
-- UPDATE messages
-- SET status = 'read'
-- WHERE status IN ('sent', 'delivered', 'sending');
-- Step 4: Alternative - Mark messages as read for YOUR chats only
-- Replace 'YOUR_USER_ID' with your actual user ID
-- UPDATE messages
-- SET status = 'read'
-- WHERE room_id IN (
--   SELECT id FROM friend_requests 
--   WHERE (sender_id = 'YOUR_USER_ID' OR receiver_id = 'YOUR_USER_ID')
--   AND status = 'accepted'
-- )
-- AND user_id != 'YOUR_USER_ID'
-- AND status != 'read';
-- Step 5: Convert all 'delivered' to 'sent'
UPDATE messages
SET status = 'sent'
WHERE status = 'delivered';
-- Step 6: Verify the fix
SELECT status,
    COUNT(*) as message_count
FROM messages
GROUP BY status
ORDER BY status;
-- ============================================
-- HOW TO GET YOUR USER ID:
-- ============================================
-- Run this to see your user ID:
SELECT id,
    email
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;
-- ============================================
-- EXPECTED RESULT AFTER FIX:
-- ============================================
-- status  | message_count
-- --------+--------------
-- read    | (some number)
-- sent    | (some number)
-- sending | 0 or very few
-- ============================================