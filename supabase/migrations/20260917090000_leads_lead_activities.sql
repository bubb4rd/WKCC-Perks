-- LeadGen Studio (staff inbox): prospective-member and referral leads.
-- Edge functions use service role; direct client access is revoked.
-- staff_roles.lead_coordinator is not consulted yet — same as the staff
-- function, every app_profiles.is_chamber_admin has full access.

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'new' check (status in (
    'new',
    'contacted',
    'qualified',
    'nurture',
    'won',
    'lost'
  )),
  source text not null default 'staff_manual' check (source in (
    'staff_manual',
    'website',
    'event',
    'member_referral',
    'other'
  )),
  company_name text,
  contact_name text,
  email citext,
  phone text,
  owner_email citext,
  referring_cm_id integer references public.chamber_members (cm_id) on delete set null,
  converted_cm_id integer references public.chamber_members (cm_id) on delete set null,
  next_follow_up_on date,
  lost_reason text,
  won_at timestamptz,
  lost_at timestamptz,
  created_by citext,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint leads_has_identity check (
    nullif(btrim(coalesce(company_name, '')), '') is not null
    or nullif(btrim(coalesce(contact_name, '')), '') is not null
  )
);

create index if not exists leads_status_created_idx
  on public.leads (status, created_at desc);
create index if not exists leads_owner_status_idx
  on public.leads (owner_email, status);
create index if not exists leads_follow_up_open_idx
  on public.leads (next_follow_up_on)
  where status in ('new', 'contacted', 'qualified', 'nurture');

comment on table public.leads is
  'Staff-only lead inbox. Access is via the leads edge function (service role), not PostgREST.';

create table if not exists public.lead_activities (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads (id) on delete cascade,
  kind text not null check (kind in (
    'note',
    'status_change',
    'assignment',
    'follow_up'
  )),
  body text,
  actor_email citext,
  occurred_at timestamptz not null default now()
);

create index if not exists lead_activities_lead_occurred_idx
  on public.lead_activities (lead_id, occurred_at desc);

comment on table public.lead_activities is
  'Append-only timeline for a lead. Updates and deletes are revoked even from service_role.';

alter table public.leads enable row level security;
revoke all on public.leads from anon, authenticated;

alter table public.lead_activities enable row level security;
revoke all on public.lead_activities from anon, authenticated;

-- True append-only: a coding mistake in the leads function cannot rewrite
-- history. Retention must run as table owner via a migration.
revoke update, delete on public.lead_activities from service_role;
