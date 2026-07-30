-- App-owned membership tier label from chamber listing export (not CM Level numeric code).
-- sync-members must not overwrite this column.
ALTER TABLE public.chamber_members
  ADD COLUMN IF NOT EXISTS membership_type text NULL;
