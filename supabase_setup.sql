-- =======================================================
-- VOICE-FIRST CITIZEN COMPLAINT SYSTEM - SUPABASE SETUP
-- =======================================================

-- 1. Enable UUID Extension
create extension if not exists "uuid-ossp";

-- 2. Create Complaints Table
create table if not exists complaints (
  id uuid primary key default uuid_generate_v4(),
  tracking_id text unique,
  user_id uuid references auth.users(id),
  text text,
  category text,
  status text default 'Pending',
  image_url text,
  video_url text,
  audio_url text,
  image_urls jsonb default '[]'::jsonb,
  latitude float,
  longitude float,
  upvotes int default 0,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Ensure image_urls is added to existing tables
alter table if exists complaints add column if not exists image_urls jsonb default '[]'::jsonb;
alter table if exists complaints add column if not exists tracking_id text unique;
-- Add translation fields for voice-to-text translation support
alter table if exists complaints add column if not exists original_language text default 'unknown';
alter table if exists complaints add column if not exists translated_description text;

-- 3. Create Upvotes Table
create table if not exists upvotes (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade,
  complaint_id uuid references complaints(id) on delete cascade,
  unique(user_id, complaint_id) 
);

-- 4. Create Campaigns Table (NGO)
create table if not exists campaigns (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text not null,
  objective text,
  category text,
  location text,
  image_url text,
  start_date timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 4.5 Create Community Tables
create table if not exists community_posts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id),
  author_email text,
  content text not null,
  image_url text,
  likes_count integer default 0,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

create table if not exists post_likes (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid references community_posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  unique(post_id, user_id)
);

create table if not exists post_comments (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid references community_posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  author_email text,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 5. Setup Storage Buckets
insert into storage.buckets (id, name, public) 
values 
  ('images', 'images', true),
  ('videos', 'videos', true),
  ('audio', 'audio', true),
  ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- 6. Set Storage Policies
drop policy if exists "Public Access" on storage.objects;
drop policy if exists "Public Insert" on storage.objects;
drop policy if exists "Public Update" on storage.objects;

create policy "Public Access" on storage.objects for select using (true);
create policy "Public Insert" on storage.objects for insert with check (true);
create policy "Public Update" on storage.objects for update using (true);

-- =======================================================
-- COMMUNITY & SOCIAL FORUM EXTENSIONS
-- =======================================================

create table if not exists community_posts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) not null,
  author_email text,
  content text not null,
  image_url text,
  likes_count integer default 0,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

create table if not exists post_likes (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid references community_posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  unique(post_id, user_id)
);

create table if not exists post_comments (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid references community_posts(id) on delete cascade,
  user_id uuid references auth.users(id) not null,
  author_email text,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Disable RLS for public open beta testing
alter table community_posts disable row level security;
alter table post_likes disable row level security;
alter table post_comments disable row level security;

-- =======================================================
-- USER PROFILES (NAME, AGE, GENDER)
-- =======================================================

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  age integer,
  gender text,
  phone text,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Trigger to automatically create a profile for every new user
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, age, gender)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    (new.raw_user_meta_data->>'age')::integer,
    new.raw_user_meta_data->>'gender'
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Allow users to read and update their own profile
alter table profiles enable row level security;
drop policy if exists "Users can view their own profile" on profiles;
create policy "Users can view their own profile" on profiles for select using ( auth.uid() = id );
drop policy if exists "Users can update their own profile" on profiles;
create policy "Users can update their own profile" on profiles for update using ( auth.uid() = id );
drop policy if exists "Users can insert their own profile" on profiles;
create policy "Users can insert their own profile" on profiles for insert with check ( auth.uid() = id );

-- =======================================================
-- ADMIN SECURE DATABASE FUNCTIONS
-- =======================================================
DROP FUNCTION IF EXISTS get_admin_complaints();
CREATE OR REPLACE FUNCTION get_admin_complaints()
RETURNS TABLE (
  id uuid,
  tracking_id text,
  text text,
  category text,
  status text,
  image_url text,
  image_urls jsonb,
  video_url text,
  audio_url text,
  latitude float,
  longitude float,
  created_at timestamp with time zone,
  citizen_name text,
  citizen_phone text,
  citizen_email text,
  citizen_age integer,
  citizen_gender text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id, c.tracking_id, c.text, c.category, c.status, c.image_url, c.image_urls, c.video_url, c.audio_url, c.latitude, c.longitude, c.created_at,
    p.full_name, p.phone, u.email::text, p.age, p.gender
  FROM complaints c
  LEFT JOIN profiles p ON c.user_id = p.id
  LEFT JOIN auth.users u ON c.user_id = u.id
  ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
