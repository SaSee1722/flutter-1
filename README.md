# GOSSIP - Secure Real-time Messaging & Calling

GOSSIP is a premium, privacy-focused Flutter application built with a Pure Black Glassmorphism UI.

## Features

- **Secure Auth**: Email/Password with unique usernames.
- **App Lock**: Secure device-local PIN protection.
- **Real-time Chat**: Lightning-fast messaging with sync and markdown support.
- **WebRTC Calls**: P2P Audio and Video calls using Supabase signaling.
- **Vibes**: 24-hour disappearing status updates.
- **OLED UI**: Pure black background with deep sky blue and baby pink accents.

## Setup Instructions

1. **Supabase Setup**:
   - Create a new project on [Supabase](https://supabase.com).
   - Run the SQL schema provided below in the SQL Editor.
   - Create a storage bucket named `status-media` and set it to public.
2. **Flutter Setup**:
   - Locate `lib/core/constants/supabase_constants.dart`.
   - Replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with your project credentials.
   - Run `flutter pub get`.
3. **Run App**:
   - `flutter run`

## Supabase SQL Schema

```sql
-- Profiles table
CREATE TABLE public.profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  username text UNIQUE NOT NULL,
  full_name text,
  avatar_url text,
  is_online boolean DEFAULT false,
  updated_at timestamp with time zone DEFAULT now()
);

-- Messages table
CREATE TABLE public.messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  room_id uuid NOT NULL,
  user_id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  content text NOT NULL,
  status text DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
  created_at timestamp with time zone DEFAULT now()
);

-- Calls table
CREATE TABLE public.calls (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  caller_id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  receiver_id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  offer jsonb,
  answer jsonb,
  status text DEFAULT 'ringing' CHECK (status IN ('ringing', 'accepted', 'rejected', 'ended')),
  created_at timestamp with time zone DEFAULT now()
);

-- ICE Candidates table
CREATE TABLE public.ice_candidates (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  call_id uuid REFERENCES public.calls ON DELETE CASCADE NOT NULL,
  candidate jsonb NOT NULL,
  is_caller boolean NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- Statuses (Vibes) table
CREATE TABLE public.statuses (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  media_url text NOT NULL,
  is_video boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone NOT NULL
);

-- RLS Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view messages in their rooms." ON public.messages FOR SELECT USING (true); -- Simplify for MVP
CREATE POLICY "Users can insert their own messages." ON public.messages FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Trigger for profile creation on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name)
  VALUES (new.id, new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```
