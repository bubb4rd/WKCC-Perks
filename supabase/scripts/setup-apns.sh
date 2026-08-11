#!/usr/bin/env bash
# Wire APNs secrets for WKCC Perks push notifications (Debug / sandbox by default).
# Usage:
#   ./supabase/scripts/setup-apns.sh /path/to/AuthKey_XXXXX.p8 YOUR_KEY_ID
#   APNS_PRODUCTION=true ./supabase/scripts/setup-apns.sh ./AuthKey_XXXXX.p8 ABCD123456
#
# Team ID and bundle ID default to the WKCC Perks project values.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

P8_PATH="${1:-}"
KEY_ID="${2:-${APNS_KEY_ID:-}}"
TEAM_ID="${APNS_TEAM_ID:-87BJQUWN86}"
BUNDLE_ID="${APNS_BUNDLE_ID:-WKCC.Wilmette-Kenilworth-Perks}"
PRODUCTION="${APNS_PRODUCTION:-false}"

if [[ -z "$P8_PATH" ]]; then
  echo "Usage: $0 /path/to/AuthKey_XXXXX.p8 KEY_ID"
  echo "Example: $0 ~/Downloads/AuthKey_AB12CD34EF.p8 AB12CD34EF"
  exit 1
fi

if [[ ! -f "$P8_PATH" ]]; then
  echo "Error: file not found: $P8_PATH" >&2
  exit 1
fi

if [[ -z "$KEY_ID" ]]; then
  # AuthKey_XXXXX.p8 → XXXXX
  base="$(basename "$P8_PATH")"
  if [[ "$base" =~ AuthKey_([A-Z0-9]+)\.p8 ]]; then
    KEY_ID="${BASH_REMATCH[1]}"
    echo "Inferred Key ID from filename: $KEY_ID"
  else
    echo "Paste APNs Key ID, then press Enter:"
    read -r KEY_ID
  fi
fi

if [[ -z "$KEY_ID" ]]; then
  echo "Error: APNS_KEY_ID is required" >&2
  exit 1
fi

PRIVATE_KEY="$(cat "$P8_PATH")"
if [[ "$PRIVATE_KEY" != *"BEGIN PRIVATE KEY"* ]]; then
  echo "Error: $P8_PATH does not look like an APNs .p8 PEM" >&2
  exit 1
fi

echo "Setting APNs secrets on linked Supabase project..."
echo "  APNS_KEY_ID=$KEY_ID"
echo "  APNS_TEAM_ID=$TEAM_ID"
echo "  APNS_BUNDLE_ID=$BUNDLE_ID"
echo "  APNS_PRODUCTION=$PRODUCTION"
echo "  APNS_PRIVATE_KEY=<from $P8_PATH>"

supabase secrets set \
  "APNS_KEY_ID=${KEY_ID}" \
  "APNS_TEAM_ID=${TEAM_ID}" \
  "APNS_BUNDLE_ID=${BUNDLE_ID}" \
  "APNS_PRIVATE_KEY=${PRIVATE_KEY}" \
  "APNS_PRODUCTION=${PRODUCTION}"

echo "Done. Secrets apply on the next perks invocation (no redeploy required)."
echo "Next: Debug build on a physical device → sign in → Allow notifications → check device_push_tokens."
