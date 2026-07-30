-- Live promotions: deals catalog + member submission queue
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.deals (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  business_id text not null,
  business_name text not null,
  short_description text not null default '',
  description text not null default '',
  terms text,
  redemption_instructions text not null default '',
  redemption_code text,
  category text not null,
  start_date timestamptz,
  end_date timestamptz,
  image_url text,
  members_only boolean not null default true,
  is_featured boolean not null default false,
  source_submission_id uuid,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists deals_end_date_idx on public.deals (end_date);
create index if not exists deals_is_featured_idx on public.deals (is_featured);
create index if not exists deals_category_idx on public.deals (category);

create table if not exists public.promotion_submissions (
  id uuid primary key default gen_random_uuid(),
  submitted_at timestamptz not null default now(),
  submitter_member_id text not null,
  submitter_email citext,
  submitter_name text not null,
  company_id text,
  company_name text not null,
  contact_email text not null default '',
  contact_phone text not null default '',
  title text not null,
  category text not null,
  short_description text not null default '',
  full_description text not null default '',
  terms text not null default '',
  redemption_instructions text not null default '',
  redemption_code_type text not null default 'No code needed',
  redemption_code text not null default '',
  start_date timestamptz not null,
  end_date timestamptz not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  admin_notes text,
  reviewed_at timestamptz,
  reviewed_by_admin_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists promotion_submissions_status_idx
  on public.promotion_submissions (status);
create index if not exists promotion_submissions_submitter_idx
  on public.promotion_submissions (submitter_member_id);

alter table public.deals
  drop constraint if exists deals_source_submission_id_fkey;
alter table public.deals
  add constraint deals_source_submission_id_fkey
  foreign key (source_submission_id)
  references public.promotion_submissions (id)
  on delete set null;

alter table public.deals enable row level security;
revoke all on public.deals from anon, authenticated;

alter table public.promotion_submissions enable row level security;
revoke all on public.promotion_submissions from anon, authenticated;

-- Note: intentionally no mock biz-* seed deals. Catalog content comes from
-- admin create / approved member submissions keyed to chamber_members.cm_id.
