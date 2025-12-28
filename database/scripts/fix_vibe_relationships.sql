-- Drop the existing foreign key to auth.users if it makes things cleaner, 
-- but adding a specific one to public.profiles is what enables the join.
-- 1. Add the foreign key relationship to profiles so Inner Join works
ALTER TABLE public.statuses DROP CONSTRAINT IF EXISTS statuses_user_id_profiles_fkey;
ALTER TABLE public.statuses
ADD CONSTRAINT statuses_user_id_profiles_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
-- 2. Reload the schema cache to ensure PostgREST picks up the new relationship
NOTIFY pgrst,
'reload config';