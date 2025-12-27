insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true);

CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING ( bucket_id = 'avatars' );
CREATE POLICY "Authenticated Upload" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'avatars' AND auth.role() = 'authenticated' );
CREATE POLICY "Owner Update" ON storage.objects FOR UPDATE USING ( bucket_id = 'avatars' AND auth.uid() = owner );

