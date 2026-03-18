-- ============================================================
-- Skin Within Aesthetics — Seedscore Portal
-- Supabase Database Schema
-- Run this entire file in your Supabase SQL Editor
-- ============================================================

-- 1. PROFILES TABLE
-- Extends auth.users with role and clinic info
create table if not exists public.profiles (
  id           uuid references auth.users on delete cascade primary key,
  full_name    text,
  clinic_name  text,
  region       text,
  role         text not null default 'franchisee'
                 check (role in ('franchisee', 'head_office')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 2. MBR SUBMISSIONS TABLE
create table if not exists public.mbr_submissions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users on delete cascade,
  franchisee_name  text,
  clinic_location  text,
  region           text,
  review_month     text not null,   -- YYYY-MM format  e.g. "2026-03"
  score            integer not null,
  tier_label       text,
  form_data        jsonb,           -- full form payload
  feedback         text,            -- AI-generated feedback text
  actions          jsonb,           -- array of 3 action strings
  submitted_at     timestamptz not null default now()
);

-- Index for fast per-user queries
create index if not exists mbr_submissions_user_id_idx
  on public.mbr_submissions (user_id, review_month desc);

-- ============================================================
-- 3. HELPER FUNCTION (avoids RLS recursion)
-- ============================================================
create or replace function public.is_head_office()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'head_office'
  );
$$;

-- ============================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles        enable row level security;
alter table public.mbr_submissions enable row level security;

-- Profiles: own row + head office can read all
create policy "profiles_select" on public.profiles
  for select using (
    auth.uid() = id or public.is_head_office()
  );

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- MBR Submissions: franchisees manage own rows; head office reads all
create policy "mbr_insert_own" on public.mbr_submissions
  for insert with check (auth.uid() = user_id);

create policy "mbr_select" on public.mbr_submissions
  for select using (
    auth.uid() = user_id or public.is_head_office()
  );

-- ============================================================
-- 5. AUTO-CREATE PROFILE ON SIGN-UP
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, clinic_name, region, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name',  ''),
    coalesce(new.raw_user_meta_data ->> 'clinic_name', ''),
    coalesce(new.raw_user_meta_data ->> 'region',      ''),
    coalesce(new.raw_user_meta_data ->> 'role',        'franchisee')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- 6. HELPER RPC: get latest score per franchisee (for ranking)
-- ============================================================
create or replace function public.get_franchisee_latest_scores()
returns table(user_id uuid, score integer, review_month text)
language sql
security definer
set search_path = public
as $$
  select distinct on (user_id)
    user_id, score, review_month
  from public.mbr_submissions
  order by user_id, review_month desc;
$$;

-- ============================================================
-- 7. SAMPLE DATA — run AFTER creating users in the Auth dashboard
-- ============================================================
-- Step 1: Create users in Supabase Auth dashboard (Authentication > Users > Add user)
-- Step 2: Copy their UUIDs and update the profiles table:
--
-- Head office user (replace UUID with real one from Auth):
-- update public.profiles
--   set full_name = 'Head Office', role = 'head_office'
--   where id = '<head-office-user-uuid>';
--
-- Franchisee example (replace UUID with real one from Auth):
-- update public.profiles
--   set full_name = 'Alice Morgan', clinic_name = 'Manchester North', region = 'North'
--   where id = '<alice-user-uuid>';
--
-- You can also create users + profiles in one go with the service-role key:
-- See README.md for the full setup guide.
