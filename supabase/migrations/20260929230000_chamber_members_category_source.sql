-- Categories now use Chambermate's business category labels verbatim
-- (see supabase/functions/_shared/categories.ts). Rename the app's original
-- "X and Y" names, and track where each business category came from so the
-- Chambermate category sync never overwrites a member's own choice.

alter table public.chamber_members
  add column if not exists category_source text,
  add column if not exists chambermate_category_key text,
  add column if not exists category_synced_at timestamptz;

alter table public.chamber_members
  drop constraint if exists chamber_members_category_source_check;
alter table public.chamber_members
  add constraint chamber_members_category_source_check
  check (category_source is null or category_source in ('member', 'chambermate'));

create temporary table category_renames (old_name text primary key, new_name text not null);
insert into category_renames (old_name, new_name) values
  ('Shopping and Specialty Retail', 'Shopping & Specialty Retail'),
  ('Home and Garden', 'Home & Garden'),
  ('Restaurants, Food and Beverages', 'Restaurants, Food & Beverages'),
  ('Government, Education and Individuals', 'Government, Education & Individuals'),
  ('Personal Services and Care', 'Personal Services & Care'),
  ('Business and Professional Services', 'Business & Professional Services'),
  ('Finance and Insurance', 'Finance & Insurance'),
  ('Advertising and Media', 'Advertising & Media');

update public.chamber_members t set category = r.new_name
from category_renames r where t.category = r.old_name;
update public.deals t set category = r.new_name
from category_renames r where t.category = r.old_name;
update public.promotion_submissions t set category = r.new_name
from category_renames r where t.category = r.old_name;

drop table category_renames;

-- Any real category already stored was picked by the member in the app. A
-- stored 'Other' is ambiguous (the profile picker defaulted to it and saved it
-- with every profile edit), so leave those unclaimed for the sync to fill.
update public.chamber_members
set category_source = 'member'
where category_source is null
  and category is not null
  and trim(category) <> ''
  and category <> 'Other';
