-- The first Chambermate sync (2026-09-29) revealed 87 legacy ChamberMaster-only
-- chamber_members rows still marked status = '2' (active) that were never linked
-- via companymate_key -- 61 are exact-name duplicates of a company Chambermate just
-- resynced fresh under a new cm_id in the 9000000+ band, the other 26 simply aren't
-- in Chambermate's current directory at all. Verified before writing this migration:
-- none of the 87 have any active (non-archived) deals or an uploaded logo_url, so
-- there is no member-facing content to lose by deactivating them.
--
-- Chambermate is now the source of truth for "currently active" -- flip these to
-- 'dropped' so they stop counting/displaying as active members. Excludes the two
-- sentinel test accounts (cm_id -1 App Review Connect, cm_id 0 Bo Hubbard Software
-- Development), which are not Chambermate-sourced and must stay untouched.
update public.chamber_members
set status = 'dropped', synced_at = now()
where status = '2'
  and companymate_key is null
  and cm_id not in (-1, 0);
