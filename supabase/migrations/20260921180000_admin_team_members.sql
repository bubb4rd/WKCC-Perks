-- Per-admin curated roster of teammates selectable as a lead owner (#43).
-- Distinct from app_profiles.is_chamber_admin: an admin's team can include
-- a bare email that isn't a chamber-staff account yet (added manually via
-- Settings), so this can't just be "everyone with is_chamber_admin".
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.admin_team_members (
  id uuid primary key default gen_random_uuid(),
  admin_email citext not null references public.app_profiles (email) on delete cascade,
  member_email citext not null,
  display_name text,
  created_at timestamptz not null default now(),
  unique (admin_email, member_email)
);

create index if not exists admin_team_members_admin_idx
  on public.admin_team_members (admin_email);

comment on table public.admin_team_members is
  'Per-admin curated roster of teammates selectable as a lead owner (GH #43). Access is via the staff edge function (service role), not PostgREST.';

alter table public.admin_team_members enable row level security;
revoke all on public.admin_team_members from anon, authenticated;
