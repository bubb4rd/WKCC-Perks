-- Member Success Hub, Phase 1: benefit catalog + tier entitlement rules.
-- Seed data resolved from the 2025 WKCC Membership Benefits sheet and the
-- 2026 mid-year update; see the WKCC Benefit Ledger for the full register of
-- discrepancies and how each was resolved (R1-R10; O4-O6 deferred).
-- Edge functions use service role; direct client access is revoked.

create table if not exists public.benefit_catalog (
  code text primary key,
  name text not null,
  category text not null,
  member_facing_description text not null default '',
  staff_instructions text not null default '',
  tracking_mode text not null check (tracking_mode in (
    'passive_continuous',  -- always on; nothing to fulfill or track
    'staff_activated',     -- staff mark it delivered
    'member_requested'     -- member asks, staff fulfills
  )),
  is_active boolean not null default true,
  source_doc text not null default 'both'
    check (source_doc in ('2025_tier_sheet', '2026_update', 'both')),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

insert into public.benefit_catalog (code, name, category, tracking_mode, source_doc, sort_order)
values
  ('recognition_membership_validation', 'Instant Recognition and Validation of Your Business', 'Recognition', 'passive_continuous', 'both', 1),
  ('advocacy_village_representation', 'Representation at Village and Chamber Meetings', 'Advocacy', 'passive_continuous', 'both', 2),
  ('advocacy_regulatory_updates', 'State and Local Business Regulations and Updates', 'Advocacy', 'passive_continuous', 'both', 3),
  ('advocacy_hot_deals_job_postings', 'Hot Deals and Job Postings', 'Advocacy', 'member_requested', 'both', 4),
  ('directory_online_listing', 'Searchable Online Directory Listing with Website Link', 'Directory', 'passive_continuous', 'both', 5),
  ('directory_event_calendar_posting', 'Post Events on Chamber Website Calendar', 'Directory', 'member_requested', 'both', 6),
  ('community_guide_listing', 'Community Guide Listing (print + online)', 'Directory', 'staff_activated', 'both', 7),
  ('event_sponsorship_opportunities', 'Event Sponsorship and Volunteer Opportunities', 'Marketing', 'member_requested', 'both', 8),
  ('social_media_promotion', 'Social Media Promotion (Facebook and Instagram)', 'Marketing', 'passive_continuous', 'both', 9),
  ('networking_event_access', 'Access to Networking Events', 'Connections', 'passive_continuous', 'both', 10),
  ('targeted_referrals', 'Targeted Referrals and Connections from Chamber Team', 'Connections', 'staff_activated', 'both', 11),
  ('welcome_bag_item', 'One Item in "Love Local" Welcome Bag', 'Connections', 'member_requested', 'both', 12),
  ('new_resident_list', 'Monthly New Resident List', 'Connections', 'staff_activated', 'both', 13),
  ('promotional_eblast', 'Dedicated Promotional E-Blast', 'Marketing', 'member_requested', 'both', 14),
  ('community_guide_recognition', 'Name/Logo Recognition in Community Guide', 'Enhanced Listing', 'staff_activated', '2025_tier_sheet', 15),
  ('website_business_presence', 'Business Directory Page and Website Visibility', 'Enhanced Listing', 'staff_activated', '2025_tier_sheet', 16),
  ('homepage_clickthru_listing', 'Click-Through Business Name on Site Homepage', 'Enhanced Listing', 'staff_activated', '2025_tier_sheet', 17),
  ('additional_category_listing', 'Additional Business Category Listing', 'Enhanced Listing', 'member_requested', '2025_tier_sheet', 18),
  ('platinum_exclusive_placements', 'Signature Placements (Event Signage + Email Footer Logo)', 'Enhanced Listing', 'staff_activated', '2025_tier_sheet', 19),
  ('flagship_event_visibility', 'Name/Logo Visibility at All Flagship Events', 'Visibility', 'staff_activated', '2025_tier_sheet', 20),
  ('newsletter_visibility', 'Name/Logo Visibility in Newsletter', 'Visibility', 'staff_activated', 'both', 21),
  ('membership_minutes_submission', 'Monday Membership Minutes Submission', 'Communications', 'member_requested', '2026_update', 22),
  ('member_directory_access', 'Member Directory and Member List Access', 'Directory', 'passive_continuous', 'both', 23)
on conflict (code) do nothing;

-- additional_category_listing is not fulfillable in-app today (the app
-- stores a single category per business) -- tracked separately as GitHub
-- issues #4/#5/#6 in bubb4rd/WKCC-Perks. Staff track it manually until that
-- ships; the catalog row and tier rules below are correct regardless.

create table if not exists public.tier_benefit_rules (
  id uuid primary key default gen_random_uuid(),
  tier_code text not null references public.membership_tiers (code),
  benefit_code text not null references public.benefit_catalog (code),
  allowance_quantity integer,
  cadence text not null default 'continuous'
    check (cadence in ('continuous', 'unlimited', 'weekly', 'monthly', 'per_benefit_year')),
  a_la_carte_price_cents integer,
  conditions jsonb not null default '{}'::jsonb,
  effective_from date not null default '2026-01-01',
  effective_to date,
  created_at timestamptz not null default now()
);

-- allowance_quantity null = unlimited within the benefit (continuous/unlimited
-- cadence). allowance_quantity = 0 with a_la_carte_price_cents set = not
-- included, purchasable a-la-carte (see promotional_eblast for Basic/NFP).
-- No row at all for a (tier, benefit) pair = not offered to that tier --
-- never conflate "0 allowance" with "no row."
create unique index if not exists tier_benefit_rules_tier_benefit_from_idx
  on public.tier_benefit_rules (tier_code, benefit_code, effective_from);

-- Benefits included, unquantified, for all five dues-bearing tiers.
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence, conditions)
select t.code, b.code, null, case b.code
    when 'advocacy_hot_deals_job_postings' then 'unlimited'
    when 'directory_event_calendar_posting' then 'unlimited'
    when 'community_guide_listing' then 'per_benefit_year'
    when 'event_sponsorship_opportunities' then 'unlimited'
    when 'targeted_referrals' then 'unlimited'
    when 'membership_minutes_submission' then 'weekly'
    else 'continuous'
  end,
  case b.code
    when 'membership_minutes_submission' then '{"submission_deadline_days_before": 7}'::jsonb
    else '{}'::jsonb
  end
from public.membership_tiers t
cross join public.benefit_catalog b
where t.code in ('platinum', 'gold', 'silver', 'basic', 'nfp')
  and b.code in (
    'recognition_membership_validation',
    'advocacy_village_representation',
    'advocacy_regulatory_updates',
    'advocacy_hot_deals_job_postings',
    'directory_online_listing',
    'directory_event_calendar_posting',
    'community_guide_listing',
    'event_sponsorship_opportunities',
    'social_media_promotion',
    'networking_event_access',
    'targeted_referrals',
    'membership_minutes_submission',
    'member_directory_access'
  )
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Welcome-bag item: Platinum, Gold, Silver (2026 update; supersedes the 2025
-- sheet's Platinum/Gold/NFP -- see Benefit Ledger R1).
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence)
values
  ('platinum', 'welcome_bag_item', 1, 'per_benefit_year'),
  ('gold', 'welcome_bag_item', 1, 'per_benefit_year'),
  ('silver', 'welcome_bag_item', 1, 'per_benefit_year')
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- New resident list: Platinum, Gold only (2026 update; supersedes the 2025
-- sheet's Platinum/Gold/NFP -- see Benefit Ledger R2).
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence)
values
  ('platinum', 'new_resident_list', null, 'monthly'),
  ('gold', 'new_resident_list', null, 'monthly')
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Promotional e-blast: Platinum 4 / Gold 2 / Silver 1 included per benefit
-- year; Basic and NFP get zero included but may purchase at $150 each
-- (Benefit Ledger R5). A row still exists for Basic/NFP -- "purchasable but
-- not included" is a different state from "not offered."
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence, a_la_carte_price_cents)
values
  ('platinum', 'promotional_eblast', 4, 'per_benefit_year', 15000),
  ('gold', 'promotional_eblast', 2, 'per_benefit_year', 15000),
  ('silver', 'promotional_eblast', 1, 'per_benefit_year', 15000),
  ('basic', 'promotional_eblast', 0, 'per_benefit_year', 15000),
  ('nfp', 'promotional_eblast', 0, 'per_benefit_year', 15000)
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Community Guide recognition: Platinum/Gold get a logo, Silver name only
-- (merged with the former duplicate "Visibility" line item -- Benefit
-- Ledger R8/O1).
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence, conditions)
values
  ('platinum', 'community_guide_recognition', null, 'per_benefit_year', '{"display": "logo"}'::jsonb),
  ('gold', 'community_guide_recognition', null, 'per_benefit_year', '{"display": "logo"}'::jsonb),
  ('silver', 'community_guide_recognition', null, 'per_benefit_year', '{"display": "name_only"}'::jsonb)
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Website business presence: Platinum gets a featured/prominent page, Gold a
-- standard page; Silver's logo inclusion is undocumented in both source
-- sheets and deferred (Benefit Ledger O4) -- default to "standard" until
-- WKCC rules otherwise. Merged with the former duplicate "on Chamber
-- website" Visibility line (R8/O1).
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence, conditions)
values
  ('platinum', 'website_business_presence', null, 'per_benefit_year', '{"prominence": "featured"}'::jsonb),
  ('gold', 'website_business_presence', null, 'per_benefit_year', '{"prominence": "standard"}'::jsonb),
  ('silver', 'website_business_presence', null, 'per_benefit_year', '{"prominence": "standard", "logo_deferred": true}'::jsonb)
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Homepage click-through: Platinum, Gold only, both with logo.
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence, conditions)
values
  ('platinum', 'homepage_clickthru_listing', null, 'per_benefit_year', '{"display": "logo"}'::jsonb),
  ('gold', 'homepage_clickthru_listing', null, 'per_benefit_year', '{"display": "logo"}'::jsonb)
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Additional category listing: Platinum 2 extra / Gold 1 / Silver 1. Not
-- buildable in-app until GitHub issues #4/#5/#6 ship (Benefit Ledger R9).
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence)
values
  ('platinum', 'additional_category_listing', 2, 'per_benefit_year'),
  ('gold', 'additional_category_listing', 1, 'per_benefit_year'),
  ('silver', 'additional_category_listing', 1, 'per_benefit_year')
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Platinum-exclusive placements (event signage + email footer logo): merged,
-- both share identical Platinum-only tier scope (Benefit Ledger R8/O1).
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence)
values
  ('platinum', 'platinum_exclusive_placements', null, 'per_benefit_year')
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Flagship event visibility: Platinum (logo), Gold (name vs. logo
-- undocumented in both sheets -- Benefit Ledger O5, deferred; default to
-- name-only until WKCC rules otherwise).
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence, conditions)
values
  ('platinum', 'flagship_event_visibility', null, 'per_benefit_year', '{"display": "logo"}'::jsonb),
  ('gold', 'flagship_event_visibility', null, 'per_benefit_year', '{"display": "name_only", "display_deferred": true}'::jsonb)
on conflict (tier_code, benefit_code, effective_from) do nothing;

-- Newsletter visibility: Platinum, Gold only. Cadence updated to weekly per
-- the 2026 "Monday Membership Minutes" update (Benefit Ledger R4).
insert into public.tier_benefit_rules (tier_code, benefit_code, allowance_quantity, cadence)
values
  ('platinum', 'newsletter_visibility', null, 'weekly'),
  ('gold', 'newsletter_visibility', null, 'weekly')
on conflict (tier_code, benefit_code, effective_from) do nothing;

alter table public.benefit_catalog enable row level security;
revoke all on public.benefit_catalog from anon, authenticated;

alter table public.tier_benefit_rules enable row level security;
revoke all on public.tier_benefit_rules from anon, authenticated;
