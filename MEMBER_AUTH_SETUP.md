# Member Auth Setup

WKCC Perks uses **app-owned email OTP auth**. ChamberMaster is the membership data source, not the identity provider.

## Architecture

1. iOS app collects membership email and a 6-digit code
2. Supabase `member-auth` edge function verifies eligibility against `chamber_members`
3. Eligible members have ChamberMaster `Status = 2`, a non-empty email, and no `DisableLogin` flag
4. ChamberMaster API key stays on the server only (`X-ApiKey`)

## Database

Apply the migration:

```bash
supabase db push
# or locally:
supabase migration up
```

Migration: [`supabase/migrations/20260710162200_chamber_members_auth.sql`](supabase/migrations/20260710162200_chamber_members_auth.sql)

Tables:

- `chamber_members` — mirrored MemberResource records (seeded from the active-members export)
- `login_codes` — hashed OTPs
- `app_profiles` — last login + optional admin override
- `app_sessions` — refresh token hashes

RLS is enabled and direct `anon` / `authenticated` access is revoked. Edge functions use the service role.

## Edge function

Deploy:

```bash
supabase functions deploy member-auth
```

[`supabase/config.toml`](supabase/config.toml) sets `verify_jwt = false` for this function because the app uses its own bearer tokens after verify.

### Routes

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/request-code` | `{ "email": "..." }` — always returns generic success |
| `POST` | `/verify-code` | `{ "email": "...", "code": "123456" }` — returns `AuthSession` JSON |
| `POST` | `/refresh` | `{ "refreshToken": "..." }` — rotates session; re-checks Status=2 |
| `GET` | `/me` | `Authorization: Bearer <accessToken>` |
| `POST` | `/sync-members` | `x-sync-secret` header — pulls ChamberMaster members |

### Secrets

```bash
supabase secrets set AUTH_JWT_SECRET="$(openssl rand -hex 32)"
supabase secrets set RESEND_API_KEY=<resend_api_key>
supabase secrets set AUTH_EMAIL_FROM="WKCC Perks <noreply@yourdomain.com>"
supabase secrets set CHAMBERMASTER_API_KEY=<chambermaster_api_key>
supabase secrets set CHAMBERMASTER_BASE_URL=https://api.chambermaster.com
supabase secrets set MEMBER_SYNC_SECRET="$(openssl rand -hex 24)"

# Optional local/staging helper (never enable in production):
# supabase secrets set AUTH_DEBUG_RETURN_CODE=true
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically to edge functions.

Without `RESEND_API_KEY`, codes are logged server-side only (useful for local testing).

## Resend (OTP email delivery)

Live OTP emails are sent by Resend from `member-auth`. If the key is missing, `request-code` still returns success and writes `login_codes`, but **no email is sent**.

### Create a Resend API key

1. Sign up / sign in at [https://resend.com](https://resend.com)
2. Open **API Keys** → **Create API Key**
   - Name: e.g. `wkcc-perks-member-auth`
   - Permission: **Sending access**
   - Copy the `re_...` value (shown once)
3. Choose a from-address:
   - **Testing:** `WKCC Perks <onboarding@resend.dev>` (works immediately; Resend may only deliver to your Resend account email)
   - **Production:** verify your domain under **Domains**, then use e.g. `WKCC Perks <noreply@wilmettekenilworth.com>`

### Wire secrets to Supabase

```bash
supabase secrets set RESEND_API_KEY="re_YOUR_KEY_HERE"
supabase secrets set AUTH_EMAIL_FROM="WKCC Perks <onboarding@resend.dev>"
# after domain verify:
# supabase secrets set AUTH_EMAIL_FROM="WKCC Perks <noreply@yourdomain.com>"
```

Or run [`supabase/scripts/setup-resend.sh`](supabase/scripts/setup-resend.sh) and paste the key when prompted.

Secrets apply on the next edge-function invocation. Redeploy only if needed:

```bash
supabase functions deploy member-auth --no-verify-jwt
```

### OTP email not arriving

| Symptom | Likely cause |
|---|---|
| App advances to code entry, no email | Missing `RESEND_API_KEY` (codes still appear in `login_codes`) |
| No `login_codes` row for that email | Not eligible (`status != 2`, empty email, or `DisableLogin`) or still on mock auth |
| Resend logs show reject / bounce | Unverified domain, or onboarding sender restricted to account email |
| Edge logs: `Failed to send email: ...` | Invalid key or bad `AUTH_EMAIL_FROM` |

Quick checks:

```bash
supabase secrets list   # confirm RESEND_API_KEY is listed
supabase db query --linked "select email, created_at, consumed_at from login_codes order by created_at desc limit 5;"
```

Also check Resend **Emails / Logs** and Supabase **Edge Functions → member-auth** logs.

## iOS configuration

In [`AppConfig.swift`](Wilmette%20Kenilworth%20Perks/Core/Utilities/AppConfig.swift):

1. `memberAuthBaseURL` is set to `https://wbzmpylhlsikgzpmfksl.supabase.co/functions/v1/member-auth`
2. `supabaseAnonKey` is set to the project anon key
3. Set `useMockAuth = false` to hit the live backend

When live auth is on, deals / submissions / admin perks also use the [`perks`](LIVE_PROMOTIONS_SETUP.md) edge function (`AppConfig.perksBaseURL`).

Mock mode still accepts any 6-digit code after requesting a login code.

## Sync members from ChamberMaster

One-shot / cron:

```bash
curl -X POST \
  "https://<project>.supabase.co/functions/v1/member-auth/sync-members" \
  -H "x-sync-secret: $MEMBER_SYNC_SECRET" \
  -H "Content-Type: application/json"
```

Or use the helper script:

```bash
./supabase/scripts/sync-members.sh
```

The sync endpoint expects a JSON member list from `GET {CHAMBERMASTER_BASE_URL}/api/v1/members` with `X-ApiKey`. Adjust the path in [`supabase/functions/member-auth/index.ts`](supabase/functions/member-auth/index.ts) if your ChamberMaster tenant uses a different members URL.

## Admin override

To grant chamber-admin entitlements for a verified email:

```sql
insert into public.app_profiles (email, cm_id, is_chamber_admin)
values ('executivedirector@wilmettekenilworth.com', <cm_id>, true)
on conflict (email) do update
set is_chamber_admin = true, updated_at = now();
```

## Security rules

- Never put `CHAMBERMASTER_API_KEY` in the iOS app
- Never call ChamberMaster directly from the client
- Do not enable `AUTH_DEBUG_RETURN_CODE` in production
- Prefer short access-token TTL; refresh re-validates active membership
