-- App-owned business profile fields (member-editable; sync-members must not overwrite).
ALTER TABLE public.chamber_members
  ADD COLUMN IF NOT EXISTS category text NULL,
  ADD COLUMN IF NOT EXISTS short_description text NULL,
  ADD COLUMN IF NOT EXISTS website_url text NULL,
  ADD COLUMN IF NOT EXISTS phone text NULL,
  ADD COLUMN IF NOT EXISTS address text NULL,
  ADD COLUMN IF NOT EXISTS address_public boolean NOT NULL DEFAULT true;
