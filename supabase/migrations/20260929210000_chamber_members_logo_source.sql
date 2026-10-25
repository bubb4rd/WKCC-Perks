-- Track where each business logo came from so the Chambermate logo sync never
-- overwrites a member's own upload and can tell when the vendor avatar changed.

alter table public.chamber_members
  add column if not exists logo_source text,
  add column if not exists chambermate_avatar_key text,
  add column if not exists logo_synced_at timestamptz;

alter table public.chamber_members
  drop constraint if exists chamber_members_logo_source_check;
alter table public.chamber_members
  add constraint chamber_members_logo_source_check
  check (logo_source is null or logo_source in ('member_upload', 'chambermate', 'legacy'));

-- Existing logos: ones in our bucket were uploaded by members; anything else
-- came from the old ChamberMaster LogoUrl backfill.
update public.chamber_members
set logo_source = case
  when logo_url like '%/storage/v1/object/public/business-logos/%' then 'member_upload'
  else 'legacy'
end
where logo_source is null
  and logo_url is not null
  and trim(logo_url) <> '';
