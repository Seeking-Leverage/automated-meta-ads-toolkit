#!/usr/bin/env bash
# pull-insights.sh — snapshot campaign insights into the campaign insights/ folder.
#
# Reads campaign ID from clients/<client>/campaigns/<slug>/state.json.
#
# Usage:
#   pull-insights.sh <client> <slug> [YYYY-MM-DD]
#
# Default date is today (UTC). Writes to:
#   clients/<client>/campaigns/<slug>/insights/<date>/

set -euo pipefail

CLIENT="${1:-}"
SLUG="${2:-}"
DATE="${3:-$(date -u +%Y-%m-%d)}"

if [[ -z "$CLIENT" || -z "$SLUG" ]]; then
  echo "usage: $(basename "$0") <client> <slug> [YYYY-MM-DD]" >&2
  echo "example: $(basename "$0") acme-co summer-sale-jul26" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
META="$HARNESS_DIR/bin/meta"
STATE_FILE="$HARNESS_DIR/clients/$CLIENT/campaigns/$SLUG/state.json"
OUT_DIR="$HARNESS_DIR/clients/$CLIENT/campaigns/$SLUG/insights/$DATE"

[[ -f "$STATE_FILE" ]] || { echo "error: state.json not found at $STATE_FILE" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq required" >&2; exit 1; }

CAMPAIGN_ID="$(jq -r '.campaign.id // empty' "$STATE_FILE")"
[[ -n "$CAMPAIGN_ID" ]] || { echo "error: no campaign.id in state.json" >&2; exit 1; }

AD_ACCOUNT_ID="$(jq -r '.ad_account_id // empty' "$STATE_FILE")"
FIELDS="spend,impressions,reach,frequency,clicks,ctr,cpc,cpm,actions,cost_per_action_type"

mkdir -p "$OUT_DIR"

pull() {
  local out="$1"; shift
  local attempt raw
  for attempt in 1 2 3 4 5; do
    raw=$("$META" "$CLIENT" -o json --no-input ads ${AD_ACCOUNT_ID:+--ad-account-id "$AD_ACCOUNT_ID"} "$@" 2>/dev/null \
      | grep -v -iE 'warning|progress|^\s*$' || true)
    if echo "$raw" | python3 -c "import sys,json;json.load(sys.stdin)" >/dev/null 2>&1; then
      echo "$raw" > "$out"
      echo "OK   $out"
      return 0
    fi
    sleep 1
  done
  echo "FAIL $out (after 5 attempts)"
  return 1
}

echo "Client: $CLIENT | Slug: $SLUG | Campaign: $CAMPAIGN_ID | Date: $DATE"
echo "Output: $OUT_DIR"
echo ""

pull "$OUT_DIR/lifetime-summary.json"     insights get --campaign-id "$CAMPAIGN_ID" --date-preset maximum   --fields "$FIELDS"
pull "$OUT_DIR/last-30d-summary.json"     insights get --campaign-id "$CAMPAIGN_ID" --date-preset last_30d  --fields "$FIELDS"
pull "$OUT_DIR/last-7d-summary.json"      insights get --campaign-id "$CAMPAIGN_ID" --date-preset last_7d   --fields "$FIELDS"
pull "$OUT_DIR/mtd-summary.json"          insights get --campaign-id "$CAMPAIGN_ID" --date-preset this_month --fields "$FIELDS"
pull "$OUT_DIR/last-7d-by-platform.json"  insights get --campaign-id "$CAMPAIGN_ID" --date-preset last_7d   --fields "$FIELDS" --breakdown publisher_platform

# Per-ad insights (no --breakdown ad in CLI)
ADS_LEN="$(jq '.ads | length' "$STATE_FILE")"
if [[ "$ADS_LEN" -gt 0 ]]; then
  mkdir -p "$OUT_DIR/per-ad"
  jq -c '.ads[]' "$STATE_FILE" | while read -r ad; do
    ad_id="$(echo "$ad" | jq -r '.id')"
    ad_name="$(echo "$ad" | jq -r '.name')"
    safe_name="$(echo "$ad_name" | tr ' ' '_' | tr -cd '[:alnum:]_-')"
    pull "$OUT_DIR/per-ad/${safe_name}-last-7d.json" \
      insights get --ad-id "$ad_id" --date-preset last_7d --fields "$FIELDS" || true
  done
fi

echo ""
echo "done. insights saved to $OUT_DIR"