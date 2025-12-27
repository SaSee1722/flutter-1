-- ============================================
-- FIX MESSAGE STATUS AND UNREAD COUNT ISSUES
-- ============================================
-- This script will:
-- 1. Check current message statuses
-- 2. Clean up any inconsistent data
-- 3. Simplify status to: sending, sent, read
-- ============================================
-- Step 1: Check current message statuses
SELECT status,
    COUNT(*) as count
FROM messages
GROUP BY status;
-- Step 2: Update all 'delivered' messages to 'sent'
-- (Simplifying: we only need 'sent' and 'read')
UPDATE messages
SET status = 'sent'
WHERE status = 'delivered';
-- Step 3: Verify the update
SELECT status,
    COUNT(*) as count
FROM messages
GROUP BY status;
-- ============================================
-- TESTING QUERIES
-- ============================================
-- Check unread messages for a specific user (replace YOUR_USER_ID)
-- SELECT m.*, p.username as sender_name
-- FROM messages m
-- JOIN profiles p ON m.user_id = p.id
-- WHERE m.room_id IN (
--   SELECT id FROM friend_requests 
--   WHERE (sender_id = 'YOUR_USER_ID' OR receiver_id = 'YOUR_USER_ID')
--   AND status = 'accepted'
-- )
-- AND m.user_id != 'YOUR_USER_ID'
-- AND m.status IN ('sent', 'delivered')
-- ORDER BY m.created_at DESC;
-- ============================================
-- RESET ALL MESSAGES TO 'sent' (if needed for testing)
-- ============================================
-- Uncomment this if you want to reset all messages:
-- UPDATE messages
-- SET status = 'sent'
-- WHERE user_id != auth.uid();
-- ============================================
-- NOTES
-- ============================================
-- After running this:
-- 1. All 'delivered' messages become 'sent'
-- 2. Unread count will only count 'sent' messages
-- 3. When you open a chat, messages become 'read'
-- 4. Unread badge should disappear correctly
-- ============================================