-- Create statuses table
CREATE TABLE IF NOT EXISTS public.statuses (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    media_url text NOT NULL,
    caption text,
    is_video boolean DEFAULT false,
    view_count int DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    expires_at timestamptz NOT NULL
);
-- Enable RLS
ALTER TABLE public.statuses ENABLE ROW LEVEL SECURITY;
-- Policies
CREATE POLICY "Public can view active statuses" ON public.statuses FOR
SELECT USING (expires_at > now());
CREATE POLICY "Users can create their own statuses" ON public.statuses FOR
INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own statuses" ON public.statuses FOR DELETE USING (auth.uid() = user_id);
-- Storage bucket definition (if not already existing)
insert into storage.buckets (id, name, public)
values ('vibe-media', 'vibe-media', true) on conflict (id) do nothing;
CREATE POLICY "Public Access Vibe Media" ON storage.objects FOR
SELECT USING (bucket_id = 'vibe-media');
CREATE POLICY "Authenticated Upload Vibe Media" ON storage.objects FOR
INSERT WITH CHECK (
        bucket_id = 'vibe-media'
        AND auth.role() = 'authenticated'
    );