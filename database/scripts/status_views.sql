-- 1. Create the table if not exists with a unique constraint
CREATE TABLE IF NOT EXISTS status_views (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    status_id uuid REFERENCES statuses(id) ON DELETE CASCADE,
    viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(status_id, viewer_id)
);
-- 2. Enable RLS
ALTER TABLE status_views ENABLE ROW LEVEL SECURITY;
-- 3. RLS Policies for status_views
DROP POLICY IF EXISTS "Users can create views" ON status_views;
CREATE POLICY "Users can create views" ON status_views FOR
INSERT WITH CHECK (auth.uid() = viewer_id);
DROP POLICY IF EXISTS "Users can view their own views" ON status_views;
CREATE POLICY "Users can view their own views" ON status_views FOR
SELECT USING (auth.uid() = viewer_id);
DROP POLICY IF EXISTS "Owners can view all views of their statuses" ON status_views;
CREATE POLICY "Owners can view all views of their statuses" ON status_views FOR
SELECT USING (
        status_id IN (
            SELECT id
            FROM statuses
            WHERE user_id = auth.uid()
        )
    );
-- 4. View Count Increment Logic (Trigger)
-- Using a trigger prevents RLS issues where a viewer can't update the owner's status table directly.
CREATE OR REPLACE FUNCTION increment_vibe_view() RETURNS TRIGGER AS $$ BEGIN
UPDATE statuses
SET view_count = view_count + 1
WHERE id = NEW.status_id;
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS on_vibe_viewed ON status_views;
CREATE TRIGGER on_vibe_viewed
AFTER
INSERT ON status_views FOR EACH ROW EXECUTE FUNCTION increment_vibe_view();