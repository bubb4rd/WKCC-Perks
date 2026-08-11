-- Per-member abuse limits for edge write paths (submissions, logos, device tokens).
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.edge_rate_limits (
  id bigserial primary key,
  bucket text not null,
  subject text not null,
  created_at timestamptz not null default now()
);

create index if not exists edge_rate_limits_bucket_subject_created_idx
  on public.edge_rate_limits (bucket, subject, created_at desc);

alter table public.edge_rate_limits enable row level security;
revoke all on public.edge_rate_limits from anon, authenticated;
