-- MBR Submissions table
-- Run this in: Supabase Dashboard → SQL Editor

create table if not exists mbr_submissions (
  id                uuid        primary key default gen_random_uuid(),
  submitted_at      timestamptz not null default now(),

  -- Franchisee identity
  franchisee_name   text        not null,
  location          text        not null,
  review_month      text        not null,   -- format: YYYY-MM
  email             text,

  -- Score & tier
  score             smallint    not null check (score between 0 and 100),
  tier_label        text        not null,

  -- Client numbers
  paying_clients    smallint    not null default 0,
  new_clients       smallint    not null default 0,
  returning_clients smallint    not null default 0,
  no_shows          smallint    not null default 0,

  -- Retail
  skinade           smallint    not null default 0,
  alumier           smallint    not null default 0,

  -- Activity
  google_new        smallint    not null default 0,
  networking        text[]      not null default '{}',
  model_day         boolean     not null default false,
  held_event        boolean     not null default false,

  -- Mindset
  effort            smallint    not null check (effort between 0 and 10),
  confidence        smallint    not null check (confidence between 0 and 10),

  -- AI-generated content
  feedback          text,
  actions           text[]      not null default '{}'
);

-- Index for common lookups
create index on mbr_submissions (franchisee_name);
create index on mbr_submissions (review_month);
create index on mbr_submissions (submitted_at desc);

-- Row-Level Security: head office can read all rows; no public access
alter table mbr_submissions enable row level security;

-- Allow inserts from the browser (anon key is fine for write-only)
create policy "Allow anonymous inserts"
  on mbr_submissions for insert
  to anon
  with check (true);

-- Only authenticated users (head office) can read submissions
create policy "Allow authenticated reads"
  on mbr_submissions for select
  to authenticated
  using (true);
