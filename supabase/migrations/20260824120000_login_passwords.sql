-- App Review password sign-in (review account only; members keep email OTP).
-- Hashes use pgcrypto blowfish. The plaintext is not stored in SQL.
-- Uses the existing App Review chamber member: wkccperksconnect@gmail.com (cm_id = -1).

create table if not exists public.login_passwords (
  email citext primary key,
  password_hash text not null,
  created_at timestamptz not null default now()
);

alter table public.login_passwords enable row level security;
revoke all on public.login_passwords from anon, authenticated;

create or replace function public.verify_login_password(p_email text, p_password text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  stored_hash text;
begin
  select password_hash into stored_hash
  from public.login_passwords
  where email = lower(trim(p_email))::citext;

  if stored_hash is null then
    perform crypt('timing-guard', gen_salt('bf'));
    return false;
  end if;

  return crypt(p_password, stored_hash) = stored_hash;
end;
$$;

revoke all on function public.verify_login_password(text, text) from public, anon, authenticated;
grant execute on function public.verify_login_password(text, text) to service_role;

-- Ensure the premade App Review member stays eligible for login.
update public.chamber_members
set
  status = '2',
  display_flags = coalesce(nullif(trim(display_flags), ''), ''),
  synced_at = now()
where cm_id = -1
  and lower(email::text) = lower('wkccperksconnect@gmail.com');

insert into public.login_passwords (email, password_hash)
values (
  'wkccperksconnect@gmail.com',
  '$2a$10$LIFUzr.ayZrelOhq8aZ2QOzjjvx2KwnDTiMv..GLG.g5eFEpJ6ORC'
)
on conflict (email) do update
set password_hash = excluded.password_hash;

insert into public.app_profiles (email, cm_id, is_chamber_admin, last_login_at, updated_at)
values (
  'wkccperksconnect@gmail.com',
  -1,
  false,
  now(),
  now()
)
on conflict (email) do update
set
  cm_id = excluded.cm_id,
  last_login_at = excluded.last_login_at,
  updated_at = now();
