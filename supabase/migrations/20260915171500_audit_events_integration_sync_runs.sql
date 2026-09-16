-- Member Success Hub, Phase 1: append-only audit log + sync run tracking.
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_email citext,
  actor_role text,
  action text not null,
  resource_type text not null,
  resource_id text not null,
  occurred_at timestamptz not null default now(),
  before jsonb,
  after jsonb
);

create index if not exists audit_events_resource_idx
  on public.audit_events (resource_type, resource_id, occurred_at desc);
create index if not exists audit_events_actor_idx
  on public.audit_events (actor_email, occurred_at desc);

alter table public.audit_events enable row level security;
revoke all on public.audit_events from anon, authenticated;

-- True append-only: even the service role (used by edge functions) cannot
-- update or delete audit rows, so a coding mistake in the staff function
-- can't quietly rewrite history. A future retention policy must run as the
-- table owner/superuser via a migration, not through the app.
revoke update, delete on public.audit_events from service_role;

create table if not exists public.integration_sync_runs (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('chambermaster', 'growthzone')),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status in ('running', 'succeeded', 'failed')),
  records_seen integer,
  records_upserted integer,
  error_text text
);

create index if not exists integration_sync_runs_source_started_idx
  on public.integration_sync_runs (source, started_at desc);

alter table public.integration_sync_runs enable row level security;
revoke all on public.integration_sync_runs from anon, authenticated;
