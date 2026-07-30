-- Business logos: persist member/company logo URLs + public storage bucket

alter table public.chamber_members
  add column if not exists logo_url text;

-- Backfill from ChamberMaster / GrowthZone raw payload when present
update public.chamber_members
set logo_url = nullif(trim(raw->>'LogoUrl'), '')
where logo_url is null
  and raw->>'LogoUrl' is not null
  and trim(raw->>'LogoUrl') <> '';

-- Public read bucket for business logos; writes go through edge (service role)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'business-logos',
  'business-logos',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public read for objects in this bucket
drop policy if exists "Public read business logos" on storage.objects;
create policy "Public read business logos"
  on storage.objects
  for select
  to public
  using (bucket_id = 'business-logos');
