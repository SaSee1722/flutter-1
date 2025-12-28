-- ============================================
-- FIX REMAINING SECURITY ISSUES (SEARCH PATHS)
-- ============================================
-- 1. Fix update_group_last_message
CREATE OR REPLACE FUNCTION public.update_group_last_message() RETURNS TRIGGER AS $$ BEGIN
UPDATE public.chat_rooms
SET last_message = NEW.content,
    last_message_time = NEW.created_at,
    updated_at = NEW.created_at
WHERE id = NEW.room_id;
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;
-- 2. Fix delete_user
CREATE OR REPLACE FUNCTION public.delete_user() RETURNS void AS $$ BEGIN
DELETE FROM auth.users
WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;
-- 3. Fix handle_new_user (The trigger function)
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER AS $$ BEGIN
INSERT INTO public.profiles (id, username, full_name, avatar_url)
VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url'
    );
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;
-- 4. NOTE: 'Compromised Passwords' warning cannot be fixed via SQL.
-- You must go to Authentication -> Providers -> Email -> Password requirements in dashboard to enable it.
SELECT '✅ ALL FUNCTIONS SECURED' as status;