#!/usr/bin/env bash
set -euo pipefail

# Sync Chambermate members into Supabase via the member-auth edge function.
#
# Required env:
#   SUPABASE_FUNCTIONS_BASE  e.g. https://xxxx.supabase.co/functions/v1
#   MEMBER_SYNC_SECRET       must match the edge function secret
#
# Optional env:
#   SYNC_CATEGORIES          "dry" or "apply" to also run sync-categories
#                            afterwards (dry run reports changes, writes nothing)
#   SYNC_HOT_DEALS           set to 1 to also mirror the Chambermate Hot Deals
#                            board into hot_deals afterwards

if [[ -z "${SUPABASE_FUNCTIONS_BASE:-}" || -z "${MEMBER_SYNC_SECRET:-}" ]]; then
  echo "Set SUPABASE_FUNCTIONS_BASE and MEMBER_SYNC_SECRET before running." >&2
  exit 1
fi

case "${SYNC_CATEGORIES:-}" in
  "") ;;
  dry) CATEGORIES_BODY='{"dryRun":true}' ;;
  apply) CATEGORIES_BODY='{"dryRun":false}' ;;
  *)
    echo "SYNC_CATEGORIES must be \"dry\" or \"apply\"." >&2
    exit 1
    ;;
esac

BASE="${SUPABASE_FUNCTIONS_BASE%/}"

curl -fsS -X POST \
  "${BASE}/member-auth/sync-members" \
  -H "x-sync-secret: ${MEMBER_SYNC_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{}'

echo
echo "Sync request completed."

if [[ "${SYNC_HOT_DEALS:-}" == "1" ]]; then
  curl -fsS -X POST \
    "${BASE}/member-auth/sync-hot-deals" \
    -H "x-sync-secret: ${MEMBER_SYNC_SECRET}" \
    -H "Content-Type: application/json" \
    -d '{}'

  echo
  echo "Hot deals sync completed."
fi

if [[ -n "${CATEGORIES_BODY:-}" ]]; then
  curl -fsS -X POST \
    "${BASE}/member-auth/sync-categories" \
    -H "x-sync-secret: ${MEMBER_SYNC_SECRET}" \
    -H "Content-Type: application/json" \
    -d "${CATEGORIES_BODY}"

  echo
  echo "Category sync (${SYNC_CATEGORIES}) completed."
fi
