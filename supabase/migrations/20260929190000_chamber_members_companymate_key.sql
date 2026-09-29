-- Chambermate migration: add companymate_key (opaque companyKey from Chambermate's
-- API) to chamber_members, and a dedicated id sequence for members that only ever
-- existed in Chambermate (no legacy ChamberMaster cm_id to reuse).
--
-- cm_id stays an integer surrogate key everywhere else in the schema (app_profiles,
-- app_sessions, membership_periods, benefit_entitlements, member_activity_events,
-- staff_tasks, leads) -- this migration does not touch any of those FKs.

alter table public.chamber_members
  add column if not exists companymate_key text;

create unique index if not exists chamber_members_companymate_key_idx
  on public.chamber_members (companymate_key)
  where companymate_key is not null;

-- New Chambermate-native members (no ChamberMaster history) get cm_id values from
-- this reserved band so they can never collide with legacy ChamberMaster numeric ids.
create sequence if not exists public.chamber_members_companymate_cm_id_seq
  start 9000000
  owned by public.chamber_members.cm_id;

-- Lets the member-auth edge function (which only has table/rpc access via
-- supabase-js, not raw SQL) reserve a block of fresh cm_id values in one round trip
-- when Chambermate returns companies with no existing companymate_key match.
create or replace function public.next_companymate_cm_ids(n integer)
returns setof integer
language sql
as $$
  select nextval('public.chamber_members_companymate_cm_id_seq')::integer
  from generate_series(1, n);
$$;

-- One-time backfill: attach companymate_key to the 140 existing chamber_members rows
-- we could confidently match to a Chambermate company (139 by exact company name,
-- 1 by contact email) out of 149 previously-Active ChamberMaster members. See the
-- chambermaster_to_chambermate_migration project memory for the full match-rate
-- analysis. Matched on chamber_members.name (not display_name), since that's the
-- field populated from ChamberMaster's own "Name" field, same as the old export's
-- "Company Name" column used to build this crosswalk.
--
-- The email-matched rows have been removed from this file because the repo is
-- public and they held member contact emails. Those rows were applied when this
-- migration ran in production on 2026-09-29; a fresh database skips them.
--
-- 9 members were deliberately left out of this backfill and need manual review:
--   - 7 with no name or email match at all: Irving's for Red Hot Lovers,
--     Wilmette Park District, Benedetto Dental, Giggles & Giraffes,
--     Sophia's Estate Sales, J.P Morgan, Campfire Sauna and Social
--   - 2 that both resolved to the same Chambermate companyKey (likely consolidated
--     into one Chambermate listing, needs a human decision on which -- or whether both
--     -- should carry the mapping): Torino Ramen, ICHI by Torino
with crosswalk (match_field, match_value, companykey) as (
  values
  ('name', 'Chalet', 'x_yB|yao4IhBXPB46cB7Vg2'),
  ('name', 'Chantilly Lace Lingerie, Inc.', 'G_DZ_oCV|SSsRQk1dje41w2'),
  ('name', 'Christensen Animal Hospital', '|AJ9gdQDLTM|BvHUv|jyTw2'),
  ('name', 'Convito Cafe & Market', 'pzyfzUHoXkLyArmTKksmAQ2'),
  ('name', 'Daniel''s Auto Body', '4zswUbCJpCcl_T3blgPCow2'),
  ('name', 'de Giulio Design', 'bqkYMvEcT5Mh4WV8GhwTYw2'),
  ('name', 'Byline Bank', 'Akeouv0NY3Uyh39cXbsX|g2'),
  ('name', 'Fuenfer Jewelers', 'Td8NirRU_C9E8JWoisOLAA2'),
  ('name', 'Green Bay Animal Hospital', 'ScWvu6Uhtnj3b1llxioJVw2'),
  ('name', 'Hanig''s Footwear', 'EMKghjVh3R0guuGnWznqhQ2'),
  ('name', 'Illinois Bone & Joint Institute - Wilmette', 'w910ZCEXs3W3_V1CANeLVQ2'),
  ('name', 'Northshore Automotive', 'rdPAW6mKtauD65dOoJyh0g2'),
  ('name', 'Plaza Orthodontics', 's|p0MgUTaQEhmMPoJRUB_A2'),
  ('name', 'F.J. Kerrigan Plumbing Co.', 'j9tH6My99yJSfBNVaDz1uQ2'),
  ('name', 'Lambrecht''s Jewelers Inc.', '5jzLNMreIwfrHD5Unluf7g2'),
  ('name', 'Michigan Shores Club', 'znxozB7kRFKLbpleY68pcA2'),
  ('name', 'Mid-Central Printing and Mailing', 'lFEZB74amTdLsLz7mrk58A2'),
  ('name', 'New Vision - Optical Boutique', 'ZG4ORoKWV_rDZJEyjgGyfA2'),
  ('name', 'Pediatric Associates of the North Shore', '33t22SO8GX46O_FVraK99w2'),
  ('name', 'Plaza del Lago', '_vAbwByO6LP7YetTmlQTaQ2'),
  ('name', 'International Bank of Chicago', '||B96syrae0pjEZk6pplRw2'),
  ('name', 'Regina Dominican High School', '|0pCR3_bd5pGS8_xwLCI0Q2'),
  ('name', 'Ridgeview Grill', 'Ex1PAkn1yhtC7HBG_hxhGA2'),
  ('name', 'Woman''s Club of Wilmette', 'hrKGFDbz4Rhs4uJlAc9r1w2'),
  ('name', 'Shawnee  Service Garage', 'F2FIbEZAcpw6No2VK9RwPA2'),
  ('name', 'Sweet''s Heating & Air Conditioning', 'I|DuJEcJ2qYx9JfJ8vTLFg2'),
  ('name', 'Terry Animal Hospital', 'VmwI2wIRe6rfayHKK7cgNg2'),
  ('name', 'Vestor Realty Consultants, Inc.', '0_Av69RAyNFjLE3I7WQQDA2'),
  ('name', 'Village of Wilmette', 'OStH0|I9FUZvTYkcY0tUIQ2'),
  ('name', 'Wilmette Auto Body Rebuilders', '5YRJyhI5dCqbahHjCEsjjg2'),
  ('name', 'Wilmette Bicycle & Sports Shop', '8pEccgY|DLsnc12WTHCKQA2'),
  ('name', 'Wilmette/Kenilworth Chamber of Commerce', 'QLM6ffBLruGsNUUnHU3F6A2'),
  ('name', 'Wilmette History Museum', 'h30006fuDjrBXhRwf7Kw|Q2'),
  ('name', 'Wilmette Lucke Plumbing, Inc.', 'C81mIs8P0jBI4PSYRxRtVA2'),
  ('name', 'Wilmette Public Library', '59pozx8P79EeU0NuqE4RYg2'),
  ('name', 'Wilmette Theatre', 'uJteMm4t3TCpbmoxkODoyA2'),
  ('name', 'greenmanIT, Inc.', 'gHxzBjosKrEyalRnHuY7YQ2'),
  ('name', 'Wilmette Maids', '3Q87W2n3IxQ1frzi0TZEUg2'),
  ('name', 'North Shore Community Bank', 'sF0eqCJwtl7xo8xvFGfBcQ2'),
  ('name', 'A Center for Acupuncture', '6RpubDSrsDw|kTxB6Py0Rw2'),
  ('name', 'Shore Line Place', 'm1XDGtAw3auI5tEjkZwOXA2'),
  ('name', 'Ronald Knox Montessori School', 'e2qMwB8AJcYHdizoSETEGQ2'),
  ('name', 'Pediatric Dentistry Specialists P.C.-Dr. Angela Kalb', 'SOfGalbImVwsL7jKY8_RLA2'),
  ('name', 'Eggemeyer & Graham Orthodontics, Ltd', 'RKapgiFgexTsxy3E8qsynQ2'),
  ('name', 'Bottle Shop, The', 'OvzjNnwGX4FTQWTGu3vQTg2'),
  ('name', 'Baker Demonstration School', '14Z0s48LN|CXYFtbZI5sQQ2'),
  ('name', 'Rotary Club of Wilmette', 'jF3Pa_WG84XUqR|5_rVAqw2'),
  ('name', 'Litigators Incorporated, P.C.', 'FK4ycDjGu7T9Sqq27JdlxA2'),
  ('name', 'Todd Markman, State Farm Insurance Agency', 'wz3jp4UV97xtgLfP|W0H5A2'),
  ('name', 'Go Green Wilmette', 'wwEEP|A7DoQYZxD2ERegRA2'),
  ('name', 'Millen Hardware', 'g|481_3yaPBcKvVR5N6RUQ2'),
  ('name', 'William Harris Lee & Co., Inc.', 'xvFmfdbLqBgUE0btmux8CQ2'),
  ('name', 'Chabad Center for Jewish Life & Learning', 'JkuGAJP1uw5Kl9SgLC6Oyw2'),
  ('name', 'Wilmette Foot & Ankle Clinic', 'zxU5BbUMxPkGjHqa0RMWmA2'),
  ('name', 'North Shore Music', '6ad23pOiABb2Zshd02ne0Q2'),
  ('name', 'Music Theater Works', '4icFp|nRPHd5wTlvtSwsTw2'),
  ('name', 'SNAP Dance', '_uT82HkxoCRs8eM8eC0Gjg2'),
  ('name', 'Yellow Bird Stationery, Invitations & Gifts', 'W_vFfGCNmPDvysFnP30jYQ2'),
  ('name', 'Residence Inn by Marriott Wilmette', 'Q|r28zO3NcAn8NWjK|iN4A2'),
  ('name', 'Law Offices of Charles E. Hutchinson, LLC', 'A2UD|1fDbWhRMJUEd5E70Q2'),
  ('name', 'Hubba-Hubba', 'F0aZIGPAgEJLc1BJrRSvlQ2'),
  ('name', 'Bella Tile & Stone, Wilmette', 'gX8lWpN4NuBFbtaAKzzM4A2'),
  ('name', 'North Shore Associates in Gyne/OB, S.C.', 'vafkiADe2cPqGxrTvG8mAQ2'),
  ('name', 'Banner Literacy', 'XPLODw0tb2a3d08U3fy0kg2'),
  ('name', 'St. Roger Abbey Organic French Gourmet Patisserie', 'FelitaBc_iia2qaHTEQi7w2'),
  ('name', 'Smilin Dental', 'zYuIqPlJUT_QIFoVhIqx1Q2'),
  ('name', 'A. Perry Homes', 's19bMtZkSzWQANOklBEnuw2'),
  ('name', 'Napolita Pizzeria & Wine Bar', '9p5lcm1GXK|QUJH9v2KrFg2'),
  ('name', 'Red Spade Environments, LLC', 'gGXtv0w_bQoEzDZ3OSpSTA2'),
  ('name', 'Efficiency Marketing & Publicity', 'EbthVoPzUwD|LYZyiShONw2'),
  ('name', 'A.S.K. Marketing Group, Inc.', '5vQscyqqpQzRINXaYyN5Zw2'),
  ('name', 'Residences of Wilmette LLC, The', 'fkkBbHqhLxNnOumDjfqtYQ2'),
  ('name', 'Oto Float', 'fJ4cGx86VCm5q0eBe2cAJw2'),
  ('name', 'Light On Anxiety Treatment Centers', '6AmCRdmKJF1PMc999BIJKA2'),
  ('name', 'Secure Futures Ltd.', 'rhtnCD8OnWs4J_6BSSqFtA2'),
  ('name', 'Bella Cosa Jewelers', '33VKlJ8JdI4iAPgoH55cHw2'),
  ('name', 'YWCA Shop for Good', 'kBjtR6riiyFFKDh9PRSMRQ2'),
  ('name', 'OsteoStrong', 'ttAZG0JeCDchnEIMG1dbnw2'),
  ('name', 'Savant Wealth Management', 'oElvbk3R7A0ami|S1cWcpQ2'),
  ('name', 'Big City Optical LLC', 'YS0mEdSCHFPskiXljr8U7g2'),
  ('name', 'Pescadero Seafood & Oyster Bar', 'JYg5E_1e0nA|TMuGz7|tGA2'),
  ('name', 'Lapels Dry Cleaning', '5BIce2IA9N68iQOedVB9SQ2'),
  ('name', 'Optima, Inc.', 'IszwioiIMe581IMrHdwW0A2'),
  ('name', 'Canning & Canning', 'O1DqJNk_v45ZvA0q7EqoTA2'),
  ('name', 'Sophia Steak', 'yabmnkXrF9tB6QfIlX1bjg2'),
  ('name', 'Bleachers Sports, Music & Framing', '7xIFaE4lCoIAjb4sOcCcZg2'),
  ('name', 'Artis Senior Living - Wilmette', '1IzMuxNz9RvMXSQGI21Ndg2'),
  ('name', 'One Magnificent Medspa', 'AdsZIlL7B12800GBPN4ymg2'),
  ('name', 'Optimum Fitness Formula 7', 'O1yidYJB0zyXBWeTdZNe_A2'),
  ('name', 'Our Place of New Trier', 'qt6r|r1ITf|oG_DiUdFSGQ2'),
  ('name', 'Nathan Sulack State Farm Insurance', '5UYKxjuFNLlm_JDl4a0R6g2'),
  ('name', 'Actors Training Center Inc.', 'EKo32QO4EDTNT5f|ntHbsg2'),
  ('name', 'Buck Russell''s Bakery & Sandwich Shop', 'XnokhP7YP5aosU8a2M0iPg2'),
  ('name', 'North Shore Exchange NFP', 'MilLvz_TuDOc7_hmo_srJg2'),
  ('name', 'Loyola Academy', 'rZRKXOyavEFo|apI_WC7xQ2'),
  ('name', 'Trinity Wilmette', 'Z9PhUulONb5viJvDI5RQcA2'),
  ('name', 'League of Women Voters Wilmette', 'Ks5b4AKDtV42TFin9_KW3A2'),
  ('name', 'Youth Choral Theater of Chicago', 'zwbwAKJ7iBM1UHU2pMAZhA2'),
  ('name', 'Valley Lodge Tavern', 'GhEVVFN8w3lDaB9Mc3uE9g2'),
  ('name', 'Vibrato Boutique', 'wBU2r0XL_YwnmSkHItr1bw2'),
  ('name', 'The Wayfair Store', 'JX5UfaB|yZtmtH5kw3jXgQ2'),
  ('name', 'FocalPoint Business Leadership Coaching', 'FruoKgZC08blQwwA4AYnvg2'),
  ('name', 'Patrician Gallery and Gatherings', 'a5Era_g5dtmtDi6ru6iyOw2'),
  ('name', 'Pro Self Storage', '4viv7tIttvspMvs5IA4IUw2'),
  ('name', 'Club Wilmette', 'h_iYPfqsN|1lQbSMRu56cA2'),
  ('name', 'North Shore Garage Doors', 'B2pQGATeJUoIEhPMLG1xaA2'),
  ('name', 'FRÍO Gelato', 'TLrSw11FxyPNyhe|ohtYQQ2'),
  ('name', 'EvaDean''s Bakery & Cafe', 'vc0MEu|yvgokujuyU2vDXg2'),
  ('name', 'Craig Scott Opticians', 'cj4sWbqZ_OaoOjuZDpIlHA2'),
  ('name', 'MazMez Middle Eastern Grill', '3iGsMYtinsPrnAn5qh1Oug2'),
  ('name', 'Edens Plaza', 'yPqq04PZSLtwqBvOmdvImg2'),
  ('name', 'Big Blue Swim School', 'Mrofd3ZBPdunbk39eCYZLQ2'),
  ('name', 'DDK Kitchen Design Group', 'ZGyTFp|UD6d0TKhjG_B2nQ2'),
  ('name', 'Nicole Jones Photography', 'kQ7nbluIOTD3YJAvziPACQ2'),
  ('name', 'The UPS Store Wilmette Downtown', 'hWIfnk6osvaGaZe|NerbAw2'),
  ('name', 'Uncharted', 'Lz9hZDnmw5vlUkeW5G98yg2'),
  ('name', 'Egg Harbor Cafe', 'q6zv9TNkDFmpZYotJmBrQA2'),
  ('name', 'The Strategy Studio LLC', 'dcnaxDJhHGdwMW2N2xmrew2'),
  ('name', 'Small Cheval', 'sqplnyB9zmuArdCtZ4EJkw2'),
  ('name', 'Forefront Dermatology', 'U0rAt62BmcqpWMlhq8s04w2'),
  ('name', 'June Children''s Shop', 'lco9T|ek095Uedh2dqAAUw2'),
  ('name', 'Linden Jewelry & Estate', 'ymcKRY8FCFkZvdnE0ZcZnw2'),
  ('name', 'Nine 4 Nine Architectural Design', '_t6pq803gNuY_kICtLrDHA2'),
  ('name', 'Fred Astaire Dance Studios - Wilmette', '7XNtFNbTanzIETtQrB_FFQ2'),
  ('name', 'Talia', 'fAiFVAWKfEoi3y5DnSTfcg2'),
  ('name', 'Heart Certified Auto Care', 'upZOhgqBHE_|cEFZ|8odsw2'),
  ('name', 'Haven Youth and Family Services', 'tMozj2U1EuW7zIbO8WTCDQ2'),
  ('name', 'Tell Your Story', '_ZU23cJ8X|Hxlyr8btmhXA2'),
  ('name', 'Blue Rose Studio', 'NtI6Eo_O_7nynQ9xdEojmg2'),
  ('name', 'US Storage Centers', 'Oyr8xTSNdctAizltvtAOKg2'),
  ('name', 'ReSource Wellness', 'grwoe416Vhh_325yNn4rEg2'),
  ('name', 'The Mette', 'Wro|cPiuTiiKqtIvJMJ_Nw2'),
  ('name', 'Wilmette Bowling Center', 'jwr_dl4Ukva8VCX0tJc5AQ2'),
  ('name', 'Crosstown Baseball Academy', 'Tex6tLJPLyW7RUFzowg_ug2'),
  ('name', 'Interactive Speech Associates, Inc', 'GqDunvqRga8V8Q7iizSO4Q2'),
  ('name', 'the reform method', 'yMFnJoxVxvU0ezqAPtX|DQ2'),
  ('name', 'Village Follies', 'g|gfX99p|dcS7hnkwix5rQ2'),
  ('name', 'WRBS Principal LLC', 'e2sin3en6n1vbcrJa0p96A2')
)
update public.chamber_members cm
set companymate_key = cw.companykey
from crosswalk cw
where cm.companymate_key is null
  and (
    (cw.match_field = 'name' and lower(trim(cm.name)) = lower(trim(cw.match_value)))
    or (cw.match_field = 'email' and cm.email = cw.match_value::citext)
  );
