-- Ensure columns exist even if table was already created
ALTER TABLE public.statuses
ADD COLUMN IF NOT EXISTS caption text;
ALTER TABLE public.statuses
ADD COLUMN IF NOT EXISTS is_video boolean DEFAULT false;
ALTER TABLE public.statuses
ADD COLUMN IF NOT EXISTS view_count int DEFAULT 0;
ALTER TABLE public.statuses
ADD COLUMN IF NOT EXISTS media_url text;
ALTER TABLE public.statuses
ADD COLUMN IF NOT EXISTS expires_at timestamptz;
-- Force schema cache reload (usually happens automatically but good to be sure)
NOTIFY pgrst,
'reload config';