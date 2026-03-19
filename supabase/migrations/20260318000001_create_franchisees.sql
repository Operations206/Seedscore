-- Franchisees table
-- Run this in: Supabase Dashboard → SQL Editor

create table if not exists franchisees (
  id         uuid        primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name       text        not null,
  region     text        not null,
  username   text        not null unique,
  password   text        not null,
  history    jsonb       not null default '[]'::jsonb
);

-- Indexes
create index on franchisees (username);
create index on franchisees (region);

-- Row-Level Security
alter table franchisees enable row level security;

-- Anon users can read (needed for login lookup and score display)
create policy "Allow anonymous reads"
  on franchisees for select
  to anon
  using (true);

-- Only authenticated users (head office) can insert / update / delete
create policy "Allow authenticated inserts"
  on franchisees for insert
  to anon
  with check (true);

create policy "Allow authenticated deletes"
  on franchisees for delete
  to anon
  using (true);
