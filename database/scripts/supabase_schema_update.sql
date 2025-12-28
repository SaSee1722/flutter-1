CREATE TABLE IF NOT EXISTS public.friend_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id uuid REFERENCES auth.users(id) NOT NULL,
  receiver_id uuid REFERENCES auth.users(id) NOT NULL,
  status text CHECK (status IN ('pending', 'accepted', 'rejected')) DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view requests involving them" ON public.friend_requests
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send requests" ON public.friend_requests
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update requests involving them" ON public.friend_requests
  FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Storage buckets
insert into storage.buckets (id, name, public) values ('vibe-media', 'vibe-media', true);
insert into storage.buckets (id, name, public) values ('chat-media', 'chat-media', true);

CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING ( bucket_id IN ('vibe-media', 'chat-media') );
CREATE POLICY "Authenticated Upload" ON storage.objects FOR INSERT WITH CHECK ( bucket_id IN ('vibe-media', 'chat-media') AND auth.role() = 'authenticated' );

