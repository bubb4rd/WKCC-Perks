# Push Notifications Setup (APNs)

WKCC Perks uses **push-only** notifications (no live in-app inbox). The Home bell remains mock-only when `AppConfig.useMockAuth = true`.

## What gets pushed

| Event | Recipients |
|-------|------------|
| Member submits a promotion | Chamber admins |
| Admin approves a submission | Submitter (approved) + all other members (new promotion) |
| Admin rejects a submission | Submitter |
| Admin creates a perk | All members |

## 1. Apple Developer

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
2. Select App ID **`WKCC.Wilmette-Kenilworth-Perks`** → enable **Push Notifications** → Save.
3. Under **Keys**, create an **Apple Push Notifications service (APNs)** key.
4. Download the `.p8` once. Note **Key ID** and your **Team ID**.

Do not commit the `.p8` file.

## 2. Xcode

- Entitlements: [`Wilmette Kenilworth Perks/Wilmette_Kenilworth_Perks.entitlements`](Wilmette%20Kenilworth%20Perks/Wilmette_Kenilworth_Perks.entitlements) (`aps-environment`). Automatic signing sets development vs production from the provisioning profile.
- Build and run on a **physical device** (Simulator does not receive remote pushes).

After the first live login, iOS shows the system notification permission prompt. Accept it so the device token can register.

## 3. Supabase secrets

### Wire secrets to Supabase

```bash
# From repo root (after downloading AuthKey_XXXXX.p8):
./supabase/scripts/setup-apns.sh ~/Downloads/AuthKey_XXXXX.p8 YOUR_KEY_ID
```

Or set manually:

```bash
supabase secrets set \
  APNS_KEY_ID="YOUR_KEY_ID" \
  APNS_TEAM_ID="87BJQUWN86" \
  APNS_BUNDLE_ID="WKCC.Wilmette-Kenilworth-Perks" \
  APNS_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXXX.p8)" \
  APNS_PRODUCTION="false"
```

- Use `APNS_PRODUCTION=false` for Debug / sandbox testing.
- Use `APNS_PRODUCTION=true` for TestFlight / App Store builds.
- Automatic signing maps `aps-environment` from the provisioning profile; keep the entitlements key present.

## 4. Migration + deploy

```bash
supabase db push
# or apply migration 20260805230000_device_push_tokens.sql

supabase functions deploy perks
```

## 5. Device test checklist

**Passed (2026-08-11):** Device push verified end-to-end (token registration + submit / approve / reject / admin-create).

Reference steps:

1. Sign in on a physical device (live auth). Allow notifications.
2. Confirm a row appears in `device_push_tokens` for your `member_id`.
3. **Submit** a promotion → admin device receives “New promotion submission”.
4. **Approve** → submitter gets “Promotion approved”; another member gets “New promotion”; submitter does **not** get the new-promotion push.
5. **Reject** a different submission → submitter gets “Promotion not approved”.
6. **Admin create perk** → members get “New promotion”.
7. Sign out → token removed (or cleared for that member).

Before TestFlight / App Store builds:

```bash
supabase secrets set APNS_PRODUCTION="true"
```

**Done (2026-08-11):** `APNS_PRODUCTION=true` is set for release / TestFlight. Use `false` again only when debugging with a local Debug install.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| No token in DB | Permission denied; not a physical device; still on mock auth |
| Push never arrives | `APNS_PRODUCTION` mismatches build (sandbox vs production); wrong Team/Key/Bundle |
| Edge logs `APNs secrets not configured` | Secrets not set; redeploy not required for secrets but confirm env |
| Edge logs `BadDeviceToken` | Token pruned automatically; re-register by relaunching signed-in app |
