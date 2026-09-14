-- Lets any OTP-verified member create/update their own password sign-in,
-- reusing the login_passwords table and pgcrypto hashing added for App Review.
create or replace function public.set_login_password(p_email text, p_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.login_passwords (email, password_hash)
  values (lower(trim(p_email))::citext, crypt(p_password, gen_salt('bf')))
  on conflict (email) do update
  set password_hash = excluded.password_hash;
end;
$$;

revoke all on function public.set_login_password(text, text) from public, anon, authenticated;
grant execute on function public.set_login_password(text, text) to service_role;
