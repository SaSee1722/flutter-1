-- Create status_views table for tracking who viewed what
CREATE TABLE IF NOT EXISTS public.status_views (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    status_id uuid REFERENCES public.statuses(id) ON DELETE CASCADE,
    viewer_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    UNIQUE(status_id, viewer_id)
);
-- Enable RLS
ALTER TABLE public.status_views ENABLE ROW LEVEL SECURITY;
-- Policies
CREATE POLICY "Users can view views of their own statuses" ON public.status_views FOR
SELECT USING (
        EXISTS (
            SELECT 1
            FROM public.statuses
            WHERE statuses.id = status_views.status_id
                AND statuses.user_id = auth.uid()
        )
    );
CREATE POLICY "Users can mark statuses as viewed" ON public.status_views FOR
INSERT WITH CHECK (auth.uid() = viewer_id);
-- Add viewer_ids column to statuses as a cache (optional but helpful for speed)
-- ALTER TABLE public.statuses ADD COLUMN IF NOT EXISTS viewer_ids uuid[] DEFAULT '{}';