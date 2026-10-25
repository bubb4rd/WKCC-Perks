-- Hot deals: read-only mirror of the Chambermate "Hot Deals" board.
-- Written only by member-auth/sync-hot-deals (service role); the app reads them
-- through perks/hot-deals. Kept separate from `deals` so admin edit/archive and
-- member submission flows can never touch Chambermate-owned content.

create table if not exists public.hot_deals (
  post_key text primary key,
  title text not null,
  body text not null default '',
  company_name text not null,
  -- Stringified chamber_members.cm_id when the company name matched a current member.
  business_id text,
  avatar_storage_key text,
  start_date timestamptz,
  end_date timestamptz,
  raw jsonb,
  synced_at timestamptz not null default now()
);

create index if not exists hot_deals_end_date_idx on public.hot_deals (end_date);

alter table public.hot_deals enable row level security;
revoke all on public.hot_deals from anon, authenticated;
