-- Member Success Hub, Phase 1: fulfillment records + the member activity timeline.
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.benefit_fulfillments (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null references public.benefit_entitlements (id) on delete cascade,
  status text not null default 'available' check (status in (
    'available',
    'requested_by_member',
    'offered',
    'scheduled',
    'in_progress',
    'completed',
    'redeemed',
    'deferred',
    'declined',
    'not_applicable',
    'expired',
    'needs_followup'
  )),
  source text not null default 'allowance' check (source in (
    'allowance',        -- decrements the entitlement's allowance
    'paid_add_on',      -- bought beyond the allowance (e.g. $150 e-blast)
    'courtesy',         -- delivered as goodwill; no allowance, no charge
    'manual_exception'  -- staff override to tier rules; requires elevated role + note
  )),
  quantity_used integer not null default 1,
  unit_price_cents integer,
  external_invoice_reference text,
  occurred_on date not null default current_date,
  staff_owner_email citext,
  member_visible boolean not null default false,
  member_visible_summary text,
  internal_notes text,
  evidence_url text,
  related_submission_id uuid references public.promotion_submissions (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Only source = 'allowance' fulfillments decrement an entitlement's
-- remaining allowance -- 'paid_add_on' and 'courtesy' never do, so a
-- Platinum member can use all 4 included e-blasts and then buy a 5th
-- without the counter going negative. Reporting must total only
-- source = 'allowance' as "value delivered"; a paid purchase must never be
-- counted as chamber-given value in a renewal summary.
--
-- member_visible_summary is the only field ever safe to return from a
-- member-facing endpoint. internal_notes and staff_owner_email must never
-- appear there -- see promotion_submissions.admin_notes / mapSubmission() in
-- supabase/functions/perks/index.ts as the existing leak to not repeat.
comment on column public.benefit_fulfillments.member_visible_summary is
  'The only fulfillment field safe to return to a member-facing endpoint.';
comment on column public.benefit_fulfillments.internal_notes is
  'Staff-only. Never serialize this field in a member-facing response.';

create index if not exists benefit_fulfillments_entitlement_id_idx
  on public.benefit_fulfillments (entitlement_id);
create index if not exists benefit_fulfillments_status_idx
  on public.benefit_fulfillments (status);
create index if not exists benefit_fulfillments_source_idx
  on public.benefit_fulfillments (source);

create table if not exists public.member_activity_events (
  id uuid primary key default gen_random_uuid(),
  cm_id integer not null references public.chamber_members (cm_id) on delete cascade,
  event_type text not null,
  actor_type text not null check (actor_type in ('staff', 'member', 'system')),
  actor_email citext,
  occurred_at timestamptz not null default now(),
  related_fulfillment_id uuid references public.benefit_fulfillments (id),
  related_task_id uuid,
  visibility text not null default 'staff_only' check (visibility in ('member', 'staff_only')),
  member_summary text,
  internal_detail text,
  created_at timestamptz not null default now()
);

-- Use event_type = 'ad_hoc_marketing_support' (or similar) for delivered
-- work with no matching entitlement -- e.g. a one-off feature article.
-- Do not loosen benefit_fulfillments.entitlement_id to accommodate this;
-- that is what this table is for.
create index if not exists member_activity_events_cm_id_occurred_idx
  on public.member_activity_events (cm_id, occurred_at desc);

alter table public.benefit_fulfillments enable row level security;
revoke all on public.benefit_fulfillments from anon, authenticated;

alter table public.member_activity_events enable row level security;
revoke all on public.member_activity_events from anon, authenticated;
