-- Safely insert bucket if not exists
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Drop generic/old policies if they exist (to clean up)
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Upload" ON storage.objects;
DROP POLICY IF EXISTS "Owner Update" ON storage.objects;

-- Create SPECIFIC policies for Avatars (using unique names to avoid conflicts)
CREATE POLICY "Avatars Public Access" ON storage.objects 
FOR SELECT USING ( bucket_id = 'avatars' );

CREATE POLICY "Avatars Authenticated Upload" ON storage.objects 
FOR INSERT WITH CHECK ( bucket_id = 'avatars' AND auth.role() = 'authenticated' );

CREATE POLICY "Avatars Owner Update" ON storage.objects 
FOR UPDATE USING ( bucket_id = 'avatars' AND auth.uid() = owner );

