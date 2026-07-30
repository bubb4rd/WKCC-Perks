#!/usr/bin/env bash
# Wire Resend secrets for member-auth OTP email delivery.
# Usage:
#   ./supabase/scripts/setup-resend.sh
#   RESEND_API_KEY=re_xxx ./supabase/scripts/setup-resend.sh
#   AUTH_EMAIL_FROM='WKCC Perks <noreply@example.com>' ./supabase/scripts/setup-resend.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FROM_DEFAULT='WKCC Perks <onboarding@resend.dev>'
AUTH_EMAIL_FROM="${AUTH_EMAIL_FROM:-$FROM_DEFAULT}"

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  echo "Paste your Resend API key (re_...), then press Enter:"
  read -r RESEND_API_KEY
fi

if [[ -z "${RESEND_API_KEY}" || "${RESEND_API_KEY}" != re_* ]]; then
  echo "Error: RESEND_API_KEY must start with re_" >&2
  exit 1
fi

echo "Setting RESEND_API_KEY and AUTH_EMAIL_FROM on the linked Supabase project..."
supabase secrets set \
  "RESEND_API_KEY=${RESEND_API_KEY}" \
  "AUTH_EMAIL_FROM=${AUTH_EMAIL_FROM}"

echo "Done. Secrets apply on the next member-auth invocation."
echo "Test: request a login code in the app (useMockAuth = false), then check inbox + spam."
echo "Optional redeploy: supabase functions deploy member-auth --no-verify-jwt"
