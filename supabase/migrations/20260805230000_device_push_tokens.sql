-- APNs device tokens for push-only notifications.
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.device_push_tokens (
  token text primary key,
  member_id text not null,
  platform text not null default 'ios',
  updated_at timestamptz not null default now()
);

create index if not exists device_push_tokens_member_id_idx
  on public.device_push_tokens (member_id);

alter table public.device_push_tokens enable row level security;
revoke all on public.device_push_tokens from anon, authenticated;
