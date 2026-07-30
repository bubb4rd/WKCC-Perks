# Live Promotions Setup

Deals and promotion submissions live in Supabase Postgres and are served by the `perks` edge function. The iOS app does **not** query tables directly — it sends the member session JWT the same way `member-auth` works.

## Architecture

1. Member signs in via `member-auth` and stores an access token in Keychain
2. Deals / submit / admin screens call `perks` with `Authorization: Bearer <accessToken>`
3. The edge function verifies the JWT (`AUTH_JWT_SECRET`), resolves admin from `app_profiles.is_chamber_admin`, and reads/writes with the service role

**Policies**

- Member submissions stay **pending** until an admin approves (approve upserts a `deals` row)
- Admin create/edit goes **live immediately** on `deals`
- Sync is load-on-appear + pull-to-refresh (no Realtime in this phase)

## Database

Apply migrations (includes auth tables + live promotions):

```bash
supabase db push
```

If `db push` complains about remote migration versions missing locally, repair history to match this repo, then push again:

```bash
supabase migration repair --status reverted <orphan-remote-version>
supabase migration repair --status applied 20260710162200
supabase db push
```

Migration: [`supabase/migrations/20260718072807_live_promotions.sql`](supabase/migrations/20260718072807_live_promotions.sql)

Tables:

- `deals` — published perks catalog (admin create / approved submissions; no mock `biz-*` seeds)
- `promotion_submissions` — member submission queue

RLS is enabled; `anon` / `authenticated` have no grants. Only the edge function (service role) touches these tables.

## Edge function

Deploy:

```bash
supabase functions deploy perks
```

[`supabase/config.toml`](supabase/config.toml) sets `verify_jwt = false` because the app uses its own session bearer token (not Supabase Auth JWTs).

Requires the same `AUTH_JWT_SECRET` already used by `member-auth`. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.

### Routes

| Method | Path | Who | Behavior |
|---|---|---|---|
| `GET` | `/deals` | member | Active deals (not expired) |
| `GET` | `/deals/:id` | member | Deal detail |
| `GET` | `/submissions` | admin (or own for member) | List; optional `?status=` |
| `GET` | `/submissions/:id` | admin / owner | Submission detail |
| `POST` | `/submissions` | member | Create pending submission |
| `PATCH` | `/submissions/:id` | admin / owner | Update while pending |
| `POST` | `/submissions/:id/approve` | admin | Approve + insert deal |
| `POST` | `/submissions/:id/reject` | admin | Reject (`{ "notes": "..." }`) |
| `GET` | `/submissions/pending-count` | admin | Pending queue size |
| `GET` / `POST` | `/admin/deals` | admin | List / create live perks |
| `GET` / `PATCH` | `/admin/deals/:id` | admin | Detail / update |

## iOS configuration

In [`AppConfig.swift`](Wilmette%20Kenilworth%20Perks/Core/Utilities/AppConfig.swift):

1. `perksBaseURL` → `https://wbzmpylhlsikgzpmfksl.supabase.co/functions/v1/perks`
2. `supabaseAnonKey` — same anon key used for `member-auth`
3. Set `useMockAuth = false` to use live auth **and** live deals/submissions/admin services

When `useMockAuth = true`, the app keeps in-memory mock deals and submissions.

## Verify across devices

1. Deploy migration + `perks` function
2. On device A (admin): set `useMockAuth = false`, sign in, create a perk **or** approve a submission
3. On device B: sign in as any entitled member, open Deals, pull to refresh
4. Confirm the new perk appears on device B without restarting the app beyond a refresh

## Security rules

- Never put the service role key in the iOS app
- Do not grant PostgREST access to `deals` / `promotion_submissions` for `anon` or `authenticated`
- Admin checks come from `app_profiles.is_chamber_admin`, not client-supplied flags
