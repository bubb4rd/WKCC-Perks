# Production Readiness & Roadmap

Status snapshot for launching WKCC Perks. Auth, deals/submissions/admin, and business logos are wired for live Supabase when `AppConfig.useMockAuth = false`. This doc lists remaining gaps — **do not treat setup guides alone as a launch checklist**.

Related setup docs:

- [MEMBER_AUTH_SETUP.md](MEMBER_AUTH_SETUP.md)
- [LIVE_PROMOTIONS_SETUP.md](LIVE_PROMOTIONS_SETUP.md)
- [GROWTHZONE_SETUP.md](GROWTHZONE_SETUP.md) (legacy; unused in current auth path)

---

## What’s already live

| Area | Status |
|------|--------|
| Member OTP auth (`member-auth`) | Live |
| Deals / submissions / admin perks (`perks`) | Live |
| Business catalog + logos (`GET businesses`, `POST company-logo`) | Live |
| Profile avatar upload → Storage + `chamber_members.logo_url` | Live |
| Business list / detail / Home partner chips use `BusinessLogoView` | Live |
| Notifications | **Still mock** (see below) |

---

## Critical (fix before launch)

### 1. Seed deals use mock `business_id`s

**Done (Jul 2026):** Removed live seed rows with `biz-001`…`biz-003` and stopped seeding them in [`20260718072807_live_promotions.sql`](supabase/migrations/20260718072807_live_promotions.sql). Cleanup migration: [`20260728185102_remove_mock_seed_deals.sql`](supabase/migrations/20260728185102_remove_mock_seed_deals.sql). Catalog content should come from admin create / approved submissions keyed to `chamber_members.cm_id`.

### 2. Deal imagery still uses Picsum

**Done:** Picsum `spotlightImageURL` removed; deal/home surfaces use `PerkPlaceholder` (and optional `image_url` when set).

### 3. No mid-session access-token refresh

**Done:** [`MemberSessionAccess`](Wilmette%20Kenilworth%20Perks/Core/Auth/MemberSessionAccess.swift) refreshes when expired or within 5 minutes of expiry; `PerksAPIClient` / `SupabaseBusinessService` / logo upload retry once after a forced refresh on 401. AuthManager syncs from Keychain via `memberSessionDidRefresh` / `memberSessionDidExpire`.

---

## Important (should address for a polished launch)

### 4. Live business catalog is sparse

**Approach (done path):** Do **not** enrich from ChamberMaster (list API has no street address / phone / website / category / about — only lat/long + logo URL). Members complete their own listing from Profile:

- Incomplete callout on Profile when logo / category / about / website / phone / address missing
- Tap Business row → edit app-owned fields (`category`, `short_description`, `website_url`, `phone`, `address`, `address_public`)
- Public directory hides address when `address_public` is false; Open in Maps still uses CM coordinates when present

**Remaining polish:** Category filters become useful as members save real categories; until then many listings may still show “Other”.

### 5. Notifications always mock

**Mitigated:** Notification bell is hidden when `useMockAuth = false` (live). Mock mode still shows the bell + `MockNotificationService`. A real notifications backend remains future work.

### 6. Membership tier always “Basic” in live auth

**Done:** App-owned `chamber_members.membership_type` imported from chamber listing CSV (`Not-For-Profit` → `Non-Profit`). `mapMember()` returns that tier; CM numeric `Level` (`"10"`) is not used for display. `sync-members` does not overwrite `membership_type`.

### 7. OTP `request-code` is not rate-limited

**Done:** Per-email cap of 5 codes / 15 minutes on `request-code` (still returns generic success; does not send). Verify attempts remain capped at `MAX_ATTEMPTS = 5`.

### 8. Member sync vs logos

`sync-members` upserts without `logo_url`, so **uploaded** logos should survive sync (good). It also does **not** re-apply ChamberMaster `raw.LogoUrl`, so CM logos only came from the one-time migration backfill.

**Action:** Decide policy: preserve uploads always; optionally refresh `logo_url` from `LogoUrl` only when `logo_url` is still an external CM URL (or null).

### 9. Deal detail editorial presentation

**Done:** Deal/perk detail editorial polish completed (layout, hierarchy, imagery, copy blocks, redemption).

### 10. Admin remove / archive promotions

**Done:** Soft-archive on `deals` (`archived_at` / `archived_by`); admin Archive/Restore in Manage Perks; member catalog and business active deals exclude archived.

---

## Feature roadmap (post-launch or next phase)

Product capabilities called out for tracking; not required to unblock first TestFlight if Critical items above are resolved, but plan capacity soon after.

### A. Member display-name rename requests

Members may see a mismatch between their real name and the name derived from ChamberMaster / `chamber_members` (e.g. business name used as person name).

**Proposed flow:**

1. Member submits a **rename request** in the app (requested first/last or display name + optional note)
2. Request lands in an admin queue (similar spirit to promotion submissions)
3. Admin **approves** or **denies**
4. On approve, app-facing profile name updates (store override on `app_profiles` or equivalent — do not blindly overwrite ChamberMaster sync source without a clear policy)

**Open decisions:** Whether approved names survive `sync-members`; whether company/business name can be requested separately from person display name.

### B. Redemption passport — “Use” action + usage tracking

Today redemption is largely presentational (show code / instructions). Add a clear **Use** (or equivalent) action on the redemption passport / redeem UI that:

- Records that the member redeemed/used the promotion (timestamp, member id, deal id)
- Supports basic analytics: use counts per perk, recent activity for admins
- Optionally limits or messages on re-use if product rules require it later

**Action:** Schema for redemption events (e.g. `deal_redemptions`), edge endpoint, passport UI button, and a lightweight admin/member history view as needed.

---

## Nice-to-have / ops

| Item | Notes |
|------|--------|
| Photo library privacy string | `PhotosPicker` usually needs none; add `NSPhotoLibraryUsageDescription` if App Review asks |
| Dead GrowthZone config | `REPLACE_WITH_PROJECT`, `UNUSED` client ID in `AppConfig` — clean up or gate behind `#if DEBUG` |
| Legacy `growthzone-auth` function | Still may exist remotely; unused by current app path |
| CORS `x-sync-secret` | Only matters if browsers call `sync-members` |
| Anon key in client | Expected for mobile; keep RLS/edge-only access; never ship `service_role` |
| Empty states | List empty states exist; sparse business About is the real UX gap |

---

## Suggested launch order

1. ~~Fix or remove mock-ID seed deals~~  
2. ~~Remove Picsum from production deal/home surfaces~~  
3. ~~Session refresh (or 401 retry)~~  
4. ~~Nail deal detail editorial presentation~~  
5. ~~Admin archive / remove promotions~~  
6. ~~Notifications: hide UI **or** build backend~~ (hidden in live; backend later)  
7. ~~Enrich business metadata **or** simplify empty UI~~ (member-owned profile edit)  
8. ~~Map membership tiers; rate-limit OTP request~~ (CSV-backed tiers + request-code throttle)  
9. ~~Confirm prod secrets and ops (below)~~ (verified 2026-07-29)  
10. App Store Connect listing + submit for review — see [`APP_STORE_SUBMIT.md`](APP_STORE_SUBMIT.md)  
11. **Next phase:** rename requests; redemption “Use” + usage tracking

---

## Pre-launch ops checklist

- [x] `useMockAuth = false` in the release build  
- [x] Supabase secrets set: `AUTH_JWT_SECRET`, `RESEND_API_KEY`, `AUTH_EMAIL_FROM`, `MEMBER_SYNC_SECRET` (if syncing), ChamberMaster keys if used  
  - Verified 2026-07-29 on project `wbzmpylhlsikgzpmfksl`. Removed prod `AUTH_DEBUG_RETURN_CODE` (must stay unset). ChamberMaster API keys not set — OK if member sync is not run from prod.  
- [x] `member-auth` and `perks` edge functions deployed (ACTIVE; `verify_jwt=false` as designed)  
- [x] Migrations applied (auth + live promotions + business logos / storage bucket + soft-archive + membership_type)  
- [x] At least one `app_profiles.is_chamber_admin = true` for chamber staff  
- [x] TestFlight with real chamber member emails (OTP delivery)  
- [x] Admin dry run: submit → approve → perk appears for members  
- [x] Admin dry run: archive/remove a live perk; confirm it disappears for members  
- [x] Logo upload dry run: Profile → appears on Businesses list / Home partners  
- [x] Deal detail visual/editorial review on device  
- [x] Confirm seed deals remapped or deleted — **done (mock seeds removed)**  
- [x] App Review demo account ready (OTP notes drafted for App Store Connect)  
- [ ] App Store assets, privacy policy / support URL as required — pack ready in [`APP_STORE_SUBMIT.md`](APP_STORE_SUBMIT.md); host privacy HTML then paste URLs in ASC  
- [ ] **Upload / submit blocked until Xcode 26+** (ASC requires iOS 26 SDK; local Xcode 16.4 archive succeeded but upload was rejected)  

---

## Out of scope (known, deferred)

- Perk/deal **image upload** (schema has `deals.image_url`; create/approve still writes `null`)  
- Full edit-business profile beyond member-owned listing fields (name/email still ChamberMaster; rename requests tracked under §A)  
- Realtime sync (app uses load-on-appear + pull-to-refresh)  
- Replacing ChamberMaster as source of truth for the member directory  
- Display-name rename requests (tracked under Feature roadmap §A — not built yet)  
- Redemption usage analytics / “Use” button (tracked under Feature roadmap §B — not built yet)  

---

## Document history

- Initial readiness pass after business logos (live upload + app-wide display). No implementation of the items above in that pass — tracking only.
- Added: deal detail editorial polish; admin archive/remove; member rename-request workflow; redemption passport “Use” + usage tracking.
- Closed critical §1–§3 and mitigated §5 (hide notifications in live): removed mock seed deals, Picsum already gone, mid-session token refresh + 401 retry.
- Closed §9 deal detail editorial polish.
- Closed §10 admin soft-archive for live promotions (DB + edge + Manage Perks UI).
- Closed §4 sparse catalog via member-owned business profile edit (not CM enrichment); ChamberMaster list payload has no street address.
- Closed §6/§7 (launch #8): CSV import of `membership_type` + websites; OTP `request-code` rate-limited (5 / 15m per email).
- Launch ops verified 2026-07-29: secrets (unset `AUTH_DEBUG_RETURN_CODE`), `member-auth`/`perks` ACTIVE, migrations applied, chamber admin present; dry runs + review account marked done. Remaining: App Store listing/submit ([`APP_STORE_SUBMIT.md`](APP_STORE_SUBMIT.md)).
- 2026-07-29: Created ASC submit pack + privacy HTML; Release archive OK; ASC upload rejected — need Xcode 26 / iOS 26 SDK.
