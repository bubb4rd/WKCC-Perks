#!/usr/bin/env bash
set -euo pipefail

# Sync ChamberMaster members into Supabase via the member-auth edge function.
#
# Required env:
#   SUPABASE_FUNCTIONS_BASE  e.g. https://xxxx.supabase.co/functions/v1
#   MEMBER_SYNC_SECRET       must match the edge function secret

if [[ -z "${SUPABASE_FUNCTIONS_BASE:-}" || -z "${MEMBER_SYNC_SECRET:-}" ]]; then
  echo "Set SUPABASE_FUNCTIONS_BASE and MEMBER_SYNC_SECRET before running." >&2
  exit 1
fi

BASE="${SUPABASE_FUNCTIONS_BASE%/}"

curl -fsS -X POST \
  "${BASE}/member-auth/sync-members" \
  -H "x-sync-secret: ${MEMBER_SYNC_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{}'

echo
echo "Sync request completed."
