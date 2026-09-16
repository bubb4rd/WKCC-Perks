-- Member Success Hub, Phase 1: staff follow-up tasks.
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.staff_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  owner_email citext not null,
  due_on date,
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high')),
  status text not null default 'open' check (status in ('open', 'in_progress', 'done', 'cancelled')),
  cm_id integer references public.chamber_members (cm_id) on delete set null,
  entitlement_id uuid references public.benefit_entitlements (id) on delete set null,
  notes text,
  completed_at timestamptz,
  created_by citext,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists staff_tasks_owner_status_idx
  on public.staff_tasks (owner_email, status);
create index if not exists staff_tasks_cm_id_idx
  on public.staff_tasks (cm_id);
create index if not exists staff_tasks_due_on_open_idx
  on public.staff_tasks (due_on)
  where status in ('open', 'in_progress');

alter table public.staff_tasks enable row level security;
revoke all on public.staff_tasks from anon, authenticated;
