-- Member Success Hub, Phase 1 foundations: membership tiers, staff roles, org settings.
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.membership_tiers (
  code text primary key,
  display_name text not null,
  annual_dues_cents integer,
  stated_value_cents integer,
  display_order integer not null default 0,
  is_entitlement_bearing boolean not null default true,
  created_at timestamptz not null default now()
);

-- display_order is presentation-only. Entitlement logic must never branch on
-- tier rank/order -- NFP receives benefits Silver and Basic do not, so tiers
-- are not a ladder. Use tier_benefit_rules as the sole source of truth.
comment on column public.membership_tiers.display_order is
  'Presentation ordering only. Never used to infer entitlement inheritance.';

insert into public.membership_tiers
  (code, display_name, annual_dues_cents, stated_value_cents, display_order, is_entitlement_bearing)
values
  ('platinum', 'Platinum', 150000, 500000, 1, true),
  ('gold', 'Gold', 100000, 300000, 2, true),
  ('silver', 'Silver', 50000, 200000, 3, true),
  ('basic', 'Basic', 30000, 100000, 4, true),
  ('nfp', 'Non-Profit', 25000, 100000, 5, true),
  ('municipality', 'Municipality', null, null, 6, false),
  ('chamber_of_commerce', 'Chamber of Commerce', null, null, 7, false)
on conflict (code) do nothing;

-- 'municipality' = partner towns/villages collaborating with WKCC on events.
-- 'chamber_of_commerce' = internal WKCC staff accounts of record (e.g. the
-- executive director). Neither is a dues-paying member business; both are
-- excluded from entitlement generation via is_entitlement_bearing = false.
-- See generate_entitlements() in a later migration.

-- Maps the free-text tier label on chamber_members.membership_type to a
-- membership_tiers.code. Mirrors mapMembershipTier() in
-- supabase/functions/member-auth/index.ts -- keep the two in sync if that
-- allow-list ever changes.
create or replace function public.membership_tier_code(raw_tier text)
returns text
language sql
immutable
as $$
  select case lower(trim(coalesce(raw_tier, '')))
    when 'platinum' then 'platinum'
    when 'gold' then 'gold'
    when 'silver' then 'silver'
    when 'basic' then 'basic'
    when 'non-profit' then 'nfp'
    when 'nonprofit' then 'nfp'
    when 'not-for-profit' then 'nfp'
    when 'municipality' then 'municipality'
    when 'chamber of commerce' then 'chamber_of_commerce'
    else 'basic'
  end;
$$;

create table if not exists public.staff_roles (
  id uuid primary key default gen_random_uuid(),
  email citext not null,
  role text not null check (role in (
    'director',
    'member_success',
    'events_marketing',
    'lead_coordinator',
    'reporting_readonly',
    'developer_admin'
  )),
  granted_by citext,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz
);

-- A staff member may hold multiple simultaneous roles; only one active grant
-- per (email, role) at a time.
create unique index if not exists staff_roles_email_role_active_idx
  on public.staff_roles (email, role)
  where revoked_at is null;

-- Additive to the existing app_profiles.is_chamber_admin boolean (kept for
-- backwards compatibility, not replaced here). This table does not by itself
-- grant sign-in -- member-auth's sign-in paths still require an eligible
-- chamber_members row. See the WKCC Benefit Ledger, register item R7, before
-- wiring staff sign-in to this table.
comment on table public.staff_roles is
  'Additive staff RBAC. Does not grant sign-in on its own -- see R7 in the WKCC Benefit Ledger.';

create table if not exists public.org_settings (
  key text primary key,
  value jsonb not null,
  updated_by citext,
  updated_at timestamptz not null default now()
);

insert into public.org_settings (key, value)
values ('show_stated_value_to_members', 'false'::jsonb)
on conflict (key) do nothing;

comment on table public.org_settings is
  'Small admin-configurable flag store. show_stated_value_to_members (default off) must be read by the member-facing value summary in Phase 2/3 before ever rendering a tier''s stated dollar value to a member.';

alter table public.membership_tiers enable row level security;
revoke all on public.membership_tiers from anon, authenticated;

alter table public.staff_roles enable row level security;
revoke all on public.staff_roles from anon, authenticated;

alter table public.org_settings enable row level security;
revoke all on public.org_settings from anon, authenticated;
