-- Soft-archive for live promotions: hide from member catalog without hard delete.
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS archived_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS archived_by text NULL;

CREATE INDEX IF NOT EXISTS deals_archived_at_idx ON public.deals (archived_at);
CREATE INDEX IF NOT EXISTS deals_active_id_idx ON public.deals (id) WHERE archived_at IS NULL;
