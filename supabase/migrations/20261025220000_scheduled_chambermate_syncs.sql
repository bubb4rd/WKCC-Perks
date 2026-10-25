-- Scheduled Chambermate syncs. Until now the member and hot deals mirrors only
-- refreshed when someone ran supabase/scripts/sync-members.sh by hand, so the app
-- drifted from the chamber website.
--
-- pg_cron fires member-auth sync routes through pg_net. The functions base URL and
-- MEMBER_SYNC_SECRET live in Vault, never in this (public) repo, so a database
-- without them (local dev, branches) cannot call production. Set them once per
-- project:
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1', 'SUPABASE_FUNCTIONS_BASE');
--   select vault.create_secret('<MEMBER_SYNC_SECRET>', 'MEMBER_SYNC_SECRET');
-- (Same names as the env vars supabase/scripts/sync-members.sh reads.)
--
-- pg_net is fire-and-forget: a cron run "succeeds" once the request is queued,
-- whatever the function returns. sync_state, written by the sync functions
-- themselves, is the record of whether a sync actually worked.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create table if not exists public.sync_state (
  source text primary key,
  last_success_at timestamptz,
  last_error text,
  last_error_at timestamptz
);

alter table public.sync_state enable row level security;
revoke all on public.sync_state from anon, authenticated;

create or replace function public.invoke_chambermate_sync(
  p_route text,
  p_timeout_ms integer default 60000
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_url text;
  sync_secret text;
begin
  select decrypted_secret into base_url
  from vault.decrypted_secrets
  where name = 'SUPABASE_FUNCTIONS_BASE';

  select decrypted_secret into sync_secret
  from vault.decrypted_secrets
  where name = 'MEMBER_SYNC_SECRET';

  if base_url is null or sync_secret is null then
    raise exception 'Vault secrets SUPABASE_FUNCTIONS_BASE / MEMBER_SYNC_SECRET are not set; skipping %', p_route;
  end if;

  return net.http_post(
    url := rtrim(base_url, '/') || '/member-auth/' || p_route,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-sync-secret', sync_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := p_timeout_ms
  );
end;
$$;

revoke all on function public.invoke_chambermate_sync(text, integer) from public, anon, authenticated;

-- Members nightly at 08:50 UTC (~3-4am Central), ten minutes ahead of a hot deals
-- pass, so a new member's post links to their business that same night. Hot deals
-- re-match every run, so earlier unlinked posts heal too. Category and logo syncs
-- stay manual: they default to dry runs and involve policy decisions.
select cron.schedule(
  'sync-chambermate-members',
  '50 8 * * *',
  $$ select public.invoke_chambermate_sync('sync-members', 120000) $$
);

select cron.schedule(
  'sync-chambermate-hot-deals',
  '*/10 * * * *',
  $$ select public.invoke_chambermate_sync('sync-hot-deals', 30000) $$
);
