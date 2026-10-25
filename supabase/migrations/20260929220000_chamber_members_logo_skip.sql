-- Remember which Chambermate avatar was rejected (too large / unsupported type)
-- so the logo sync stops re-downloading it every run. A changed avatar key
-- makes the member a candidate again.

alter table public.chamber_members
  add column if not exists logo_skip_key text,
  add column if not exists logo_skip_reason text;
