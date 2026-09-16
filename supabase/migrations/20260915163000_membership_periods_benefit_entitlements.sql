-- Member Success Hub, Phase 1: benefit periods + the entitlement engine.
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.membership_periods (
  id uuid primary key default gen_random_uuid(),
  cm_id integer references public.chamber_members (cm_id) on delete cascade,
  period_start date not null,
  period_end date not null,
  created_at timestamptz not null default now(),
  constraint membership_periods_period_order_chk check (period_end > period_start)
);

-- cm_id null = the chamber-wide default period (Phase 0 decision: kept for
-- now rather than per-member dues-anniversary periods -- see Benefit Ledger
-- O3/R10). A member-specific row overrides the default for that member only.
create index if not exists membership_periods_cm_id_idx
  on public.membership_periods (cm_id);

create unique index if not exists membership_periods_default_unique_idx
  on public.membership_periods (period_start, period_end)
  where cm_id is null;

insert into public.membership_periods (cm_id, period_start, period_end)
values (null, '2026-01-01', '2026-12-31')
on conflict (period_start, period_end) where cm_id is null do nothing;

-- Resolves the active benefit period for a member on a given date: a
-- member-specific override first, then the chamber-wide default, then a
-- plain calendar-year fallback so the system always has *a* period even
-- before any row is seeded for that year.
create or replace function public.resolve_membership_period(
  p_cm_id integer,
  p_on date default current_date
)
returns table (period_start date, period_end date)
language sql
stable
as $$
  select mp.period_start, mp.period_end
  from public.membership_periods mp
  where mp.cm_id = p_cm_id
    and p_on between mp.period_start and mp.period_end
  union all
  select mp.period_start, mp.period_end
  from public.membership_periods mp
  where mp.cm_id is null
    and p_on between mp.period_start and mp.period_end
    and not exists (
      select 1 from public.membership_periods x
      where x.cm_id = p_cm_id and p_on between x.period_start and x.period_end
    )
  union all
  select date_trunc('year', p_on)::date,
         (date_trunc('year', p_on) + interval '1 year' - interval '1 day')::date
  where not exists (
    select 1 from public.membership_periods x
    where p_on between x.period_start and x.period_end
      and (x.cm_id = p_cm_id or x.cm_id is null)
  )
  limit 1;
$$;

create table if not exists public.benefit_entitlements (
  id uuid primary key default gen_random_uuid(),
  cm_id integer not null references public.chamber_members (cm_id) on delete cascade,
  benefit_code text not null references public.benefit_catalog (code),
  tier_code_snapshot text not null references public.membership_tiers (code),
  period_start date not null,
  period_end date not null,
  allowance_quantity integer,
  a_la_carte_price_cents integer,
  source text not null default 'rule' check (source in ('rule', 'manual_exception')),
  created_by citext,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists benefit_entitlements_member_benefit_period_idx
  on public.benefit_entitlements (cm_id, benefit_code, period_start);

create index if not exists benefit_entitlements_cm_id_idx
  on public.benefit_entitlements (cm_id);

-- Materializes a member's entitlements for a benefit period from
-- tier_benefit_rules. Idempotent (on conflict do nothing) -- safe to re-run
-- for backfills. Members whose tier is not entitlement-bearing (Municipality,
-- Chamber of Commerce -- see membership_tiers) get zero rows, by design, not
-- as a bug. Rows with source = 'manual_exception' are inserted separately by
-- staff tooling and are never touched or overwritten by this function.
create or replace function public.generate_entitlements(
  p_cm_id integer,
  p_period_start date default null,
  p_period_end date default null
)
returns integer
language plpgsql
as $$
declare
  v_tier_code text;
  v_period_start date;
  v_period_end date;
  v_inserted integer := 0;
begin
  select public.membership_tier_code(cm.membership_type)
    into v_tier_code
  from public.chamber_members cm
  where cm.cm_id = p_cm_id;

  if v_tier_code is null then
    raise exception 'Unknown member: %', p_cm_id;
  end if;

  if not exists (
    select 1 from public.membership_tiers mt
    where mt.code = v_tier_code and mt.is_entitlement_bearing
  ) then
    return 0;
  end if;

  if p_period_start is null or p_period_end is null then
    select rp.period_start, rp.period_end
      into v_period_start, v_period_end
    from public.resolve_membership_period(p_cm_id) rp;
  else
    v_period_start := p_period_start;
    v_period_end := p_period_end;
  end if;

  insert into public.benefit_entitlements
    (cm_id, benefit_code, tier_code_snapshot, period_start, period_end,
     allowance_quantity, a_la_carte_price_cents, source)
  select
    p_cm_id,
    tbr.benefit_code,
    v_tier_code,
    v_period_start,
    v_period_end,
    tbr.allowance_quantity,
    tbr.a_la_carte_price_cents,
    'rule'
  from public.tier_benefit_rules tbr
  where tbr.tier_code = v_tier_code
    and v_period_start >= tbr.effective_from
    and (tbr.effective_to is null or v_period_start <= tbr.effective_to)
  on conflict (cm_id, benefit_code, period_start) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

alter table public.membership_periods enable row level security;
revoke all on public.membership_periods from anon, authenticated;

alter table public.benefit_entitlements enable row level security;
revoke all on public.benefit_entitlements from anon, authenticated;
